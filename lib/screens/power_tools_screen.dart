import 'package:flutter/material.dart';

import '../controllers/phase_two_controller.dart';
import '../controllers/player_controller.dart';
import '../models/advanced_models.dart';
import '../models/track.dart';
import '../services/audio_fingerprint_service.dart';
import '../theme/app_theme.dart';

class PowerToolsScreen extends StatefulWidget {
  const PowerToolsScreen({
    super.key,
    required this.player,
    required this.phaseTwo,
    required this.library,
  });

  final PlayerController player;
  final PhaseTwoController phaseTwo;
  final List<Track> library;

  @override
  State<PowerToolsScreen> createState() => _PowerToolsScreenState();
}

class _PowerToolsScreenState extends State<PowerToolsScreen> {
  bool _scanning = false;
  List<DuplicateGroup>? _duplicates;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.phaseTwo,
      builder: (context, _) => Scaffold(
        appBar: AppBar(
          title: const Text('Power tools'),
          backgroundColor: AppTheme.backgroundOf(context),
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 30),
          children: [
            _IntroCard(accent: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 24),
            const _Label('CONTENT DUPLICATES'),
            _Panel(
              child: ListTile(
                leading: _scanning
                    ? const SizedBox.square(
                        dimension: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.fingerprint_rounded),
                title: const Text(
                  'Exact file duplicate scan',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: Text(
                  _duplicates == null
                      ? 'Find byte-identical audio files safely'
                      : '${_duplicates!.length} duplicate groups found',
                ),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: _scanning ? null : _scanDuplicates,
              ),
            ),
            const SizedBox(height: 22),
            const _Label('CUSTOM TAGS'),
            _Panel(
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.sell_outlined),
                    title: const Text(
                      'Custom track fields',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    subtitle: Text(
                      widget.player.current.isEmpty
                          ? 'Play a track before adding personal tags'
                          : 'Mood, instrument, notes • ${widget.player.current.title}',
                    ),
                    trailing: widget.player.current.isEmpty
                        ? null
                        : const Icon(Icons.chevron_right_rounded),
                    onTap: widget.player.current.isEmpty
                        ? null
                        : _editCustomTags,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),
            const _Label('MANUAL SMART PLAYLIST'),
            _Panel(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (widget.phaseTwo.playlistRules.isEmpty)
                      Text(
                        'No conditions yet. Add conditions such as genre = Jazz AND rating ≥ 4.',
                        style: TextStyle(color: AppTheme.mutedOf(context)),
                      )
                    else
                      ...widget.phaseTwo.playlistRules.indexed.map(
                        (entry) => ListTile(
                          contentPadding: EdgeInsets.zero,
                          dense: true,
                          leading: Text(
                            entry.$1 == 0 ? 'IF' : 'AND',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.primary,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          title: Text(
                            '${_fieldLabel(entry.$2.field)} ${_operatorLabel(entry.$2.operator).toLowerCase()} ${entry.$2.value}',
                          ),
                          trailing: IconButton(
                            onPressed: () =>
                                widget.phaseTwo.removeRule(entry.$1),
                            icon: const Icon(Icons.close_rounded),
                          ),
                        ),
                      ),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: _addRule,
                      icon: const Icon(Icons.add_rounded),
                      label: const Text('Add condition'),
                    ),
                    if (widget.phaseTwo.playlistRules.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Text(
                        '${_ruleMatches.length} matching tracks',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 10,
                        runSpacing: 8,
                        children: [
                          OutlinedButton.icon(
                            onPressed: _ruleMatches.isEmpty
                                ? null
                                : _showRuleMatches,
                            icon: const Icon(Icons.visibility_outlined),
                            label: const Text('Preview matches'),
                          ),
                          FilledButton.icon(
                            onPressed: _ruleMatches.isEmpty
                                ? null
                                : _saveRulePlaylist,
                            icon: const Icon(Icons.playlist_add_rounded),
                            label: const Text('Save as playlist'),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 22),
            const _Label('DEVICE MIGRATION'),
            _Panel(
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.upload_file_rounded),
                    title: const Text(
                      'Export complete backup',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    subtitle: const Text(
                      'Themes, favorites, rules, tags, bookmarks, and playlists',
                    ),
                    onTap: _export,
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.settings_backup_restore_rounded),
                    title: const Text('Import backup'),
                    subtitle: const Text('Restore from an open JSON file'),
                    onTap: _import,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _scanDuplicates() async {
    setState(() => _scanning = true);
    final result = await AudioFingerprintService().findDuplicates(
      widget.library,
    );
    if (!mounted) return;
    setState(() {
      _duplicates = result;
      _scanning = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          result.isEmpty
              ? 'No content-identical tracks found'
              : '${result.length} duplicate groups found',
        ),
      ),
    );
    if (result.isNotEmpty) _showDuplicateResults(result);
  }

  void _showDuplicateResults(List<DuplicateGroup> groups) {
    final byId = {for (final track in widget.library) track.id: track};
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppTheme.surfaceHighOf(context),
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => SizedBox(
        height: MediaQuery.sizeOf(context).height * .7,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          children: [
            Text(
              'Exact duplicate files',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 10),
            ...groups.indexed.map((entry) {
              final group = entry.$2;
              return ExpansionTile(
                title: Text('Group ${entry.$1 + 1}'),
                subtitle: Text(
                  '${group.trackIds.length} files • ${_formatBytes(group.savedBytes)} recoverable',
                ),
                children: group.trackIds
                    .map(
                      (id) => ListTile(
                        leading: const Icon(Icons.audio_file_rounded),
                        title: Text(byId[id]?.title ?? id),
                        subtitle: Text(byId[id]?.filePath ?? 'Unavailable'),
                      ),
                    )
                    .toList(),
              );
            }),
          ],
        ),
      ),
    );
  }

  String _formatBytes(int bytes) {
    if (bytes >= 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / 1024).toStringAsFixed(1)} KB';
  }

  void _editCustomTags() {
    if (widget.player.current.isEmpty) return;
    final mood = TextEditingController(
      text: widget.phaseTwo.customTagsFor(widget.player.current.id)['mood'],
    );
    final notes = TextEditingController(
      text: widget.phaseTwo.customTagsFor(widget.player.current.id)['notes'],
    );
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppTheme.surfaceHighOf(context),
        title: Text('Tags • ${widget.player.current.title}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: mood,
              decoration: const InputDecoration(labelText: 'Mood'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: notes,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'Personal notes'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              widget.phaseTwo.setCustomTag(
                widget.player.current.id,
                'mood',
                mood.text,
              );
              widget.phaseTwo.setCustomTag(
                widget.player.current.id,
                'notes',
                notes.text,
              );
              Navigator.pop(dialogContext);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    ).whenComplete(() {
      mood.dispose();
      notes.dispose();
    });
  }

  Future<void> _addRule() async {
    var field = RuleField.genre;
    var operator = RuleOperator.equals;
    final value = TextEditingController();
    final rule = await showDialog<PlaylistRule>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          final operators = _operatorsFor(field);
          return AlertDialog(
            title: const Text('Add playlist condition'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<RuleField>(
                  initialValue: field,
                  decoration: const InputDecoration(labelText: 'Field'),
                  items: RuleField.values
                      .map(
                        (item) => DropdownMenuItem(
                          value: item,
                          child: Text(_fieldLabel(item)),
                        ),
                      )
                      .toList(),
                  onChanged: (item) {
                    if (item == null) return;
                    setDialogState(() {
                      field = item;
                      if (!_operatorsFor(field).contains(operator)) {
                        operator = RuleOperator.equals;
                      }
                    });
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<RuleOperator>(
                  key: ValueKey('$field-$operator'),
                  initialValue: operator,
                  decoration: const InputDecoration(labelText: 'Condition'),
                  items: operators
                      .map(
                        (item) => DropdownMenuItem(
                          value: item,
                          child: Text(_operatorLabel(item)),
                        ),
                      )
                      .toList(),
                  onChanged: (item) {
                    if (item != null) {
                      setDialogState(() => operator = item);
                    }
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: value,
                  autofocus: true,
                  keyboardType:
                      field == RuleField.year ||
                          field == RuleField.rating ||
                          field == RuleField.duration
                      ? const TextInputType.numberWithOptions(decimal: true)
                      : TextInputType.text,
                  decoration: InputDecoration(
                    labelText: field == RuleField.duration
                        ? 'Minutes'
                        : 'Value',
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () {
                  if (value.text.trim().isEmpty) return;
                  Navigator.pop(
                    dialogContext,
                    PlaylistRule(
                      field: field,
                      operator: operator,
                      value: value.text.trim(),
                    ),
                  );
                },
                child: const Text('Add'),
              ),
            ],
          );
        },
      ),
    );
    value.dispose();
    if (rule != null) widget.phaseTwo.addRule(rule);
  }

  List<Track> get _ruleMatches {
    final rules = widget.phaseTwo.playlistRules;
    if (rules.isEmpty) return const [];
    return widget.library
        .where((track) => rules.every((rule) => rule.matches(track)))
        .toList(growable: false);
  }

  void _showRuleMatches() {
    final matches = _ruleMatches;
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) => SizedBox(
        height: MediaQuery.sizeOf(sheetContext).height * .72,
        child: Column(
          children: [
            ListTile(
              title: const Text(
                'Matching tracks',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
              subtitle: Text('${matches.length} tracks match every condition'),
              trailing: FilledButton.icon(
                onPressed: () {
                  widget.player.playTrack(matches.first, from: matches);
                  Navigator.pop(sheetContext);
                },
                icon: const Icon(Icons.play_arrow_rounded),
                label: const Text('Play'),
              ),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: matches.length,
                itemBuilder: (context, index) {
                  final track = matches[index];
                  return ListTile(
                    title: Text(track.title),
                    subtitle: Text('${track.artist} • ${track.album}'),
                    onTap: () => widget.player.playTrack(track, from: matches),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveRulePlaylist() async {
    final name = TextEditingController(text: 'Rule matches');
    final accepted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Save matching tracks'),
        content: TextField(
          controller: name,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Playlist name'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    final playlistName = name.text.trim();
    name.dispose();
    if (accepted != true || playlistName.isEmpty) return;
    final id = widget.phaseTwo.createPlaylist(playlistName);
    widget.phaseTwo.addTracksToPlaylist(
      id,
      _ruleMatches.map((track) => track.id),
    );
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('$playlistName saved to Playlists')));
  }

  Future<void> _export() async {
    final path = await widget.phaseTwo.exportBackup();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          path == null ? 'Backup export canceled' : 'Auralis backup exported',
        ),
      ),
    );
  }

  Future<void> _import() async {
    final success = await widget.phaseTwo.importBackup();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success ? 'Backup restored' : 'Backup import cancelled or invalid',
          ),
        ),
      );
    }
  }
}

List<RuleOperator> _operatorsFor(RuleField field) =>
    field == RuleField.genre || field == RuleField.artist
    ? const [RuleOperator.equals, RuleOperator.contains]
    : const [
        RuleOperator.equals,
        RuleOperator.greaterThan,
        RuleOperator.lessThan,
        RuleOperator.atLeast,
      ];

String _fieldLabel(RuleField field) => switch (field) {
  RuleField.genre => 'Genre',
  RuleField.year => 'Year',
  RuleField.rating => 'Rating',
  RuleField.artist => 'Artist',
  RuleField.duration => 'Duration (minutes)',
};

String _operatorLabel(RuleOperator operator) => switch (operator) {
  RuleOperator.equals => 'Equals',
  RuleOperator.contains => 'Contains',
  RuleOperator.greaterThan => 'Greater than',
  RuleOperator.lessThan => 'Less than',
  RuleOperator.atLeast => 'At least',
};

class _IntroCard extends StatelessWidget {
  const _IntroCard({required this.accent});
  final Color accent;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      gradient: LinearGradient(
        colors: [accent.withValues(alpha: .22), AppTheme.surfaceOf(context)],
      ),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: accent.withValues(alpha: .2)),
    ),
    child: Row(
      children: [
        const Icon(Icons.construction_rounded, size: 32),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Manual tools, transparent changes',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 4),
              Text(
                'Review duplicate results, tags, and rule matches before saving.',
                style: TextStyle(
                  color: AppTheme.mutedOf(context),
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _Label extends StatelessWidget {
  const _Label(this.value);
  final String value;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(left: 3, bottom: 8),
    child: Text(
      value,
      style: TextStyle(
        fontSize: 10,
        letterSpacing: 1.4,
        color: AppTheme.mutedOf(context),
        fontWeight: FontWeight.w800,
      ),
    ),
  );
}

class _Panel extends StatelessWidget {
  const _Panel({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => Material(
    color: AppTheme.surfaceOf(context),
    clipBehavior: Clip.antiAlias,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(20),
      side: BorderSide(color: AppTheme.outlineOf(context)),
    ),
    child: child,
  );
}
