import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';
import 'package:path/path.dart' as p;

enum LiveService { youtube, twitch, kick }

class LiveTool {
  const LiveTool(this.exe, this.wingetId);

  final String exe;
  final String wingetId;

  String get name => p.basenameWithoutExtension(exe);
}

const LiveTool kYtDlp = LiveTool('yt-dlp.exe', 'yt-dlp.yt-dlp');
const LiveTool kStreamlink = LiveTool(
  'streamlink.exe',
  'Streamlink.Streamlink',
);

/// yt-dlp needs a JavaScript runtime to read YouTube; it only looks for deno
/// on PATH, which a freshly installed one may not be on yet.
const LiveTool kDeno = LiveTool('deno.exe', 'DenoLand.Deno');

/// Where "Connect account" keeps the YouTube login the embedded browser made.
String youtubeCookiesPath(Map<String, String> environment) => p.join(
  environment['APPDATA'] ?? '',
  'Tonkatsu Box',
  'Tonkatsu Box',
  'youtube_cookies.txt',
);

final Logger _cookieLog = Logger('YoutubeCookies');
int _copyCounter = 0;

/// yt-dlp rewrites the cookie file it is given, YouTube rotates the login in
/// it, and two runs at once would tear the file. So each run gets its own copy
/// and the saved file is replaced only by a copy that came back whole.
Future<T> withYoutubeCookies<T>(
  Map<String, String> environment,
  Future<T> Function(List<String> cookieArgs) run,
) async {
  final File master = File(youtubeCookiesPath(environment));
  if (!master.existsSync()) return run(const <String>[]);
  final File copy = File('${master.path}.${pid}_${_copyCounter++}.tmp');
  master.copySync(copy.path);
  try {
    return await run(<String>['--cookies', copy.path]);
  } finally {
    _keepRotatedCookies(copy, master);
  }
}

void _keepRotatedCookies(File copy, File master) {
  try {
    if (copy.existsSync() &&
        copy.lengthSync() > 0 &&
        copy.readAsStringSync().startsWith('# Netscape')) {
      copy.renameSync(master.path);
    } else if (copy.existsSync()) {
      copy.deleteSync();
    }
  } on FileSystemException catch (e) {
    _cookieLog.warning('could not store the refreshed YouTube login: $e');
  }
}

const Duration _kResolveTimeout = Duration(seconds: 60);

LiveTool toolFor(LiveService service) =>
    service == LiveService.youtube ? kYtDlp : kStreamlink;

/// A pasted link stays as it is; a bare channel name becomes the service URL,
/// and YouTube free text becomes a one-result search.
String normalizeLiveInput(LiveService service, String input) {
  final String text = input.trim();
  if (text.contains('://')) return text;
  return switch (service) {
    LiveService.twitch => 'https://twitch.tv/$text',
    LiveService.kick => 'https://kick.com/$text',
    LiveService.youtube => 'ytsearch1:$text',
  };
}

/// Looks for [tool] on PATH and in the places winget and the installers use.
/// A program installed a minute ago is often not on this process's PATH yet.
String? findTool(
  LiveTool tool,
  Map<String, String> environment, {
  bool Function(String path) exists = _fileExists,
  List<String> Function(String dir) listDirs = _listDirs,
}) {
  final String? localAppData = environment['LOCALAPPDATA'];
  final List<String> packageDirs = localAppData == null || localAppData.isEmpty
      ? const <String>[]
      : listDirs(
          p.join(localAppData, 'Microsoft', 'WinGet', 'Packages'),
        ).where((String d) => p.basename(d).startsWith(tool.wingetId)).toList();
  final List<String> dirs = <String>[
    ...(environment['PATH'] ?? environment['Path'] ?? '')
        .split(';')
        .where((String d) => d.isNotEmpty),
    ...packageDirs,
    if (localAppData != null && localAppData.isNotEmpty) ...<String>[
      p.join(localAppData, 'Programs', 'Streamlink', 'bin'),
    ],
    if (environment['LOCALAPPDATA'] case final String dir when dir.isNotEmpty)
      p.join(dir, 'Microsoft', 'WinGet', 'Links'),
    if (environment['ProgramFiles'] case final String dir when dir.isNotEmpty)
      p.join(dir, 'Streamlink', 'bin'),
    if (environment['ProgramFiles(x86)'] case final String dir
        when dir.isNotEmpty)
      p.join(dir, 'Streamlink', 'bin'),
  ];
  for (final String dir in dirs) {
    final String candidate = p.join(dir, tool.exe);
    if (exists(candidate)) return candidate;
  }
  return null;
}

bool _fileExists(String path) => File(path).existsSync();

List<String> _listDirs(String dir) {
  final Directory directory = Directory(dir);
  if (!directory.existsSync()) return const <String>[];
  return <String>[
    for (final FileSystemEntity e in directory.listSync())
      if (e is Directory) e.path,
  ];
}

class StreamResolveException implements Exception {
  const StreamResolveException(this.message, {this.missingTool});

  final String message;

  /// Set when the helper program is not installed.
  final LiveTool? missingTool;

  @override
  String toString() => 'StreamResolveException: $message';
}

final Provider<StreamResolver> streamResolverProvider =
    Provider<StreamResolver>((Ref ref) => const StreamResolver());

/// Turns a YouTube, Twitch or Kick link into a direct stream URL that any
/// player can open, using yt-dlp or streamlink.
class StreamResolver {
  const StreamResolver();

  static final Logger _log = Logger('StreamResolver');

  /// [useAccount] lets yt-dlp use the connected YouTube account (age gates,
  /// private videos); if that fails the plain call is tried once.
  Future<String> resolve(
    LiveService service,
    String input, {
    bool useAccount = false,
  }) async {
    if (service == LiveService.youtube && useAccount) {
      try {
        return await _resolve(service, input, withAccount: true);
      } on StreamResolveException catch (e) {
        if (e.missingTool != null) rethrow;
        _log.warning('retrying without the account: ${e.message}');
      }
    }
    return _resolve(service, input, withAccount: false);
  }

  Future<String> _resolve(
    LiveService service,
    String input, {
    required bool withAccount,
  }) async {
    final LiveTool tool = toolFor(service);
    final String? exe = findTool(tool, Platform.environment);
    if (exe == null) {
      throw StreamResolveException(
        '${tool.name} is not installed',
        missingTool: tool,
      );
    }
    final String url = normalizeLiveInput(service, input);
    final String? deno = findTool(kDeno, Platform.environment);
    List<String> argsWith(List<String> cookieArgs) =>
        service == LiveService.youtube
        ? <String>[
            if (deno != null) ...<String>['--js-runtimes', 'deno:$deno'],
            ...cookieArgs,
            '-g',
            '-f',
            'b/best',
            '--no-playlist',
            url,
          ]
        : <String>['--stream-url', url, 'best'];
    _log.info('resolving ${tool.name} $url');
    final ProcessResult result = withAccount
        ? await withYoutubeCookies<ProcessResult>(
            Platform.environment,
            (List<String> cookieArgs) => Process.run(
              exe,
              argsWith(cookieArgs),
            ).timeout(_kResolveTimeout),
          )
        : await Process.run(
            exe,
            argsWith(const <String>[]),
          ).timeout(_kResolveTimeout);
    final String out = '${result.stdout}'.trim();
    final String line = out.split('\n').first.trim();
    if (result.exitCode != 0 || !line.startsWith('http')) {
      final String err = '${result.stderr}'.trim();
      _log.warning('resolve failed (${result.exitCode}): $err');
      throw StreamResolveException(
        err.isEmpty ? 'no stream found' : err.split('\n').last,
      );
    }
    return line;
  }
}
