import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:greengo_mobile/services/data_service.dart';
import '../widgets/traffic_light.dart';
import '../widgets/mascot_widget.dart';
import '../widgets/metrics_card.dart';
import '../services/model_service.dart';
import '../models/prediction_data.dart';
import '../models/prediction_request.dart';
import '../models/prediction_response.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  bool _isRunning = false;
  int _lightCount = 0;
  String _selectedMascot = 'Lighty';
  bool _enableVoice = false;
  double _simSpeed = 1.00;
  PredictionData? _currentPrediction;
  bool _isBackendAvailable = false;
  String _connectionStatus = 'Initializing...';
  int _currentPhase = 0;
  double _distanceToLight = 150.0;

  double _currentSpeed = 0.0;
  double _targetSpeed = 0.0;
  final math.Random _random = math.Random();
  Timer? _simulationTimer;

  final List<String> _mascots = ['None', 'Lighty', 'Arrow', 'RoboRoadie'];

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  @override
  void dispose() {
    _simulationTimer?.cancel();
    super.dispose();
  }

  Future<void> _initializeApp() async {
    await Future.wait([
      _checkBackendConnection(),
      DataService.loadDataset(),
    ]);
    _setupNextLightScenario(isInitial: true);
  }

  Future<void> _checkBackendConnection() async {
    const maxAttempts = 5; // Increased attempts
    Duration delay = const Duration(seconds: 2); // Increased initial delay
    bool isHealthy = false;

    for (int attempt = 1; attempt <= maxAttempts; attempt++) {
      if (!mounted) return; 
      setState(() {
        _connectionStatus = 'Connecting (attempt $attempt/$maxAttempts)...';
      });

      isHealthy = await ModelService.checkHealth();
      if (isHealthy) break;

      if (attempt < maxAttempts) {
        await Future.delayed(delay);
        // Exponential backoff to give server time to wake up
        delay *= 2;
      }
    }

    if (mounted) {
      setState(() {
        _isBackendAvailable = isHealthy;
        _connectionStatus = isHealthy ? 'Connected to AI Model 🚀' : 'Using Simulation Mode 🔄';
      });
    }
  }

  void _startSimulation() {
    if (_isRunning) return;
    if (!DataService.isLoaded) {
      DataService.loadDataset();
    }
    setState(() {
      _isRunning = true;
    });
    _simulationTimer = Timer.periodic(Duration(milliseconds: (_simSpeed * 1000).round()), (timer) {
      if (!_isRunning) {
        timer.cancel();
        return;
      }
      _tick();
    });
  }

  void _stopSimulation() {
    if (mounted) {
      setState(() {
        _isRunning = false;
        _simulationTimer?.cancel();
      });
    }
  }

  Future<void> _tick() async {
    final dataPoint = DataService.getNextDataPoint();

    if (mounted) {
      setState(() {
        _currentPhase = dataPoint.phaseId;
      });
    }

    final request = PredictionRequest(
      vehicleCount: dataPoint.vehicleCount.toInt(),
      pedestrianCount: dataPoint.pedestrianCount.toInt(),
      secondsToNextChange: dataPoint.secondsToNextChange,
      elapsedInPhase: dataPoint.elapsedInPhase,
      weatherRainFlag: dataPoint.weatherRainFlag,
      phaseId: _currentPhase,
      distanceToLight: _distanceToLight,
    );

    try {
      final response = await ModelService.getPrediction(request);
      _updateSimulationState(response, dataPoint);
    } catch (e) {
      print('❌ Error in simulation tick: $e');
      _simulateFallbackPrediction(dataPoint);
    }
  }

  void _updateSimulationState(PredictionResponse response, TrafficDataPoint dataPoint) {
    _targetSpeed = response.recommendedSpeed;
    _updateVehicleDynamics();

    if (mounted) {
      setState(() {
        _currentPrediction = PredictionData(
          secondsToChange: response.secondsToChange,
          recommendedSpeed: _targetSpeed,
          currentSpeed: _currentSpeed,
          currentPhase: _currentPhase,
          distanceToLight: _distanceToLight,
          stopsAvoided: _lightCount,
          fuelSaved: _lightCount * 0.02,
          elapsedInPhase: dataPoint.elapsedInPhase,
          predictionSource: response.predictionSource,
        );
      });
    }
  }

  void _simulateFallbackPrediction(TrafficDataPoint dataPoint) {
    double secondsToChange;
    switch (_currentPhase) {
      case 0: secondsToChange = 25.0 + _random.nextDouble() * 15.0; break;
      case 1: secondsToChange = 4.0 + _random.nextDouble() * 2.0; break;
      case 2: secondsToChange = 40.0 + _random.nextDouble() * 20.0; break;
      default: secondsToChange = 30.0;
    }

    double safeSeconds = math.max(secondsToChange - 3, 2);
    _targetSpeed = (_distanceToLight / safeSeconds) * 3.6;
    _targetSpeed = _targetSpeed.clamp(15.0, 55.0);

    final fallbackResponse = PredictionResponse(
      secondsToChange: secondsToChange,
      recommendedSpeed: _targetSpeed,
      predictionSource: 'fallback_simulation',
      status: 'success',
    );
    _updateSimulationState(fallbackResponse, dataPoint);
  }

  void _updateVehicleDynamics() {
    bool isBrakingForRed = _currentPhase == 2 && _distanceToLight < 80;
    if (isBrakingForRed) {
      _targetSpeed = _targetSpeed * (_distanceToLight / 80);
    }

    double speedDifference = _targetSpeed - _currentSpeed;
    double accelerationFactor = (speedDifference > 0) ? 0.35 : (isBrakingForRed ? 0.2 : 0.1);
    _currentSpeed += speedDifference * accelerationFactor;
    _currentSpeed = _currentSpeed.clamp(0.0, 80.0);

    double distanceTraveled = (_currentSpeed / 3.6) * _simSpeed;
    _distanceToLight -= distanceTraveled;

    if (_distanceToLight <= 0) {
      _setupNextLightScenario();
    }
  }

  void _setupNextLightScenario({bool isInitial = false}) {
    if (!isInitial) {
      _lightCount++;
    } else {
      _currentSpeed = 0.0;
    }
    _distanceToLight = 80 + _random.nextDouble() * 70; // 80m to 150m

    if (!isInitial) {
      _currentSpeed = math.max(20.0, _currentSpeed * 0.7);
    }
    if (mounted) {
      setState(() {});
    }
  }

  void _passLight() {
    if (mounted) {
      setState(() {
        _setupNextLightScenario();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('GreenGo Mobile'),
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: Row(
              children: [
                Icon(
                  _isBackendAvailable ? Icons.cloud_done : Icons.cloud_off,
                  color: _isBackendAvailable ? Colors.green : Colors.orange,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  _isBackendAvailable ? 'AI Mode' : 'Sim Mode',
                  style: TextStyle(
                    color: _isBackendAvailable ? Colors.green : Colors.orange,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: _showSettingsDialog,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _isBackendAvailable ? Colors.green[50] : Colors.orange[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: _isBackendAvailable ? Colors.green : Colors.orange,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    _isBackendAvailable ? Icons.check_circle : Icons.schedule,
                    color: _isBackendAvailable ? Colors.green : Colors.orange,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _connectionStatus,
                      style: TextStyle(
                        color: _isBackendAvailable ? Colors.green : Colors.orange,
                        fontWeight: FontWeight.w500,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  // NEW: Retry button appears when offline
                  if (!_isBackendAvailable)
                    TextButton(onPressed: _checkBackendConnection, child: const Text('Retry')),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 2,
                    child: Column(
                      children: [
                        TrafficLightWidget(
                          phase: _currentPhase,
                          isLighty: _selectedMascot == 'Lighty',
                        ),
                        const SizedBox(height: 20),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: _getPhaseColor(_currentPhase).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: _getPhaseColor(_currentPhase),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              _buildPhaseIndicator('GREEN', 0),
                              _buildPhaseIndicator('YELLOW', 1),
                              _buildPhaseIndicator('RED', 2),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                        Column(
                          children: [
                            LinearProgressIndicator(
                              value: _currentPrediction != null
                                  ? (_currentPrediction!.elapsedInPhase / 60).clamp(0.0, 1.0)
                                  : 0.0,
                              backgroundColor: Colors.grey[300],
                              color: _getPhaseColor(_currentPhase),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Elapsed: ${_currentPrediction?.elapsedInPhase.toStringAsFixed(0) ?? "0"}s',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        Row(
                          children: [
                            Expanded(
                              child: FilledButton.icon(
                                onPressed: _isRunning ? _stopSimulation : _startSimulation,
                                icon: Icon(_isRunning ? Icons.stop : Icons.play_arrow),
                                label: Text(_isRunning ? 'Stop Demo' : 'Start Demo'),
                                style: FilledButton.styleFrom(
                                  backgroundColor: _isRunning ? Colors.red : Colors.green,
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            IconButton(
                              onPressed: _passLight,
                              icon: const Icon(Icons.traffic),
                              style: IconButton.styleFrom(
                                backgroundColor: Colors.blue,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.all(16),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    flex: 1,
                    child: Column(
                      children: [
                        MetricsCard(
                          title: 'Next Change',
                          value: _currentPrediction?.secondsToChange.toStringAsFixed(1) ?? '--',
                          unit: 's',
                          icon: Icons.timer,
                        ),
                        const SizedBox(height: 10),
                        MetricsCard(
                          title: 'Current Speed',
                          value: _currentPrediction?.currentSpeed.toStringAsFixed(0) ?? '--',
                          unit: 'km/h',
                          icon: Icons.speed,
                          color: Colors.blue,
                        ),
                        const SizedBox(height: 10),
                        MetricsCard(
                          title: 'Target Speed',
                          value: _currentPrediction?.recommendedSpeed.toStringAsFixed(0) ?? '--',
                          unit: 'km/h',
                          icon: Icons.assistant_direction,
                        ),
                        const SizedBox(height: 10),
                        MetricsCard(
                          title: 'Distance',
                          value: _currentPrediction?.distanceToLight.toStringAsFixed(1) ?? '--',
                          unit: 'm',
                          icon: Icons.place,
                        ),
                        const Spacer(),
                        if (_selectedMascot != 'None')
                          MascotWidget(
                            mascotName: _selectedMascot,
                            speed: _currentPrediction?.recommendedSpeed ?? 0,
                            secondsToChange: _currentPrediction?.secondsToChange,
                            isSpeaking: _enableVoice,
                            phase: _currentPhase,
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.green[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.green),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildStatItem('Lights Passed', _lightCount.toString(), Icons.traffic, Colors.green),
                  _buildStatItem('Stops Avoided',
                      _currentPrediction?.stopsAvoided.toString() ?? '0',
                      Icons.thumb_up,
                      Colors.blue
                  ),
                  _buildStatItem('Fuel Saved',
                      '${_currentPrediction?.fuelSaved.toStringAsFixed(2) ?? "0.00"}L',
                      Icons.local_gas_station,
                      Colors.orange
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPhaseIndicator(String label, int phase) {
    final isActive = _currentPhase == phase;
    return Column(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: isActive ? _getPhaseColor(phase) : Colors.grey[300],
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
            color: isActive ? _getPhaseColor(phase) : Colors.grey,
          ),
        ),
      ],
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: Colors.grey,
          ),
        ),
      ],
    );
  }

  Color _getPhaseColor(int phase) {
    switch (phase) {
      case 0: return Colors.green;
      case 1: return Colors.amber;
      case 2: return Colors.red;
      default: return Colors.grey;
    }
  }

  void _showSettingsDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            return AlertDialog(
              title: const Text('Settings'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ListTile(
                      leading: const Icon(Icons.pets),
                      title: const Text('Mascot'),
                      trailing: DropdownButton<String>(
                        value: _selectedMascot,
                        onChanged: (value) {
                          if (value == null) return;
                          this.setState(() {
                            _selectedMascot = value;
                          });
                        },
                        items: _mascots.map((mascot) {
                          return DropdownMenuItem(
                            value: mascot,
                            child: Text(mascot),
                          );
                        }).toList(),
                      ),
                    ),
                    ListTile(
                      leading: const Icon(Icons.volume_up),
                      title: const Text('Voice Guidance'),
                      trailing: Switch(
                        value: _enableVoice,
                        onChanged: (value) {
                          this.setState(() {
                             _enableVoice = value;
                          });
                        },
                      ),
                    ),
                    const Divider(),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                      child: Text('Simulation Speed: ${_simSpeed.toStringAsFixed(2)}s'),
                    ),
                    Slider(
                      value: _simSpeed,
                      min: 0.20,
                      max: 1.50,
                      divisions: 13,
                      label: _simSpeed.toStringAsFixed(2),
                      onChanged: (value) {
                        this.setState(() {
                          _simSpeed = value;
                        });
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Close'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
