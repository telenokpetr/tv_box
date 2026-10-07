import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:tonkatsu_box/core/api/tmdb_api.dart';
import 'package:tonkatsu_box/features/watch/catalog_shelves.dart';

import '../../helpers/test_helpers.dart';

void main() {
  late MockTmdbApi tmdb;
  late ProviderContainer container;

  setUp(() {
    tmdb = MockTmdbApi();
    container = ProviderContainer(
      overrides: <Override>[tmdbApiProvider.overrideWithValue(tmdb)],
    );
    addTearDown(container.dispose);
  });

  group('studioCompaniesProvider', () {
    test('joins the ids of the companies that match the studio', () async {
      when(() => tmdb.searchCompanies('Netflix')).thenAnswer(
        (_) async => const <TmdbCompany>[
          TmdbCompany(id: 1, name: 'Netflix'),
          TmdbCompany(id: 2, name: 'Netflix Animation'),
          TmdbCompany(id: 3, name: 'Not A Match'),
        ],
      );

      final String ids = await container.read(
        studioCompaniesProvider('netflix').future,
      );

      expect(ids, '1|2');
    });

    test('Apple is asked for both of its film studios', () async {
      when(() => tmdb.searchCompanies('Apple Studios')).thenAnswer(
        (_) async => const <TmdbCompany>[
          TmdbCompany(id: 10, name: 'Apple Studios'),
        ],
      );
      when(() => tmdb.searchCompanies('Apple Original Films')).thenAnswer(
        (_) async => const <TmdbCompany>[
          TmdbCompany(id: 11, name: 'Apple Original Films'),
        ],
      );

      final String ids = await container.read(
        studioCompaniesProvider('apple').future,
      );

      expect(ids, '10|11');
    });

    test('an unreachable TMDB gives no ids instead of an error', () async {
      when(
        () => tmdb.searchCompanies(any()),
      ).thenThrow(const TmdbApiException('Failed to search companies'));

      final String ids = await container.read(
        studioCompaniesProvider('netflix').future,
      );

      expect(ids, isEmpty);
    });

    test(
      'a lookup that failed once and then worked still finds the ids',
      () async {
        int calls = 0;
        when(() => tmdb.searchCompanies('Netflix')).thenAnswer((_) async {
          if (calls++ == 0) {
            throw const TmdbApiException('Failed to search companies');
          }
          return const <TmdbCompany>[TmdbCompany(id: 5, name: 'Netflix')];
        });

        final String ids = await container.read(
          studioCompaniesProvider('netflix').future,
        );

        expect(ids, '5');
        expect(calls, 2);
      },
    );
  });
}
