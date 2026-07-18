import 'package:flutter/material.dart';

import '../controllers/phase_two_controller.dart';
import '../models/track.dart';
import '../theme/app_theme.dart';

Future<void> showAddTracksToPlaylist(
  BuildContext context, {
  required PhaseTwoController phaseTwo,
  required List<Track> tracks,
}) async {
  if (tracks.isEmpty) return;
  final selectedId = await showModalBottomSheet<String>(
    context: context,
    backgroundColor: AppTheme.surfaceHighOf(context),
    showDragHandle: true,
    builder: (sheetContext) => SafeArea(
      child: AnimatedBuilder(
        animation: phaseTwo,
        builder: (context, _) => ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
          children: [
            Text(
              tracks.length == 1
                  ? 'Add to playlist'
                  : 'Add ${tracks.length} tracks to playlist',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(Icons.add_rounded),
              title: const Text('New playlist'),
              onTap: () async {
                final id = await _createPlaylist(sheetContext, phaseTwo);
                if (id != null && sheetContext.mounted) {
                  Navigator.pop(sheetContext, id);
                }
              },
            ),
            if (phaseTwo.userPlaylists.isEmpty)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'No playlists yet.',
                  style: TextStyle(color: AppTheme.mutedOf(context)),
                ),
              )
            else
              ...phaseTwo.userPlaylists.map(
                (playlist) => ListTile(
                  leading: const Icon(Icons.queue_music_rounded),
                  title: Text(playlist.name),
                  subtitle: Text('${playlist.trackIds.length} tracks'),
                  onTap: () => Navigator.pop(sheetContext, playlist.id),
                ),
              ),
          ],
        ),
      ),
    ),
  );
  if (selectedId == null || !context.mounted) return;
  phaseTwo.addTracksToPlaylist(selectedId, tracks.map((track) => track.id));
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(
        tracks.length == 1
            ? '${tracks.first.title} added to playlist'
            : '${tracks.length} tracks added to playlist',
      ),
    ),
  );
}

Future<String?> _createPlaylist(
  BuildContext context,
  PhaseTwoController phaseTwo,
) async {
  final controller = TextEditingController();
  final name = await showDialog<String>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('New playlist'),
      content: TextField(
        controller: controller,
        autofocus: true,
        textInputAction: TextInputAction.done,
        decoration: const InputDecoration(hintText: 'Playlist name'),
        onSubmitted: (value) {
          if (value.trim().isNotEmpty) Navigator.pop(dialogContext, value);
        },
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            final value = controller.text.trim();
            if (value.isNotEmpty) Navigator.pop(dialogContext, value);
          },
          child: const Text('Create'),
        ),
      ],
    ),
  );
  controller.dispose();
  if (name == null) return null;
  return phaseTwo.createPlaylist(name);
}
