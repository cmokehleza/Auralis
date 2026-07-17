import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../controllers/phase_three_controller.dart';
import '../controllers/player_controller.dart';
import '../models/phase_three_models.dart';
import '../services/library_integrity_service.dart';
import '../services/library_repository.dart';
import '../services/home_widget_service.dart';
import '../services/phase_three_services.dart';
import '../services/report_export_service.dart';
import '../theme/app_theme.dart';
import '../widgets/album_artwork.dart';

class PhaseThreeHubScreen extends StatefulWidget {
  const PhaseThreeHubScreen({
    super.key,
    required this.player,
    required this.phaseThree,
    required this.services,
  });

  final PlayerController player;
  final PhaseThreeController phaseThree;
  final PhaseThreeServices services;

  @override
  State<PhaseThreeHubScreen> createState() => _PhaseThreeHubScreenState();
}

class _PhaseThreeHubScreenState extends State<PhaseThreeHubScreen> {
  final _pin = TextEditingController();
  String? _status;

  @override
  void dispose() {
    _pin.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: Listenable.merge([
      widget.phaseThree,
      widget.services.largeLibrary,
      widget.services.localNetwork,
      widget.services.batteryProfile,
    ]),
    builder: (context, _) {
      final phase = widget.phaseThree;
      final services = widget.services;
      final output = phase.activeOutput;
      return Scaffold(
        appBar: AppBar(title: const Text('Performance & connected devices')),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 34),
          children: [
            if (_status != null)
              _InfoBanner(
                text: _status!,
                onClose: () => setState(() => _status = null),
              ),
            const _Label('PERFORMANCE & RECOVERY'),
            _Card(
              children: [
                ListTile(
                  leading: services.largeLibrary.scanning
                      ? const CircularProgressIndicator(strokeWidth: 2)
                      : const Icon(Icons.sync_rounded),
                  title: const Text('Background library re-scan'),
                  subtitle: Text(
                    '${services.largeLibrary.totalCount} indexed • ${services.largeLibrary.loadedCount} loaded',
                  ),
                  onTap: services.largeLibrary.scanning ? null : _rescan,
                ),
                ListTile(
                  leading: const Icon(Icons.health_and_safety_outlined),
                  title: const Text('Check & repair library integrity'),
                  subtitle: const Text(
                    'Duplicate IDs, invalid durations, and empty titles',
                  ),
                  onTap: _integrityCheck,
                ),
                SwitchListTile(
                  secondary: const Icon(Icons.battery_saver_outlined),
                  title: const Text('Battery profiling mode'),
                  subtitle: Text(
                    services.batteryProfile.running
                        ? '${services.batteryProfile.samples.length} samples collected'
                        : 'Developer telemetry for background playback',
                  ),
                  value: phase.batteryProfilerEnabled,
                  onChanged: _toggleBatteryProfiler,
                ),
                if (services.batteryProfile.samples.isNotEmpty)
                  ListTile(
                    leading: const Icon(Icons.analytics_outlined),
                    title: const Text('Profiling report'),
                    subtitle: Text(services.batteryProfile.buildReport()),
                  ),
              ],
            ),
            const _Label('AUDIO ROUTING & OUTPUT'),
            _Card(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: DropdownButtonFormField<String>(
                    initialValue: output.id,
                    decoration: const InputDecoration(
                      labelText: 'Output profile',
                    ),
                    items: phase.outputProfiles
                        .map(
                          (item) => DropdownMenuItem(
                            value: item.id,
                            child: Text(item.name),
                          ),
                        )
                        .toList(),
                    onChanged: (id) {
                      if (id == null) return;
                      phase.selectOutput(id);
                      widget.player.applyOutputProfile(phase.activeOutput);
                    },
                  ),
                ),
                _SliderSetting(
                  title: 'Remembered volume',
                  valueLabel: '${(output.volume * 100).round()}%',
                  value: output.volume,
                  min: 0,
                  max: 1,
                  onChanged: (value) =>
                      _updateOutput(output.copyWith(volume: value)),
                ),
                SwitchListTile(
                  secondary: const Icon(Icons.usb_rounded),
                  title: const Text('USB output preference'),
                  subtitle: Text(
                    'Saved for this output profile. Android does not expose verified bit-perfect status.',
                  ),
                  value: output.bitPerfectRequested,
                  onChanged: output.isDigital
                      ? (value) => _updateOutput(
                          output.copyWith(bitPerfectRequested: value),
                        )
                      : null,
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: SegmentedButton<AudioFocusBehavior>(
                    segments: const [
                      ButtonSegment(
                        value: AudioFocusBehavior.pause,
                        label: Text('Pause'),
                      ),
                      ButtonSegment(
                        value: AudioFocusBehavior.duck,
                        label: Text('Duck'),
                      ),
                      ButtonSegment(
                        value: AudioFocusBehavior.ignore,
                        label: Text('Ignore'),
                      ),
                    ],
                    selected: {phase.audioFocusBehavior},
                    onSelectionChanged: (value) =>
                        phase.setAudioFocusBehavior(value.first),
                  ),
                ),
              ],
            ),
            const _Label('MANUAL LIBRARY INTELLIGENCE'),
            _Card(
              children: [
                ListTile(
                  leading: const Icon(Icons.link_rounded),
                  title: const Text('Link alternate versions'),
                  subtitle: Text('${phase.linkedGroups.length} manual groups'),
                  onTap: _linkTracks,
                ),
                ListTile(
                  leading: const Icon(Icons.album_outlined),
                  title: const Text('Album grouping audit'),
                  subtitle: Text(_albumSummary()),
                ),
                ListTile(
                  leading: const Icon(Icons.query_stats_rounded),
                  title: const Text('Listening statistics'),
                  subtitle: Text(
                    '${phase.totalPlays} plays • ${Duration(milliseconds: phase.totalListeningMs).inMinutes} minutes',
                  ),
                  onTap: _showStats,
                ),
              ],
            ),
            const _Label('LOCAL NETWORK & COLLABORATION'),
            _Card(
              children: [
                SwitchListTile(
                  secondary: const Icon(Icons.wifi_tethering_rounded),
                  title: const Text('Share on this Wi-Fi'),
                  subtitle: Text(
                    services.localNetwork.hosting
                        ? 'Port ${services.localNetwork.port} • PIN ${services.localNetwork.pairingPin}'
                        : 'No cloud; the server stays on your local network',
                  ),
                  value: services.localNetwork.hosting,
                  onChanged: (value) =>
                      value ? _startHost() : services.localNetwork.stopHost(),
                ),
                ListTile(
                  leading: const Icon(Icons.qr_code_2_rounded),
                  title: const Text('Show local pairing QR'),
                  subtitle: const Text('Send this library/controller link'),
                  enabled: services.localNetwork.hosting,
                  onTap: services.localNetwork.hosting ? _showQr : null,
                ),
                ListTile(
                  leading: const Icon(Icons.radar_rounded),
                  title: const Text('Find Auralis devices'),
                  subtitle: Text(
                    '${services.localNetwork.peers.length} devices found',
                  ),
                  onTap: services.localNetwork.discover,
                ),
                if (services.localNetwork.peers.isNotEmpty)
                  ...services.localNetwork.peers.map(
                    (peer) => ListTile(
                      leading: const Icon(Icons.devices_rounded),
                      title: Text(peer.name),
                      subtitle: Text('${peer.host}:${peer.port}'),
                      trailing: const Icon(Icons.gamepad_outlined),
                      onTap: () => _remoteControl(peer),
                    ),
                  ),
              ],
            ),
            const _Label('ACCESSIBILITY & DISPLAY'),
            _Card(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: DropdownButtonFormField<String>(
                    initialValue: phase.localeCode,
                    decoration: const InputDecoration(
                      labelText: 'Locale and layout direction',
                    ),
                    items: const [
                      DropdownMenuItem(value: 'en', child: Text('English')),
                      DropdownMenuItem(
                        value: 'ar',
                        child: Text('العربية • RTL'),
                      ),
                      DropdownMenuItem(value: 'es', child: Text('Español')),
                    ],
                    onChanged: (value) =>
                        value == null ? null : phase.setLocale(value),
                  ),
                ),
                SwitchListTile(
                  secondary: const Icon(Icons.touch_app_rounded),
                  title: const Text('Larger tap targets'),
                  value: phase.largeTapTargets,
                  onChanged: phase.setLargeTapTargets,
                ),
                SwitchListTile(
                  secondary: const Icon(Icons.view_compact_alt_outlined),
                  title: const Text('Simplified mode'),
                  subtitle: const Text(
                    'Keep primary playback and library controls visible',
                  ),
                  value: phase.displayMode == AuralisDisplayMode.simplified,
                  onChanged: (value) => phase.setDisplayMode(
                    value
                        ? AuralisDisplayMode.simplified
                        : AuralisDisplayMode.full,
                  ),
                ),
                SwitchListTile(
                  secondary: const Icon(Icons.subtitles_rounded),
                  title: const Text('Synced lyrics panel'),
                  value: phase.showLyrics,
                  onChanged: (value) => phase.configureLyrics(visible: value),
                ),
                ListTile(
                  leading: const Icon(Icons.lyrics_outlined),
                  title: const Text('Import synced .lrc lyrics'),
                  subtitle: Text(
                    'Attach captions to ${widget.player.current.title}',
                  ),
                  onTap: _importLyrics,
                ),
                _SliderSetting(
                  title: 'Lyrics size',
                  valueLabel: '${phase.lyricsFontScale.toStringAsFixed(1)}×',
                  value: phase.lyricsFontScale,
                  min: .8,
                  max: 2,
                  divisions: 12,
                  onChanged: (value) => phase.configureLyrics(fontScale: value),
                ),
                SwitchListTile(
                  secondary: const Icon(Icons.contrast_rounded),
                  title: const Text('High-contrast lyrics'),
                  value: phase.highContrastLyrics,
                  onChanged: (value) =>
                      phase.configureLyrics(highContrast: value),
                ),
              ],
            ),
            const _Label('FINAL POLISH'),
            _Card(
              children: [
                ListTile(
                  leading: const Icon(Icons.new_releases_outlined),
                  title: const Text("What's new"),
                  subtitle: const Text(
                    'Auralis Phase 3 hardening & connected playback',
                  ),
                  onTap: _showChangelog,
                ),
                ListTile(
                  leading: const Icon(Icons.table_view_outlined),
                  title: const Text('Export library report'),
                  subtitle: const Text(
                    'CSV with metadata and manual listening counters',
                  ),
                  onTap: _exportReport,
                ),
              ],
            ),
          ],
        ),
      );
    },
  );

  Future<void> _rescan() async {
    final result = await widget.services.largeLibrary.rescanInBackground();
    if (result.tracks.isNotEmpty) {
      AlbumArtwork.clearMemoryCache();
      HomeWidgetService.clearArtworkCache();
      LibraryRepository.replaceWithDeviceTracks(result.tracks);
      widget.player.replaceLibrary(result.tracks);
    }
    setState(
      () => _status =
          '${result.tracks.length} tracks indexed without stopping playback.',
    );
  }

  void _integrityCheck() {
    final report = const LibraryIntegrityService().checkAndRepair(
      widget.services.largeLibrary.allTracks,
    );
    if (!report.healthy) {
      widget.services.largeLibrary.replace(report.repairedTracks);
      LibraryRepository.replaceWithDeviceTracks(report.repairedTracks);
      widget.player.replaceLibrary(report.repairedTracks);
    }
    setState(
      () => _status = report.healthy
          ? 'Integrity check passed.'
          : 'Repaired ${report.invalidTracks} invalid records and removed ${report.duplicateIds} duplicate IDs.',
    );
  }

  Future<void> _toggleBatteryProfiler(bool value) async {
    widget.phaseThree.setBatteryProfiler(value);
    if (value) {
      await widget.services.batteryProfile.start(
        isPlaying: () => widget.player.isPlaying,
      );
    } else {
      widget.services.batteryProfile.stop();
    }
  }

  void _updateOutput(OutputProfile profile) {
    widget.phaseThree.updateOutput(profile);
    widget.player.applyOutputProfile(profile);
  }

  Future<void> _linkTracks() async {
    final tracks = widget.player.queue.take(20).toList();
    final selected = <String>{widget.player.current.id};
    await showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Link alternate versions'),
          content: SizedBox(
            width: 480,
            child: ListView(
              shrinkWrap: true,
              children: tracks
                  .map(
                    (track) => CheckboxListTile(
                      value: selected.contains(track.id),
                      title: Text(track.title),
                      subtitle: Text(track.artist),
                      onChanged: (value) => setDialogState(
                        () => value == true
                            ? selected.add(track.id)
                            : selected.remove(track.id),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: selected.length < 2
                  ? null
                  : () {
                      widget.phaseThree.linkTracks(
                        selected.toList(),
                        'Alternate versions',
                      );
                      Navigator.pop(context);
                    },
              child: const Text('Link'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _importLyrics() async {
    const type = XTypeGroup(label: 'Synchronized lyrics', extensions: ['lrc']);
    final file = await openFile(acceptedTypeGroups: const [type]);
    if (file == null) return;
    final lines = (await file.readAsString())
        .split(RegExp(r'\r?\n'))
        .where((line) => RegExp(r'^\[\d+:\d+').hasMatch(line.trim()))
        .toList();
    if (lines.isEmpty) {
      setState(
        () => _status = 'That file contains no synchronized lyric timestamps.',
      );
      return;
    }
    widget.player.updateTrack(
      widget.player.current.copyWith(syncedLyrics: lines),
    );
    widget.phaseThree.configureLyrics(visible: true);
    setState(
      () => _status = '${lines.length} synchronized lyric lines attached.',
    );
  }

  String _albumSummary() {
    final tracks = widget.services.largeLibrary.allTracks;
    final multiDisc = tracks
        .where((track) => track.discNumber > 1)
        .map((track) => track.album)
        .toSet()
        .length;
    final compilations = tracks
        .where((track) => track.isCompilation)
        .map((track) => track.album)
        .toSet()
        .length;
    return '$multiDisc multi-disc albums • $compilations compilations';
  }

  void _showStats() {
    final ranked = widget.phaseThree.stats.entries.toList()
      ..sort((a, b) => b.value.playCount.compareTo(a.value.playCount));
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: AppTheme.surfaceHigh,
      builder: (context) => ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            'Listening statistics',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          if (ranked.isEmpty)
            const Text('Counters begin when you play a track.'),
          ...ranked.take(20).map((entry) {
            final track = widget.services.largeLibrary.allTracks
                .where((track) => track.id == entry.key)
                .firstOrNull;
            return ListTile(
              title: Text(track?.title ?? entry.key),
              subtitle: Text(
                '${entry.value.playCount} plays • ${entry.value.listenedMs ~/ 60000} min',
              ),
            );
          }),
        ],
      ),
    );
  }

  Future<void> _startHost() async {
    await widget.services.localNetwork.startHost(
      player: widget.player,
      library: () => widget.services.largeLibrary.allTracks.isEmpty
          ? widget.player.queue
          : widget.services.largeLibrary.allTracks,
      deviceName: Platform.localHostname,
    );
  }

  Future<String> _localAddress() async {
    final interfaces = await NetworkInterface.list(
      type: InternetAddressType.IPv4,
    );
    for (final interface in interfaces) {
      for (final address in interface.addresses) {
        if (!address.isLoopback && !address.address.startsWith('169.254')) {
          return address.address;
        }
      }
    }
    return '127.0.0.1';
  }

  Future<void> _showQr() async {
    final link = widget.services.localNetwork
        .localLink(await _localAddress())
        .toString();
    if (!mounted) return;
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Pair locally'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Semantics(
              label: 'QR code containing the local Auralis pairing link',
              child: QrImageView(
                data: link,
                size: 230,
                backgroundColor: Colors.white,
              ),
            ),
            const SizedBox(height: 12),
            SelectableText(link, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  void _remoteControl(RemotePeer peer) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: AppTheme.surfaceHigh,
      builder: (context) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(peer.name, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            TextField(
              controller: _pin,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: '6-digit pairing PIN',
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                IconButton.filledTonal(
                  tooltip: 'Previous',
                  onPressed: () => _send(peer, 'previous'),
                  icon: const Icon(Icons.skip_previous_rounded),
                ),
                IconButton.filled(
                  tooltip: 'Play or pause',
                  onPressed: () => _send(peer, 'playPause'),
                  icon: const Icon(Icons.play_arrow_rounded),
                ),
                IconButton.filledTonal(
                  tooltip: 'Next',
                  onPressed: () => _send(peer, 'next'),
                  icon: const Icon(Icons.skip_next_rounded),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _send(RemotePeer peer, String action) async {
    try {
      await widget.services.localNetwork.control(
        peer,
        action,
        _pin.text.trim(),
      );
    } catch (error) {
      if (mounted) {
        setState(() => _status = 'Remote command failed: $error');
      }
    }
  }

  void _showChangelog() => showDialog<void>(
    context: context,
    builder: (context) => const AlertDialog(
      title: Text("What's new in 1.1"),
      content: Text(
        '• Paged 100k+ library architecture\n'
        '• Queue and screen crash recovery\n'
        '• Output profiles and focus policies\n'
        '• Cue sheets, linked tracks, and listening counters\n'
        '• Local Wi-Fi sharing and remote control\n'
        '• RTL, simplified mode, synced lyrics, and reports',
      ),
    ),
  );

  Future<void> _exportReport() async {
    final path = await const ReportExportService().exportLibrary(
      widget.services.largeLibrary.allTracks,
      widget.phaseThree.stats,
    );
    if (mounted && path != null) {
      setState(() => _status = 'Report exported to $path');
    }
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(5, 24, 5, 9),
    child: Text(
      text,
      style: const TextStyle(
        color: AppTheme.muted,
        fontSize: 11,
        fontWeight: FontWeight.w800,
        letterSpacing: 1.2,
      ),
    ),
  );
}

class _Card extends StatelessWidget {
  const _Card({required this.children});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: AppTheme.surface,
      borderRadius: BorderRadius.circular(18),
    ),
    child: Column(children: children),
  );
}

class _SliderSetting extends StatelessWidget {
  const _SliderSetting({
    required this.title,
    required this.valueLabel,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
    this.divisions,
  });
  final String title;
  final String valueLabel;
  final double value;
  final double min;
  final double max;
  final int? divisions;
  final ValueChanged<double> onChanged;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
    child: Column(
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            Text(
              valueLabel,
              style: TextStyle(color: Theme.of(context).colorScheme.primary),
            ),
          ],
        ),
        Slider(
          value: value.clamp(min, max),
          min: min,
          max: max,
          divisions: divisions,
          onChanged: onChanged,
        ),
      ],
    ),
  );
}

class _InfoBanner extends StatelessWidget {
  const _InfoBanner({required this.text, required this.onClose});
  final String text;
  final VoidCallback onClose;
  @override
  Widget build(BuildContext context) => Material(
    color: Theme.of(context).colorScheme.primary.withValues(alpha: .13),
    borderRadius: BorderRadius.circular(14),
    child: ListTile(
      title: Text(text),
      trailing: IconButton(
        onPressed: onClose,
        icon: const Icon(Icons.close_rounded),
      ),
    ),
  );
}
