import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:logging/logging.dart';

/// Hosts that some networks answer with a dead address; they are looked up
/// over HTTPS when the system's answer is useless.
const Set<String> kDohHosts = <String>{'api.themoviedb.org', 'api.tmdb.org'};

const List<String> _kDohEndpoints = <String>[
  'https://cloudflare-dns.com/dns-query',
  'https://dns.google/resolve',
];
const Duration _kDohTimeout = Duration(seconds: 6);
const Duration _kCacheFor = Duration(minutes: 10);
const int _kDnsTypeA = 1;

final Logger _log = Logger('DohFallback');

/// A loopback or empty answer means the network sinkholes the name.
bool isSinkholed(InternetAddress address) =>
    address.isLoopback ||
    address.isLinkLocal ||
    address.address == '0.0.0.0' ||
    address.address == '::';

/// The IPv4 addresses in a DNS-over-HTTPS JSON answer.
List<InternetAddress> parseDohAnswer(Object? json) {
  if (json is! Map<String, dynamic>) return const <InternetAddress>[];
  final Object? answers = json['Answer'];
  if (answers is! List<dynamic>) return const <InternetAddress>[];
  final List<InternetAddress> out = <InternetAddress>[];
  for (final Object? a in answers) {
    if (a is! Map<String, dynamic> || a['type'] != _kDnsTypeA) continue;
    final Object? data = a['data'];
    final InternetAddress? address = data is String
        ? InternetAddress.tryParse(data)
        : null;
    if (address != null && !isSinkholed(address)) out.add(address);
  }
  return out;
}

/// Finds a usable address for a host the system resolves badly.
class DohResolver {
  DohResolver({
    Future<List<InternetAddress>> Function(String host)? systemLookup,
    Future<Object?> Function(String url)? fetchJson,
    DateTime Function()? now,
  }) : _systemLookup = systemLookup ?? InternetAddress.lookup,
       _fetchJson = fetchJson ?? _defaultFetch,
       _now = now ?? DateTime.now;

  final Future<List<InternetAddress>> Function(String host) _systemLookup;
  final Future<Object?> Function(String url) _fetchJson;
  final DateTime Function() _now;
  final Map<String, ({InternetAddress? address, DateTime at})> _cache =
      <String, ({InternetAddress? address, DateTime at})>{};

  /// Null when the system's own answer is fine and should be used as is.
  Future<InternetAddress?> override(String host) async {
    final ({InternetAddress? address, DateTime at})? cached = _cache[host];
    if (cached != null && _now().difference(cached.at) < _kCacheFor) {
      return cached.address;
    }
    final InternetAddress? found = await _resolve(host);
    _cache[host] = (address: found, at: _now());
    return found;
  }

  Future<InternetAddress?> _resolve(String host) async {
    try {
      final List<InternetAddress> system = await _systemLookup(host);
      if (system.any((InternetAddress a) => !isSinkholed(a))) return null;
    } on SocketException {
      // No answer at all is as bad as a sinkholed one.
    }
    for (final String endpoint in _kDohEndpoints) {
      try {
        final Object? json = await _fetchJson(
          '$endpoint?name=$host&type=A',
        ).timeout(_kDohTimeout);
        final List<InternetAddress> addresses = parseDohAnswer(json);
        if (addresses.isNotEmpty) {
          _log.info('$host answered with a dead address, using $endpoint');
          return addresses.first;
        }
      } on Exception catch (e) {
        _log.warning('DNS over HTTPS failed at $endpoint: $e');
      }
    }
    return null;
  }

  static Future<Object?> _defaultFetch(String url) async {
    final HttpClient client = HttpClient();
    try {
      final HttpClientRequest request = await client.getUrl(Uri.parse(url));
      request.headers.set('accept', 'application/dns-json');
      final HttpClientResponse response = await request.close();
      return jsonDecode(await response.transform(utf8.decoder).join());
    } finally {
      client.close(force: true);
    }
  }
}

/// A connection for [uri]: through the proxy if there is one, to the address
/// DNS over HTTPS found if the host needs it, else the way Dart would.
Future<ConnectionTask<Socket>> connectWithFallback(
  DohResolver resolver,
  Uri uri,
  String? proxyHost,
  int? proxyPort,
) async {
  // Through a proxy the client tunnels and secures the link itself.
  if (proxyHost != null) return Socket.startConnect(proxyHost, proxyPort ?? 80);
  final bool secure = uri.isScheme('https');
  final int port = uri.hasPort ? uri.port : (secure ? 443 : 80);
  final InternetAddress? address = kDohHosts.contains(uri.host)
      ? await resolver.override(uri.host)
      : null;
  if (address != null) {
    final ConnectionTask<Socket> plain = await Socket.startConnect(
      address,
      port,
    );
    if (!secure) return plain;
    // The name stays the real one, so the certificate is checked against it.
    final Future<Socket> tls = plain.socket.then<Socket>(
      (Socket s) => SecureSocket.secure(s, host: uri.host),
    );
    return ConnectionTask.fromSocket<Socket>(tls, plain.cancel);
  }
  return secure
      ? SecureSocket.startConnect(uri.host, port)
      : Socket.startConnect(uri.host, port);
}

/// Makes [dio] reach the hosts in [kDohHosts] even on a network that
/// sinkholes their names.
void applyDohFallback(Dio dio, {DohResolver? resolver}) {
  final DohResolver doh = resolver ?? DohResolver();
  dio.httpClientAdapter = IOHttpClientAdapter(
    createHttpClient: () {
      final HttpClient client = HttpClient();
      client.connectionFactory = (Uri uri, String? proxyHost, int? proxyPort) =>
          connectWithFallback(doh, uri, proxyHost, proxyPort);
      return client;
    },
  );
}
