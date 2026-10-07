import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:tonkatsu_box/features/watch/youtube_cookies_export.dart';

String reply(List<Map<String, Object?>> cookies) =>
    jsonEncode(<String, Object?>{'cookies': cookies});

Map<String, Object?> cookie(
  String name,
  String domain, {
  String value = 'v',
  bool httpOnly = false,
  bool secure = true,
  Object expires = 1900000000.5,
  String path = '/',
}) => <String, Object?>{
  'name': name,
  'value': value,
  'domain': domain,
  'path': path,
  'httpOnly': httpOnly,
  'secure': secure,
  'expires': expires,
};

void main() {
  group('parseBrowserCookies', () {
    test('reads the fields of a DevTools reply', () {
      final List<BrowserCookie> cookies = parseBrowserCookies(
        reply(<Map<String, Object?>>[
          cookie('SID', '.google.com', httpOnly: true),
        ]),
      );
      expect(cookies, hasLength(1));
      expect(cookies.single.name, 'SID');
      expect(cookies.single.domain, '.google.com');
      expect(cookies.single.httpOnly, isTrue);
      expect(cookies.single.secure, isTrue);
      expect(cookies.single.expires, 1900000000);
    });

    test('a session cookie (expires -1) becomes 0', () {
      final List<BrowserCookie> cookies = parseBrowserCookies(
        reply(<Map<String, Object?>>[cookie('S', '.google.com', expires: -1)]),
      );
      expect(cookies.single.expires, 0);
    });

    test('rows without a name or a domain are dropped', () {
      final List<BrowserCookie> cookies = parseBrowserCookies(
        reply(<Map<String, Object?>>[
          cookie('', '.google.com'),
          cookie('X', ''),
          cookie('OK', '.youtube.com'),
        ]),
      );
      expect(cookies.map((BrowserCookie c) => c.name), <String>['OK']);
    });

    test('anything else is an empty list', () {
      expect(parseBrowserCookies('{}'), isEmpty);
      expect(parseBrowserCookies('[]'), isEmpty);
      expect(parseBrowserCookies('{"cookies":"x"}'), isEmpty);
    });
  });

  group('hasYoutubeLogin', () {
    test('LOGIN_INFO on youtube.com means signed in', () {
      expect(
        hasYoutubeLogin(
          parseBrowserCookies(
            reply(<Map<String, Object?>>[cookie('LOGIN_INFO', '.youtube.com')]),
          ),
        ),
        isTrue,
      );
    });

    test('the Google cookies alone are not enough yet', () {
      expect(
        hasYoutubeLogin(
          parseBrowserCookies(
            reply(<Map<String, Object?>>[
              cookie('SID', '.google.com'),
              cookie('SAPISID', '.google.com'),
            ]),
          ),
        ),
        isFalse,
      );
    });

    test('an empty LOGIN_INFO does not count', () {
      expect(
        hasYoutubeLogin(
          parseBrowserCookies(
            reply(<Map<String, Object?>>[
              cookie('LOGIN_INFO', '.youtube.com', value: ''),
            ]),
          ),
        ),
        isFalse,
      );
    });
  });

  group('toNetscapeCookies', () {
    test('writes one tab-separated line per cookie under the header', () {
      final String text = toNetscapeCookies(
        parseBrowserCookies(
          reply(<Map<String, Object?>>[
            cookie('PREF', '.youtube.com', value: 'a=b', secure: false),
          ]),
        ),
      );
      final List<String> lines = text.trim().split('\n');
      expect(lines.first, '# Netscape HTTP Cookie File');
      expect(lines.last, '.youtube.com\tTRUE\t/\tFALSE\t1900000000\tPREF\ta=b');
    });

    test('HttpOnly cookies get the prefix yt-dlp understands', () {
      final String text = toNetscapeCookies(
        parseBrowserCookies(
          reply(<Map<String, Object?>>[
            cookie('SID', '.google.com', httpOnly: true),
          ]),
        ),
      );
      expect(text, contains('#HttpOnly_.google.com\tTRUE'));
    });

    test('a host cookie has no subdomain flag', () {
      final String text = toNetscapeCookies(
        parseBrowserCookies(
          reply(<Map<String, Object?>>[cookie('OSID', 'accounts.google.com')]),
        ),
      );
      expect(text, contains('accounts.google.com\tFALSE'));
    });

    test('keeps only YouTube and Google domains', () {
      final String text = toNetscapeCookies(
        parseBrowserCookies(
          reply(<Map<String, Object?>>[
            cookie('SID', '.google.ru'),
            cookie('LOGIN_INFO', '.youtube.com'),
            cookie('session', 'movix.ru'),
          ]),
        ),
      );
      expect(text, contains('.google.ru'));
      expect(text, contains('.youtube.com'));
      expect(text, isNot(contains('movix.ru')));
    });
  });

  group('isYoutubeSessionDomain', () {
    test('matches the account and video domains in any country', () {
      expect(isYoutubeSessionDomain('.youtube.com'), isTrue);
      expect(isYoutubeSessionDomain('accounts.google.com'), isTrue);
      expect(isYoutubeSessionDomain('.google.co.uk'), isTrue);
      expect(isYoutubeSessionDomain('example.com'), isFalse);
    });
  });
}
