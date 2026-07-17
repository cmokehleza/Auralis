import 'package:flutter/material.dart';

import '../controllers/phase_two_controller.dart';
import '../controllers/player_controller.dart';
import '../models/track.dart';
import '../services/large_library_service.dart';
import '../theme/app_theme.dart';
import '../widgets/track_tile.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({
    super.key,
    required this.player,
    required this.phaseTwo,
    required this.library,
  });

  final PlayerController player;
  final PhaseTwoController phaseTwo;
  final LargeLibraryService library;

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _controller = TextEditingController();
  List<Track> _results = const [];
  int _generation = 0;
  bool _searching = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _search(String query) async {
    final generation = ++_generation;
    if (query.trim().isEmpty) {
      setState(() {
        _results = const [];
        _searching = false;
      });
      return;
    }
    setState(() => _searching = true);
    final results = await widget.library.find(query);
    if (!mounted || generation != _generation) return;
    setState(() {
      _results = results;
      _searching = false;
    });
  }

  void _selectGenre(String genre) {
    _controller.text = genre;
    _controller.selection = TextSelection.collapsed(offset: genre.length);
    _search(genre);
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: widget.library,
    builder: (context, _) {
      final hasQuery = _controller.text.trim().isNotEmpty;
      final genres = widget.library.allTracks
          .map((track) => track.genre.trim())
          .where(
            (genre) =>
                genre.isNotEmpty && genre.toLowerCase() != 'unknown genre',
          )
          .toSet()
          .take(8)
          .toList();
      return ListView(
        key: const PageStorageKey('search'),
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
        children: [
          Text('Search', style: Theme.of(context).textTheme.displaySmall),
          const SizedBox(height: 18),
          TextField(
            controller: _controller,
            textInputAction: TextInputAction.search,
            onChanged: _search,
            onSubmitted: _search,
            decoration: InputDecoration(
              hintText: 'Tracks, artists, albums, genres',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: hasQuery
                  ? IconButton(
                      tooltip: 'Clear search',
                      onPressed: () {
                        _controller.clear();
                        _search('');
                      },
                      icon: const Icon(Icons.close_rounded),
                    )
                  : null,
            ),
          ),
          const SizedBox(height: 24),
          if (_searching)
            const Center(child: CircularProgressIndicator())
          else if (!hasQuery) ...[
            if (widget.library.allTracks.isEmpty)
              const _EmptySearchLibrary()
            else if (genres.isNotEmpty) ...[
              Text(
                'Browse genres',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (var index = 0; index < genres.length; index++)
                    _GenreChip(
                      label: genres[index],
                      color: _genreColors[index % _genreColors.length],
                      onTap: () => _selectGenre(genres[index]),
                    ),
                ],
              ),
            ],
          ] else ...[
            Text(
              '${_results.length} results',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            if (_results.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 50),
                child: Column(
                  children: [
                    Icon(
                      Icons.search_off_rounded,
                      size: 48,
                      color: AppTheme.muted,
                    ),
                    SizedBox(height: 14),
                    Text(
                      'Nothing found',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              )
            else
              ..._results.map(
                (track) => TrackTile(
                  track: track,
                  player: widget.player,
                  phaseTwo: widget.phaseTwo,
                  onTap: () => widget.player.playTrack(track, from: _results),
                ),
              ),
          ],
        ],
      );
    },
  );
}

const _genreColors = [
  Color(0xFFFF8C72),
  Color(0xFF65C8FF),
  Color(0xFFB9F66A),
  Color(0xFF64E6D4),
  Color(0xFFC39BFF),
  Color(0xFFFFCF70),
];

class _GenreChip extends StatelessWidget {
  const _GenreChip({
    required this.label,
    required this.color,
    required this.onTap,
  });

  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: (MediaQuery.sizeOf(context).width - 50) / 2,
    height: 64,
    child: Material(
      color: color.withValues(alpha: .13),
      borderRadius: BorderRadius.circular(17),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(17),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Row(
            children: [
              Icon(Icons.music_note_rounded, color: color),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _EmptySearchLibrary extends StatelessWidget {
  const _EmptySearchLibrary();

  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.only(top: 36),
    child: Column(
      children: [
        Icon(Icons.library_music_outlined, size: 48, color: AppTheme.muted),
        SizedBox(height: 12),
        Text('Scan your phone in Library before searching.'),
      ],
    ),
  );
}
