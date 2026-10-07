import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';

import 'api_dio.dart';

const String kKickLanguageRu = 'ru';
const String kKickLanguageEn = 'en';
const int _kPages = 3;

// Kick answers a bare HTTP client with a challenge page, not JSON.
const String _kBrowserAgent =
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
    '(KHTML, like Gecko) Chrome/124.0 Safari/537.36';

class KickApiException implements Exception {
  const KickApiException(this.message);

  final String message;

  @override
  String toString() => 'KickApiException: $message';
}

class KickStream {
  const KickStream({
    required this.slug,
    required this.name,
    required this.title,
    required this.viewers,
    this.category,
    this.thumbnail,
  });

  final String slug;
  final String name;
  final String title;
  final int viewers;
  final String? category;
  final String? thumbnail;

  String get url => 'https://kick.com/$slug';
}

/// Streams in a `featured-livestreams` page; rows without a channel are
/// dropped.
List<KickStream> parseKickStreams(Map<String, dynamic> json) {
  final Object? rows = json['data'];
  if (rows is! List<dynamic>) return const <KickStream>[];
  final List<KickStream> streams = <KickStream>[];
  for (final Object? row in rows) {
    if (row is! Map<String, dynamic>) continue;
    final Object? channel = row['channel'];
    if (channel is! Map<String, dynamic>) continue;
    final Object? slug = channel['slug'];
    if (slug is! String || slug.isEmpty) continue;
    final Object? user = channel['user'];
    final Object? username = user is Map<String, dynamic>
        ? user['username']
        : null;
    final Object? categories = row['categories'];
    final Object? firstCategory = categories is List<dynamic>
        ? categories.firstOrNull
        : null;
    final Object? thumbnail = row['thumbnail'];
    streams.add(
      KickStream(
        slug: slug,
        name: username is String && username.isNotEmpty ? username : slug,
        title: row['session_title'] is String
            ? row['session_title'] as String
            : '',
        viewers: (row['viewer_count'] as num?)?.toInt() ?? 0,
        category: firstCategory is Map<String, dynamic>
            ? firstCategory['name'] as String?
            : null,
        thumbnail: thumbnail is Map<String, dynamic>
            ? thumbnail['src'] as String?
            : null,
      ),
    );
  }
  return streams;
}

final Provider<KickApi> kickApiProvider = Provider<KickApi>(
  (Ref ref) => KickApi(),
);

/// The live streams Kick itself lists, in one language; no key is needed.
class KickApi {
  KickApi({Dio? dio})
    : _dio =
          dio ??
          createApiDio(
            connectTimeout: const Duration(seconds: 8),
            receiveTimeout: const Duration(seconds: 20),
            headers: const <String, String>{'User-Agent': _kBrowserAgent},
          );

  static final Logger _log = Logger('KickApi');
  final Dio _dio;

  Future<List<KickStream>> liveStreams({
    String language = kKickLanguageRu,
  }) async {
    Object? firstError;
    final List<List<KickStream>?> pages =
        await Future.wait(<Future<List<KickStream>?>>[
          for (int page = 1; page <= _kPages; page++)
            _page(language, page).then<List<KickStream>?>(
              (List<KickStream> items) => items,
              onError: (Object error) {
                firstError ??= error;
                return null;
              },
            ),
        ]);
    final List<List<KickStream>> loaded = pages
        .whereType<List<KickStream>>()
        .toList();
    if (loaded.isEmpty) {
      throw KickApiException('$firstError');
    }
    final Set<String> seen = <String>{};
    final List<KickStream> streams = <KickStream>[
      for (final List<KickStream> page in loaded)
        for (final KickStream s in page)
          if (seen.add(s.slug)) s,
    ]..sort((KickStream a, KickStream b) => b.viewers.compareTo(a.viewers));
    _log.info('kick $language: ${streams.length} live streams');
    return streams;
  }

  Future<List<KickStream>> _page(String language, int page) async {
    final Response<dynamic> response = await _dio.get<dynamic>(
      'https://kick.com/stream/featured-livestreams/$language',
      queryParameters: <String, dynamic>{'page': page},
    );
    final Object? data = response.data;
    if (data is! Map<String, dynamic>) {
      throw const KickApiException('Unexpected Kick response');
    }
    return parseKickStreams(data);
  }
}

final AutoDisposeFutureProviderFamily<List<KickStream>, String>
kickStreamsProvider = FutureProvider.autoDispose
    .family<List<KickStream>, String>(
      (Ref ref, String language) =>
          ref.watch(kickApiProvider).liveStreams(language: language),
    );
