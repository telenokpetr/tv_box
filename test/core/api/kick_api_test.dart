import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:tonkatsu_box/core/api/kick_api.dart';

import '../../helpers/test_helpers.dart';

Map<String, dynamic> row(
  String slug, {
  int viewers = 10,
  String title = 'Live',
  String? user,
  bool withChannel = true,
}) => <String, dynamic>{
  if (withChannel)
    'channel': <String, dynamic>{
      'slug': slug,
      'user': <String, dynamic>{'username': user ?? slug.toUpperCase()},
    },
  'session_title': title,
  'viewer_count': viewers,
  'categories': <dynamic>[
    <String, dynamic>{'name': 'Poker'},
  ],
  'thumbnail': <String, dynamic>{'src': 'http://t/$slug.webp'},
};

Response<dynamic> page(List<Map<String, dynamic>> rows) => Response<dynamic>(
  data: <String, dynamic>{'data': rows},
  statusCode: 200,
  requestOptions: RequestOptions(),
);

void main() {
  setUpAll(registerAllFallbacks);

  group('parseKickStreams', () {
    test('reads channel, title, viewers, category and thumbnail', () {
      final List<KickStream> streams = parseKickStreams(<String, dynamic>{
        'data': <dynamic>[
          row('alice', viewers: 42, title: 'Hello', user: 'Alice'),
        ],
      });
      expect(streams, hasLength(1));
      expect(streams.single.slug, 'alice');
      expect(streams.single.name, 'Alice');
      expect(streams.single.title, 'Hello');
      expect(streams.single.viewers, 42);
      expect(streams.single.category, 'Poker');
      expect(streams.single.thumbnail, 'http://t/alice.webp');
      expect(streams.single.url, 'https://kick.com/alice');
    });

    test('rows without a channel are dropped', () {
      final List<KickStream> streams = parseKickStreams(<String, dynamic>{
        'data': <dynamic>[row('x', withChannel: false), row('ok')],
      });
      expect(streams.map((KickStream s) => s.slug), <String>['ok']);
    });

    test('a body without data is an empty list', () {
      expect(parseKickStreams(<String, dynamic>{}), isEmpty);
    });
  });

  group('KickApi.liveStreams', () {
    late MockDio dio;
    late KickApi sut;

    setUp(() {
      dio = MockDio();
      sut = KickApi(dio: dio);
    });

    test('merges the pages, drops repeats and sorts by viewers', () async {
      when(
        () => dio.get<dynamic>(
          any(),
          queryParameters: any(named: 'queryParameters'),
        ),
      ).thenAnswer((Invocation inv) async {
        final Map<String, dynamic> q =
            inv.namedArguments[#queryParameters] as Map<String, dynamic>;
        return switch (q['page']) {
          1 => page(<Map<String, dynamic>>[
            row('a', viewers: 5),
            row('b', viewers: 50),
          ]),
          2 => page(<Map<String, dynamic>>[
            row('b', viewers: 50),
            row('c', viewers: 20),
          ]),
          _ => page(<Map<String, dynamic>>[]),
        };
      });

      final List<KickStream> streams = await sut.liveStreams();

      expect(streams.map((KickStream s) => s.slug), <String>['b', 'c', 'a']);
    });

    test('a failed page is left out while the others load', () async {
      when(
        () => dio.get<dynamic>(
          any(),
          queryParameters: any(named: 'queryParameters'),
        ),
      ).thenAnswer((Invocation inv) async {
        final Map<String, dynamic> q =
            inv.namedArguments[#queryParameters] as Map<String, dynamic>;
        if (q['page'] != 1) {
          throw DioException(
            requestOptions: RequestOptions(),
            message: 'reset',
          );
        }
        return page(<Map<String, dynamic>>[row('only')]);
      });

      final List<KickStream> streams = await sut.liveStreams();

      expect(streams.map((KickStream s) => s.slug), <String>['only']);
    });

    test('fails when every page fails', () async {
      when(
        () => dio.get<dynamic>(
          any(),
          queryParameters: any(named: 'queryParameters'),
        ),
      ).thenThrow(
        DioException(requestOptions: RequestOptions(), message: 'offline'),
      );

      await expectLater(sut.liveStreams(), throwsA(isA<KickApiException>()));
    });

    test('asks for the language it was given', () async {
      when(
        () => dio.get<dynamic>(
          any(),
          queryParameters: any(named: 'queryParameters'),
        ),
      ).thenAnswer((_) async => page(<Map<String, dynamic>>[]));

      await sut.liveStreams(language: kKickLanguageEn);

      final List<dynamic> urls = verify(
        () => dio.get<dynamic>(
          captureAny(),
          queryParameters: any(named: 'queryParameters'),
        ),
      ).captured;
      expect(
        urls.every(
          (dynamic u) => u == 'https://kick.com/stream/featured-livestreams/en',
        ),
        isTrue,
      );
    });
  });
}
