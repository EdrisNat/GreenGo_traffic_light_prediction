import 'package:flutter/services.dart';
import 'package:csv/csv.dart';
import 'dart:math';

class TrafficDataPoint {
  final double vehicleCount;
  final double pedestrianCount;
  final double secondsToNextChange;
  final double elapsedInPhase;
  final int weatherRainFlag;
  final int phaseId;
  final String timestamp;

  TrafficDataPoint({
    required this.vehicleCount,
    required this.pedestrianCount,
    required this.secondsToNextChange,
    required this.elapsedInPhase,
    required this.weatherRainFlag,
    required this.phaseId,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
        'vehicle_count': vehicleCount,
        'pedestrian_count': pedestrianCount,
        'seconds_to_next_change': secondsToNextChange,
        'elapsed_in_phase': elapsedInPhase,
        'weather_rain_flag': weatherRainFlag,
        'phase_id': phaseId,
        'timestamp': timestamp,
      };
}

class DataService {
  static List<TrafficDataPoint> _dataset = [];
  static int _currentIndex = 0;
  static bool _isLoaded = false;
  static final Random _random = Random();

  static Future<void> loadDataset() async {
    if (_isLoaded) return;

    try {
      print('📁 Loading traffic dataset...');
      final String data = await rootBundle.loadString('assets/data/greengo_cleaned_dataset.csv');
      List<List<dynamic>> csvTable = const CsvToListConverter().convert(data, eol: '\n');

      if (csvTable.length > 1) {
        final headers = csvTable[0].map((h) => h.toString().trim().toLowerCase()).toList();
        _dataset = csvTable.sublist(1).map((row) {
          return TrafficDataPoint(
            vehicleCount: _safeDouble(row, headers, 'vehicle_count'),
            pedestrianCount: _safeDouble(row, headers, 'pedestrian_count'),
            secondsToNextChange: _safeDouble(row, headers, 'seconds_to_next_change'),
            elapsedInPhase: _safeDouble(row, headers, 'elapsed_in_phase'),
            weatherRainFlag: _safeInt(row, headers, 'weather_rain_flag'),
            phaseId: _safeInt(row, headers, 'phase_id'),
            timestamp: row[_getBestIndex(headers, ['timestamp'])]?.toString() ?? '',
          );
        }).toList();

        _isLoaded = true;
        print('✅ Dataset loaded: ${_dataset.length} records');
      } else {
        _createSampleData();
      }
    } catch (e) {
      print('❌ Error loading dataset: $e');
      _createSampleData();
    }
  }

  static int _getBestIndex(List<String> headers, List<String> potentialNames) {
      for (String name in potentialNames) {
          int index = headers.indexOf(name);
          if (index != -1) return index;
      }
      return -1; // Sentinel value
  }

  static double _safeDouble(List<dynamic> row, List<String> headers, String colName) {
      int index = _getBestIndex(headers, [colName, colName.replaceAll('_', ' ')]);
      if (index == -1 || index >= row.length) return 0.0;
      dynamic value = row[index];
      if (value == null) return 0.0;
      if (value is double) return value;
      if (value is int) return value.toDouble();
      return double.tryParse(value.toString()) ?? 0.0;
  }

  static int _safeInt(List<dynamic> row, List<String> headers, String colName) {
      int index = _getBestIndex(headers, [colName, colName.replaceAll('_', ' ')]);
      if (index == -1 || index >= row.length) return 0;
      dynamic value = row[index];
      if (value == null) return 0;
      if (value is int) return value;
      if (value is double) return value.toInt();
      return int.tryParse(value.toString()) ?? 0;
  }

  static void _createSampleData() {
    print('🔄 Creating sample data as a fallback...');
    _dataset = List.generate(100, (index) => TrafficDataPoint(
      vehicleCount: (index % 20).toDouble(),
      pedestrianCount: (index % 10).toDouble(),
      secondsToNextChange: (30 + index % 30).toDouble(),
      elapsedInPhase: (index % 60).toDouble(),
      weatherRainFlag: index % 3 == 0 ? 1 : 0,
      phaseId: index % 3,
      timestamp: '2024-01-01 12:00:00',
    ));
    _isLoaded = true;
  }

  static TrafficDataPoint getNextDataPoint() {
    if (!_isLoaded || _dataset.isEmpty) {
       if (!_isLoaded) {
        print('🚨 Dataset not loaded, returning empty data point.');
        _createSampleData(); // Ensure there's always data
      }
      return _dataset.first;
    }

    final originalData = _dataset[_currentIndex];

    // Cycle through phases deterministically to guarantee all are shown
    final int forcedPhaseId = _currentIndex % 3;

    // Create a new data point, overriding the phaseId to ensure a full cycle
    final correctedData = TrafficDataPoint(
      phaseId: forcedPhaseId,
      // Use original data for other fields to maintain realism
      vehicleCount: originalData.vehicleCount,
      pedestrianCount: originalData.pedestrianCount,
      secondsToNextChange: originalData.secondsToNextChange,
      elapsedInPhase: originalData.elapsedInPhase,
      weatherRainFlag: originalData.weatherRainFlag,
      timestamp: originalData.timestamp,
    );
    
    _currentIndex = (_currentIndex + 1) % _dataset.length;
    return correctedData;
  }

  static int get datasetLength => _dataset.length;
  static int get currentIndex => _currentIndex;
  static bool get isLoaded => _isLoaded;
  static void reset() {
    _currentIndex = 0;
  }
}