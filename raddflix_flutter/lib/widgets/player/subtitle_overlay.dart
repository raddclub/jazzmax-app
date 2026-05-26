import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/player/player_prefs.dart';

/// Custom subtitle overlay that renders subtitle text using PlayerPrefs styles.
/// Wraps around the actual MPV subtitle track (which is set to invisible via
/// SubtitleViewConfiguration(visible:false)) so we control the full style.
class SubtitleOverlay extends StatelessWidget {
  final String? currentLine;
  final PlayerPrefs prefs;

  const SubtitleOverlay({
    super.key,
    required this.currentLine,
    required this.prefs,
  });

  Alignment get _alignment {
    switch (prefs.subtitlePosition) {
      case 'top': return Alignment.topCenter;
      case 'center': return Alignment.center;
      default: return Alignment.bottomCenter;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (currentLine == null || currentLine!.isEmpty) return const SizedBox.shrink();

    final textColor = Color(int.parse(
        prefs.subtitleTextColor.value.toRadixString(16).padLeft(8, 'ff'), radix: 16));
    final outlineColor = Color(int.parse(
        prefs.subtitleOutlineColor.value.toRadixString(16).padLeft(8, 'ff'), radix: 16));
    final bgColor = prefs.subtitleBackgroundColor.withOpacity(prefs.subtitleBackgroundOpacity);

    return Positioned.fill(
      child: Align(
        alignment: _alignment,
        child: Padding(
          padding: EdgeInsets.only(
            bottom: prefs.subtitlePosition == 'bottom' ? 80 + prefs.subtitleVerticalOffset * 50 : 0,
            top: prefs.subtitlePosition == 'top' ? 20 + prefs.subtitleVerticalOffset * 50 : 0,
          ),
          child: GestureDetector(
            onLongPress: () {
              Clipboard.setData(ClipboardData(text: currentLine!));
            },
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 24),
              padding: bgColor.opacity > 0.01
                  ? const EdgeInsets.symmetric(horizontal: 8, vertical: 4)
                  : EdgeInsets.zero,
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                currentLine!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: prefs.subtitleFontSize,
                  color: textColor,
                  fontWeight: prefs.subtitleBold ? FontWeight.bold : FontWeight.normal,
                  fontStyle: prefs.subtitleItalic ? FontStyle.italic : FontStyle.normal,
                  shadows: prefs.subtitleOutlineThickness > 0 ? [
                    Shadow(
                      offset: Offset(prefs.subtitleOutlineThickness, prefs.subtitleOutlineThickness),
                      blurRadius: prefs.subtitleOutlineThickness * 2,
                      color: outlineColor,
                    ),
                    Shadow(
                      offset: Offset(-prefs.subtitleOutlineThickness, -prefs.subtitleOutlineThickness),
                      blurRadius: prefs.subtitleOutlineThickness * 2,
                      color: outlineColor,
                    ),
                  ] : null,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
