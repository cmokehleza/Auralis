import 'package:flutter/material.dart';

import '../controllers/phase_two_controller.dart';
import '../controllers/player_controller.dart';
import '../models/advanced_models.dart';
import '../services/audio_fingerprint_service.dart';
import '../theme/app_theme.dart';

class PowerToolsScreen extends StatefulWidget {
  const PowerToolsScreen({
    super.key,
    required this.player,
    required this.phaseTwo,
  });

  final PlayerController player;
  final PhaseTwoController phaseTwo;

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
          backgroundColor: AppTheme.ink,
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
                      'Mood, instrument, notes • ${widget.player.current.title}',
                    ),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: _editCustomTags,
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
                      const Text(
                        'No conditions yet. Add conditions such as genre = Jazz AND rating ≥ 4.',
                        style: TextStyle(color: AppTheme.muted),
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
                            '${entry.$2.field.name} ${entry.$2.operator.name} ${entry.$2.value}',
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
                      'Themes, rules, tags, bookmarks, and playlists',
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
      widget.player.queue,
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
    final byId = {for (final track in widget.player.queue) track.id: track};
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppTheme.surfaceHigh,
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
    final mood = TextEditingController(
      text: widget.phaseTwo.customTagsFor(widget.player.current.id)['mood'],
    );
    final notes = TextEditingController(
      text: widget.phaseTwo.customTagsFor(widget.player.current.id)['notes'],
    );
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppTheme.surfaceHigh,
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
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Add playlist condition'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<RuleField>(
                initialValue: field,
                decoration: const InputDecoration(labelText: 'Field'),
                items: RuleField.values
                    .map(
                      (item) =>
                          DropdownMenuItem(value: item, child: Text(item.name)),
                    )
                    .toList(),
                onChanged: (item) =>
                    item == null ? null : setDialogState(() => field = item),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<RuleOperator>(
                initialValue: operator,
                decoration: const InputDecoration(labelText: 'Condition'),
                items: RuleOperator.values
                    .map(
                      (item) =>
                          DropdownMenuItem(value: item, child: Text(item.name)),
                    )
                    .toList(),
                onChanged: (item) =>
                    item == null ? null : setDialogState(() => operator = item),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: value,
                autofocus: true,
                decoration: const InputDecoration(labelText: 'Value'),
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
        ),
      ),
    );
    value.dispose();
    if (rule != null) widget.phaseTwo.addRule(rule);
  }

  Future<void> _export() async {
    final path = await widget.phaseTwo.exportBackup();
    if (mounted && path != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Auralis backup exported')));
    }
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

class _IntroCard extends StatelessWidget {
  const _IntroCard({required this.accent});
  final Color accent;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      gradient: LinearGradient(
        colors: [accent.withValues(alpha: .22), AppTheme.surface],
      ),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: accent.withValues(alpha: .2)),
    ),
    child: const Row(
      children: [
        Icon(Icons.construction_rounded, size: 32),
        SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Manual tools, transparent changes',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
              SizedBox(height: 4),
              Text(
                'Every library edit is previewed and user-controlled.',
                style: TextStyle(color: AppTheme.muted, fontSize: 12),
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
      style: const TextStyle(
        fontSize: 10,
        letterSpacing: 1.4,
        color: AppTheme.muted,
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
    color: AppTheme.surface,
    clipBehavior: Clip.antiAlias,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(20),
      side: BorderSide(color: Colors.white.withValues(alpha: .05)),
    ),
    child: child,
  );
}
