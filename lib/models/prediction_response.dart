class PredictionResponse {
  final double secondsToChange;
  final double recommendedSpeed;
  final String status;
  final String? message;
  final String predictionSource;

  PredictionResponse({
    required this.secondsToChange,
    required this.recommendedSpeed,
    required this.status,
    this.message,
    required this.predictionSource,
  });

  factory PredictionResponse.fromJson(Map<String, dynamic> json) {
    return PredictionResponse(
      secondsToChange: (json['seconds_to_change'] as num? ?? 30.0).toDouble(),
      recommendedSpeed: (json['recommended_speed'] as num? ?? 40.0).toDouble(),
      status: json['status'] as String? ?? 'error',
      message: json['message'] as String?,
      // FIXED: Correctly looks for 'prediction_source' from the backend
      predictionSource: json['prediction_source'] as String? ?? 'unknown',
    );
  }
}
