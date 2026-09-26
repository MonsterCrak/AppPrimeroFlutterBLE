/// Toggle between simulated and real BLE modes.
///
/// A `SegmentedButton` with two options:
/// - **Simulación**: el recorrido es por waypoints, RSSI calculado.
/// - **Real BLE**: el recorrido es caminando, RSSI real del escaneo.
library;

import 'package:flutter/material.dart';

import 'package:app_primero_flutter_ble/models/beacon_mode.dart';

class ModeSelector extends StatelessWidget {
  final BeaconMode mode;
  final ValueChanged<BeaconMode> onChanged;
  final bool enabled;

  const ModeSelector({
    super.key,
    required this.mode,
    required this.onChanged,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<BeaconMode>(
      segments: const [
        ButtonSegment<BeaconMode>(
          value: BeaconMode.simulated,
          label: Text('Simulación'),
          icon: Icon(Icons.science_outlined),
        ),
        ButtonSegment<BeaconMode>(
          value: BeaconMode.realBle,
          label: Text('Real BLE'),
          icon: Icon(Icons.bluetooth_searching),
        ),
      ],
      selected: {mode},
      onSelectionChanged: enabled
          ? (selection) => onChanged(selection.first)
          : null,
    );
  }
}