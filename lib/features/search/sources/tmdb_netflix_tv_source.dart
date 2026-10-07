import 'package:core/models/data_source.dart';
import 'package:core/models/media_type.dart';
import 'package:core/models/tv_show.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/tmdb_api.dart';
import '../../../l10n/app_localizations.dart';
import '../filters/min_rating_filter.dart';
import '../filters/min_votes_filter.dart';
import '../filters/tmdb_genre_filter.dart';
import '../filters/year_filter.dart';
import '../models/search_source.dart';
import '../providers/genre_provider.dart';
import '../utils/genre_utils.dart';

/// Netflix original and licensed series via TMDB Discover.
/// TMDB network ID 213 = Netflix.
class TmdbNetflixTvSource extends SearchSource {
  /// TMDB network ID for Netflix.
  static const int _kNetflixId = 213;

  @override
  String get id => 'netflix_tv';

  @override
  MediaType get outputMediaType => MediaType.tvShow;

  @override
  DataSource get dataSource => DataSource.tmdb;

  @override
  String label(S l) => 'Netflix';

  @override
  IconData get icon => Icons.play_circle_outline;

  @override
  bool get supportsBrowse => true;

  /// Netflix does not provide a meaningful text-search-by-network filter,
  /// so we disable free-text search and keep Browse-only mode.
  @override
  bool get supportsSearch => false;

  @override
  List<SearchFilter> get filters => <SearchFilter>[
        TmdbGenreFilter(type: 'tv'),
        YearFilter(),
        MinRatingFilter(),
        MinVotesFilter(),
      ];

  @override
  List<BrowseSortOption> get sortOptions => const <BrowseSortOption>[
        BrowseSortOption(id: 'popular', apiValue: 'popularity.desc'),
        BrowseSortOption(id: 'top_rated', apiValue: 'vote_average.desc'),
        BrowseSortOption(id: 'newest', apiValue: 'first_air_date.desc'),
      ];

  @override
  String searchHint(S l) => l.searchHintTv;

  @override
  Future<BrowseResult> fetch(
    Ref ref, {
    String? query,
    required Map<String, Object?> filterValues,
    required String sortBy,
    required int page,
  }) async {
    final TmdbApi tmdb = ref.read(tmdbApiProvider);
    final Map<String, String> genreMap =
        await ref.read(tvGenreMapProvider.future);

    final Object? yearValue = filterValues['year'];
    int? year;
    String? firstAirDateGte;
    String? firstAirDateLte;

    if (yearValue is int) {
      year = yearValue;
    } else if (yearValue is (int, int)) {
      firstAirDateGte = '${yearValue.$1}-01-01';
      firstAirDateLte = '${yearValue.$2}-12-31';
    }

    final List<int>? genreIds = _readGenreIds(filterValues['genre']);
    final double? minRating =
        (filterValues['minRating'] as num?)?.toDouble();
    final int? minVotes = filterValues['minVotes'] as int?;

    final List<TvShow> tvShows = await tmdb.discoverTvShows(
      genreIds: _genreIdsToParam(genreIds),
      year: year,
      firstAirDateGte: firstAirDateGte,
      firstAirDateLte: firstAirDateLte,
      voteCountGte: minVotes,
      voteAverageGte: minRating,
      withNetworks: '$_kNetflixId',
      withoutGenreIds: <int>[tmdbAnimationGenreId],
      sortBy: sortBy,
      page: page,
    );

    final List<TvShow> resolved = resolveTvGenres(tvShows, genreMap);

    return BrowseResult(
      items: resolved,
      mediaType: MediaType.tvShow,
      hasMore: tvShows.length >= 20,
      currentPage: page,
    );
  }
}

List<int>? _readGenreIds(Object? value) {
  return switch (value) {
    final List<Object?> list => list.whereType<int>().toList(),
    final int id => <int>[id],
    _ => null,
  };
}

String? _genreIdsToParam(List<int>? ids) {
  if (ids == null || ids.isEmpty) return null;
  return ids.join(',');
}
