class PredictionRequest {
  final int vehicleCount;
  final int pedestrianCount;
  final double secondsToNextChange;
  final double elapsedInPhase;
  final int weatherRainFlag;
  final int phaseId;
  final double distanceToLight;

  PredictionRequest({
    required this.vehicleCount,
    required this.pedestrianCount,
    required this.secondsToNextChange,
    required this.elapsedInPhase,
    required this.weatherRainFlag,
    required this.phaseId,
    required this.distanceToLight,
  });

  Map<String, dynamic> toJson() => {
    'vehicle_count': vehicleCount,
    'pedestrian_count': pedestrianCount,
    'seconds_to_next_change': secondsToNextChange,
    'elapsed_in_phase': elapsedInPhase,
    'weather_rain_flag': weatherRainFlag,
    'phase_id': phaseId,
    'distance_to_light': distanceToLight,
  };
}
