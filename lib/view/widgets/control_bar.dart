/// Start/Stop control bar.
///
/// Single button whose label toggles based on the SimulationNotifier state.
/// In Real BLE mode the start button is hidden — the user walks
/// physically, the timer is meaningless.
library;

import 'package:flutter/material.dart';

import 'package:app_primero_flutter_ble/models/beacon_mode.dart';
import 'package:app_primero_flutter_ble/state/simulation_notifier.dart';

class ControlBar extends StatelessWidget {
  final SimulationNotifier notifier;
  final VoidCallback? onReset;

  const ControlBar({
    super.key,
    required this.notifier,
    this.onReset,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: notifier,
      builder: (context, _) {
        final isRealBle = notifier.mode == BeaconMode.realBle;
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (!isRealBle)
              ElevatedButton.icon(
                key: const ValueKey('start-stop-button'),
                icon: Icon(notifier.isRunning ? Icons.pause : Icons.play_arrow),
                label: Text(notifier.isRunning ? 'Detener' : 'Iniciar'),
                onPressed: () {
                  if (notifier.isRunning) {
                    notifier.stop();
                  } else {
                    notifier.start();
                  }
                },
              ),
            if (onReset != null) ...[
              const SizedBox(width: 12),
              OutlinedButton.icon(
                icon: const Icon(Icons.replay),
                label: const Text('Reset'),
                onPressed: onReset,
              ),
            ],
          ],
        );
      },
    );
  }
}