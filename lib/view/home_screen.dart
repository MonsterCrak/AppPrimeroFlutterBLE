/// Home screen: composes the map, telemetry panel and control bar.
///
/// Wraps a [SimulationNotifier] (via [ListenableBuilder]) and a
/// [ModeController] for swapping between simulated and real BLE sources.
/// Surfaces mode-switch errors and live BLE errors via SnackBars.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart' as ph;

import 'package:app_primero_flutter_ble/models/beacon_mode.dart';
import 'package:app_primero_flutter_ble/sources/ble_error.dart';
import 'package:app_primero_flutter_ble/state/mode_controller.dart';
import 'package:app_primero_flutter_ble/state/simulation_notifier.dart';
import 'package:app_primero_flutter_ble/view/widgets/control_bar.dart';
import 'package:app_primero_flutter_ble/view/widgets/map_canvas.dart';
import 'package:app_primero_flutter_ble/view/widgets/mode_selector.dart';
import 'package:app_primero_flutter_ble/view/widgets/telemetry_panel.dart';

class HomeScreen extends StatefulWidget {
  final SimulationNotifier notifier;
  final ModeController modeController;

  const HomeScreen({
    super.key,
    required this.notifier,
    required this.modeController,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  StreamSubscription<BleError?>? _errorsSub;
  final _scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

  @override
  void initState() {
    super.initState();
    _errorsSub = widget.modeController.errors.stream.listen(_showError);
  }

  @override
  void dispose() {
    _errorsSub?.cancel();
    super.dispose();
  }

  void _showError(BleError? err) {
    if (err == null || !mounted) return;
    final messenger = _scaffoldMessengerKey.currentState;
    if (messenger == null) return;

    final requiresSettings = err.requiresOpenSettings;
    messenger
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Text(err.message),
          backgroundColor: Colors.red.shade700,
          duration: const Duration(seconds: 6),
          action: requiresSettings
              ? SnackBarAction(
                  label: 'Settings',
                  textColor: Colors.white,
                  onPressed: () => ph.openAppSettings(),
                )
              : SnackBarAction(
                  label: 'OK',
                  textColor: Colors.white,
                  onPressed: () {},
                ),
        ),
      );
  }

  Future<void> _onModeChanged(BuildContext context, BeaconMode target) async {
    final messenger = _scaffoldMessengerKey.currentState;
    final result = await widget.modeController.switchTo(target);
    if (!result.ok && messenger != null) {
      messenger
        ..clearSnackBars()
        ..showSnackBar(
          SnackBar(
            content: Text(result.errorMessage ?? 'Error al cambiar de modo'),
            backgroundColor: Colors.red.shade700,
            duration: const Duration(seconds: 6),
            action: result.requiresOpenSettings
                ? SnackBarAction(
                    label: 'Settings',
                    textColor: Colors.white,
                    onPressed: () => ph.openAppSettings(),
                  )
                : null,
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ScaffoldMessenger(
      key: _scaffoldMessengerKey,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Emulador BLE Indoor'),
          backgroundColor: Theme.of(context).colorScheme.inversePrimary,
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Center(
                child: ListenableBuilder(
                  listenable: widget.notifier,
                  builder: (_, __) => _ModeBadge(
                    mode: widget.notifier.mode == BeaconMode.simulated
                        ? 'SIMULACIÓN'
                        : 'REAL BLE',
                  ),
                ),
              ),
            ),
          ],
        ),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                ListenableBuilder(
                  listenable: widget.notifier,
                  builder: (_, __) => ModeSelector(
                    mode: widget.notifier.mode,
                    onChanged: (m) => _onModeChanged(context, m),
                  ),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 500),
                      child: ListenableBuilder(
                        listenable: widget.notifier,
                        builder: (_, __) => MapCanvas(
                          houseMap: widget.notifier.houseMap,
                          userPosition: widget.notifier.userPosition,
                          route: widget.notifier.waypoints,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                const _Legend(),
                const SizedBox(height: 8),
                ListenableBuilder(
                  listenable: widget.notifier,
                  builder: (_, __) => TelemetryPanel(notifier: widget.notifier),
                ),
                const SizedBox(height: 12),
                ListenableBuilder(
                  listenable: widget.notifier,
                  builder: (_, __) => ControlBar(
                    notifier: widget.notifier,
                    onReset: widget.notifier.reset,
                  ),
                ),
              ],
            ),
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
        color: mode == 'SIMULACIÓN'
            ? Colors.amber.shade100
            : Colors.red.shade100,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: mode == 'SIMULACIÓN'
              ? Colors.amber.shade800
              : Colors.red.shade800,
        ),
      ),
      child: Text(
        'MODO $mode',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: mode == 'SIMULACIÓN'
              ? Colors.amber.shade900
              : Colors.red.shade900,
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