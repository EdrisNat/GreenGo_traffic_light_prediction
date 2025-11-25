import 'package:flutter/material.dart';

class TrafficLightWidget extends StatelessWidget {
  final int phase;
  final bool isLighty;

  const TrafficLightWidget({
    super.key,
    required this.phase,
    this.isLighty = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 120,
      height: 250,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          colors: [Color(0xFF2E2E2E), Color(0xFF000000)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.35),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
        border: Border.all(color: Colors.black87, width: 1),
      ),
      child: Stack(
        children: [
          // Traffic light body
          Column(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _LightCircle(
                color: phase == 2 ? Colors.red : Colors.red.withOpacity(0.25),
                isActive: phase == 2,
              ),
              _LightCircle(
                color: phase == 1 ? Colors.amber : Colors.amber.withOpacity(0.25),
                isActive: phase == 1,
              ),
              _LightCircle(
                color: phase == 0 ? Colors.green : Colors.green.withOpacity(0.25),
                isActive: phase == 0,
              ),
            ],
          ),
          // Smiley face for Lighty
          if (isLighty && phase == 0)
            Positioned(
              bottom: 40,
              left: 0,
              right: 0,
              child: Container(
                width: 30,
                height: 15,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.white, width: 2),
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(10),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _LightCircle extends StatelessWidget {
  final Color color;
  final bool isActive;

  const _LightCircle({
    required this.color,
    required this.isActive,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        boxShadow: isActive
            ? [
          BoxShadow(
            color: color.withOpacity(0.8),
            blurRadius: 15,
            spreadRadius: 2,
          ),
        ]
            : null,
      ),
    );
  }
}