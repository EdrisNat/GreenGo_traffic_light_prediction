import 'package:flutter/material.dart';

class ControlPanel extends StatefulWidget {
  final bool isRunning;
  final Function(bool) onRunningChanged;
  final double simSpeed;
  final Function(double) onSimSpeedChanged;
  final int sequenceLength;
  final Function(int) onSequenceLengthChanged;

  const ControlPanel({
    super.key,
    required this.isRunning,
    required this.onRunningChanged,
    required this.simSpeed,
    required this.onSimSpeedChanged,
    required this.sequenceLength,
    required this.onSequenceLengthChanged,
  });

  @override
  State<ControlPanel> createState() => _ControlPanelState();
}

class _ControlPanelState extends State<ControlPanel> {
  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Simulation Controls',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),

            // Start/Stop Button
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () {
                  widget.onRunningChanged(!widget.isRunning);
                },
                icon: Icon(
                  widget.isRunning ? Icons.stop : Icons.play_arrow,
                ),
                label: Text(
                  widget.isRunning ? 'Stop Simulation' : 'Start Simulation',
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: widget.isRunning ? Colors.red : Colors.green,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Simulation Speed
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Simulation Speed: ${widget.simSpeed}s/step',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                Slider(
                  value: widget.simSpeed,
                  min: 0.05,
                  max: 1.0,
                  divisions: 19,
                  onChanged: widget.onSimSpeedChanged,
                  label: '${widget.simSpeed}s',
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Sequence Length
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Sequence Length: ${widget.sequenceLength}',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                Slider(
                  value: widget.sequenceLength.toDouble(),
                  min: 3,
                  max: 20,
                  divisions: 17,
                  onChanged: (value) {
                    widget.onSequenceLengthChanged(value.toInt());
                  },
                  label: '${widget.sequenceLength}',
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Stats
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildStat('Model Status', 'Ready', Icons.check_circle, Colors.green),
                  _buildStat('Features', '7', Icons.list, Colors.blue),
                  _buildStat('MAE', '2.5s', Icons.analytics, Colors.orange),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStat(String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            fontSize: 10,
            color: Colors.grey,
          ),
        ),
      ],
    );
  }
}