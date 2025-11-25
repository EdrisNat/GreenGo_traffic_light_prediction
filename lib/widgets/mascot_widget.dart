import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';

class MascotWidget extends StatefulWidget {
  final String mascotName;
  final double speed;
  final double? secondsToChange;
  final bool isSpeaking;
  final int phase; // 0: green, 1: yellow, 2: red
  final int? nextPhaseHint; // The phase that will come after yellow
  final ValueChanged<bool>? onSpeakingChanged;

  const MascotWidget({
    super.key,
    required this.mascotName,
    required this.speed,
    this.secondsToChange,
    this.isSpeaking = false,
    this.phase = 0,
    this.nextPhaseHint,
    this.onSpeakingChanged,
  });

  @override
  State<MascotWidget> createState() => _MascotWidgetState();
}

class _MascotWidgetState extends State<MascotWidget> {
  final FlutterTts _tts = FlutterTts();
  String _lastUtterance = '';
  DateTime _lastSpoken = DateTime.fromMillisecondsSinceEpoch(0);
  bool _isSpeakingNow = false;
  int _lastPhase = -1;
  final Duration _samePhaseCooldown = const Duration(seconds: 15);
  final Duration _phaseChangeCooldown = const Duration(seconds: 5);

  @override
  void initState() {
    super.initState();
    _configureTts();
  }

  @override
  void didUpdateWidget(covariant MascotWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isSpeaking && !_isSpeakingNow) {
      _maybeSpeak();
    }
  }

  @override
  void dispose() {
    _tts.stop();
    super.dispose();
  }

  Future<void> _configureTts() async {
    await _tts.setLanguage('en-US');
    await _tts.setSpeechRate(0.5);
    await _tts.setVolume(1.0);
    await _tts.setPitch(1.0);
    await _tts.awaitSpeakCompletion(true);

    _tts.setStartHandler(() {
      _isSpeakingNow = true;
      widget.onSpeakingChanged?.call(true);
      debugPrint('TTS started: \\u201d$_lastUtterance\\u201d');
    });

    _tts.setCompletionHandler(() {
      _isSpeakingNow = false;
      widget.onSpeakingChanged?.call(false);
      _lastPhase = widget.phase;
      debugPrint('TTS completed');
    });

    _tts.setErrorHandler((msg) {
      _isSpeakingNow = false;
      widget.onSpeakingChanged?.call(false);
      debugPrint('TTS error: $msg');
    });
  }

  Future<void> _maybeSpeak() async {
    final now = DateTime.now();
    final bool phaseChanged = widget.phase != _lastPhase;
    final Duration minGap = phaseChanged ? _phaseChangeCooldown : _samePhaseCooldown;

    if (now.difference(_lastSpoken) < minGap) return;

    final utterance = _buildUtterance();
    if (utterance.isEmpty) return;
    if (!phaseChanged && utterance == _lastUtterance) return;

    _lastUtterance = utterance;
    _lastSpoken = now;
    await _tts.speak(utterance);
  }

  String _buildUtterance() {
    if (widget.secondsToChange == null) return '';
    
    final speedStr = widget.speed.toStringAsFixed(0);
    final secStr = widget.secondsToChange!.toStringAsFixed(0);

    switch (widget.phase) {
      case 2: // Red
        return 'Signal is red. In $secStr seconds, the light will be green. Prepare to proceed at $speedStr kilometers per hour.';
      case 1: // Yellow
        String nextAction = (widget.nextPhaseHint == 2) 
            ? "Prepare to stop."
            : "Get ready for change.";
        return 'Signal is yellow. $nextAction Change in $secStr seconds. Recommended speed is $speedStr kilometers per hour.';
      default: // Green
        return 'Signal is green. Maintain $speedStr kilometers per hour to clear the intersection before the light turns red in $secStr seconds.';
    }
  }

  String _getMascotMessage() {
    final state = _phaseLabel();
    if (widget.secondsToChange == null) {
      return "$state: ${widget.mascotName} is waiting for timing data...";
    }
    final sec = widget.secondsToChange!.toStringAsFixed(1);
    final spd = widget.speed.toStringAsFixed(0);
    switch (widget.phase) {
      case 2:
        return "$state: Change in $sec s. Aim for $spd km/h to meet the green.";
      case 1:
        String nextPhaseAction = (widget.nextPhaseHint == 2) ? "Prepare to stop." : "Get ready for green.";
        return "$state: Change in $sec s. $nextPhaseAction";
      default:
        return "$state: Change in $sec s. Maintain $spd km/h.";
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 120,
          height: 120,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              colors: [Color(0xFFB9F6CA), Color(0xFF66BB6A)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              _getMascotContent(),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Container(
          width: 150,
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.green.shade200),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 10,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Text(
            _getMascotMessage(),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 11),
            textAlign: TextAlign.center,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _getMascotContent() {
    final baseColor = () {
      switch (widget.phase) {
        case 2:
          return Colors.redAccent;
        case 1:
          return Colors.amberAccent;
        default:
          return Colors.greenAccent;
      }
    }();

    switch (widget.mascotName) {
      case 'Lighty':
        final double targetScale = widget.phase == 0
            ? 1.05
            : widget.phase == 1
                ? 1.0
                : 0.95;
        return TweenAnimationBuilder<double>(
          tween: Tween<double>(begin: 1.0, end: targetScale),
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeInOut,
          builder: (context, value, child) {
            return Transform.scale(
              scale: value,
              child: Container(
                width: 52,
                height: 80,
                decoration: BoxDecoration(
                  color: Colors.black87,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: List.generate(3, (index) {
                    final bool isActive =
                        (index == 0 && widget.phase == 0) ||
                        (index == 1 && widget.phase == 1) ||
                        (index == 2 && widget.phase == 2);

                    Color faceColor;
                    String faceEmoji;
                    switch (index) {
                      case 0:
                        faceColor = Colors.greenAccent;
                        faceEmoji = '😊';
                        break;
                      case 1:
                        faceColor = Colors.amberAccent;
                        faceEmoji = '🙂';
                        break;
                      default:
                        faceColor = Colors.redAccent;
                        faceEmoji = '😌';
                        break;
                    }

                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeInOut,
                      width: isActive ? 26 : 22,
                      height: isActive ? 26 : 22,
                      decoration: BoxDecoration(
                        color: faceColor,
                        shape: BoxShape.circle,
                        boxShadow: isActive
                            ? [
                                BoxShadow(
                                  color: faceColor.withOpacity(0.6),
                                  blurRadius: 10,
                                ),
                              ]
                            : null,
                      ),
                      child: Center(
                        child: Text(
                          faceEmoji,
                          style: const TextStyle(fontSize: 14),
                        ),
                      ),
                    );
                  }),
                ),
              ),
            );
          },
        );
      case 'Arrow':
        final double normalizedSpeed = widget.speed.clamp(0, 80) / 80.0;
        final double targetX = -0.1 + 0.2 * normalizedSpeed;
        return TweenAnimationBuilder<Offset>(
          tween: Tween<Offset>(
            begin: Offset.zero,
            end: Offset(targetX, 0),
          ),
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeInOut,
          builder: (context, value, child) {
            return SlideTransition(
              position: AlwaysStoppedAnimation<Offset>(value),
              child: Icon(
                Icons.arrow_forward,
                size: 56,
                color: baseColor,
              ),
            );
          },
        );
      case 'RoboRoadie':
        final double targetY = widget.phase == 0
            ? -0.05
            : widget.phase == 1
                ? 0.0
                : 0.05;
        return TweenAnimationBuilder<Offset>(
          tween: Tween<Offset>(
            begin: Offset.zero,
            end: Offset(0, targetY),
          ),
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeInOut,
          builder: (context, value, child) {
            return SlideTransition(
              position: AlwaysStoppedAnimation<Offset>(value),
              child: Icon(
                Icons.smart_toy,
                size: 56,
                color: baseColor,
              ),
            );
          },
        );
      default:
        return const Icon(Icons.help, size: 56, color: Colors.white);
    }
  }

  String _phaseLabel() {
    switch (widget.phase) {
      case 2: return 'Red';
      case 1: return 'Yellow';
      default: return 'Green';
    }
  }
}