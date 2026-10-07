import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:tonkatsu_box/features/watch/stream_resolver.dart';
import 'package:tonkatsu_box/features/watch/youtube_feed.dart';

void main() {
  const Map<String, String> env = <String, String>{
    'APPDATA': r'C:\Users\Me\AppData\Roaming',
  };

  group('youtubeCookiesPath', () {
    test('lives in the app data folder', () {
      expect(
        youtubeCookiesPath(env),
        p.join(
          r'C:\Users\Me\AppData\Roaming',
          'Tonkatsu Box',
          'Tonkatsu Box',
          'youtube_cookies.txt',
        ),
      );
    });
  });

  group('withYoutubeCookies', () {
    late Directory appData;
    late Map<String, String> tempEnv;
    late File master;

    setUp(() {
      appData = Directory.systemTemp.createTempSync('yt_cookies_');
      tempEnv = <String, String>{'APPDATA': appData.path};
      master = File(youtubeCookiesPath(tempEnv));
      master.parent.createSync(recursive: true);
    });

    tearDown(() => appData.deleteSync(recursive: true));

    test('no saved login means no cookie arguments', () async {
      List<String>? seen;
      await withYoutubeCookies<void>(tempEnv, (List<String> args) async {
        seen = args;
      });
      expect(seen, isEmpty);
    });

    test('runs on a private copy, not on the saved file', () async {
      master.writeAsStringSync('# Netscape HTTP Cookie File\nold\n');
      List<String>? seen;
      await withYoutubeCookies<void>(tempEnv, (List<String> args) async {
        seen = args;
      });
      expect(seen?.first, '--cookies');
      expect(seen?.last, isNot(master.path));
      expect(File(seen?.last ?? '').existsSync(), isFalse);
    });

    test('a refreshed copy replaces the saved file', () async {
      master.writeAsStringSync('# Netscape HTTP Cookie File\nold\n');
      await withYoutubeCookies<void>(tempEnv, (List<String> args) async {
        File(
          args.last,
        ).writeAsStringSync('# Netscape HTTP Cookie File\nrotated\n');
      });
      expect(master.readAsStringSync(), contains('rotated'));
    });

    test('a copy that came back torn is thrown away', () async {
      master.writeAsStringSync('# Netscape HTTP Cookie File\nold\n');
      await withYoutubeCookies<void>(tempEnv, (List<String> args) async {
        File(args.last).writeAsStringSync('');
      });
      expect(master.readAsStringSync(), contains('old'));
      expect(
        master.parent.listSync().whereType<File>().map((File f) => f.path),
        <String>[master.path],
      );
    });

    test('a failing run still cleans up its copy', () async {
      master.writeAsStringSync('# Netscape HTTP Cookie File\nold\n');
      await expectLater(
        withYoutubeCookies<void>(tempEnv, (List<String> args) async {
          throw StateError('yt-dlp died');
        }),
        throwsStateError,
      );
      expect(master.parent.listSync().whereType<File>(), hasLength(1));
    });
  });

  group('isReconnectNeeded', () {
    test('recognizes the messages YouTube gives for a dead login', () {
      expect(
        isReconnectNeeded(
          'ERROR: The provided YouTube account cookies are no longer valid.',
        ),
        isTrue,
      );
      expect(isReconnectNeeded('Sign in to confirm you are not a bot'), isTrue);
      expect(isReconnectNeeded('This video requires login'), isTrue);
    });

    test('network failures are not a dead login', () {
      expect(
        isReconnectNeeded('Unable to download webpage: timed out'),
        isFalse,
      );
      expect(isReconnectNeeded(''), isFalse);
    });
  });
}
