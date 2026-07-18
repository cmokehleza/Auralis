import 'dart:async';

import 'package:flutter/material.dart';

import '../models/track.dart';
import '../services/lyrics_service.dart';
import '../theme/app_motion.dart';
import '../theme/app_theme.dart';

class SyncedLyricsView extends StatefulWidget {
  const SyncedLyricsView({
    super.key,
    required this.track,
    required this.position,
    this.fontScale = 1,
    this.highContrast = false,
    this.compact = true,
    this.lyricsService = const LyricsService(),
  });

  final Track track;
  final Duration position;
  final double fontScale;
  final bool highContrast;
  final bool compact;
  final LyricsService lyricsService;

  @override
  State<SyncedLyricsView> createState() => _SyncedLyricsViewState();
}

class _SyncedLyricsViewState extends State<SyncedLyricsView> {
  final ScrollController _scrollController = ScrollController();
  LyricsDocument? _document;
  late String _trackId;
  late int _attachedLyricsSignature;
  int _loadGeneration = 0;
  int _activeIndex = -1;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _trackId = widget.track.id;
    _attachedLyricsSignature = Object.hashAll(widget.track.syncedLyrics);
    _startLoad();
  }

  @override
  void didUpdateWidget(covariant SyncedLyricsView oldWidget) {
    super.didUpdateWidget(oldWidget);
    final signature = Object.hashAll(widget.track.syncedLyrics);
    if (_trackId != widget.track.id ||
        _attachedLyricsSignature != signature ||
        oldWidget.lyricsService != widget.lyricsService) {
      _trackId = widget.track.id;
      _attachedLyricsSignature = signature;
      _document = null;
      _loading = true;
      _activeIndex = -1;
      _startLoad();
    }
  }

  @override
  void dispose() {
    _loadGeneration++;
    _scrollController.dispose();
    super.dispose();
  }

  void _startLoad() {
    final generation = ++_loadGeneration;
    final track = widget.track;
    unawaited(_resolve(track, generation));
  }

  Future<void> _resolve(Track track, int generation) async {
    LyricsDocument? resolved;
    if (!track.isEmpty) {
      try {
        resolved = await widget.lyricsService.loadFor(track);
      } catch (_) {
        resolved = null;
      }
    }
    if (!mounted ||
        generation != _loadGeneration ||
        track.id != widget.track.id) {
      return;
    }
    setState(() {
      _document = resolved;
      _loading = false;
      _activeIndex = -1;
    });
  }

  @override
  Widget build(BuildContext context) {
    final nextActive = _document?.activeIndexAt(widget.position) ?? -1;
    if (_activeIndex != nextActive) {
      _activeIndex = nextActive;
      if (nextActive >= 0) _scrollToActive(context, nextActive);
    }
    final height = widget.compact ? 136.0 * widget.fontScale : null;
    return Semantics(
      liveRegion: _activeIndex >= 0,
      label: _activeIndex >= 0 && _document != null
          ? 'Current lyric: ${_document!.lines[_activeIndex].text}'
          : null,
      child: Container(
        height: height,
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: widget.highContrast
              ? Colors.black
              : AppTheme.surface.withValues(alpha: .72),
          borderRadius: BorderRadius.circular(14),
          border: widget.highContrast ? Border.all(color: Colors.white) : null,
        ),
        child: _buildContent(context, nextActive),
      ),
    );
  }

  Widget _buildContent(BuildContext context, int activeIndex) {
    if (_loading) {
      return const Center(
        child: SizedBox.square(
          dimension: 22,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }
    final document = _document;
    if (document == null || document.lines.isEmpty) {
      return Center(
        child: Text(
          'Lyrics not found for this song',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: widget.highContrast ? Colors.white : AppTheme.muted,
            fontSize: 15 * widget.fontScale,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }

    final itemExtent = (widget.compact ? 42.0 : 64.0) * widget.fontScale;
    return ListView.builder(
      controller: _scrollController,
      itemExtent: itemExtent,
      padding: EdgeInsets.symmetric(
        vertical: widget.compact ? itemExtent : itemExtent * 1.4,
      ),
      itemCount: document.lines.length,
      itemBuilder: (context, index) {
        final line = document.lines[index];
        final active = index == activeIndex;
        final synced = document.isSynced;
        final activeColor = widget.highContrast
            ? Colors.white
            : Theme.of(context).colorScheme.primary;
        final inactiveColor = widget.highContrast
            ? Colors.white70
            : AppTheme.muted;
        return Center(
          child: AnimatedDefaultTextStyle(
            duration: AppMotion.duration(context, AppMotion.fast),
            curve: Curves.easeOutCubic,
            style: TextStyle(
              color: active || !synced ? activeColor : inactiveColor,
              fontSize:
                  (active
                      ? (widget.compact ? 17 : 24)
                      : (widget.compact ? 15 : 19)) *
                  widget.fontScale,
              height: 1.22,
              fontWeight: active ? FontWeight.w700 : FontWeight.w500,
            ),
            child: AnimatedOpacity(
              duration: AppMotion.duration(context, AppMotion.fast),
              opacity: active || !synced ? 1 : .62,
              child: Text(
                line.text,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
            ),
          ),
        );
      },
    );
  }

  void _scrollToActive(BuildContext context, int index) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      final itemExtent = (widget.compact ? 42.0 : 64.0) * widget.fontScale;
      final viewport = _scrollController.position.viewportDimension;
      final requested = index * itemExtent - (viewport - itemExtent) / 2;
      final target = requested.clamp(
        _scrollController.position.minScrollExtent,
        _scrollController.position.maxScrollExtent,
      );
      if (AppMotion.reduced(context)) {
        _scrollController.jumpTo(target);
      } else {
        unawaited(
          _scrollController.animateTo(
            target,
            duration: AppMotion.fast,
            curve: Curves.easeOutCubic,
          ),
        );
      }
    });
  }
}
