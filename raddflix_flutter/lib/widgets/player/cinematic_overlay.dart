import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/constants.dart';

/// Cinematic Mode overlay — controls hidden, gestures active.
/// Entry: tap dedicated button. Exit: swipe up from bottom → minimal strip.
class CinematicOverlay extends StatefulWidget {
  final bool isPlaying;
  final Duration position;
  final Duration duration;
  final String Function(Duration) fmtDur;
  final VoidCallback onPlayPause;
  final VoidCallback onExit;
  final ValueChanged<double> onSeekTo;

  const CinematicOverlay({
    super.key,
    required this.isPlaying,
    required this.position,
    required this.duration,
    required this.fmtDur,
    required this.onPlayPause,
    required this.onExit,
    required this.onSeekTo,
  });

  @override
  State<CinematicOverlay> createState() => _CinematicOverlayState();
}

class _CinematicOverlayState extends State<CinematicOverlay> {
  bool _stripVisible = false;
  double _dragStart = 0;

  void _showStrip() {
    setState(() => _stripVisible = true);
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) setState(() => _stripVisible = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onVerticalDragStart: (d) => _dragStart = d.localPosition.dy,
      onVerticalDragEnd: (d) {
        // Swipe up from bottom area → show strip
        if (_dragStart > MediaQuery.of(context).size.height * 0.7 && d.primaryVelocity != null && d.primaryVelocity! < -100) {
          _showStrip();
        }
      },
      onTap: _showStrip,
      child: Positioned.fill(
        child: Stack(children: [
          // Invisible full-screen tap area
          Container(color: Colors.transparent),

          // Minimal strip (slides up from bottom on swipe)
          if (_stripVisible)
            Positioned(
              bottom: 0, left: 0, right: 0,
              child: _CinematicStrip(
                isPlaying: widget.isPlaying,
                position: widget.position,
                duration: widget.duration,
                fmtDur: widget.fmtDur,
                onPlayPause: widget.onPlayPause,
                onExit: widget.onExit,
                onSeekTo: widget.onSeekTo,
              ).animate()
                .slideY(begin: 1, end: 0, duration: 200.ms, curve: AppCurves.standard)
                .fadeIn(duration: 150.ms),
            ),
        ]),
      ),
    );
  }
}

class _CinematicStrip extends StatelessWidget {
  final bool isPlaying;
  final Duration position;
  final Duration duration;
  final String Function(Duration) fmtDur;
  final VoidCallback onPlayPause;
  final VoidCallback onExit;
  final ValueChanged<double> onSeekTo;

  const _CinematicStrip({
    required this.isPlaying, required this.position, required this.duration,
    required this.fmtDur, required this.onPlayPause, required this.onExit,
    required this.onSeekTo,
  });

  double get _progress => duration.inMilliseconds > 0
      ? (position.inMilliseconds / duration.inMilliseconds).clamp(0.0, 1.0)
      : 0.0;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black.withOpacity(0.75),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        // Seek bar
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 2,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
            activeTrackColor: AppColors.primary,
            inactiveTrackColor: Colors.white24,
            thumbColor: AppColors.primary,
          ),
          child: Slider(
            value: _progress,
            onChanged: onSeekTo,
          ),
        ),
        Row(children: [
          Text(fmtDur(position),
              style: const TextStyle(color: Colors.white70, fontSize: 11)),
          const Spacer(),
          // Play/Pause
          GestureDetector(
            onTap: onPlayPause,
            child: Container(
              width: 40, height: 40,
              decoration: BoxDecoration(shape: BoxShape.circle, color: AppColors.primary),
              child: Icon(isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                  color: Colors.white, size: 22),
            ),
          ),
          const Spacer(),
          // Exit cinematic
          GestureDetector(
            onTap: onExit,
            child: const Text('Exit Cinematic',
                style: TextStyle(color: Colors.white54, fontSize: 11)),
          ),
        ]),
      ]),
    );
  }
}
