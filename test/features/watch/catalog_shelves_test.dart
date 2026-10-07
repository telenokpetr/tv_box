import 'package:flutter_test/flutter_test.dart';
import 'package:tonkatsu_box/features/watch/catalog_shelves.dart';

CatalogItem item(
  String title,
  double? rating, {
  int? year,
  bool serial = false,
}) => CatalogItem(title: title, rating: rating, year: year, isSerial: serial);

void main() {
  group('mergeByRating', () {
    test('orders by rating, unrated last', () {
      final List<CatalogItem> merged = mergeByRating(
        <CatalogItem>[item('a', 7.0), item('b', null)],
        <CatalogItem>[item('c', 8.5), item('d', 7.0)],
      );
      expect(merged.map((CatalogItem i) => i.title), <String>[
        'c',
        'a',
        'd',
        'b',
      ]);
    });

    test('ties keep the order the lists came in', () {
      final List<CatalogItem> merged = mergeByRating(
        <CatalogItem>[item('first', 8.0)],
        <CatalogItem>[item('second', 8.0)],
      );
      expect(merged.map((CatalogItem i) => i.title), <String>[
        'first',
        'second',
      ]);
    });

    test('drops a duplicate that appears in both lists', () {
      final List<CatalogItem> merged = mergeByRating(
        <CatalogItem>[item('x', 8.0, year: 1999)],
        <CatalogItem>[item('x', 8.0, year: 1999)],
      );
      expect(merged, hasLength(1));
    });
  });

  group('dedupeItems', () {
    test('same title in a different year or kind is a different item', () {
      final List<CatalogItem> out = dedupeItems(<CatalogItem>[
        item('Dune', 8, year: 1984),
        item('Dune', 8, year: 2021),
        item('Dune', 8, year: 2021, serial: true),
        item('Dune', 8, year: 2021),
      ]);
      expect(out, hasLength(3));
    });
  });

  group('shelf ids', () {
    test('every shelf id is unique and the serial ones exist', () {
      expect(kShelfIds.toSet(), hasLength(kShelfIds.length));
      expect(kShelfIds.toSet().containsAll(kSerialShelves), isTrue);
    });
  });

  group('new shelves', () {
    test('genre, country and chip shelves are listed once and in order', () {
      expect(kShelfIds, containsAll(kNewShelves));
      expect(kShelfIds, containsAll(kGenreShelves));
      expect(kShelfIds, containsAll(kCountryShelves));
      expect(kShelfIds, containsAll(kShelfChips.keys));
    });

    test('every genre shelf has an id for movies or series', () {
      for (final MapEntry<String, GenreIds> e in kGenreIds.entries) {
        expect(e.value.movie != null || e.value.tv != null, isTrue, reason: e.key);
      }
    });

    test('every country shelf filters by something', () {
      for (final MapEntry<String, CountryFilter> e in kCountryFilters.entries) {
        expect(
          e.value.country != null || e.value.language != null,
          isTrue,
          reason: e.key,
        );
      }
    });

    test('shelves with choices start on the first one', () {
      for (final MapEntry<String, List<String>> e in kShelfChips.entries) {
        expect(e.value, isNotEmpty);
        expect(e.value.first, 'all', reason: e.key);
      }
    });
  });

  group('parseShelfId', () {
    test('a plain id has no chip', () {
      final ({String base, String? chip}) spec = parseShelfId('docs');
      expect(spec.base, 'docs');
      expect(spec.chip, isNull);
    });

    test('splits the base from the chip', () {
      final ({String base, String? chip}) spec = parseShelfId('docs:bbc');
      expect(spec.base, 'docs');
      expect(spec.chip, 'bbc');
    });

    test('shelfIdFor is the inverse', () {
      expect(shelfIdFor('docs', 'bbc'), 'docs:bbc');
      expect(shelfIdFor('docs', null), 'docs');
      expect(parseShelfId(shelfIdFor('netflix_apple', 'apple')).chip, 'apple');
    });
  });

  group('tmdbDate', () {
    test('pads month and day', () {
      expect(tmdbDate(DateTime(2026, 3, 7)), '2026-03-07');
      expect(tmdbDate(DateTime(2026, 12, 31)), '2026-12-31');
    });
  });

  group('studioMatches', () {
    test('Netflix companies by prefix, any case', () {
      expect(studioMatches('netflix', 'Netflix'), isTrue);
      expect(studioMatches('netflix', 'NETFLIX Animation'), isTrue);
      expect(studioMatches('netflix', 'Not Netflix'), isFalse);
    });

    test('Apple counts its film studios, not the fruit stands', () {
      expect(studioMatches('apple', 'Apple Studios'), isTrue);
      expect(studioMatches('apple', 'Apple Original Films'), isTrue);
      expect(studioMatches('apple', 'Apple Pie Productions'), isFalse);
    });

    test('an unknown studio matches nothing', () {
      expect(studioMatches('hulu', 'Hulu'), isFalse);
    });
  });

  group('interleave', () {
    test('alternates the two lists and appends the longer tail', () {
      final List<CatalogItem> out = interleave(
        <CatalogItem>[item('m1', 1), item('m2', 1), item('m3', 1)],
        <CatalogItem>[item('s1', 1, serial: true)],
      );
      expect(out.map((CatalogItem i) => i.title), <String>[
        'm1',
        's1',
        'm2',
        'm3',
      ]);
    });

    test('handles empty sides', () {
      expect(interleave(<CatalogItem>[], <CatalogItem>[]), isEmpty);
      expect(
        interleave(<CatalogItem>[item('a', 1)], <CatalogItem>[]),
        hasLength(1),
      );
    });
  });
}
