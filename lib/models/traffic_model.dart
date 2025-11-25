class TrafficModel {
  final String name;
  final String version;
  final List<String> features;
  final double testMae;

  const TrafficModel({
    required this.name,
    required this.version,
    required this.features,
    required this.testMae,
  });

  // Simulate model loading
  static Future<TrafficModel> loadModel() async {
    await Future.delayed(const Duration(milliseconds: 500));
    return TrafficModel(
      name: 'GreenGo Traffic Model',
      version: '1.0.0',
      features: [
        'vehicle_count',
        'pedestrian_count',
        'seconds_to_next_change',
        'elapsed_in_phase',
        'weather_rain_flag',
        'phase_id',
        'distance_to_light'
      ],
      testMae: 2.5,
    );
  }
}