/// Home screen: composes the map, telemetry panel and control bar.
///
/// The widget subscribes to a [SimulationNotifier] via `ListenableBuilder`.
library;

import 'package:flutter/material.dart';

import 'package:app_primero_flutter_ble/models/beacon_mode.dart';
import 'package:app_primero_flutter_ble/state/simulation_notifier.dart';
import 'package:app_primero_flutter_ble/view/widgets/control_bar.dart';
import 'package:app_primero_flutter_ble/view/widgets/map_canvas.dart';
import 'package:app_primero_flutter_ble/view/widgets/telemetry_panel.dart';

class HomeScreen extends StatelessWidget {
  final SimulationNotifier notifier;

  const HomeScreen({super.key, required this.notifier});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Emulador BLE Indoor'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Center(
              child: _ModeBadge(
                mode: notifier.mode == BeaconMode.simulated
                    ? 'SIMULACIÓN'
                    : 'REAL BLE',
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: ListenableBuilder(
            listenable: notifier,
            builder: (context, _) {
              return Column(
                children: [
                  Expanded(
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 500),
                        child: MapCanvas(
                          houseMap: notifier.houseMap,
                          userPosition: notifier.userPosition,
                          route: notifier.waypoints,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const _Legend(),
                  const SizedBox(height: 8),
                  TelemetryPanel(notifier: notifier),
                  const SizedBox(height: 12),
                  ControlBar(
                    notifier: notifier,
                    onReset: notifier.reset,
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _ModeBadge extends StatelessWidget {
  final String mode;
  const _ModeBadge({required this.mode});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: mode == 'SIMULACIÓN' ? Colors.amber.shade100 : Colors.red.shade100,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: mode == 'SIMULACIÓN' ? Colors.amber.shade800 : Colors.red.shade800,
        ),
      ),
      child: Text(
        'MODO $mode',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: mode == 'SIMULACIÓN' ? Colors.amber.shade900 : Colors.red.shade900,
        ),
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: const [
        _LegendDot(color: Color(0xFF66BB6A), label: 'Baliza'),
        SizedBox(width: 12),
        _LegendDot(color: Color(0xFF2196F3), label: 'Usuario'),
        SizedBox(width: 12),
        _LegendDot(color: Color(0xFF9E9E9E), label: 'Ruta'),
      ],
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}