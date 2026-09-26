/// Telemetry panel: shows current user position + top-N nearest beacons with
/// their RSSI in dBm and Euclidean distance.
library;

import 'package:flutter/material.dart';

import 'package:app_primero_flutter_ble/models/rssi_sample.dart';
import 'package:app_primero_flutter_ble/state/simulation_notifier.dart';

class TelemetryPanel extends StatelessWidget {
  final SimulationNotifier notifier;
  final int topN;

  const TelemetryPanel({
    super.key,
    required this.notifier,
    this.topN = 3,
  });

  @override
  Widget build(BuildContext context) {
    final pos = notifier.userPosition;
    final nearest = notifier.nearestBeacons(n: topN);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.black12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Telemetría',
              style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 6),
          Text(
            'Pos: (${pos.dx.toStringAsFixed(2)}, ${pos.dy.toStringAsFixed(2)})',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 6),
          ...nearest.map((s) => _buildRow(context, s)),
          if (nearest.isEmpty)
            Text('— sin beacons detectados —',
                style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }

  Widget _buildRow(BuildContext context, RssiSample s) {
    final beacon = notifier.beaconById(s.beaconId);
    final label = beacon?.label ?? s.beaconId;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Text(
        '• $label  ${s.dbm.toStringAsFixed(0)} dBm  '
        '(${s.distance.toStringAsFixed(2)} u)',
        style: Theme.of(context).textTheme.bodySmall,
      ),
    );
  }
}