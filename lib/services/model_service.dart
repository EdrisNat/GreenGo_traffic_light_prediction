import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/prediction_request.dart';
import '../models/prediction_response.dart';

class ModelService {
  // For Android emulator: use 10.0.2.2 to connect to localhost
  // static const String baseUrl = 'http://10.0.2.2:8000';
  static const String baseUrl = 'https://greengo-mobile.onrender.com';


  // For Chrome browser: use localhost
  // static const String baseUrl = 'http://localhost:8000';

  // For physical device: use your computer's IP address
  // static const String baseUrl = 'http://192.168.1.100:8000';

  static Future<PredictionResponse> getPrediction(PredictionRequest request) async {
    try {
      print('🌐 Sending prediction request to: $baseUrl/predict');

      final response = await http.post(
        Uri.parse('$baseUrl/predict'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(request.toJson()),
      );

      print('📡 Response status: ${response.statusCode}');
      print('📡 Response body: ${response.body}');

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = json.decode(response.body);
        return PredictionResponse.fromJson(responseData);
      } else {
        print('❌ API error: ${response.statusCode}');
        return _getFallbackPrediction(request, 'api_error');
      }
    } catch (e) {
      print('❌ Network error: $e');
      return _getFallbackPrediction(request, 'network_error');
    }
  }

  static PredictionResponse _getFallbackPrediction(PredictionRequest request, String errorType) {
    print('🔄 Using fallback prediction due to: $errorType');

    // Your existing fallback logic
    double seconds;
    double speed;

    switch (request.phaseId) {
      case 2: // red
        seconds = 45 + (request.distanceToLight / 3.6) * 0.3;
        break;
      case 1: // yellow
        seconds = 3;
        break;
      default: // green
        seconds = 30;
    }

    speed = (request.distanceToLight / seconds.clamp(1, 60)) * 3.6;
    speed = speed.clamp(10.0, 50.0);

    return PredictionResponse(
      secondsToChange: seconds,
      recommendedSpeed: speed,
      status: 'fallback',
      message: 'Using simulated prediction due to $errorType',
      predictionSource: errorType,
    );
  }

  static Future<bool> checkHealth() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/health'));
      return response.statusCode == 200;
    } catch (e) {
      print('❌ Health check failed: $e');
      return false;
    }
  }

  static Future<Map<String, dynamic>> getModelInfo() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/model-info'));
      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
      return {};
    } catch (e) {
      print('❌ Model info error: $e');
      return {};
    }
  }
}
