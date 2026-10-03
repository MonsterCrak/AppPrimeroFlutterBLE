/// Cuarto (Real BLE) view.
///
/// Renders the room map with the user position and the strongest beacon's
/// distance. Does NOT expose simulation controls — the user walks
/// physically and the BLE pipeline drives the position.
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:app_primero_flutter_ble/models/rssi_sample.dart';
import 'package:app_primero_flutter_ble/state/simulation_notifier.dart';
import 'package:app_primero_flutter_ble/view/theme/app_theme.dart';
import 'package:app_primero_flutter_ble/view/widgets/map_canvas.dart';

class CuartoScreen extends StatelessWidget {
  final SimulationNotifier notifier;

  const CuartoScreen({super.key, required this.notifier});

  @override
  Widget build(BuildContext context) {
    return Consumer<SimulationNotifier>(
      builder: (context, notifier, _) {
        final map = notifier.houseMap;
        final dims = map.realDimensions;
        final dimLabel = dims == null
            ? null
            : '${dims.width.toStringAsFixed(1)} × '
                '${dims.height.toStringAsFixed(1)} m';
        final snapshot = notifier.rssiSource.current();
        // Pick the strongest beacon (closest = highest dBm).
        final strongest = _strongestBeacon(snapshot);

        return ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.lg,
            AppSpacing.lg,
            AppSpacing.xxl,
          ),
          children: [
            _Header(title: map.name, subtitle: dimLabel),
            const SizedBox(height: AppSpacing.lg),
            _MapCard(notifier: notifier),
            const SizedBox(height: AppSpacing.md),
            _DistanceStrip(sample: strongest),
          ],
        );
      },
    );
  }

  RssiSample? _strongestBeacon(Map<String, RssiSample> snapshot) {
    if (snapshot.isEmpty) return null;
    final list = snapshot.values.toList()
      ..sort((a, b) => b.dbm.compareTo(a.dbm));
    return list.first;
  }
}

class _Header extends StatelessWidget {
  final String title;
  final String? subtitle;

  const _Header({required this.title, this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _humanizeRoomName(title),
          style: const TextStyle(
            fontSize: AppTypography.titleSize + 4,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
            height: 1.15,
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 4),
          Text(
            subtitle!,
            style: const TextStyle(
              fontSize: AppTypography.bodySize,
              color: AppColors.textMuted,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ],
    );
  }

  /// Maps the internal map name (e.g. "CuartoPractica1") to a friendly
  /// label. Falls back to the raw name if no mapping is known.
  static String _humanizeRoomName(String internal) {
    switch (internal) {
      case 'CuartoPractica1':
        return 'Cuarto 1';
      case 'MiCasa':
        return 'Mi Casa';
      case 'CasaDemo':
        return 'Casa Demo';
      default:
        return internal;
    }
  }
}

class _MapCard extends StatelessWidget {
  final SimulationNotifier notifier;

  const _MapCard({required this.notifier});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: AppCardDecoration.card(),
      child: AspectRatio(
        aspectRatio:
            notifier.houseMap.bounds.width / notifier.houseMap.bounds.height,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: MapCanvas(
            houseMap: notifier.houseMap,
            userPosition: notifier.userPosition,
            route: const [],
          ),
        ),
      ),
    );
  }
}

class _DistanceStrip extends StatelessWidget {
  final RssiSample? sample;

  const _DistanceStrip({required this.sample});

  @override
  Widget build(BuildContext context) {
    final hasSignal = sample != null;
    final color = hasSignal ? AppColors.success : AppColors.warning;
    final label = hasSignal ? sample!.beaconId : 'B1';
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.30)),
      ),
      child: Row(
        children: [
          Icon(
            hasSignal ? Icons.sensors : Icons.sensors_off,
            color: color,
            size: 20,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: hasSignal
                ? Text(
                    '$label detectado a ${sample!.distance.toStringAsFixed(1)} m',
                    style: const TextStyle(
                      fontSize: AppTypography.bodySize,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  )
                : const Text(
                    'B1 sin señal',
                    style: TextStyle(
                      fontSize: AppTypography.bodySize,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
          ),
          if (hasSignal)
            Text(
              '${sample!.dbm.toStringAsFixed(0)} dBm',
              style: TextStyle(
                fontSize: AppTypography.bodySize,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
        ],
      ),
    );
  }
}
