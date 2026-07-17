import 'package:flutter/material.dart';

import '../controllers/phase_two_controller.dart';
import '../controllers/phase_three_controller.dart';
import '../controllers/player_controller.dart';
import '../models/phase_three_models.dart';
import '../models/advanced_models.dart';
import '../models/track.dart';
import '../services/library_repository.dart';
import '../services/home_widget_service.dart';
import '../services/large_library_service.dart';
import '../theme/app_theme.dart';
import '../widgets/album_artwork.dart';
import '../widgets/track_tile.dart';
import '../widgets/playlist_picker.dart';
import 'power_tools_screen.dart';

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({
    super.key,
    required this.player,
    required this.phaseTwo,
    required this.phaseThree,
    required this.largeLibrary,
  });

  final PlayerController player;
  final PhaseTwoController phaseTwo;
  final PhaseThreeController phaseThree;
  final LargeLibraryService largeLibrary;

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  bool _scanning = false;

  @override
  void initState() {
    super.initState();
    if (widget.largeLibrary.allTracks.isEmpty) {
      widget.largeLibrary.replace(LibraryRepository.tracks);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 12, 10),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Your library',
                    style: Theme.of(context).textTheme.displaySmall,
                  ),
                ),
                IconButton(
                  tooltip: 'Scan this phone',
                  onPressed: _scanning ? null : _scan,
                  icon: _scanning
                      ? const SizedBox.square(
                          dimension: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.sync_rounded),
                ),
                IconButton(
                  tooltip: 'Power tools',
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => PowerToolsScreen(
                        player: widget.player,
                        phaseTwo: widget.phaseTwo,
                      ),
                    ),
                  ),
                  icon: const Icon(Icons.construction_rounded),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: TabBar(
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              labelColor: Theme.of(context).colorScheme.primary,
              indicatorColor: Theme.of(context).colorScheme.primary,
              dividerColor: Colors.transparent,
              tabs: const [
                Tab(text: 'Tracks'),
                Tab(text: 'Albums'),
                Tab(text: 'Playlists'),
                Tab(text: 'Folders'),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              children: [
                _TracksTab(
                  player: widget.player,
                  library: widget.largeLibrary,
                  phaseThree: widget.phaseThree,
                  phaseTwo: widget.phaseTwo,
                  onScan: _scan,
                ),
                _AlbumsTab(
                  player: widget.player,
                  library: widget.largeLibrary,
                  phaseTwo: widget.phaseTwo,
                ),
                _PlaylistsTab(
                  player: widget.player,
                  library: widget.largeLibrary,
                  phaseTwo: widget.phaseTwo,
                ),
                const _FoldersTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _scan() async {
    setState(() => _scanning = true);
    final result = await widget.largeLibrary.rescanInBackground();
    if (!mounted) return;
    if (result.tracks.isNotEmpty) {
      AlbumArtwork.clearMemoryCache();
      HomeWidgetService.clearArtworkCache();
      LibraryRepository.replaceWithDeviceTracks(result.tracks);
      widget.player.replaceLibrary(result.tracks);
    }
    setState(() => _scanning = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          result.error != null
              ? 'Library scan failed. Your existing music was kept.'
              : result.permissionGranted
              ? 'Library updated • ${result.tracks.length} device tracks indexed'
              : 'Music permission is required to scan this phone',
        ),
      ),
    );
  }
}

class _TracksTab extends StatelessWidget {
  const _TracksTab({
    required this.player,
    required this.library,
    required this.phaseThree,
    required this.phaseTwo,
    required this.onScan,
  });
  final PlayerController player;
  final LargeLibraryService library;
  final PhaseThreeController phaseThree;
  final PhaseTwoController phaseTwo;
  final VoidCallback onScan;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: library,
      builder: (context, _) {
        final groups = phaseThree.linkedGroups;
        final tracks = library.visibleTracks.where((track) {
          for (final group in groups) {
            if (group.trackIds.contains(track.id)) {
              return group.preferredTrackId == track.id;
            }
          }
          return true;
        }).toList();
        final allTracks = library.allTracks;
        if (tracks.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.library_music_outlined,
                    size: 48,
                    color: AppTheme.muted,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'No music indexed',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: onScan,
                    icon: const Icon(Icons.sync_rounded),
                    label: const Text('Scan this phone'),
                  ),
                ],
              ),
            ),
          );
        }
        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(17),
              ),
              child: Row(
                children: [
                  Icon(
                    tracks.first.isDeviceTrack
                        ? Icons.phone_android_rounded
                        : Icons.science_outlined,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          tracks.first.isDeviceTrack
                              ? 'On this phone'
                              : 'Music library',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        Text(
                          '${library.totalCount} tracks • ${library.loadedCount} loaded',
                          style: const TextStyle(
                            color: AppTheme.muted,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () =>
                        player.playTrack(allTracks.first, from: allTracks),
                    icon: const Icon(Icons.play_arrow_rounded),
                    label: const Text('Play all'),
                  ),
                ],
              ),
            ),
            ...tracks.map((track) {
              final linked = groups
                  .where((group) => group.preferredTrackId == track.id)
                  .firstOrNull;
              return Column(
                children: [
                  TrackTile(
                    track: track,
                    player: player,
                    phaseTwo: phaseTwo,
                    dense: true,
                    onTap: () => player.playTrack(track, from: allTracks),
                  ),
                  if (linked != null)
                    Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: TextButton.icon(
                        onPressed: () =>
                            _chooseLinkedVersion(context, linked, allTracks),
                        icon: const Icon(Icons.link_rounded, size: 16),
                        label: Text(
                          '${linked.trackIds.length} linked versions',
                        ),
                      ),
                    ),
                ],
              );
            }),
            if (library.hasMore)
              OutlinedButton.icon(
                onPressed: library.loadNextPage,
                icon: const Icon(Icons.expand_more_rounded),
                label: Text(
                  'Load ${library.pageSize} more (${library.loadedCount}/${library.totalCount})',
                ),
              ),
          ],
        );
      },
    );
  }

  void _chooseLinkedVersion(
    BuildContext context,
    LinkedTrackGroup group,
    List<Track> allTracks,
  ) {
    final byId = {for (final track in allTracks) track.id: track};
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: AppTheme.surfaceHigh,
      builder: (context) => RadioGroup<String>(
        groupValue: group.preferredTrackId,
        onChanged: (value) {
          if (value != null) {
            phaseThree.selectLinkedVersion(group.id, value);
          }
          Navigator.pop(context);
        },
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: group.trackIds.map((id) {
            final track = byId[id];
            return ListTile(
              leading: Radio<String>(value: id),
              title: Text(track?.title ?? id),
              subtitle: Text(track?.artist ?? 'Unavailable'),
            );
          }).toList(),
        ),
      ),
    );
  }
}

class _AlbumsTab extends StatelessWidget {
  const _AlbumsTab({
    required this.player,
    required this.library,
    required this.phaseTwo,
  });
  final PlayerController player;
  final LargeLibraryService library;
  final PhaseTwoController phaseTwo;

  @override
  Widget build(BuildContext context) {
    final source = library.allTracks;
    final albums = source.map((track) => track.album).toSet().toList()
      ..sort((a, b) {
        final aCompilation = source.any(
          (track) => track.album == a && track.isCompilation,
        );
        final bCompilation = source.any(
          (track) => track.album == b && track.isCompilation,
        );
        if (aCompilation != bCompilation) return aCompilation ? 1 : -1;
        return a.compareTo(b);
      });
    return GridView.builder(
      padding: const EdgeInsets.all(20),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 240,
        crossAxisSpacing: 15,
        mainAxisSpacing: 22,
        childAspectRatio: .78,
      ),
      itemCount: albums.length,
      itemBuilder: (context, index) {
        final album = albums[index];
        final albumTracks = source.where((item) => item.album == album).toList()
          ..sort((a, b) {
            final disc = a.discNumber.compareTo(b.discNumber);
            return disc != 0
                ? disc
                : (a.trackNumber ?? 0).compareTo(b.trackNumber ?? 0);
          });
        final track = albumTracks.first;
        return InkWell(
          onTap: () => player.playTrack(track, from: albumTracks),
          onLongPress: () => _albumActions(context, track, albumTracks),
          borderRadius: BorderRadius.circular(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AspectRatio(
                aspectRatio: 1,
                child: LayoutBuilder(
                  builder: (_, constraints) => AlbumArtwork(
                    colors: track.colors,
                    artworkId: track.albumArtId,
                    size: constraints.maxWidth,
                    radius: 18,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                album,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              Text(
                albumTracks.any((item) => item.isCompilation)
                    ? 'Various Artists • Compilation'
                    : '${track.albumArtist ?? track.artist}${albumTracks.map((item) => item.discNumber).toSet().length > 1 ? ' • Multi-disc' : ''}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: AppTheme.muted, fontSize: 12),
              ),
            ],
          ),
        );
      },
    );
  }

  void _albumActions(BuildContext context, Track track, List<Track> tracks) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppTheme.surfaceHigh,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.queue_play_next_rounded),
              title: const Text('Play album next'),
              onTap: () {
                player.addNext(track);
                Navigator.pop(sheetContext);
              },
            ),
            ListTile(
              leading: const Icon(Icons.playlist_add_rounded),
              title: const Text('Add album to playlist'),
              onTap: () {
                Navigator.pop(sheetContext);
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (!context.mounted) return;
                  showAddTracksToPlaylist(
                    context,
                    phaseTwo: phaseTwo,
                    tracks: tracks,
                  );
                });
              },
            ),
            ListTile(
              leading: const Icon(Icons.info_outline_rounded),
              title: Text('${tracks.length} tracks • ${track.album}'),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlaylistsTab extends StatelessWidget {
  const _PlaylistsTab({
    required this.player,
    required this.library,
    required this.phaseTwo,
  });
  final PlayerController player;
  final LargeLibraryService library;
  final PhaseTwoController phaseTwo;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: phaseTwo,
    builder: (context, _) => ListView(
      padding: const EdgeInsets.all(20),
      children: [
        OutlinedButton.icon(
          onPressed: () => _newPlaylist(context),
          icon: const Icon(Icons.add_rounded),
          label: const Text('New playlist'),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(50),
          ),
        ),
        const SizedBox(height: 18),
        if (phaseTwo.userPlaylists.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 36),
            child: Column(
              children: [
                Icon(
                  Icons.queue_music_rounded,
                  size: 44,
                  color: AppTheme.muted,
                ),
                SizedBox(height: 12),
                Text('No playlists yet'),
                SizedBox(height: 4),
                Text(
                  'Create one, then add songs from any track menu.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppTheme.muted),
                ),
              ],
            ),
          )
        else
          ...phaseTwo.userPlaylists.map((playlist) {
            final byId = {
              for (final track in library.allTracks) track.id: track,
            };
            final tracks = playlist.trackIds
                .map((id) => byId[id])
                .whereType<Track>()
                .toList();
            final artwork = tracks.firstOrNull;
            return ListTile(
              contentPadding: const EdgeInsets.symmetric(vertical: 5),
              leading: artwork == null
                  ? const SizedBox.square(
                      dimension: 58,
                      child: Icon(Icons.queue_music_rounded),
                    )
                  : AlbumArtwork(
                      colors: artwork.colors,
                      artworkId: artwork.albumArtId,
                      size: 58,
                      radius: 13,
                    ),
              title: Text(
                playlist.name,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              subtitle: Text(
                '${tracks.length} tracks',
                style: const TextStyle(color: AppTheme.muted),
              ),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => _openPlaylist(context, playlist, tracks),
            );
          }),
      ],
    ),
  );

  void _newPlaylist(BuildContext context) {
    final controller = TextEditingController();
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppTheme.surfaceHigh,
        title: const Text('New playlist'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Playlist name'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final name = controller.text.trim();
              if (name.isEmpty) return;
              phaseTwo.createPlaylist(name);
              Navigator.pop(dialogContext);
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(SnackBar(content: Text('$name created')));
            },
            child: const Text('Create'),
          ),
        ],
      ),
    ).whenComplete(controller.dispose);
  }

  void _openPlaylist(
    BuildContext context,
    UserPlaylist playlist,
    List<Track> tracks,
  ) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppTheme.surfaceHigh,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) => SizedBox(
        height: MediaQuery.sizeOf(sheetContext).height * .72,
        child: Column(
          children: [
            ListTile(
              title: Text(
                playlist.name,
                style: Theme.of(sheetContext).textTheme.titleLarge,
              ),
              subtitle: Text('${tracks.length} tracks'),
              trailing: IconButton(
                tooltip: 'Delete playlist',
                onPressed: () {
                  phaseTwo.deletePlaylist(playlist.id);
                  Navigator.pop(sheetContext);
                },
                icon: const Icon(Icons.delete_outline_rounded),
              ),
            ),
            if (tracks.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: FilledButton.icon(
                  onPressed: () {
                    player.playTrack(tracks.first, from: tracks);
                    Navigator.pop(sheetContext);
                  },
                  icon: const Icon(Icons.play_arrow_rounded),
                  label: const Text('Play all'),
                ),
              ),
            const SizedBox(height: 8),
            Expanded(
              child: tracks.isEmpty
                  ? const Center(child: Text('This playlist is empty'))
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                      itemCount: tracks.length,
                      itemBuilder: (context, index) {
                        final track = tracks[index];
                        return ListTile(
                          leading: AlbumArtwork(
                            colors: track.colors,
                            artworkId: track.albumArtId,
                            size: 46,
                            radius: 10,
                          ),
                          title: Text(track.title),
                          subtitle: Text(track.artist),
                          onTap: () => player.playTrack(track, from: tracks),
                          trailing: IconButton(
                            tooltip: 'Remove from playlist',
                            onPressed: () {
                              phaseTwo.removeTrackFromPlaylist(
                                playlist.id,
                                track.id,
                              );
                              Navigator.pop(sheetContext);
                            },
                            icon: const Icon(Icons.remove_circle_outline),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FoldersTab extends StatelessWidget {
  const _FoldersTab();
  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(20),
    children: [
      ListTile(
        contentPadding: EdgeInsets.zero,
        leading: Icon(
          Icons.folder_rounded,
          color: Theme.of(context).colorScheme.primary,
          size: 34,
        ),
        title: Text('Music', style: TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text('Android MediaStore • automatically indexed'),
        trailing: Icon(
          Icons.check_circle_rounded,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
      ListTile(
        contentPadding: EdgeInsets.zero,
        leading: Icon(Icons.usb_rounded, color: AppTheme.muted, size: 34),
        title: Text('USB audio'),
        subtitle: Text('Connect a drive to browse'),
        trailing: Icon(Icons.chevron_right_rounded),
      ),
    ],
  );
}
