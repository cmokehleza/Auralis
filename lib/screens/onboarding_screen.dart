import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({
    super.key,
    required this.onComplete,
    required this.onScan,
  });

  final VoidCallback onComplete;
  final Future<int> Function() onScan;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _page = PageController();
  int _index = 0;
  int? _scanCount;

  @override
  void dispose() {
    _page.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Column(
        children: [
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: TextButton(
              onPressed: widget.onComplete,
              child: const Text('Set up later'),
            ),
          ),
          Expanded(
            child: PageView(
              controller: _page,
              onPageChanged: (value) => setState(() => _index = value),
              children: [
                const _OnboardingPage(
                  icon: Icons.library_music_rounded,
                  title: 'Your music, entirely yours',
                  body:
                      'Auralis plays local files and keeps advanced controls manual. Nothing is uploaded.',
                ),
                _OnboardingPage(
                  icon: Icons.folder_copy_rounded,
                  title: 'Choose your library',
                  body: _scanCount == null
                      ? 'Scan Android MediaStore now. You can scan again from Library at any time.'
                      : '$_scanCount tracks are ready.',
                  action: FilledButton.icon(
                    onPressed: () async {
                      final count = await widget.onScan();
                      if (mounted) setState(() => _scanCount = count);
                    },
                    icon: const Icon(Icons.sync_rounded),
                    label: const Text('Scan music'),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(24),
            child: Row(
              children: [
                Text(
                  '${_index + 1} / 2',
                  style: const TextStyle(color: AppTheme.muted),
                ),
                const Spacer(),
                FilledButton(
                  onPressed: _index == 1
                      ? widget.onComplete
                      : () => _page.nextPage(
                          duration: const Duration(milliseconds: 320),
                          curve: Curves.easeOutCubic,
                        ),
                  child: Text(_index == 1 ? 'Start listening' : 'Continue'),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class _OnboardingPage extends StatelessWidget {
  const _OnboardingPage({
    required this.icon,
    required this.title,
    required this.body,
    this.action,
  });
  final IconData icon;
  final String title;
  final String body;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 36),
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: 82, color: Theme.of(context).colorScheme.primary),
        const SizedBox(height: 32),
        Text(
          title,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.displaySmall,
        ),
        const SizedBox(height: 14),
        Text(
          body,
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppTheme.muted, height: 1.5),
        ),
        if (action != null) ...[const SizedBox(height: 24), action!],
      ],
    ),
  );
}
