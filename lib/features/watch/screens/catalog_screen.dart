import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/catalog_api.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/constants/platform_features.dart';
import '../../../shared/theme/app_spacing.dart';
import '../../../shared/widgets/screen_app_bar.dart';
import '../../settings/screens/credentials_screen.dart';
import '../../settings/screens/watch_settings_screen.dart';
import '../catalog_shelves.dart';
import '../channel_views.dart';
import '../iptv_probe.dart';
import '../play_stream.dart';
import '../stream_resolver.dart';
import 'live_panel.dart';
import 'movix_panel.dart';
import '../providers/watch_providers.dart';
import '../watch_query.dart';
import 'watch_screen.dart';

// The TV look of the app: a graphite background, a light blue accent and large
// type, readable from across a room. Everything can be reached with the arrow
// keys and OK, and the focused item always shows a frame.
const String _kFont = 'Segoe UI';
const Color _kBackground = Color(0xFF101318);
const Color _kLayer = Color(0xFF191E26);
const Color _kStroke = Color(0xFF364150);
const Color _kHover = Color(0x14FFFFFF);
const Color _kSelected = Color(0x1F8BB8FF);
const Color _kAccent = Color(0xFF8BB8FF);
const Color _kTextPrimary = Color(0xFFFFFFFF);
const Color _kTextSecondary = Color(0xFFC0CAD7);
const Color _kTextTertiary = Color(0xFF94A3B8);

const double _kCornerRadius = 12;
const double _kRailWidth = 320;
const double _kRailCompactWidth = 80;
const double _kRailBreakpoint = 900;
const double _kRailItemHeight = 56;
const double _kFocusWidth = 3;
const double _kCardWidth = 220;
const double _kGridGap = 24;
const double _kChannelWidth = 250;
const double _kChannelAspect = 1.05;
const Duration _kHoverDuration = Duration(milliseconds: 120);
const Duration _kScrollToFocus = Duration(milliseconds: 160);

/// Rail sections; a divider is drawn between groups.
final List<List<String>> _kRailGroups = <List<String>>[
  <String>['recs'],
  <String>['trend_movies', 'trend_series', 'top_series'],
  kNewShelves,
  kGenreShelves,
  kCountryShelves,
  <String>['netflix_apple', 'docs'],
  <String>['cartoons', 'old_cartoons', 'soviet_cartoons'],
  <String>['anime', 'old_anime'],
  <String>['tv', 'youtube', 'twitch', 'kick', 'movix'],
  <String>['movies_top', 'series_top', 'movies_popular'],
  <String>['kp_movies_top', 'kp_series_top', 'kp_popular'],
  <String>['settings_watch', 'settings_keys'],
];

const Set<String> _kSettingsIds = <String>{'settings_watch', 'settings_keys'};

IconData _shelfIcon(String id) => switch (id) {
  'recs' => Icons.auto_awesome_outlined,
  'trend_movies' => Icons.local_fire_department_outlined,
  'trend_series' => Icons.tv_outlined,
  'top_series' => Icons.star_outline,
  'cartoons' => Icons.toys_outlined,
  'old_cartoons' => Icons.history,
  'soviet_cartoons' => Icons.flag_outlined,
  'anime' => Icons.animation,
  'old_anime' => Icons.history_edu_outlined,
  'settings_watch' => Icons.tune,
  'settings_keys' => Icons.key_outlined,
  'tv' => Icons.live_tv_outlined,
  'youtube' => Icons.smart_display_outlined,
  'twitch' => Icons.videogame_asset_outlined,
  'kick' => Icons.sports_esports_outlined,
  'movix' => Icons.movie_filter_outlined,
  'movies_top' => Icons.emoji_events_outlined,
  'series_top' => Icons.workspace_premium_outlined,
  'movies_popular' => Icons.trending_up,
  'kp_movies_top' => Icons.emoji_events_outlined,
  'kp_series_top' => Icons.workspace_premium_outlined,
  'kp_popular' => Icons.trending_up,
  'new_movies' => Icons.new_releases_outlined,
  'new_series' => Icons.fiber_new_outlined,
  'on_air' => Icons.sensors,
  'pop_movies' => Icons.trending_up,
  'pop_series' => Icons.trending_up,
  'top_movies' => Icons.emoji_events_outlined,
  'g_comedy' => Icons.sentiment_very_satisfied_outlined,
  'g_action' => Icons.flash_on_outlined,
  'g_thriller' => Icons.psychology_alt_outlined,
  'g_horror' => Icons.nightlight_outlined,
  'g_scifi' => Icons.rocket_launch_outlined,
  'g_drama' => Icons.theater_comedy_outlined,
  'g_crime' => Icons.gavel,
  'g_mystery' => Icons.help_outline,
  'g_war' => Icons.shield_outlined,
  'g_fantasy' => Icons.auto_fix_high,
  'g_romance' => Icons.favorite_border,
  'g_family' => Icons.family_restroom_outlined,
  'g_history' => Icons.account_balance_outlined,
  'g_western' => Icons.landscape_outlined,
  'c_ru' => Icons.flag_outlined,
  'c_soviet' => Icons.star_border,
  'c_kr' => Icons.public,
  'c_tr' => Icons.public,
  'c_gb' => Icons.public,
  'netflix_apple' => Icons.connected_tv_outlined,
  'docs' => Icons.article_outlined,
  _ => Icons.movie_outlined,
};

String _shelfLabel(S l, String id) => switch (id) {
  'recs' => l.catalogRecs,
  'trend_movies' => l.catalogMoviesTrending,
  'trend_series' => l.catalogSeriesTrending,
  'top_series' => l.catalogSeriesTop,
  'cartoons' => l.catalogCartoons,
  'old_cartoons' => l.catalogOldCartoons,
  'soviet_cartoons' => l.catalogSovietCartoons,
  'anime' => l.catalogAnime,
  'old_anime' => l.catalogOldAnime,
  'settings_watch' => l.settingsWatch,
  'settings_keys' => l.settingsApiKeys,
  'tv' => l.catalogTv,
  'youtube' => 'YouTube', // proper noun
  'twitch' => 'Twitch', // proper noun
  'kick' => 'Kick', // proper noun
  'movix' => 'Movix', // proper noun
  'movies_top' => l.catalogImdbMovies,
  'series_top' => l.catalogImdbSeries,
  'movies_popular' => l.catalogImdbNew,
  'kp_movies_top' => l.catalogKpMovies,
  'kp_series_top' => l.catalogKpSeries,
  'kp_popular' => l.catalogKpPopular,
  'new_movies' => l.catalogMoviesNew,
  'new_series' => l.catalogSeriesNew,
  'on_air' => l.catalogOnAir,
  'pop_movies' => l.catalogMoviesPopular,
  'pop_series' => l.catalogSeriesPopular,
  'top_movies' => l.catalogMoviesBest,
  'g_comedy' => l.catalogGenreComedy,
  'g_action' => l.catalogGenreAction,
  'g_thriller' => l.catalogGenreThriller,
  'g_horror' => l.catalogGenreHorror,
  'g_scifi' => l.catalogGenreSciFi,
  'g_drama' => l.catalogGenreDrama,
  'g_crime' => l.catalogGenreCrime,
  'g_mystery' => l.catalogGenreMystery,
  'g_war' => l.catalogGenreWar,
  'g_fantasy' => l.catalogGenreFantasy,
  'g_romance' => l.catalogGenreRomance,
  'g_family' => l.catalogGenreFamily,
  'g_history' => l.catalogGenreHistory,
  'g_western' => l.catalogGenreWestern,
  'c_ru' => l.catalogCountryRu,
  'c_soviet' => l.catalogCountrySoviet,
  'c_kr' => l.catalogCountryKr,
  'c_tr' => l.catalogCountryTr,
  'c_gb' => l.catalogCountryGb,
  'netflix_apple' => 'Netflix \u00B7 Apple TV+', // proper nouns
  'docs' => l.catalogDocs,
  _ => id,
};

String _chipLabel(S l, String chip) => switch (chip) {
  'all' => l.catalogChipAll,
  'movies' => l.catalogChipMovies,
  'series' => l.catalogChipSeries,
  'new' => l.catalogChipNew,
  'netflix' => 'Netflix', // proper noun
  'apple' => 'Apple TV+', // proper noun
  'bbc' => 'BBC', // proper noun
  _ => chip,
};

/// Recommendations, TMDB shelves (series, cartoons, old cartoons, anime) and
/// the IMDb and Kinopoisk lists from the catalog container, with a search over
/// TMDB. A tap on a title goes straight to the torrent picker.
class CatalogScreen extends StatefulWidget {
  /// [embedded] is the app's home tab: the shell already draws the app bar.
  const CatalogScreen({this.embedded = false, super.key});

  final bool embedded;

  @override
  State<CatalogScreen> createState() => _CatalogScreenState();
}

class _CatalogScreenState extends State<CatalogScreen> {
  final TextEditingController _search = TextEditingController();
  String _query = '';
  String _selected = kShelfIds.first;
  bool _genresOpen = false;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _setQuery(String text) => setState(() => _query = text.trim());

  void _select(String id) {
    _search.clear();
    setState(() {
      _selected = id;
      _query = '';
    });
  }

  void _toggleGenres() => setState(() => _genresOpen = !_genresOpen);

  @override
  Widget build(BuildContext context) {
    final S l = S.of(context);
    final ThemeData base = Theme.of(context);
    final ThemeData theme = base.copyWith(
      scaffoldBackgroundColor: _kBackground,
      textTheme: base.textTheme.apply(
        fontFamily: _kFont,
        bodyColor: _kTextPrimary,
        displayColor: _kTextPrimary,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: _kLayer,
        hintStyle: const TextStyle(fontFamily: _kFont, color: _kTextTertiary),
        prefixIconColor: _kTextTertiary,
        contentPadding: const EdgeInsets.symmetric(vertical: 10),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(_kCornerRadius),
          borderSide: const BorderSide(color: _kStroke),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(_kCornerRadius),
          borderSide: const BorderSide(color: _kStroke),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(_kCornerRadius),
          borderSide: const BorderSide(color: _kAccent, width: 2),
        ),
      ),
    );
    return Theme(
      data: theme,
      child: Scaffold(
        backgroundColor: _kBackground,
        appBar: widget.embedded ? null : ScreenAppBar(title: l.catalogTitle),
        body: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints box) {
            final bool compact = box.maxWidth < _kRailBreakpoint;
            return Row(
              children: <Widget>[
                _Rail(
                  selected: _query.isEmpty ? _selected : '',
                  compact: compact,
                  onSelect: _select,
                  genresOpen: _genresOpen,
                  onToggleGenres: _toggleGenres,
                ),
                Expanded(
                  child: _Content(
                    controller: _search,
                    query: _query,
                    selected: _selected,
                    onSubmitted: _setQuery,
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _Rail extends StatelessWidget {
  const _Rail({
    required this.selected,
    required this.compact,
    required this.onSelect,
    required this.genresOpen,
    required this.onToggleGenres,
  });

  final String selected;
  final bool compact;
  final ValueChanged<String> onSelect;
  final bool genresOpen;
  final VoidCallback onToggleGenres;

  Widget _item(S l, String id) => _RailItem(
    icon: _shelfIcon(id),
    label: _shelfLabel(l, id),
    selected: id == selected,
    compact: compact,
    onTap: () => onSelect(id),
  );

  @override
  Widget build(BuildContext context) {
    final S l = S.of(context);
    // Settings sit below the scrolling list, so they stay in reach however
    // short the window is.
    final List<List<String>> groups = <List<String>>[
      for (final List<String> g in _kRailGroups)
        if (!g.every(_kSettingsIds.contains))
          identical(g, kGenreShelves)
              ? g
              : <String>[
                  for (final String id in g)
                    // WebView2 exists on Windows only.
                    if (id != 'movix' || kIsWindowsApp) id,
                ],
    ];
    return Container(
      width: compact ? _kRailCompactWidth : _kRailWidth,
      color: _kBackground,
      child: Column(
        children: <Widget>[
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
              children: <Widget>[
                for (int g = 0; g < groups.length; g++) ...<Widget>[
                  if (g > 0)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                      child: Divider(height: 1, color: _kStroke),
                    ),
                  if (identical(groups[g], kGenreShelves)) ...<Widget>[
                    _RailItem(
                      icon: Icons.category_outlined,
                      label: l.catalogGenres,
                      selected: false,
                      compact: compact,
                      expanded: genresOpen,
                      onTap: onToggleGenres,
                    ),
                    if (genresOpen)
                      for (final String id in groups[g]) _item(l, id),
                  ] else
                    for (final String id in groups[g]) _item(l, id),
                ],
              ],
            ),
          ),
          const Divider(height: 1, color: _kStroke),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
            child: Column(
              children: <Widget>[
                for (final String id in _kSettingsIds) _item(l, id),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RailItem extends StatefulWidget {
  const _RailItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.compact,
    required this.onTap,
    this.expanded,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final bool compact;
  final VoidCallback onTap;

  /// Set for a folding header: whether its items are showing.
  final bool? expanded;

  @override
  State<_RailItem> createState() => _RailItemState();
}

class _RailItemState extends State<_RailItem> {
  bool _hover = false;
  bool _focus = false;

  void _onFocusChange(bool focused) {
    // The rail scrolls: a key press must never leave the focus out of sight.
    if (focused) {
      Scrollable.ensureVisible(context, duration: _kScrollToFocus);
    }
  }

  @override
  Widget build(BuildContext context) {
    final Color fill = widget.selected
        ? _kSelected
        : _hover || _focus
        ? _kHover
        : Colors.transparent;
    final Widget row = Row(
      children: <Widget>[
        // The accent pill marks the current page.
        AnimatedContainer(
          duration: _kHoverDuration,
          width: 4,
          height: widget.selected ? 26 : 0,
          decoration: BoxDecoration(
            color: _kAccent,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 14),
        Icon(widget.icon, size: 26, color: _kTextPrimary),
        if (!widget.compact) ...<Widget>[
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              widget.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontFamily: _kFont,
                fontSize: 19,
                color: _kTextPrimary,
              ),
            ),
          ),
          if (widget.expanded case final bool open)
            Padding(
              padding: const EdgeInsets.only(right: 14),
              child: Icon(
                open ? Icons.expand_less : Icons.expand_more,
                size: 26,
                color: _kTextTertiary,
              ),
            ),
        ],
      ],
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: FocusableActionDetector(
        autofocus: widget.selected,
        mouseCursor: SystemMouseCursors.click,
        onShowHoverHighlight: (bool v) => setState(() => _hover = v),
        onShowFocusHighlight: (bool v) => setState(() => _focus = v),
        onFocusChange: _onFocusChange,
        actions: <Type, Action<Intent>>{
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (_) {
              widget.onTap();
              return null;
            },
          ),
        },
        child: GestureDetector(
          onTap: widget.onTap,
          behavior: HitTestBehavior.opaque,
          child: Tooltip(
            message: widget.compact ? widget.label : '',
            child: AnimatedContainer(
              duration: _kHoverDuration,
              height: _kRailItemHeight,
              decoration: BoxDecoration(
                color: fill,
                borderRadius: BorderRadius.circular(_kCornerRadius),
                border: Border.all(
                  color: _focus ? _kAccent : Colors.transparent,
                  width: _kFocusWidth,
                ),
              ),
              child: row,
            ),
          ),
        ),
      ),
    );
  }
}

class _Content extends StatelessWidget {
  const _Content({
    required this.controller,
    required this.query,
    required this.selected,
    required this.onSubmitted,
  });

  final TextEditingController controller;
  final String query;
  final String selected;
  final ValueChanged<String> onSubmitted;

  @override
  Widget build(BuildContext context) {
    final S l = S.of(context);
    final bool searching = query.isNotEmpty;
    final LiveService? live = LiveService.values
        .where((LiveService s) => s.name == selected)
        .firstOrNull;
    return Container(
      margin: const EdgeInsets.only(top: 4, right: 8, bottom: 8),
      decoration: BoxDecoration(
        color: _kLayer,
        borderRadius: BorderRadius.circular(_kCornerRadius + 4),
        border: Border.all(color: _kStroke),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 4),
            child: Text(
              searching ? query : _shelfLabel(l, selected),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontFamily: _kFont,
                fontSize: 40,
                fontWeight: FontWeight.w600,
                color: _kTextPrimary,
              ),
            ),
          ),
          if (live == null &&
              selected != 'movix' &&
              !_kSettingsIds.contains(selected))
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 8),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: TextField(
                  controller: controller,
                  textInputAction: TextInputAction.search,
                  style: const TextStyle(fontFamily: _kFont, fontSize: 19),
                  decoration: InputDecoration(
                    isDense: true,
                    hintText: l.catalogSearchHint,
                    prefixIcon: const Icon(Icons.search, size: 26),
                    suffixIcon: searching
                        ? IconButton(
                            icon: const Icon(Icons.close, size: 22),
                            onPressed: () {
                              controller.clear();
                              onSubmitted('');
                            },
                          )
                        : null,
                  ),
                  onSubmitted: onSubmitted,
                ),
              ),
            ),
          Expanded(
            child: selected == 'settings_watch'
                ? const WatchSettingsScreen(embedded: true)
                : selected == 'settings_keys'
                ? const CredentialsScreen(embedded: true)
                : selected == 'movix'
                ? const MovixPanel()
                : live != null
                ? LivePanel(key: ValueKey<String>(selected), service: live)
                : searching && selected != 'tv'
                ? _SearchResults(query: query)
                : _ShelfView(id: selected, filter: query),
          ),
        ],
      ),
    );
  }
}

class _SearchResults extends ConsumerWidget {
  const _SearchResults({required this.query});

  final String query;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final S l = S.of(context);
    return ref
        .watch(catalogSearchProvider(query))
        .when(
          data: (List<CatalogItem> items) => items.isEmpty
              ? _Message(l.catalogEmpty)
              : _CatalogGrid(items: items, showRank: false),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (Object error, StackTrace stack) =>
              _Message(l.catalogLoadFailed('$error')),
        );
  }
}

class _ShelfView extends ConsumerWidget {
  const _ShelfView({required this.id, this.filter = '', super.key});

  final String id;

  /// Narrows a TV shelf by channel name; other shelves search TMDB instead.
  final String filter;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final S l = S.of(context);
    if (id == 'tv') return _TvShelf(filter: filter);
    if (kShelfChips.containsKey(id)) return _ChipShelf(id: id);
    final AsyncValue<List<CatalogItem>> shelf = ref.watch(shelfProvider(id));
    return shelf.when(
      data: (List<CatalogItem> all) {
        final String needle = filter.toLowerCase();
        final List<CatalogItem> items = id == 'tv' && needle.isNotEmpty
            ? all
                  .where(
                    (CatalogItem c) => c.title.toLowerCase().contains(needle),
                  )
                  .toList()
            : all;
        return items.isEmpty
            ? _Message(_emptyText(l))
            : _CatalogGrid(items: items, showRank: id != 'tv');
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (Object error, StackTrace stack) => _Message(
        l.catalogLoadFailed(
          error is CatalogApiException ? error.message : '$error',
        ),
      ),
    );
  }

  String _emptyText(S l) {
    if (id == 'recs') return l.catalogRecsEmpty;
    if (id.startsWith('kp_')) return l.catalogNoKinopoisk;
    return l.catalogEmpty;
  }
}

/// A shelf with a row of choices (platform, kind of documentary) above it.
class _ChipShelf extends StatefulWidget {
  const _ChipShelf({required this.id});

  final String id;

  @override
  State<_ChipShelf> createState() => _ChipShelfState();
}

class _ChipShelfState extends State<_ChipShelf> {
  late String _chip = kShelfChips[widget.id]?.first ?? '';

  @override
  Widget build(BuildContext context) {
    final S l = S.of(context);
    final List<String> chips = kShelfChips[widget.id] ?? const <String>[];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              for (final String chip in chips)
                ChoiceChip(
                  key: ValueKey<String>(chip),
                  label: Text(_chipLabel(l, chip)),
                  selected: _chip == chip,
                  onSelected: (_) => setState(() => _chip = chip),
                ),
            ],
          ),
        ),
        Expanded(
          child: _ShelfView(
            key: ValueKey<String>(shelfIdFor(widget.id, _chip)),
            id: shelfIdFor(widget.id, _chip),
          ),
        ),
      ],
    );
  }
}

/// Channels of the playlist that actually answer; dead links are checked in
/// the background and left out, so a tap never ends in "file not found".
class _TvShelf extends ConsumerWidget {
  const _TvShelf({required this.filter});

  final String filter;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final S l = S.of(context);
    final IptvProbeState? probe = ref.watch(iptvProbeProvider).valueOrNull;
    final Map<String, ChannelStat> stats = ref.watch(channelViewsProvider);
    return ref
        .watch(shelfProvider('tv'))
        .when(
          data: (List<CatalogItem> all) {
            final Set<String> alive = probe?.alive ?? const <String>{};
            final String needle = filter.toLowerCase();
            final List<CatalogItem> items = sortByViews(<CatalogItem>[
              for (final CatalogItem c in all)
                if (alive.contains(c.streamUrl) &&
                    (needle.isEmpty || c.title.toLowerCase().contains(needle)))
                  c,
            ], stats);
            final bool checking = probe == null || !probe.finished;
            return Column(
              children: <Widget>[
                if (checking)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 4, 24, 8),
                    child: Row(
                      children: <Widget>[
                        Expanded(
                          child: LinearProgressIndicator(
                            value: probe == null || probe.total == 0
                                ? null
                                : probe.done / probe.total,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          l.catalogTvChecking(
                            probe?.done ?? 0,
                            probe?.total ?? all.length,
                          ),
                          style: const TextStyle(
                            fontFamily: _kFont,
                            fontSize: 12,
                            color: _kTextTertiary,
                          ),
                        ),
                      ],
                    ),
                  ),
                Expanded(
                  child: items.isEmpty
                      ? (checking ? const SizedBox() : _Message(l.catalogEmpty))
                      : _CatalogGrid(
                          items: items,
                          showRank: false,
                          channels: true,
                        ),
                ),
              ],
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (Object error, StackTrace stack) =>
              _Message(l.catalogLoadFailed('$error')),
        );
  }
}

class _Message extends StatelessWidget {
  const _Message(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontFamily: _kFont,
            fontSize: 18,
            color: _kTextSecondary,
          ),
        ),
      ),
    );
  }
}

class _CatalogGrid extends StatelessWidget {
  const _CatalogGrid({
    required this.items,
    this.showRank = true,
    this.channels = false,
  });

  final List<CatalogItem> items;
  final bool showRank;

  /// Wide square tiles for TV channels instead of portrait posters.
  final bool channels;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: channels ? _kChannelWidth : _kCardWidth,
        mainAxisSpacing: _kGridGap,
        crossAxisSpacing: _kGridGap,
        childAspectRatio: channels ? _kChannelAspect : 0.5,
      ),
      itemCount: items.length,
      itemBuilder: (BuildContext context, int index) => _CatalogCardView(
        key: ValueKey<String>(items[index].key),
        rank: showRank ? index + 1 : null,
        item: items[index],
      ),
    );
  }
}

class _CatalogCardView extends ConsumerStatefulWidget {
  const _CatalogCardView({required this.rank, required this.item, super.key});

  final int? rank;
  final CatalogItem item;

  @override
  ConsumerState<_CatalogCardView> createState() => _CatalogCardViewState();
}

class _CatalogCardViewState extends ConsumerState<_CatalogCardView> {
  bool _hover = false;
  bool _focus = false;

  void _onFocusChange(bool focused) {
    // Arrow keys walk the grid: keep the focused card on screen.
    if (focused) {
      Scrollable.ensureVisible(
        context,
        alignment: 0.5,
        duration: _kScrollToFocus,
      );
    }
  }

  void _open(String title) {
    final CatalogItem item = widget.item;
    final String? stream = item.streamUrl;
    if (stream != null) {
      ref.read(channelViewsProvider.notifier).record(item.title);
      playStream(context, ref, url: stream, title: title);
      return;
    }
    final String original = item.original ?? '';
    final WatchQuery query = (
      title: title,
      originalTitle: original.isEmpty ? null : original,
      year: item.year,
      isSerial: item.isSerial,
    );
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (BuildContext context) => WatchScreen(query: query),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final CatalogItem item = widget.item;
    final CatalogEntry? entry = item.entry;
    // Container entries carry no poster; TMDB shelves already have one.
    final CatalogCard? card = entry == null
        ? null
        : ref.watch(catalogCardProvider(entry)).valueOrNull;
    final String title = card?.title ?? item.title;
    final String? poster = item.posterUrl ?? card?.posterUrl;
    final double? rating = item.rating;
    final int views = item.streamUrl == null
        ? 0
        : ref.watch(
            channelViewsProvider.select(
              (Map<String, ChannelStat> m) =>
                  m[channelKey(item.title)]?.count ?? 0,
            ),
          );
    return FocusableActionDetector(
      mouseCursor: SystemMouseCursors.click,
      onShowHoverHighlight: (bool v) => setState(() => _hover = v),
      onShowFocusHighlight: (bool v) => setState(() => _focus = v),
      onFocusChange: _onFocusChange,
      actions: <Type, Action<Intent>>{
        ActivateIntent: CallbackAction<ActivateIntent>(
          onInvoke: (_) {
            _open(title);
            return null;
          },
        ),
      },
      child: GestureDetector(
        onTap: () => _open(title),
        child: AnimatedContainer(
          duration: _kHoverDuration,
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: _hover || _focus ? _kHover : Colors.transparent,
            borderRadius: BorderRadius.circular(_kCornerRadius),
            border: Border.all(
              color: _focus
                  ? _kAccent
                  : _hover
                  ? _kStroke
                  : Colors.transparent,
              width: _kFocusWidth,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: Stack(
                  fit: StackFit.expand,
                  children: <Widget>[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(_kCornerRadius - 2),
                      child: poster == null
                          ? const ColoredBox(color: _kBackground)
                          : CachedNetworkImage(
                              imageUrl: poster,
                              fit: item.streamUrl == null
                                  ? BoxFit.cover
                                  : BoxFit.contain,
                              errorWidget:
                                  (BuildContext c, String u, Object e) =>
                                      const ColoredBox(color: _kBackground),
                            ),
                    ),
                    if (widget.rank != null)
                      Positioned(
                        left: 8,
                        top: 8,
                        child: _Badge(text: '${widget.rank}'),
                      ),
                    if (views > 0)
                      Positioned(
                        left: 8,
                        top: 8,
                        child: _Badge(text: '\u25B6 $views'),
                      ),
                    if (rating != null && rating > 0)
                      Positioned(
                        right: 8,
                        top: 8,
                        child: _Badge(text: rating.toStringAsFixed(1)),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontFamily: _kFont,
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  color: _kTextPrimary,
                ),
              ),
              if (item.year != null)
                Text(
                  '${item.year}',
                  style: const TextStyle(
                    fontFamily: _kFont,
                    fontSize: 15,
                    color: _kTextTertiary,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        child: Text(
          text,
          style: const TextStyle(
            fontFamily: _kFont,
            color: _kAccent,
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
