import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tonkatsu_box/core/api/doh_fallback_io.dart';

Map<String, dynamic> answer(List<Map<String, dynamic>> records) =>
    <String, dynamic>{'Answer': records};

Map<String, dynamic> a(String ip) => <String, dynamic>{'type': 1, 'data': ip};

void main() {
  group('isSinkholed', () {
    test('loopback, link-local and empty addresses are dead ends', () {
      expect(isSinkholed(InternetAddress('127.0.0.1')), isTrue);
      expect(isSinkholed(InternetAddress('0.0.0.0')), isTrue);
      expect(isSinkholed(InternetAddress('169.254.1.1')), isTrue);
      expect(isSinkholed(InternetAddress('::1')), isTrue);
    });

    test('a public address is fine', () {
      expect(isSinkholed(InternetAddress('3.173.161.20')), isFalse);
    });
  });

  group('parseDohAnswer', () {
    test('keeps the A records and drops the rest', () {
      final List<InternetAddress> out = parseDohAnswer(
        answer(<Map<String, dynamic>>[
          <String, dynamic>{'type': 5, 'data': 'alias.example.'},
          a('3.173.161.20'),
          a('3.173.161.21'),
        ]),
      );
      expect(out.map((InternetAddress i) => i.address), <String>[
        '3.173.161.20',
        '3.173.161.21',
      ]);
    });

    test('a sinkholed answer from DoH is not trusted either', () {
      expect(
        parseDohAnswer(answer(<Map<String, dynamic>>[a('127.0.0.1')])),
        isEmpty,
      );
    });

    test('anything else is empty', () {
      expect(parseDohAnswer(null), isEmpty);
      expect(parseDohAnswer(<String, dynamic>{}), isEmpty);
      expect(parseDohAnswer(<String, dynamic>{'Answer': 'x'}), isEmpty);
    });
  });

  group('DohResolver.override', () {
    DateTime clock = DateTime(2026);

    DohResolver resolver({
      required List<InternetAddress> system,
      required List<Map<String, dynamic>> doh,
      List<String>? asked,
    }) => DohResolver(
      systemLookup: (String host) async => system,
      fetchJson: (String url) async {
        asked?.add(url);
        return answer(doh);
      },
      now: () => clock,
    );

    test('a working system answer is left alone', () async {
      final List<String> asked = <String>[];
      final InternetAddress? found = await resolver(
        system: <InternetAddress>[InternetAddress('3.1.1.1')],
        doh: <Map<String, dynamic>>[a('9.9.9.9')],
        asked: asked,
      ).override('api.themoviedb.org');

      expect(found, isNull);
      expect(asked, isEmpty);
    });

    test('a sinkholed system answer is replaced by the DoH one', () async {
      final InternetAddress? found = await resolver(
        system: <InternetAddress>[InternetAddress('127.0.0.1')],
        doh: <Map<String, dynamic>>[a('3.173.161.20')],
      ).override('api.themoviedb.org');

      expect(found?.address, '3.173.161.20');
    });

    test('no system answer at all also goes to DoH', () async {
      final DohResolver r = DohResolver(
        systemLookup: (String host) async =>
            throw const SocketException('no dns'),
        fetchJson: (String url) async =>
            answer(<Map<String, dynamic>>[a('3.173.161.20')]),
        now: () => clock,
      );

      expect((await r.override('api.tmdb.org'))?.address, '3.173.161.20');
    });

    test('the answer is kept for a while, then asked again', () async {
      final List<String> asked = <String>[];
      final DohResolver r = resolver(
        system: <InternetAddress>[InternetAddress('127.0.0.1')],
        doh: <Map<String, dynamic>>[a('3.173.161.20')],
        asked: asked,
      );

      await r.override('api.themoviedb.org');
      await r.override('api.themoviedb.org');
      expect(asked, hasLength(1));

      clock = clock.add(const Duration(minutes: 11));
      await r.override('api.themoviedb.org');
      expect(asked, hasLength(2));
    });

    test('when DoH has nothing either the system answer is used', () async {
      final InternetAddress? found = await resolver(
        system: <InternetAddress>[InternetAddress('127.0.0.1')],
        doh: <Map<String, dynamic>>[],
      ).override('api.themoviedb.org');

      expect(found, isNull);
    });

    test('a DoH endpoint that throws falls through to the next', () async {
      int calls = 0;
      final DohResolver r = DohResolver(
        systemLookup: (String host) async => <InternetAddress>[
          InternetAddress('127.0.0.1'),
        ],
        fetchJson: (String url) async {
          if (calls++ == 0) throw const SocketException('blocked');
          return answer(<Map<String, dynamic>>[a('3.173.161.20')]);
        },
        now: () => clock,
      );

      expect((await r.override('api.themoviedb.org'))?.address, '3.173.161.20');
      expect(calls, 2);
    });
  });
}
