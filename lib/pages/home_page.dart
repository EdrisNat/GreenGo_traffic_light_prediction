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
  bool _enableVoice = true; // Voice enabled by default
  double _simSpeed = 1.50; // Set to max by default
  PredictionData? _currentPrediction;
  bool _isBackendAvailable = false;
  String _connectionStatus = 'Initializing...';
  int _currentPhase = 0;
  double _distanceToLight = 250.0;
  bool _isTtsSpeaking = false;
  int? _pendingPhase;
  bool _pendingNextLight = false;

  double _currentSpeed = 0.0;
  double _targetSpeed = 0.0;
  final math.Random _random = math.Random();

  final List<String> _mascots = ['None', 'Lighty', 'Arrow', 'RoboRoadie'];

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    await Future.wait([
      _checkBackendConnection(),
      DataService.loadDataset(),
    ]);
    _setupNextLightScenario(isInitial: true);
  }

  Future<void> _checkBackendConnection() async {
    const maxAttempts = 6;
    Duration delay = const Duration(milliseconds: 500);
    bool isHealthy = false;
    for (int attempt = 1; attempt <= maxAttempts; attempt++) {
      if (mounted) {
        setState(() {
          _connectionStatus =
              'Connecting to AI Model (attempt $attempt/$maxAttempts)...';
        });
      }
      isHealthy = await ModelService.checkHealth();
      if (isHealthy) break;
      await Future.delayed(delay);
      final int nextMs =
          ((delay.inMilliseconds * 1.8).clamp(800, 5000)).round();
      delay = Duration(milliseconds: nextMs);
    }
    if (mounted) {
      setState(() {
        _isBackendAvailable = isHealthy;
        _connectionStatus = isHealthy
            ? 'Connected to AI Model 🚀'
            : 'Using Simulation Mode 🔄 (offline)';
      });
    }
  }

  void _startSimulation() async {
    if (_isRunning) return;

    if (!DataService.isLoaded) {
      await DataService.loadDataset();
    }

    setState(() {
      _isRunning = true;
    });

    while (_isRunning) {
      final dataPoint = DataService.getNextDataPoint();

      if (mounted) {
        setState(() {
          if (_isTtsSpeaking) {
            _pendingPhase = dataPoint.phaseId;
          } else {
            _currentPhase = dataPoint.phaseId;
          }
        });
      }

      final request = PredictionRequest(
        vehicleCount: dataPoint.vehicleCount.toInt(),
        pedestrianCount: dataPoint.pedestrianCount.toInt(),
        secondsToNextChange: dataPoint.secondsToNextChange,
        elapsedInPhase: dataPoint.elapsedInPhase,
        weatherRainFlag: dataPoint.weatherRainFlag,
        phaseId: dataPoint.phaseId,
        distanceToLight: _distanceToLight,
      );

      try {
        final response = await ModelService.getPrediction(request);
        _updateSimulationState(response, dataPoint);
      } catch (e) {
        print('❌ Error in simulation loop: $e');
        _simulateFallbackPrediction(dataPoint);
      }

      await Future.delayed(Duration(milliseconds: (_simSpeed * 1000).round()));
    }
  }

  void _updateSimulationState(
      PredictionResponse response, TrafficDataPoint dataPoint) {
    final double seconds = dataPoint.secondsToNextChange.clamp(1.0, 300.0);
    double derivedSpeed = (_distanceToLight / seconds) * 3.6;
    double maxSpeed;
    switch (_currentPhase) {
      case 1:
        maxSpeed = 40.0;
        break;
      case 2:
        maxSpeed = 50.0;
        break;
      default:
        maxSpeed = 60.0;
    }
    derivedSpeed = derivedSpeed.clamp(10.0, maxSpeed);

    final double backendSpeed = response.recommendedSpeed;
    if (backendSpeed > 0) {
      _targetSpeed = (0.7 * derivedSpeed) + (0.3 * backendSpeed);
    } else {
      _targetSpeed = derivedSpeed;
    }

    double speedDifference = _targetSpeed - _currentSpeed;
    double accelerationFactor = 0.2;
    _currentSpeed += speedDifference * accelerationFactor;
    _currentSpeed += (_random.nextDouble() - 0.5) * 2.0;
    _currentSpeed = _currentSpeed.clamp(0.0, 80.0);

    double distanceTraveled = (_currentSpeed / 3.6) * _simSpeed;
    _distanceToLight -= distanceTraveled;

    if (_distanceToLight <= 0) {
      if (_isTtsSpeaking) {
        _pendingNextLight = true;
      } else {
        _setupNextLightScenario();
      }
    }

    if (mounted) {
      setState(() {
        _currentPrediction = PredictionData(
          secondsToChange: dataPoint.secondsToNextChange,
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
      case 0:
        secondsToChange = 30.0 + _random.nextDouble() * 10.0;
        break;
      case 1:
        secondsToChange = 5.0 + _random.nextDouble() * 2.0;
        break;
      case 2:
        secondsToChange = 45.0 + _random.nextDouble() * 15.0;
        break;
      default:
        secondsToChange = 30.0;
    }

    if (dataPoint.vehicleCount > 5) secondsToChange *= 1.2;

    double safeSeconds = math.max(secondsToChange - 5, 3);
    _targetSpeed = (_distanceToLight / safeSeconds) * 3.6;
    _targetSpeed = _targetSpeed.clamp(20.0, 60.0);

    final fallbackResponse = PredictionResponse(
      secondsToChange: secondsToChange,
      recommendedSpeed: _targetSpeed,
      predictionSource: 'fallback_simulation',
      status: 'success',
    );
    _updateSimulationState(fallbackResponse, dataPoint);
  }

  void _setupNextLightScenario({bool isInitial = false}) {
    if (!isInitial) {
      _lightCount++;
    }
    _distanceToLight = 200 + _random.nextDouble() * 250;
    _currentSpeed = math.max(15.0, _currentSpeed * 0.7);
    _pendingNextLight = false;
  }

  void _stopSimulation() {
    if (mounted) {
      setState(() {
        _isRunning = false;
      });
    }
  }

  void _passLight() {
    if (mounted) {
      setState(() {
        if (_isTtsSpeaking) {
          _pendingNextLight = true;
        } else {
          _setupNextLightScenario();
        }
      });
    }
  }

  void _onMascotSpeakingChanged(bool speaking) {
    if (!mounted) return;
    setState(() {
      _isTtsSpeaking = speaking;
      if (!speaking) {
        if (_pendingPhase != null) {
          _currentPhase = _pendingPhase!;
          _pendingPhase = null;
        }
        if (_pendingNextLight) {
          _setupNextLightScenario();
        }
      }
    });
  }

  String _getMascotMessage(double? seconds, double speed) {
    if (seconds == null) {
      return "$_selectedMascot says: Waiting for data...";
    }
    if (_currentSpeed > speed + 5) {
      return "$_selectedMascot says: Too fast! Slow to ${speed.toStringAsFixed(0)} km/h.";
    } else if (_currentSpeed < speed - 5) {
      return "$_selectedMascot says: Speed up! Aim for ${speed.toStringAsFixed(0)} km/h.";
    } else {
      return "$_selectedMascot says: Perfect! Hold this speed.";
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
            padding: const EdgeInsets.only(right: 8.0),
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
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: TextButton.icon(
              icon: const Icon(Icons.settings),
              label: const Text('Settings'),
              onPressed: _showSettingsDialog,
              style: TextButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _isBackendAvailable
                      ? Colors.green[50]
                      : Colors.orange[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: _isBackendAvailable ? Colors.green : Colors.orange,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      _isBackendAvailable
                          ? Icons.check_circle
                          : Icons.schedule,
                      color:
                          _isBackendAvailable ? Colors.green : Colors.orange,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _connectionStatus,
                      style: TextStyle(
                        color: _isBackendAvailable
                            ? Colors.green
                            : Colors.orange,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              LayoutBuilder(builder: (context, constraints) {
                if (constraints.maxWidth > 600) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 3,
                        child: _buildLeftPanel(),
                      ),
                      const SizedBox(width: 20),
                      Expanded(
                        flex: 2,
                        child: _buildRightPanel(),
                      ),
                    ],
                  );
                } else {
                  return Column(
                    children: [
                      _buildLeftPanel(),
                      const SizedBox(height: 20),
                      _buildRightPanel(),
                    ],
                  );
                }
              }),
              const SizedBox(height: 16),
              _buildStatsBar(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLeftPanel() {
    return Column(
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
              minHeight: 6,
            ),
            const SizedBox(height: 8),
            Text(
              'Elapsed in Phase: ${_currentPrediction?.elapsedInPhase.toStringAsFixed(0) ?? "0"}s',
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
                  backgroundColor: _isRunning ? Colors.redAccent : Colors.green,
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildRightPanel() {
    return Column(
      children: [
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            MetricsCard(
              title: 'Next Change',
              value:
                  _currentPrediction?.secondsToChange.toStringAsFixed(1) ?? '--',
              unit: 's',
              icon: Icons.timer,
              color: Colors.purple,
            ),
            MetricsCard(
              title: 'Current Speed',
              value: _currentPrediction?.currentSpeed.toStringAsFixed(0) ?? '--',
              unit: 'km/h',
              icon: Icons.speed,
              color: Colors.blue,
            ),
            MetricsCard(
              title: 'Target Speed',
              value: _currentPrediction?.recommendedSpeed.toStringAsFixed(0) ??
                  '--',
              unit: 'km/h',
              icon: Icons.assistant_direction,
              color: Colors.green,
            ),
            MetricsCard(
              title: 'Distance',
              value:
                  _currentPrediction?.distanceToLight.toStringAsFixed(1) ?? '--',
              unit: 'm',
              icon: Icons.place,
              color: Colors.orange,
            ),
          ],
        ),
        const SizedBox(height: 20),
        if (_selectedMascot != 'None')
          MascotWidget(
            mascotName: _selectedMascot,
            speed: _currentPrediction?.recommendedSpeed ?? 0,
            secondsToChange: _currentPrediction?.secondsToChange,
            isSpeaking: _enableVoice,
            phase: _currentPhase,
            nextPhaseHint:
                _currentPhase == 1 ? (_pendingPhase ?? _pendingPhase) : null,
            onSpeakingChanged: _onMascotSpeakingChanged,
          ),
      ],
    );
  }

  Widget _buildStatsBar() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: Theme.of(context).colorScheme.primaryContainer),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem('Lights Passed', _lightCount.toString(),
              Icons.traffic_outlined, Colors.green),
          _buildStatItem(
              'Stops Avoided',
              _currentPrediction?.stopsAvoided.toString() ?? '0',
              Icons.thumb_up_alt_outlined,
              Colors.blue),
          _buildStatItem(
              'Fuel Saved',
              '${_currentPrediction?.fuelSaved.toStringAsFixed(2) ?? "0.00"}L',
              Icons.local_gas_station_outlined,
              Colors.orange),
        ],
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
            boxShadow: isActive
                ? [
                    BoxShadow(
                      color: _getPhaseColor(phase).withOpacity(0.7),
                      blurRadius: 5,
                      spreadRadius: 1,
                    )
                  ]
                : [],
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
        Icon(icon, color: color, size: 28),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 2),
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
      case 0:
        return Colors.green;
      case 1:
        return Colors.amber;
      case 2:
        return Colors.red;
      default:
        return Colors.grey;
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
                      trailing: SizedBox(
                        width: 120,
                        child: DropdownButton<String>(
                          isExpanded: true,
                          value: _selectedMascot,
                          onChanged: (value) {
                            if (value == null) return;
                            this.setState(() {
                              _selectedMascot = value;
                            });
                            setState(() {});
                          },
                          items: _mascots.map((mascot) {
                            return DropdownMenuItem(
                              value: mascot,
                              child: Text(mascot),
                            );
                          }).toList(),
                        ),
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
                          setState((){});
                        },
                      ),
                    ),
                    const Divider(),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16.0, vertical: 8.0),
                      child: Text(
                          'Simulation Speed: ${_simSpeed.toStringAsFixed(2)}x'),
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
                         setState((){});
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
