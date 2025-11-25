import 'package:flutter_tts/flutter_tts.dart';

enum TtsState { playing, stopped }

class AudioService {
  final FlutterTts _flutterTts = FlutterTts();
  TtsState _ttsState = TtsState.stopped;

  AudioService() {
    _initTts();
  }

  Future<void> _initTts() async {
    await _flutterTts.setLanguage("en-US");
    await _flutterTts.setSpeechRate(0.5);
    await _flutterTts.setPitch(1.0);
    await _flutterTts.setVolume(1.0);

    _flutterTts.setStartHandler(() {
      _ttsState = TtsState.playing;
    });

    _flutterTts.setCompletionHandler(() {
      _ttsState = TtsState.stopped;
    });

    _flutterTts.setErrorHandler((msg) {
      _ttsState = TtsState.stopped;
    });
  }

  Future<void> speak(String text) async {
    if (_ttsState != TtsState.playing) {
      await _flutterTts.speak(text);
    }
  }

  Future<void> stop() async {
    await _flutterTts.stop();
    _ttsState = TtsState.stopped;
  }

  void dispose() {
    _flutterTts.stop();
  }
}