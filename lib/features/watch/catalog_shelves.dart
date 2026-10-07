import 'package:core/models/movie.dart';
import 'package:core/models/tv_show.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/catalog_api.dart';
import '../../core/api/iptv_api.dart';
import '../../core/api/tmdb_api.dart';
import '../recommendations/providers/recommendations_provider.dart';
import 'providers/watch_providers.dart';

/// The Animation genre id on TMDB, the same for movies and TV.
const int _kAnimationGenre = 16;
const int _kShelfPages = 4;

/// One title on a catalog shelf, whichever source it came from.
class CatalogItem {
  const CatalogItem({
    required this.title,
    required this.isSerial,
    this.original,
    this.year,
    this.rating,
    this.posterUrl,
    this.entry,
    this.streamUrl,
    this.group,
  });

  factory CatalogItem.fromMovie(Movie m) => CatalogItem(
    title: m.title,
    original: m.originalTitle,
    year: m.releaseYear,
    rating: m.rating,
    posterUrl: m.posterThumbUrl,
    isSerial: false,
  );

  factory CatalogItem.fromTv(TvShow t) => CatalogItem(
    title: t.title,
    original: t.originalTitle,
    year: t.firstAirYear,
    rating: t.rating,
    posterUrl: t.posterThumbUrl,
    isSerial: true,
  );

  /// A list entry from the catalog container; its poster is resolved lazily.
  factory CatalogItem.fromEntry(CatalogEntry e, {required bool isSerial}) =>
      CatalogItem(
        title: e.title,
        original: e.original,
        year: e.year,
        rating: e.rating,
        isSerial: isSerial,
        entry: e,
      );

  /// A TV channel: the tap plays this URL instead of searching torrents.
  factory CatalogItem.fromChannel(IptvChannel c) => CatalogItem(
    title: c.name,
    posterUrl: c.logo,
    isSerial: false,
    streamUrl: c.url,
    group: c.group,
  );

  final String title;
  final String? original;
  final int? year;
  final double? rating;
  final String? posterUrl;
  final bool isSerial;
  final CatalogEntry? entry;
  final String? streamUrl;
  final String? group;

  String get key => '$title|$year|$isSerial|${streamUrl ?? ''}';
}

/// Highest rating first, unrated last; ties keep their original order.
List<CatalogItem> mergeByRating(List<CatalogItem> a, List<CatalogItem> b) {
  final List<CatalogItem> all = <CatalogItem>[...a, ...b];
  final Map<CatalogItem, int> order = <CatalogItem, int>{
    for (int i = 0; i < all.length; i++) all[i]: i,
  };
  all.sort((CatalogItem x, CatalogItem y) {
    final double rx = x.rating ?? -1;
    final double ry = y.rating ?? -1;
    final int byRating = ry.compareTo(rx);
    return byRating != 0 ? byRating : (order[x] ?? 0).compareTo(order[y] ?? 0);
  });
  return dedupeItems(all);
}

List<CatalogItem> dedupeItems(List<CatalogItem> items) {
  final Set<String> seen = <String>{};
  return <CatalogItem>[
    for (final CatalogItem item in items)
      if (seen.add(item.key)) item,
  ];
}

/// Shelf ids in tab order. TMDB shelves are queried live; the container ones
/// read the lists it refreshes every couple of days.
final List<String> kShelfIds = <String>[
  'recs',
  'trend_movies',
  'trend_series',
  'top_series',
  ...kNewShelves,
  ...kGenreShelves,
  ...kCountryShelves,
  'netflix_apple',
  'docs',
  'cartoons',
  'old_cartoons',
  'soviet_cartoons',
  'anime',
  'old_anime',
  'tv',
  'movies_top',
  'series_top',
  'movies_popular',
  'kp_movies_top',
  'kp_series_top',
  'kp_popular',
];

const Set<String> kSerialShelves = <String>{
  'trend_series',
  'top_series',
  'series_top',
  'kp_series_top',
};

// The pages are independent requests, so they go out together.
Future<List<CatalogItem>> _movies(
  Future<List<Movie>> Function(int page) fetch,
) async {
  final List<List<Movie>> pages = await Future.wait(<Future<List<Movie>>>[
    for (int page = 1; page <= _kShelfPages; page++) fetch(page),
  ]);
  return dedupeItems(<CatalogItem>[
    for (final List<Movie> movies in pages)
      ...movies.map(CatalogItem.fromMovie),
  ]);
}

Future<List<CatalogItem>> _series(
  Future<List<TvShow>> Function(int page) fetch,
) async {
  final List<List<TvShow>> pages = await Future.wait(<Future<List<TvShow>>>[
    for (int page = 1; page <= _kShelfPages; page++) fetch(page),
  ]);
  return dedupeItems(<CatalogItem>[
    for (final List<TvShow> shows in pages) ...shows.map(CatalogItem.fromTv),
  ]);
}

/// Movies and TV of one kind merged into a single rating-ordered shelf.
Future<List<CatalogItem>> _both(
  Future<List<Movie>> Function(int page) movies,
  Future<List<TvShow>> Function(int page) tv,
) async {
  final List<List<CatalogItem>> parts = await Future.wait(
    <Future<List<CatalogItem>>>[_movies(movies), _series(tv)],
  );
  return mergeByRating(parts[0], parts[1]);
}

/// Shelves of what is new and what is popular right now.
const List<String> kNewShelves = <String>[
  'new_movies',
  'new_series',
  'on_air',
  'pop_movies',
  'pop_series',
  'top_movies',
];

/// A genre shelf asks TMDB for the genre's movies and series together; the
/// two kinds number their genres differently, and some have no TV twin.
class GenreIds {
  const GenreIds({this.movie, this.tv});

  final String? movie;
  final String? tv;
}

const Map<String, GenreIds> kGenreIds = <String, GenreIds>{
  'g_comedy': GenreIds(movie: '35', tv: '35'),
  'g_action': GenreIds(movie: '28', tv: '10759'),
  'g_thriller': GenreIds(movie: '53'),
  'g_horror': GenreIds(movie: '27'),
  'g_scifi': GenreIds(movie: '878', tv: '10765'),
  'g_drama': GenreIds(movie: '18', tv: '18'),
  'g_crime': GenreIds(movie: '80', tv: '80'),
  'g_mystery': GenreIds(movie: '9648', tv: '9648'),
  'g_war': GenreIds(movie: '10752', tv: '10768'),
  'g_fantasy': GenreIds(movie: '14', tv: '10765'),
  'g_romance': GenreIds(movie: '10749'),
  'g_family': GenreIds(movie: '10751', tv: '10751'),
  'g_history': GenreIds(movie: '36'),
  'g_western': GenreIds(movie: '37', tv: '37'),
};

final List<String> kGenreShelves = List<String>.unmodifiable(kGenreIds.keys);

/// Where a country shelf's titles come from. The USSR has no origin country
/// on TMDB, so the Soviet shelf is Russian-language titles up to 1991.
class CountryFilter {
  const CountryFilter({
    required this.movieVotes,
    required this.tvVotes,
    this.country,
    this.language,
    this.until,
  });

  final String? country;
  final String? language;
  final String? until;
  final int movieVotes;
  final int tvVotes;
}

const Map<String, CountryFilter> kCountryFilters = <String, CountryFilter>{
  'c_ru': CountryFilter(country: 'RU', movieVotes: 150, tvVotes: 40),
  'c_soviet': CountryFilter(
    language: 'ru',
    until: '1991-12-31',
    movieVotes: 25,
    tvVotes: 8,
  ),
  'c_kr': CountryFilter(country: 'KR', movieVotes: 300, tvVotes: 100),
  'c_tr': CountryFilter(country: 'TR', movieVotes: 80, tvVotes: 60),
  'c_gb': CountryFilter(country: 'GB', movieVotes: 500, tvVotes: 200),
};

final List<String> kCountryShelves = List<String>.unmodifiable(
  kCountryFilters.keys,
);

/// Shelves with a row of choices above the grid: shelf id -> its choices.
const Map<String, List<String>> kShelfChips = <String, List<String>>{
  'netflix_apple': <String>['all', 'netflix', 'apple'],
  'docs': <String>['all', 'movies', 'series', 'bbc', 'new'],
};

/// A shelf id is `base` or `base:chip`.
({String base, String? chip}) parseShelfId(String id) {
  final int cut = id.indexOf(':');
  return cut < 0
      ? (base: id, chip: null)
      : (base: id.substring(0, cut), chip: id.substring(cut + 1));
}

String shelfIdFor(String base, String? chip) =>
    chip == null ? base : '$base:$chip';

/// `2026-10-07`, the date format TMDB discover takes.
String tmdbDate(DateTime date) =>
    '${date.year}-${date.month.toString().padLeft(2, '0')}-'
    '${date.day.toString().padLeft(2, '0')}';

const int _kNetflixNetwork = 213;
const int _kAppleNetwork = 2552;
const String _kBbcNetworks = '4|332|1048';
const String _kDocumentaryGenre = '99';

/// What each studio is called on TMDB; movies have no network, so they are
/// matched through the production companies found by these names.
const Map<String, List<String>> _kStudioQueries = <String, List<String>>{
  'netflix': <String>['Netflix'],
  'apple': <String>['Apple Studios', 'Apple Original Films'],
};

bool studioMatches(String studio, String company) {
  final String name = company.toLowerCase();
  return switch (studio) {
    'netflix' => name.startsWith('netflix'),
    'apple' =>
      name.startsWith('apple studios') ||
          name.startsWith('apple original films'),
    _ => false,
  };
}

/// The `|`-joined company ids of a studio, looked up by name once per run so
/// no id has to be hard-coded; empty when TMDB knows none.
final FutureProviderFamily<String, String> studioCompaniesProvider =
    FutureProvider.family<String, String>((Ref ref, String studio) async {
      final TmdbApi tmdb = ref.read(tmdbApiProvider);
      final Set<int> ids = <int>{};
      for (final String query in _kStudioQueries[studio] ?? const <String>[]) {
        for (final TmdbCompany c in await tmdb.searchCompanies(query)) {
          if (studioMatches(studio, c.name)) ids.add(c.id);
        }
      }
      return ids.take(10).join('|');
    });

/// Movies and series, either of which may be absent.
Future<List<CatalogItem>> _mixed({
  Future<List<Movie>> Function(int page)? movies,
  Future<List<TvShow>> Function(int page)? tv,
}) async {
  final List<List<CatalogItem>> parts = await Future.wait(
    <Future<List<CatalogItem>>>[
      if (movies != null)
        _movies(movies)
      else
        Future<List<CatalogItem>>.value(<CatalogItem>[]),
      if (tv != null)
        _series(tv)
      else
        Future<List<CatalogItem>>.value(<CatalogItem>[]),
    ],
  );
  return mergeByRating(parts[0], parts[1]);
}

Future<List<CatalogItem>> _studioShelf(
  Ref ref,
  TmdbApi tmdb,
  String studio,
  int network,
) async {
  final String companies = await ref.watch(
    studioCompaniesProvider(studio).future,
  );
  return _mixed(
    movies: companies.isEmpty
        ? null
        : (int p) => tmdb.discoverMovies(
            withCompanies: companies,
            voteCountGte: 10,
            page: p,
          ),
    tv: (int p) => tmdb.discoverTvShows(
      withNetworks: '$network',
      voteCountGte: 10,
      page: p,
    ),
  );
}

Future<List<CatalogItem>> _platformShelf(
  Ref ref,
  TmdbApi tmdb,
  String? chip,
) async {
  switch (chip) {
    case 'netflix':
      return _studioShelf(ref, tmdb, 'netflix', _kNetflixNetwork);
    case 'apple':
      return _studioShelf(ref, tmdb, 'apple', _kAppleNetwork);
    default:
      final List<List<CatalogItem>> both = await Future.wait(
        <Future<List<CatalogItem>>>[
          _studioShelf(ref, tmdb, 'netflix', _kNetflixNetwork),
          _studioShelf(ref, tmdb, 'apple', _kAppleNetwork),
        ],
      );
      return mergeByRating(both[0], both[1]);
  }
}

Future<List<CatalogItem>> _docsShelf(TmdbApi tmdb, String? chip, DateTime now) {
  final String yearAgo = tmdbDate(now.subtract(const Duration(days: 365)));
  final String today = tmdbDate(now);
  Future<List<Movie>> movies(int p) =>
      tmdb.discoverMovies(genreId: 99, voteCountGte: 40, page: p);
  Future<List<TvShow>> series(int p) =>
      tmdb.discoverTvShows(genreId: 99, voteCountGte: 20, page: p);
  switch (chip) {
    case 'movies':
      return _mixed(movies: movies);
    case 'series':
      return _mixed(tv: series);
    case 'bbc':
      return _mixed(
        tv: (int p) => tmdb.discoverTvShows(
          genreIds: _kDocumentaryGenre,
          withNetworks: _kBbcNetworks,
          voteCountGte: 5,
          page: p,
        ),
      );
    case 'new':
      return _mixed(
        movies: (int p) => tmdb.discoverMovies(
          genreId: 99,
          releaseDateGte: yearAgo,
          releaseDateLte: today,
          voteCountGte: 5,
          page: p,
        ),
        tv: (int p) => tmdb.discoverTvShows(
          genreId: 99,
          firstAirDateGte: yearAgo,
          firstAirDateLte: today,
          voteCountGte: 5,
          page: p,
        ),
      );
    default:
      return _mixed(movies: movies, tv: series);
  }
}

Future<List<CatalogItem>?> _extraShelf(
  Ref ref,
  TmdbApi tmdb,
  String id,
  DateTime now,
) async {
  final ({String base, String? chip}) spec = parseShelfId(id);
  final String today = tmdbDate(now);
  switch (spec.base) {
    case 'new_movies':
      return _movies(
        (int p) => tmdb.discoverMovies(
          releaseDateGte: tmdbDate(now.subtract(const Duration(days: 120))),
          releaseDateLte: today,
          voteCountGte: 20,
          page: p,
        ),
      );
    case 'new_series':
      return _series(
        (int p) => tmdb.discoverTvShows(
          firstAirDateGte: tmdbDate(now.subtract(const Duration(days: 240))),
          firstAirDateLte: today,
          voteCountGte: 15,
          page: p,
        ),
      );
    case 'on_air':
      return _series(
        (int p) => tmdb.discoverTvShows(
          airDateGte: tmdbDate(now.subtract(const Duration(days: 7))),
          airDateLte: tmdbDate(now.add(const Duration(days: 7))),
          voteCountGte: 40,
          page: p,
        ),
      );
    case 'pop_movies':
      return _movies((int p) => tmdb.getPopularMovies(page: p));
    case 'pop_series':
      return _series(
        (int p) => tmdb.discoverTvShows(voteCountGte: 200, page: p),
      );
    case 'top_movies':
      return _movies((int p) => tmdb.getTopRatedMovies(page: p));
    case 'netflix_apple':
      return _platformShelf(ref, tmdb, spec.chip);
    case 'docs':
      return _docsShelf(tmdb, spec.chip, now);
  }
  final GenreIds? genre = kGenreIds[spec.base];
  if (genre != null) {
    final String? movieGenre = genre.movie;
    final String? tvGenre = genre.tv;
    return _mixed(
      movies: movieGenre == null
          ? null
          : (int p) => tmdb.discoverMovies(
              genreIds: movieGenre,
              voteCountGte: 300,
              page: p,
            ),
      tv: tvGenre == null
          ? null
          : (int p) => tmdb.discoverTvShows(
              genreIds: tvGenre,
              voteCountGte: 150,
              page: p,
            ),
    );
  }
  final CountryFilter? country = kCountryFilters[spec.base];
  if (country != null) {
    final String sort = country.until != null
        ? 'vote_average.desc'
        : 'popularity.desc';
    return _mixed(
      movies: (int p) => tmdb.discoverMovies(
        withOriginCountry: country.country,
        originalLanguage: country.language,
        releaseDateLte: country.until,
        voteCountGte: country.movieVotes,
        sortBy: sort,
        page: p,
      ),
      tv: (int p) => tmdb.discoverTvShows(
        withOriginCountry: country.country,
        originalLanguage: country.language,
        firstAirDateLte: country.until,
        voteCountGte: country.tvVotes,
        sortBy: sort,
        page: p,
      ),
    );
  }
  return null;
}

final AutoDisposeFutureProviderFamily<List<CatalogItem>, String> shelfProvider =
    FutureProvider.autoDispose.family<List<CatalogItem>, String>((
      Ref ref,
      String id,
    ) async {
      final TmdbApi tmdb = ref.read(tmdbApiProvider);
      final List<CatalogItem>? extra = await _extraShelf(
        ref,
        tmdb,
        id,
        DateTime.now(),
      );
      if (extra != null) return extra;
      switch (id) {
        case 'recs':
          final RecommendationResult result = await ref.watch(
            recommendationsProvider.future,
          );
          return dedupeItems(<CatalogItem>[
            for (final RecommendationRowUi row in result.rows)
              for (final RecommendedItem item in row.items)
                if (item.media is Movie)
                  CatalogItem.fromMovie(item.media as Movie)
                else if (item.media is TvShow)
                  CatalogItem.fromTv(item.media as TvShow),
          ]);
        case 'tv':
          final List<IptvChannel> channels = await ref.watch(
            iptvChannelsProvider.future,
          );
          return <CatalogItem>[
            for (final IptvChannel c in channels) CatalogItem.fromChannel(c),
          ];
        case 'trend_movies':
          return _movies((int p) => tmdb.getTrendingMovies(page: p));
        case 'trend_series':
          return _series((int p) => tmdb.getTrendingTvShows(page: p));
        case 'top_series':
          return _series((int p) => tmdb.getTopRatedTvShows(page: p));
        case 'cartoons':
          return _both(
            (int p) => tmdb.discoverMovies(
              genreId: _kAnimationGenre,
              releaseDateGte: '1990-01-01',
              voteCountGte: 500,
              sortBy: 'vote_average.desc',
              page: p,
            ),
            (int p) => tmdb.discoverTvShows(
              genreId: _kAnimationGenre,
              firstAirDateGte: '1990-01-01',
              voteCountGte: 300,
              sortBy: 'vote_average.desc',
              page: p,
            ),
          );
        case 'old_cartoons':
          return _both(
            (int p) => tmdb.discoverMovies(
              genreId: _kAnimationGenre,
              releaseDateLte: '1989-12-31',
              voteCountGte: 300,
              sortBy: 'vote_average.desc',
              page: p,
            ),
            (int p) => tmdb.discoverTvShows(
              genreId: _kAnimationGenre,
              firstAirDateLte: '1989-12-31',
              voteCountGte: 100,
              sortBy: 'vote_average.desc',
              page: p,
            ),
          );
        case 'soviet_cartoons':
          return _both(
            (int p) => tmdb.discoverMovies(
              genreId: _kAnimationGenre,
              originalLanguage: 'ru',
              releaseDateLte: '1991-12-31',
              voteCountGte: 15,
              sortBy: 'vote_average.desc',
              page: p,
            ),
            (int p) => tmdb.discoverTvShows(
              genreId: _kAnimationGenre,
              originalLanguage: 'ru',
              firstAirDateLte: '1991-12-31',
              voteCountGte: 10,
              sortBy: 'vote_average.desc',
              page: p,
            ),
          );
        case 'anime':
          return _both(
            (int p) => tmdb.discoverMovies(
              genreId: _kAnimationGenre,
              originalLanguage: 'ja',
              voteCountGte: 300,
              page: p,
            ),
            (int p) => tmdb.discoverTvShows(
              genreId: _kAnimationGenre,
              originalLanguage: 'ja',
              voteCountGte: 200,
              page: p,
            ),
          );
        case 'old_anime':
          return _both(
            (int p) => tmdb.discoverMovies(
              genreId: _kAnimationGenre,
              originalLanguage: 'ja',
              releaseDateLte: '2005-12-31',
              voteCountGte: 200,
              sortBy: 'vote_average.desc',
              page: p,
            ),
            (int p) => tmdb.discoverTvShows(
              genreId: _kAnimationGenre,
              originalLanguage: 'ja',
              firstAirDateLte: '2005-12-31',
              voteCountGte: 150,
              sortBy: 'vote_average.desc',
              page: p,
            ),
          );
      }
      final CatalogData data = await ref.watch(catalogProvider.future);
      return <CatalogItem>[
        for (final CatalogEntry e in data.lists[id] ?? const <CatalogEntry>[])
          CatalogItem.fromEntry(e, isSerial: kSerialShelves.contains(id)),
      ];
    });

/// Alternates two relevance-ordered lists so neither kind buries the other.
List<CatalogItem> interleave(List<CatalogItem> a, List<CatalogItem> b) {
  final List<CatalogItem> out = <CatalogItem>[];
  for (int i = 0; i < a.length || i < b.length; i++) {
    if (i < a.length) out.add(a[i]);
    if (i < b.length) out.add(b[i]);
  }
  return dedupeItems(out);
}

/// Text search over TMDB movies and series for the catalog search field.
final AutoDisposeFutureProviderFamily<List<CatalogItem>, String>
catalogSearchProvider = FutureProvider.autoDispose
    .family<List<CatalogItem>, String>((Ref ref, String query) async {
      final TmdbApi tmdb = ref.read(tmdbApiProvider);
      final List<Movie> movies = await tmdb.searchMovies(query);
      final List<TvShow> series = await tmdb.searchTvShows(query);
      return interleave(
        movies.map(CatalogItem.fromMovie).toList(),
        series.map(CatalogItem.fromTv).toList(),
      );
    });
