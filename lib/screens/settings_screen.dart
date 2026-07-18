import 'package:flutter/material.dart';

import '../controllers/phase_two_controller.dart';
import '../controllers/phase_three_controller.dart';
import '../controllers/player_controller.dart';
import '../models/advanced_models.dart';
import '../models/phase_three_models.dart';
import '../services/background_image_service.dart';
import '../services/phase_three_services.dart';
import '../theme/app_theme.dart';
import '../widgets/app_background.dart';
import 'phase_three_hub_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({
    super.key,
    required this.player,
    required this.phaseTwo,
    required this.phaseThree,
    required this.services,
  });

  final PlayerController player;
  final PhaseTwoController phaseTwo;
  final PhaseThreeController phaseThree;
  final PhaseThreeServices services;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _audioKey = GlobalKey();
  final _playbackKey = GlobalKey();
  final _libraryKey = GlobalKey();
  final _themeKey = GlobalKey();
  final _hardwareKey = GlobalKey();
  final _accessibilityKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([
        widget.phaseTwo,
        widget.phaseThree,
        widget.services.largeLibrary,
      ]),
      builder: (context, _) => ListView(
        key: const PageStorageKey('settings'),
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 30),
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Settings',
                  style: Theme.of(context).textTheme.displaySmall,
                ),
              ),
              IconButton(
                tooltip: 'Search all settings',
                onPressed: _searchSettings,
                icon: const Icon(Icons.manage_search_rounded),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ListTile(
            tileColor: AppTheme.surfaceOf(context),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            leading: Icon(
              Icons.rocket_launch_outlined,
              color: Theme.of(context).colorScheme.primary,
            ),
            title: const Text(
              'Performance & connected devices',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            subtitle: const Text(
              'Routing, recovery, LAN sharing, accessibility, reports',
            ),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: _openPhaseThree,
          ),
          const SizedBox(height: 24),
          _SectionLabel('AUDIO QUALITY', key: _audioKey),
          _Panel(
            children: [
              _SettingSwitch(
                icon: Icons.content_cut_rounded,
                title: 'Skip silence',
                subtitle: 'Use Android audio silence skipping when supported',
                value: widget.phaseTwo.silenceCalibration,
                onChanged: widget.phaseTwo.setSilenceCalibration,
              ),
            ],
          ),
          const SizedBox(height: 24),
          _SectionLabel('PLAYBACK', key: _playbackKey),
          _Panel(
            children: [
              _ValueSetting(
                icon: Icons.timer_outlined,
                title: 'Sleep timer',
                value: _sleepTimerLabel,
                onTap: _showSleepTimer,
              ),
            ],
          ),
          const SizedBox(height: 24),
          _SectionLabel('LIBRARY', key: _libraryKey),
          _Panel(
            children: [
              _ValueSetting(
                icon: Icons.storage_rounded,
                title: 'Indexed music',
                value: '${widget.services.largeLibrary.totalCount} tracks',
              ),
              _ValueSetting(
                icon: Icons.backup_outlined,
                title: 'Backup & restore',
                value: 'JSON file',
                onTap: _showBackupRestore,
              ),
            ],
          ),
          const SizedBox(height: 24),
          _SectionLabel('THEME', key: _themeKey),
          _Panel(
            children: [
              _ValueSetting(
                icon: Icons.wallpaper_rounded,
                title: 'Background',
                value: _backgroundLabel,
                onTap: _showBackgroundSettings,
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Appearance',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: SegmentedButton<ThemeMode>(
                        showSelectedIcon: false,
                        segments: const [
                          ButtonSegment(
                            value: ThemeMode.system,
                            label: Text('System'),
                          ),
                          ButtonSegment(
                            value: ThemeMode.light,
                            label: Text('Light'),
                          ),
                          ButtonSegment(
                            value: ThemeMode.dark,
                            label: Text('Dark'),
                          ),
                        ],
                        selected: {widget.phaseTwo.themeMode},
                        onSelectionChanged: (selection) =>
                            widget.phaseTwo.setThemeMode(selection.single),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Custom accent',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 14,
                      children: [
                        for (final color in const [
                          Color(0xFF95F3C7),
                          Color(0xFF65C8FF),
                          Color(0xFFFF8C72),
                          Color(0xFFC39BFF),
                          Color(0xFFFFCF70),
                        ])
                          _AccentChoice(
                            color: color,
                            selected: widget.phaseTwo.accent == color,
                            onTap: () => widget.phaseTwo.setAccent(color),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _SectionLabel('HARDWARE & SAFETY', key: _hardwareKey),
          _Panel(
            children: [
              _SettingSwitch(
                icon: Icons.headphones_battery_rounded,
                title: 'Pause on disconnect',
                subtitle:
                    'Stop playback when headphones or Bluetooth disconnect',
                value: widget.phaseTwo.autoPauseOnDisconnect,
                onChanged: widget.phaseTwo.setAutoPauseOnDisconnect,
              ),
              _SettingSwitch(
                icon: Icons.bluetooth_connected_rounded,
                title: 'Resume on reconnect',
                subtitle:
                    'Continue only after a matching audio interruption ends',
                value: widget.phaseTwo.autoResumeOnReconnect,
                onChanged: widget.phaseTwo.setAutoResumeOnReconnect,
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
                child: Column(
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.hearing_rounded),
                        const SizedBox(width: 14),
                        const Expanded(
                          child: Text(
                            'Maximum volume',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                        Text(
                          '${(widget.phaseTwo.volumeLimit * 100).round()}%',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.primary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    Slider(
                      min: .2,
                      max: 1,
                      divisions: 16,
                      value: widget.phaseTwo.volumeLimit,
                      onChanged: (value) {
                        widget.phaseTwo.setVolumeLimit(value);
                        widget.player.setVolumeLimit(value);
                      },
                    ),
                  ],
                ),
              ),
              ListTile(
                leading: const Icon(Icons.directions_car_rounded),
                title: const Text(
                  'Car & wearable controls',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: const Text(
                  'Enabled through the system media session',
                ),
                trailing: Icon(
                  Icons.check_circle_rounded,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _SectionLabel('ACCESSIBILITY', key: _accessibilityKey),
          _Panel(
            children: [
              _SettingSwitch(
                icon: Icons.contrast_rounded,
                title: 'High contrast',
                subtitle: 'Increase text and control contrast',
                value: widget.phaseTwo.highContrast,
                onChanged: widget.phaseTwo.setHighContrast,
              ),
            ],
          ),
          const SizedBox(height: 24),
          Center(
            child: Column(
              children: [
                const Text(
                  'AURALIS',
                  style: TextStyle(
                    letterSpacing: 2.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Version 1.1.1 • Local music, stored on your device',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppTheme.mutedOf(context),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _openPhaseThree() => Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => PhaseThreeHubScreen(
        player: widget.player,
        phaseThree: widget.phaseThree,
        services: widget.services,
      ),
    ),
  );

  String get _sleepTimerLabel => switch (widget.phaseTwo.sleepMode) {
    SleepTimerMode.off => 'Off',
    SleepTimerMode.minutes => '${widget.phaseTwo.sleepMinutes} min',
    SleepTimerMode.endOfTrack => 'After this track',
    SleepTimerMode.endOfQueue => 'After queue',
  };

  String get _backgroundLabel => switch (widget.phaseThree.backgroundMode) {
    AppBackgroundMode.defaultTheme => 'Default',
    AppBackgroundMode.dynamic => 'Dynamic',
    AppBackgroundMode.customImage => 'Custom image',
    AppBackgroundMode.theme => switch (widget.phaseThree.backgroundTheme) {
      AppBackgroundTheme.aurora => 'Aurora',
      AppBackgroundTheme.midnight => 'Midnight',
      AppBackgroundTheme.sunset => 'Sunset',
      AppBackgroundTheme.graphite => 'Graphite',
    },
  };

  Future<void> _showBackgroundSettings() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.surfaceHighOf(context),
      showDragHandle: true,
      builder: (sheetContext) => AnimatedBuilder(
        animation: widget.phaseThree,
        builder: (sheetContext, _) {
          final controller = widget.phaseThree;
          final mode = controller.backgroundMode;
          final hasCustom = controller.customBackgroundPath?.isNotEmpty == true;
          return SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                    title: Text(
                      'App background',
                      style: Theme.of(sheetContext).textTheme.titleLarge,
                    ),
                    subtitle: const Text(
                      'Wallpapers are dimmed automatically so controls stay readable.',
                    ),
                  ),
                  const SizedBox(height: 8),
                  _BackgroundChoice(
                    icon: Icons.auto_awesome_rounded,
                    title: 'Dynamic',
                    subtitle: 'Soft-focus artwork from the current song',
                    selected: mode == AppBackgroundMode.dynamic,
                    onTap: controller.setDynamicBackground,
                  ),
                  _BackgroundChoice(
                    icon: Icons.photo_library_outlined,
                    title: 'Custom image',
                    subtitle: hasCustom
                        ? 'Saved securely on this device'
                        : 'Choose a photo from your device',
                    selected: mode == AppBackgroundMode.customImage,
                    onTap: hasCustom
                        ? () => controller.setCustomBackground(
                            controller.customBackgroundPath!,
                          )
                        : () => _pickCustomBackground(sheetContext),
                    action: hasCustom
                        ? IconButton(
                            tooltip: 'Choose a different image',
                            onPressed: () =>
                                _pickCustomBackground(sheetContext),
                            icon: const Icon(Icons.edit_outlined),
                          )
                        : null,
                  ),
                  const SizedBox(height: 14),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Text(
                      'SOLID / GRADIENT THEME',
                      style: TextStyle(
                        fontSize: 10,
                        letterSpacing: 1.35,
                        color: AppTheme.mutedOf(sheetContext),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      for (final theme in AppBackgroundTheme.values)
                        _BackgroundThemeChoice(
                          theme: theme,
                          selected:
                              mode == AppBackgroundMode.theme &&
                              controller.backgroundTheme == theme,
                          onTap: () => controller.setThemeBackground(theme),
                        ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  OutlinedButton.icon(
                    onPressed: mode == AppBackgroundMode.defaultTheme
                        ? null
                        : _resetBackground,
                    icon: const Icon(Icons.restart_alt_rounded),
                    label: const Text('Reset to Default'),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _pickCustomBackground(BuildContext sheetContext) async {
    try {
      final path = await BackgroundImageService.pickAndStore();
      if (path == null) return;
      widget.phaseThree.setCustomBackground(path);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Custom background applied')),
      );
    } on Object catch (error) {
      if (!mounted) return;
      final message = error is FormatException
          ? error.message
          : 'Could not use that image. Please choose another one.';
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message.toString())));
    }
  }

  Future<void> _resetBackground() async {
    final oldPath = widget.phaseThree.customBackgroundPath;
    widget.phaseThree.resetBackground();
    await BackgroundImageService.remove(oldPath);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Default background restored')),
    );
  }

  Future<void> _showSleepTimer() async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppTheme.surfaceHighOf(context),
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: Text(
                  'Sleep timer',
                  style: Theme.of(sheetContext).textTheme.titleLarge,
                ),
              ),
              for (final minutes in const [15, 30, 60])
                ListTile(
                  leading: const Icon(Icons.timer_outlined),
                  title: Text('Stop in $minutes minutes'),
                  onTap: () {
                    widget.player.configureSleepStop(
                      afterCurrentTrack: false,
                      afterQueue: false,
                    );
                    widget.phaseTwo.configureSleepTimer(
                      SleepTimerMode.minutes,
                      minutes: minutes,
                      onElapsed: widget.player.pause,
                    );
                    Navigator.pop(sheetContext);
                  },
                ),
              ListTile(
                leading: const Icon(Icons.skip_next_rounded),
                title: const Text('Stop after this track'),
                onTap: () {
                  widget.player.configureSleepStop(
                    afterCurrentTrack: true,
                    afterQueue: false,
                  );
                  widget.phaseTwo.configureSleepTimer(
                    SleepTimerMode.endOfTrack,
                  );
                  Navigator.pop(sheetContext);
                },
              ),
              ListTile(
                leading: const Icon(Icons.queue_music_rounded),
                title: const Text('Stop after the queue'),
                onTap: () {
                  widget.player.configureSleepStop(
                    afterCurrentTrack: false,
                    afterQueue: true,
                  );
                  widget.phaseTwo.configureSleepTimer(
                    SleepTimerMode.endOfQueue,
                  );
                  Navigator.pop(sheetContext);
                },
              ),
              ListTile(
                leading: const Icon(Icons.timer_off_outlined),
                title: const Text('Turn off'),
                onTap: () {
                  widget.player.configureSleepStop(
                    afterCurrentTrack: false,
                    afterQueue: false,
                  );
                  widget.phaseTwo.configureSleepTimer(SleepTimerMode.off);
                  Navigator.pop(sheetContext);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showBackupRestore() async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppTheme.surfaceHighOf(context),
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: Text(
                  'Backup & restore',
                  style: Theme.of(sheetContext).textTheme.titleLarge,
                ),
                subtitle: const Text(
                  'Themes, favorites, bookmarks, tags, rules, and playlists',
                ),
              ),
              ListTile(
                leading: const Icon(Icons.upload_file_rounded),
                title: const Text('Export settings backup'),
                onTap: () async {
                  Navigator.pop(sheetContext);
                  final path = await widget.phaseTwo.exportBackup();
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        path == null ? 'Backup canceled' : 'Backup exported',
                      ),
                    ),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.settings_backup_restore_rounded),
                title: const Text('Import settings backup'),
                onTap: () async {
                  Navigator.pop(sheetContext);
                  final success = await widget.phaseTwo.importBackup();
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        success
                            ? 'Backup restored'
                            : 'No valid backup was imported',
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _searchSettings() async {
    const entries = <String, String>{
      'Skip silence': 'Audio quality',
      'Sleep timer': 'Playback',
      'Indexed music': 'Library',
      'Backup & restore': 'Library',
      'Appearance (system, light, dark)': 'Theme',
      'Custom accent': 'Theme',
      'Background and wallpaper': 'Theme',
      'Pause on disconnect': 'Hardware & safety',
      'Resume on reconnect': 'Hardware & safety',
      'Maximum volume': 'Hardware & safety',
      'Output profiles': 'Performance & connected devices',
      'Audio focus': 'Performance & connected devices',
      'Battery profiler': 'Performance & connected devices',
      'Linked tracks': 'Performance & connected devices',
      'Listening statistics': 'Performance & connected devices',
      'Local network sharing': 'Performance & connected devices',
      'Remote control': 'Performance & connected devices',
      'Language and RTL': 'Performance & connected devices',
      'Simplified mode': 'Performance & connected devices',
      'Synced lyrics': 'Performance & connected devices',
      'Library report': 'Performance & connected devices',
    };
    final selected = await showSearch<String?>(
      context: context,
      delegate: _SettingsSearchDelegate(entries),
    );
    if (!mounted || selected == null) return;
    if (entries[selected] == 'Performance & connected devices') {
      _openPhaseThree();
    } else {
      final key = switch (entries[selected]) {
        'Audio quality' => _audioKey,
        'Playback' => _playbackKey,
        'Library' => _libraryKey,
        'Theme' => _themeKey,
        'Hardware & safety' => _hardwareKey,
        'Accessibility' => _accessibilityKey,
        _ => null,
      };
      final target = key?.currentContext;
      if (target != null && target.mounted) {
        await Scrollable.ensureVisible(
          target,
          duration: const Duration(milliseconds: 420),
          curve: Curves.easeOutCubic,
          alignment: .08,
        );
      }
    }
  }
}

class _SettingsSearchDelegate extends SearchDelegate<String?> {
  _SettingsSearchDelegate(this.entries);
  final Map<String, String> entries;

  @override
  String get searchFieldLabel => 'Find any setting';

  @override
  List<Widget>? buildActions(BuildContext context) => [
    if (query.isNotEmpty)
      IconButton(
        tooltip: 'Clear',
        onPressed: () => query = '',
        icon: const Icon(Icons.close_rounded),
      ),
  ];

  @override
  Widget? buildLeading(BuildContext context) => IconButton(
    tooltip: 'Back',
    onPressed: () => close(context, null),
    icon: const Icon(Icons.arrow_back_rounded),
  );

  @override
  Widget buildResults(BuildContext context) => _results(context);

  @override
  Widget buildSuggestions(BuildContext context) => _results(context);

  Widget _results(BuildContext context) {
    final needle = query.toLowerCase();
    final matches = entries.entries
        .where(
          (entry) =>
              entry.key.toLowerCase().contains(needle) ||
              entry.value.toLowerCase().contains(needle),
        )
        .toList();
    return ListView.builder(
      itemCount: matches.length,
      itemBuilder: (context, index) {
        final entry = matches[index];
        return ListTile(
          leading: const Icon(Icons.tune_rounded),
          title: Text(entry.key),
          subtitle: Text(entry.value),
          onTap: () => close(context, entry.key),
        );
      },
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label, {super.key});
  final String label;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(left: 4, bottom: 9),
    child: Text(
      label,
      style: TextStyle(
        fontSize: 10,
        letterSpacing: 1.5,
        color: AppTheme.mutedOf(context),
        fontWeight: FontWeight.w800,
      ),
    ),
  );
}

class _Panel extends StatelessWidget {
  const _Panel({required this.children});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => Material(
    color: AppTheme.surfaceOf(context),
    clipBehavior: Clip.antiAlias,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(20),
      side: BorderSide(color: AppTheme.outlineOf(context)),
    ),
    child: Column(children: children),
  );
}

class _SettingSwitch extends StatelessWidget {
  const _SettingSwitch({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  @override
  Widget build(BuildContext context) => SwitchListTile(
    secondary: Icon(icon),
    title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
    subtitle: Text(
      subtitle,
      style: TextStyle(color: AppTheme.mutedOf(context), fontSize: 12),
    ),
    value: value,
    onChanged: onChanged,
  );
}

class _ValueSetting extends StatelessWidget {
  const _ValueSetting({
    required this.icon,
    required this.title,
    required this.value,
    this.onTap,
  });
  final IconData icon;
  final String title;
  final String value;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => ListTile(
    leading: Icon(icon),
    title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
    trailing: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: TextStyle(color: AppTheme.mutedOf(context), fontSize: 12),
        ),
        if (onTap != null) ...[
          const SizedBox(width: 5),
          Icon(Icons.chevron_right_rounded, color: AppTheme.mutedOf(context)),
        ],
      ],
    ),
    onTap: onTap,
  );
}

class _AccentChoice extends StatelessWidget {
  const _AccentChoice({
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    selected: selected,
    label: 'Select accent color',
    child: InkWell(
      borderRadius: BorderRadius.circular(30),
      onTap: onTap,
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(
            color: selected
                ? Theme.of(context).colorScheme.onSurface
                : Colors.transparent,
            width: 3,
          ),
        ),
        child: selected
            ? const Icon(Icons.check_rounded, color: AppTheme.ink)
            : null,
      ),
    ),
  );
}

class _BackgroundChoice extends StatelessWidget {
  const _BackgroundChoice({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
    this.action,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Material(
      color: selected
          ? Theme.of(context).colorScheme.primary.withValues(alpha: .1)
          : Theme.of(context).colorScheme.surfaceContainer,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: selected
              ? Theme.of(context).colorScheme.primary.withValues(alpha: .55)
              : AppTheme.outlineOf(context),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        leading: Icon(
          icon,
          color: selected
              ? Theme.of(context).colorScheme.primary
              : AppTheme.mutedOf(context),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text(subtitle),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ?action,
            if (selected)
              Icon(
                Icons.check_circle_rounded,
                color: Theme.of(context).colorScheme.primary,
              ),
          ],
        ),
        selected: selected,
        onTap: onTap,
      ),
    ),
  );
}

class _BackgroundThemeChoice extends StatelessWidget {
  const _BackgroundThemeChoice({
    required this.theme,
    required this.selected,
    required this.onTap,
  });

  final AppBackgroundTheme theme;
  final bool selected;
  final VoidCallback onTap;

  String get label => switch (theme) {
    AppBackgroundTheme.aurora => 'Aurora',
    AppBackgroundTheme.midnight => 'Midnight',
    AppBackgroundTheme.sunset => 'Sunset',
    AppBackgroundTheme.graphite => 'Graphite',
  };

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    selected: selected,
    label: 'Use $label background',
    child: InkWell(
      key: ValueKey('background-theme-choice-${theme.name}'),
      borderRadius: BorderRadius.circular(15),
      onTap: onTap,
      child: SizedBox(
        width: 72,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              height: 58,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(15),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: backgroundThemeColors(theme),
                ),
                border: Border.all(
                  color: selected
                      ? Theme.of(context).colorScheme.primary
                      : AppTheme.outlineOf(context),
                  width: selected ? 3 : 1,
                ),
              ),
              child: selected
                  ? const Center(
                      child: Icon(Icons.check_rounded, color: Colors.white),
                    )
                  : null,
            ),
            const SizedBox(height: 6),
            Text(
              label,
              maxLines: 1,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    ),
  );
}
