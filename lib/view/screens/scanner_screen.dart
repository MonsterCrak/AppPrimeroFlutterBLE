/// BLE Scanner debug view.
///
/// Surfaces everything the user needs to diagnose a "no beacons detected"
/// problem:
///   * Bluetooth + permission + scan status (top status card)
///   * Live list of detected beacons with RSSI, signal-strength bar,
///     distance, and relative "last seen" timestamp
///   * Last BLE error with a Settings CTA when the OS requires manual
///     permission re-grant
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:provider/provider.dart';

import 'package:app_primero_flutter_ble/models/beacon_mode.dart';
import 'package:app_primero_flutter_ble/models/rssi_sample.dart';
import 'package:app_primero_flutter_ble/permissions/permission_service.dart';
import 'package:app_primero_flutter_ble/sources/ble_error.dart';
import 'package:app_primero_flutter_ble/state/mode_controller.dart';
import 'package:app_primero_flutter_ble/state/simulation_notifier.dart';
import 'package:app_primero_flutter_ble/view/theme/app_theme.dart';
import 'package:app_primero_flutter_ble/view/widgets/empty_state.dart';
import 'package:app_primero_flutter_ble/view/widgets/section_header.dart';
import 'package:app_primero_flutter_ble/view/widgets/signal_strength_bar.dart';

class ScannerScreen extends StatefulWidget {
  final SimulationNotifier notifier;
  final ModeController modeController;
  final PermissionService permissionService;

  const ScannerScreen({
    super.key,
    required this.notifier,
    required this.modeController,
    required this.permissionService,
  });

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen>
    with SingleTickerProviderStateMixin {
  StreamSubscription<BleError?>? _errorsSub;
  late final Ticker _refreshTicker;

  /// Latest permission snapshot (refreshed when the user comes back to
  /// this tab after changing system settings).
  PermissionStatusReport? _permissions;

  /// Last BLE error that came through the errors stream.
  BleError? _lastError;

  /// Per-beacon "last seen" timestamp, populated whenever the snapshot
  /// is refreshed. Beacons that drop out of the snapshot retain their
  /// timestamp so we can show "hace Xs".
  final Map<String, DateTime> _lastSeen = <String, DateTime>{};

  @override
  void initState() {
    super.initState();
    _errorsSub = widget.modeController.errors.stream.listen(_onError);
    _refreshPermissions();
    // Tick once per second so the "hace Xs" labels stay current.
    // Uses a Ticker (not a Timer.periodic) so the test framework's
    // TickerMode(enabled: false) actually pauses it, and so dispose()
    // cleanly cancels pending ticks.
    _refreshTicker = createTicker((_) {
      if (mounted) setState(() {});
    });
    _refreshTicker.start();
  }

  @override
  void dispose() {
    _errorsSub?.cancel();
    _refreshTicker.dispose();
    super.dispose();
  }

  Future<void> _refreshPermissions() async {
    try {
      final report = await widget.permissionService.check();
      if (!mounted) return;
      setState(() => _permissions = report);
    } catch (_) {
      // Ignore: permission check failure shouldn't crash the debug view.
    }
  }

  void _onError(BleError? err) {
    if (!mounted) return;
    setState(() => _lastError = err);
    // Permissions state may have changed — re-check.
    if (err?.kind == BleErrorKind.permissionDenied ||
        err?.kind == BleErrorKind.permissionPermanentlyDenied) {
      _refreshPermissions();
    }
  }

  /// Returns true when the most recent BLE error indicates Bluetooth is
  /// disabled or unavailable.
  bool get _bluetoothLikelyOff {
    final err = _lastError;
    if (err == null) return false;
    return err.kind == BleErrorKind.bluetoothOff ||
        err.kind == BleErrorKind.unknown;
  }

  bool get _permissionsGranted =>
      _permissions?.allGranted ?? false;

  bool get _isScanning =>
      widget.notifier.mode == BeaconMode.realBle &&
      !_bluetoothLikelyOff;

  void _maybeUpdateLastSeen(Map<String, RssiSample> snapshot) {
    final now = DateTime.now();
    for (final id in snapshot.keys) {
      _lastSeen[id] = now;
    }
  }

  String _formatAgo(DateTime then) {
    final d = DateTime.now().difference(then);
    if (d.inSeconds < 1) return 'recién';
    if (d.inSeconds < 60) return 'hace ${d.inSeconds}s';
    final m = d.inMinutes;
    if (m < 60) return 'hace ${m}m';
    return 'hace ${d.inHours}h';
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<SimulationNotifier>(
      builder: (context, notifier, _) {
        final snapshot = notifier.rssiSource.current();
        _maybeUpdateLastSeen(snapshot);

        // Sort by signal strength (closer to 0 dBm = closer beacon).
        final beacons = snapshot.values.toList()
          ..sort((a, b) => b.dbm.compareTo(a.dbm));

        return RefreshIndicator(
          onRefresh: _refreshPermissions,
          color: AppColors.primary,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.lg,
              AppSpacing.lg,
              AppSpacing.xxl,
            ),
            children: [
              _StatusCard(
                bluetoothOk: !_bluetoothLikelyOff,
                permissionsGranted: _permissionsGranted,
                isScanning: _isScanning,
              ),
              const SizedBox(height: AppSpacing.lg),
              SectionHeader(
                icon: Icons.sensors,
                label: 'Balizas detectadas',
                trailing: Text(
                  '${beacons.length}',
                  style: const TextStyle(
                    fontSize: AppTypography.sectionHeaderSize,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              _BeaconsList(
                beacons: beacons,
                lastSeen: _lastSeen,
                formatAgo: _formatAgo,
              ),
              const SizedBox(height: AppSpacing.lg),
              if (_lastError != null) ...[
                SectionHeader(
                  icon: Icons.error_outline,
                  label: 'Último error',
                  color: AppColors.error,
                ),
                const SizedBox(height: AppSpacing.sm),
                _ErrorCard(
                  error: _lastError!,
                  onOpenSettings: widget.permissionService.openSettings,
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

/// Top status card: Bluetooth + Permissions + Scan state.
class _StatusCard extends StatelessWidget {
  final bool bluetoothOk;
  final bool permissionsGranted;
  final bool isScanning;

  const _StatusCard({
    required this.bluetoothOk,
    required this.permissionsGranted,
    required this.isScanning,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: AppCardDecoration.card(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: SectionHeader(
                  icon: Icons.bluetooth,
                  label: 'Estado BLE',
                ),
              ),
              const _ModeBadgeReal(),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          _StatusRow(
            color: bluetoothOk ? AppColors.success : AppColors.error,
            icon: bluetoothOk ? Icons.bluetooth : Icons.bluetooth_disabled,
            label: 'Bluetooth',
            value: bluetoothOk ? 'Encendido' : 'Apagado o no disponible',
          ),
          const SizedBox(height: AppSpacing.sm),
          _StatusRow(
            color: permissionsGranted ? AppColors.success : AppColors.warning,
            icon: permissionsGranted
                ? Icons.verified_user_outlined
                : Icons.lock_outline,
            label: 'Permisos',
            value: permissionsGranted ? 'Concedidos' : 'Pendientes',
          ),
          const SizedBox(height: AppSpacing.sm),
          _StatusRow(
            color: isScanning
                ? AppColors.success
                : (_bluetoothIdleColor(bluetoothOk, permissionsGranted)),
            icon: isScanning ? Icons.radar : Icons.radar_outlined,
            label: 'Escaneo',
            value: isScanning ? 'Activo' : 'Inactivo',
            pulse: isScanning,
          ),
        ],
      ),
    );
  }

  static Color _bluetoothIdleColor(bool bt, bool perms) {
    if (!bt) return AppColors.error;
    if (!perms) return AppColors.warning;
    return AppColors.textMuted;
  }
}

class _StatusRow extends StatelessWidget {
  final Color color;
  final IconData icon;
  final String label;
  final String value;
  final bool pulse;

  const _StatusRow({
    required this.color,
    required this.icon,
    required this.label,
    required this.value,
    this.pulse = false,
  });

  @override
  Widget build(BuildContext context) {
    final dot = Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
    return Row(
      children: [
        if (pulse) _PulseDot(color: color) else dot,
        const SizedBox(width: AppSpacing.sm),
        Icon(icon, size: 18, color: color),
        const SizedBox(width: AppSpacing.sm),
        Text(
          label,
          style: const TextStyle(
            fontSize: AppTypography.bodySize,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        const Spacer(),
        Text(
          value,
          style: TextStyle(
            fontSize: AppTypography.bodySize,
            color: color,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

/// Always-green REAL BLE badge in the status card header.
class _ModeBadgeReal extends StatelessWidget {
  const _ModeBadgeReal();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.success.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.success.withValues(alpha: 0.3)),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.sensors, size: 12, color: AppColors.success),
          SizedBox(width: 4),
          Text(
            'REAL BLE',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: AppColors.success,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}

/// Tiny pulsing dot used while the scanner is running.
class _PulseDot extends StatefulWidget {
  final Color color;
  const _PulseDot({required this.color});

  @override
  State<_PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<_PulseDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (_, __) {
        final scale = 0.85 + _controller.value * 0.35;
        return Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: widget.color.withValues(alpha: 0.35),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Container(
              width: 10 * scale,
              height: 10 * scale,
              decoration: BoxDecoration(
                color: widget.color,
                shape: BoxShape.circle,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _BeaconsList extends StatelessWidget {
  final List<RssiSample> beacons;
  final Map<String, DateTime> lastSeen;
  final String Function(DateTime) formatAgo;

  const _BeaconsList({
    required this.beacons,
    required this.lastSeen,
    required this.formatAgo,
  });

  @override
  Widget build(BuildContext context) {
    if (beacons.isEmpty) {
      return Container(
        decoration: AppCardDecoration.card(),
        child: const EmptyState(
          icon: Icons.sensors_off,
          title: 'Sin beacons detectados en rango',
          subtitle:
              'Verificá que el beacon FSC-BP104D esté encendido y con '
              'Minor=1, Major=1.\nProbá moverte cerca de la baliza.',
        ),
      );
    }
    return Container(
      decoration: AppCardDecoration.card(),
      child: Column(
        children: [
          for (var i = 0; i < beacons.length; i++) ...[
            if (i > 0)
              const Divider(
                height: 1,
                thickness: 1,
                indent: AppSpacing.lg,
                endIndent: AppSpacing.lg,
                color: AppColors.divider,
              ),
            _BeaconRow(
              sample: beacons[i],
              lastSeenAt: lastSeen[beacons[i].beaconId],
              formatAgo: formatAgo,
            ),
          ],
        ],
      ),
    );
  }
}

class _BeaconRow extends StatelessWidget {
  final RssiSample sample;
  final DateTime? lastSeenAt;
  final String Function(DateTime) formatAgo;

  const _BeaconRow({
    required this.sample,
    required this.lastSeenAt,
    required this.formatAgo,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  sample.beaconId,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
              ),
              const Spacer(),
              if (lastSeenAt != null)
                Text(
                  formatAgo(lastSeenAt!),
                  style: const TextStyle(
                    fontSize: AppTypography.captionSize,
                    color: AppColors.textMuted,
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Text(
                '${sample.dbm.toStringAsFixed(0)} dBm',
                style: const TextStyle(
                  fontSize: AppTypography.titleSize,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Text(
                '${sample.distance.toStringAsFixed(1)} m',
                style: const TextStyle(
                  fontSize: AppTypography.bodySize,
                  color: AppColors.textMuted,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          SignalStrengthBar(dbm: sample.dbm),
        ],
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  final BleError error;
  final Future<void> Function() onOpenSettings;

  const _ErrorCard({required this.error, required this.onOpenSettings});

  @override
  Widget build(BuildContext context) {
    final color = error.requiresOpenSettings ? AppColors.warning : AppColors.error;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                error.requiresOpenSettings
                    ? Icons.warning_amber_rounded
                    : Icons.error_outline,
                color: color,
                size: 22,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  error.kind.name,
                  style: TextStyle(
                    fontSize: AppTypography.bodySize,
                    fontWeight: FontWeight.w700,
                    color: color,
                    letterSpacing: 0.4,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            error.message,
            style: const TextStyle(
              fontSize: AppTypography.bodySize,
              color: AppColors.textPrimary,
              height: 1.4,
            ),
          ),
          if (error.requiresOpenSettings) ...[
            const SizedBox(height: AppSpacing.md),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () {
                  onOpenSettings();
                },
                icon: const Icon(Icons.settings, size: 18),
                label: const Text('Settings'),
                style: TextButton.styleFrom(
                  foregroundColor: color,
                  textStyle: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// (end of file)
