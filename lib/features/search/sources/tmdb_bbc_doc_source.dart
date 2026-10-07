import 'package:core/models/data_source.dart';
import 'package:core/models/media_type.dart';
import 'package:core/models/tv_show.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/tmdb_api.dart';
import '../../../l10n/app_localizations.dart';
import '../filters/min_rating_filter.dart';
import '../filters/min_votes_filter.dart';
import '../filters/year_filter.dart';
import '../models/search_source.dart';
import '../providers/genre_provider.dart';
import '../utils/genre_utils.dart';

/// BBC documentaries via TMDB Discover.
///
/// Combines network filter (BBC One=4, BBC Two=332, BBC Four=1048) with
/// the TMDB Documentary genre ID (99).
class TmdbBbcDocSource extends SearchSource {
  /// TMDB Documentary genre ID.
  static const int _kDocumentaryGenreId = 99;

  /// TMDB network IDs for BBC channels: BBC One | BBC Two | BBC Four.
  static const String _kBbcNetworks = '4|332|1048';

  @override
  String get id => 'bbc_docs';

  @override
  MediaType get outputMediaType => MediaType.tvShow;

  @override
  DataSource get dataSource => DataSource.tmdb;

  @override
  String label(S l) => 'BBC Documentaries';

  @override
  IconData get icon => Icons.document_scanner_outlined;

  @override
  bool get supportsBrowse => true;

  @override
  bool get supportsSearch => false;

  @override
  List<SearchFilter> get filters => <SearchFilter>[
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

    final double? minRating =
        (filterValues['minRating'] as num?)?.toDouble();
    final int? minVotes = filterValues['minVotes'] as int?;

    final List<TvShow> tvShows = await tmdb.discoverTvShows(
      genreIds: '$_kDocumentaryGenreId',
      year: year,
      firstAirDateGte: firstAirDateGte,
      firstAirDateLte: firstAirDateLte,
      voteCountGte: minVotes,
      voteAverageGte: minRating,
      withNetworks: _kBbcNetworks,
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
