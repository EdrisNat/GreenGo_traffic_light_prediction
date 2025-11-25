class PredictionData {
  final double secondsToChange;
  final double recommendedSpeed;
  final double currentSpeed;
  final int currentPhase;
  final double distanceToLight;
  final int stopsAvoided;
  final double fuelSaved;
  final double elapsedInPhase;
  final String predictionSource;

  PredictionData({
    required this.secondsToChange,
    required this.recommendedSpeed,
    required this.currentSpeed,
    required this.currentPhase,
    required this.distanceToLight,
    required this.stopsAvoided,
    required this.fuelSaved,
    required this.elapsedInPhase,
    required this.predictionSource,
  });
}
