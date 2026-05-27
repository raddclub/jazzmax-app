import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../core/player/player_prefs.dart';

const _bands = <String>['60', '170', '310', '600', '1k', '3k', '6k', '12k', '14k', '16k'];
const _presets = {
  'flat':  [0.0, 0.0,  0.0,  0.0,  0.0,  0.0,  0.0,  0.0,  0.0,  0.0],
  'rock':  [4.0, 3.0,  2.0, -1.0, -1.0,  2.0,  4.0,  5.0,  5.0,  4.0],
  'pop':   [-1.0,2.0,  4.0,  4.0,  2.0,  0.0, -1.0, -1.0,  0.0,  1.0],
  'bass':  [6.0, 5.0,  4.0,  2.0,  0.0, -1.0, -2.0, -3.0, -3.0, -3.0],
  'movie': [3.0, 2.0,  1.0,  0.0,  1.0,  3.0,  4.0,  4.0,  3.0,  2.0],
  'voice': [-2.0,-2.0, 2.0,  5.0,  5.0,  4.0,  2.0,  0.0, -1.0, -2.0],
};

class EqPanel extends StatefulWidget {
  final PlayerPrefs prefs;
  final ValueChanged<PlayerPrefs> onChanged;
  final VoidCallback onDone;

  const EqPanel({super.key, required this.prefs, required this.onChanged, required this.onDone});

  @override
  State<EqPanel> createState() => _EqPanelState();
}

class _EqPanelState extends State<EqPanel> {
  late List<double> _bands;
  late bool _enabled;
  late String _preset;
  late bool _dialogueBoost;
  late bool _normalization;

  @override
  void initState() {
    super.initState();
    _bands       = List<double>.from(widget.prefs.equalizerBands);
    _enabled     = widget.prefs.equalizerEnabled;
    _preset      = widget.prefs.equalizerPreset;
    _dialogueBoost = widget.prefs.dialogueBoostEnabled;
    _normalization = widget.prefs.audioNormalization;
  }

  void _notify() {
    widget.onChanged(widget.prefs.copyWith(
      equalizerEnabled: _enabled,
      equalizerPreset: _preset,
      equalizerBands: _bands,
      dialogueBoostEnabled: _dialogueBoost,
      audioNormalization: _normalization,
    ));
  }

  void _applyPreset(String p) {
    if (_presets[p] == null) return;
    setState(() {
      _preset = p;
      _bands = List<double>.from(_presets[p]!);
    });
    _notify();
  }

  @override
  Widget build(BuildContext context) {
    const accent = Color(0xFFE8002D);
    return Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.75),
      decoration: const BoxDecoration(
        color: Color(0xFF1A1A2E),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        // Handle
        Center(child:Container(width:36,height:4,
          decoration:BoxDecoration(color:Colors.white24,borderRadius:BorderRadius.circular(2)))),
        const SizedBox(height:12),
        // Header
        Row(mainAxisAlignment:MainAxisAlignment.spaceBetween, children:[
          const Text('Equalizer',style:TextStyle(color:Colors.white,fontSize:16,fontWeight:FontWeight.w600)),
          Row(children:[
            Switch(value:_enabled, activeColor:accent, onChanged:(v){ setState(()=>_enabled=v); _notify(); }),
            TextButton(onPressed:widget.onDone, child:const Text('Done',style:TextStyle(color:accent))),
          ]),
        ]),

        // Dialogue Boost + Normalization
        Row(children:[
          _Chip('Dialogue Boost', Icons.record_voice_over_rounded, _dialogueBoost, (v){
            setState((){ _dialogueBoost=v; if(v){ _enabled=false; } }); _notify();
          }),
          const SizedBox(width:8),
          _Chip('Normalize', Icons.graphic_eq_rounded, _normalization, (v){
            setState(()=>_normalization=v); _notify();
          }),
        ]),
        const SizedBox(height:10),

        // Presets
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(children: _presets.keys.map((p) => Padding(
            padding:const EdgeInsets.only(right:6),
            child:ChoiceChip(
              label:Text(p[0].toUpperCase()+p.substring(1)),
              selected:_preset==p,
              selectedColor:accent,
              labelStyle:TextStyle(color:_preset==p?Colors.white:Colors.white60,fontSize:12),
              backgroundColor:Colors.white12,
              onSelected:(_)=>_applyPreset(p),
            ),
          )).toList()),
        ),
        const SizedBox(height:12),

        // Sliders — 10 bands
        if (_enabled) SizedBox(
          height: 160,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: List.generate(_bands.length, (i) => Expanded(child:
              Column(children:[
                Expanded(child: RotatedBox(
                  quarterTurns: 3,
                  child: Slider(
                    value: _bands[i].clamp(-12.0, 12.0),
                    min: -12, max: 12,
                    activeColor: accent,
                    inactiveColor: Colors.white12,
                    onChanged: (v){
                      setState((){ _bands[i]=v; _preset='custom'; });
                      _notify();
                    },
                  ),
                )),
                Text(_bands[i]==0?'0':(_bands[i]>0?'+${_bands[i].toStringAsFixed(0)}':'${_bands[i].toStringAsFixed(0)}'),
                  style:const TextStyle(color:Colors.white54,fontSize:9)),
                Text('${_bands[i].toStringAsFixed(0)} Hz', style:const TextStyle(color:Colors.white38,fontSize:9)),
              ]),
            )).toList(),
          ),
        ).animate().fadeIn(duration:200.ms),
      ]),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool active;
  final ValueChanged<bool> onChanged;
  const _Chip(this.label, this.icon, this.active, this.onChanged);
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: () => onChanged(!active),
    child: AnimatedContainer(
      duration: const Duration(milliseconds:180),
      padding: const EdgeInsets.symmetric(horizontal:10,vertical:6),
      decoration: BoxDecoration(
        color: active ? const Color(0x33E8002D) : Colors.white10,
        border: Border.all(color: active ? const Color(0xFFE8002D) : Colors.white12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(mainAxisSize:MainAxisSize.min, children:[
        Icon(icon, size:14, color: active ? const Color(0xFFE8002D) : Colors.white60),
        const SizedBox(width:4),
        Text(label, style: TextStyle(color: active ? const Color(0xFFE8002D) : Colors.white60, fontSize:12)),
      ]),
    ),
  );
}
