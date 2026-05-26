import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../core/player/player_prefs.dart';

/// In-player quick settings bottom sheet.
/// Shows the most-needed settings without leaving the player.
class QuickSettingsPanel extends StatefulWidget {
  final PlayerPrefs prefs;
  final ValueChanged<PlayerPrefs> onChanged;
  final VoidCallback onDone;
  final VoidCallback onOpenFullSettings;
  final int subDelayMs;
  final int audioDelayMs;
  final ValueChanged<int> onSubDelay;
  final ValueChanged<int> onAudioDelay;
  final VoidCallback onOpenSubSync;
  final VoidCallback onOpenAudioSync;
  final double speed;
  final ValueChanged<double> onSpeedChanged;

  const QuickSettingsPanel({
    super.key,
    required this.prefs,
    required this.onChanged,
    required this.onDone,
    required this.onOpenFullSettings,
    required this.subDelayMs,
    required this.audioDelayMs,
    required this.onSubDelay,
    required this.onAudioDelay,
    required this.onOpenSubSync,
    required this.onOpenAudioSync,
    required this.speed,
    required this.onSpeedChanged,
  });

  @override
  State<QuickSettingsPanel> createState() => _QuickSettingsPanelState();
}

class _QuickSettingsPanelState extends State<QuickSettingsPanel> {
  late PlayerPrefs _p;

  @override
  void initState() { super.initState(); _p = widget.prefs; }

  void _update(PlayerPrefs next) { setState(() => _p = next); widget.onChanged(next); }

  @override
  Widget build(BuildContext context) {
    const accent = Color(0xFFE8002D);
    const speeds = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0];

    return Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
      decoration: const BoxDecoration(
        color: Color(0xFF12121E),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        // Handle
        Padding(padding:const EdgeInsets.only(top:12,bottom:4),
          child:Center(child:Container(width:36,height:4,
            decoration:BoxDecoration(color:Colors.white24,borderRadius:BorderRadius.circular(2))))),

        // Header
        Padding(padding:const EdgeInsets.fromLTRB(16,4,8,8),
          child:Row(children:[
            const Text('Player Settings',style:TextStyle(color:Colors.white,fontSize:15,fontWeight:FontWeight.w600)),
            const Spacer(),
            TextButton.icon(
              onPressed:widget.onOpenFullSettings,
              icon:const Icon(Icons.tune_rounded,size:14),
              label:const Text('Full Settings',style:TextStyle(fontSize:12)),
              style:TextButton.styleFrom(foregroundColor:accent),
            ),
            TextButton(onPressed:widget.onDone,
              child:const Text('Done',style:TextStyle(color:Colors.white60,fontSize:13))),
          ])),

        Flexible(child:SingleChildScrollView(padding:const EdgeInsets.fromLTRB(16,0,16,24),child:Column(children:[
          // ── Toggles ────────────────────────────────────────────
          _QRow('Gestures',Icons.swipe_rounded,
            trailing:Switch(value:_p.gestureEnabled,activeColor:accent,
              onChanged:(v)=>_update(_p.copyWith(gestureEnabled:v)))),
          _QRow('Subtitles',Icons.subtitles_outlined,
            trailing:Switch(value:_p.subtitleEnabled,activeColor:accent,
              onChanged:(v)=>_update(_p.copyWith(subtitleEnabled:v)))),
          _QRow('Dialogue Boost',Icons.record_voice_over_rounded,
            trailing:Switch(value:_p.dialogueBoostEnabled,activeColor:accent,
              onChanged:(v)=>_update(_p.copyWith(dialogueBoostEnabled:v)))),
          _QRow('Night Mode',Icons.nightlight_rounded,
            trailing:Switch(value:_p.nightMode,activeColor:accent,
              onChanged:(v)=>_update(_p.copyWith(nightMode:v)))),
          _QRow('Ambilight',Icons.blur_on_rounded,
            trailing:Switch(value:_p.ambilightEnabled,activeColor:accent,
              onChanged:(v)=>_update(_p.copyWith(ambilightEnabled:v)))),
          _QRow('Transparent Player',Icons.opacity,
            trailing:Switch(value:_p.transparentModeEnabled,activeColor:accent,
              onChanged:(v)=>_update(_p.copyWith(transparentModeEnabled:v)))),
          _QRow('Binge Guard',Icons.health_and_safety_outlined,
            trailing:Switch(value:_p.bingeGuardEnabled,activeColor:accent,
              onChanged:(v)=>_update(_p.copyWith(bingeGuardEnabled:v)))),

          const Divider(color:Colors.white12,height:24),

          // ── Volume Boost ───────────────────────────────────────
          _QRow('Volume Boost', Icons.volume_up_rounded,
            trailing:Text('${(_p.volumeBoostMultiplier*100).toInt()}%',
              style:TextStyle(color:_p.volumeBoostMultiplier>2.0?Colors.red:_p.volumeBoostMultiplier>1.5?Colors.orange:Colors.white,fontWeight:FontWeight.w600))),
          Slider(value:_p.volumeBoostMultiplier,min:1.0,max:3.0,divisions:20,
            activeColor:accent,inactiveColor:Colors.white12,
            label:'${(_p.volumeBoostMultiplier*100).toInt()}%',
            onChanged:(v)=>_update(_p.copyWith(volumeBoostMultiplier:v))),
          if (_p.volumeBoostMultiplier > 2.0)
            const Padding(padding:EdgeInsets.only(bottom:8),
              child:Text('⚠ May distort audio at 300%',
                style:TextStyle(color:Colors.red,fontSize:11),textAlign:TextAlign.center))
          else if (_p.volumeBoostMultiplier > 1.5)
            const Padding(padding:EdgeInsets.only(bottom:8),
              child:Text('⚠ High volume — use with caution',
                style:TextStyle(color:Colors.orange,fontSize:11),textAlign:TextAlign.center)),

          // ── Sub Size ───────────────────────────────────────────
          _QRow('Sub Size',Icons.text_fields_rounded,
            trailing:Text('${_p.subtitleFontSize.toInt()}px',
              style:const TextStyle(color:Colors.white70))),
          Slider(value:_p.subtitleFontSize,min:10,max:40,
            activeColor:accent,inactiveColor:Colors.white12,
            onChanged:(v)=>_update(_p.copyWith(subtitleFontSize:v))),

          const Divider(color:Colors.white12,height:24),

          // ── Sync ───────────────────────────────────────────────
          _SyncRow(
            label:'Sub Sync',
            delayMs:widget.subDelayMs,
            onReset:()=>widget.onSubDelay(0),
            onFull:widget.onOpenSubSync,
          ),
          const SizedBox(height:6),
          _SyncRow(
            label:'Audio Sync',
            delayMs:widget.audioDelayMs,
            onReset:()=>widget.onAudioDelay(0),
            onFull:widget.onOpenAudioSync,
          ),

          const Divider(color:Colors.white12,height:24),

          // ── Speed ─────────────────────────────────────────────
          const Text('Speed',style:TextStyle(color:Colors.white70,fontSize:13)),
          const SizedBox(height:6),
          Row(children: speeds.map((s) => Expanded(child: Padding(
            padding:const EdgeInsets.symmetric(horizontal:2),
            child:_SpeedChip(s, widget.speed==s, ()=>widget.onSpeedChanged(s)),
          ))).toList()),

          const Divider(color:Colors.white12,height:24),

          // ── Rotation ──────────────────────────────────────────
          _QRow('Rotation',Icons.screen_rotation_rounded,
            trailing:Text(_rotationShort(_p.rotationMode),
              style:const TextStyle(color:Colors.white70,fontSize:12))),

          const Divider(color:Colors.white12,height:24),

          // ── Auto-hide ─────────────────────────────────────────
          const Text('Auto-hide Controls',style:TextStyle(color:Colors.white70,fontSize:13)),
          const SizedBox(height:6),
          Row(children:[0,2,3,5,10].map((s)=>Expanded(child:Padding(
            padding:const EdgeInsets.symmetric(horizontal:2),
            child:_HideChip(s,_p.autoHideSeconds==s,
              ()=>_update(_p.copyWith(autoHideSeconds:s))),
          ))).toList()),
        ]))),
      ]),
    ).animate().slideY(begin:0.15,end:0,duration:260.ms,curve:Curves.easeOutCubic)
     .fadeIn(duration:200.ms);
  }
}

class _QRow extends StatelessWidget {
  final String label;
  final IconData icon;
  final Widget trailing;
  const _QRow(this.label, this.icon, {required this.trailing});
  @override
  Widget build(BuildContext ctx) => Row(children:[
    Icon(icon,size:17,color:Colors.white54),
    const SizedBox(width:10),
    Expanded(child:Text(label,style:const TextStyle(color:Colors.white,fontSize:13))),
    trailing,
  ]);
}

class _SyncRow extends StatelessWidget {
  final String label;
  final int delayMs;
  final VoidCallback onReset;
  final VoidCallback onFull;
  const _SyncRow({required this.label,required this.delayMs,required this.onReset,required this.onFull});
  @override
  Widget build(BuildContext context) => Row(children:[
    Expanded(child:Text(label,style:const TextStyle(color:Colors.white70,fontSize:13))),
    Text(delayMs==0?'+0ms':'${delayMs>0?'+':''}${delayMs}ms',
      style:TextStyle(color:delayMs==0?Colors.white38:const Color(0xFFE8002D),fontWeight:FontWeight.w600,fontSize:12)),
    if (delayMs!=0) ...[
      const SizedBox(width:4),
      GestureDetector(onTap:onReset,
        child:const Icon(Icons.refresh_rounded,size:14,color:Color(0xFFE8002D))),
    ],
    const SizedBox(width:8),
    TextButton(onPressed:onFull,
      child:const Text('Full Sync →',style:TextStyle(color:Color(0xFFE8002D),fontSize:11))),
  ]);
}

class _SpeedChip extends StatelessWidget {
  final double speed;
  final bool selected;
  final VoidCallback onTap;
  const _SpeedChip(this.speed, this.selected, this.onTap);
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration:const Duration(milliseconds:150),
      padding:const EdgeInsets.symmetric(vertical:6),
      decoration:BoxDecoration(
        color:selected?const Color(0xFFE8002D):Colors.white12,
        borderRadius:BorderRadius.circular(6)),
      alignment:Alignment.center,
      child:Text(speed==1.0?'×1.0':'×$speed',
        style:TextStyle(color:selected?Colors.white:Colors.white60,fontSize:11,fontWeight:selected?FontWeight.bold:FontWeight.normal)),
    ),
  );
}

class _HideChip extends StatelessWidget {
  final int secs;
  final bool selected;
  final VoidCallback onTap;
  const _HideChip(this.secs, this.selected, this.onTap);
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration:const Duration(milliseconds:150),
      padding:const EdgeInsets.symmetric(vertical:6),
      decoration:BoxDecoration(
        color:selected?const Color(0xFFE8002D):Colors.white12,
        borderRadius:BorderRadius.circular(6)),
      alignment:Alignment.center,
      child:Text(secs==0?'∞':'${secs}s',
        style:TextStyle(color:selected?Colors.white:Colors.white60,fontSize:11,fontWeight:selected?FontWeight.bold:FontWeight.normal)),
    ),
  );
}

String _rotationShort(String mode) {
  switch (mode) {
    case 'lock_left':    return '🔒 Left';
    case 'lock_right':   return '🔒 Right';
    case 'lock_portrait': return '🔒 Portrait';
    case 'auto':         return '🔄 Auto';
    case 'lock_current': return '🔒 Current';
    default:             return '🔄 Landscape';
  }
}
