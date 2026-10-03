/// Top-level screen of the app.
///
/// Uses an [IndexedStack] to keep both tabs alive (the BLE pipeline and
/// the scanner subscription stay mounted when switching tabs) and a
/// custom [AppBottomNav] for the tab bar.
///
/// On [initState], kicks off the BLE permission flow so the user doesn't
/// have to tap anything to start scanning.
library;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import 'package:app_primero_flutter_ble/models/beacon_mode.dart';
import 'package:app_primero_flutter_ble/permissions/permission_service.dart';
import 'package:app_primero_flutter_ble/state/mode_controller.dart';
import 'package:app_primero_flutter_ble/state/simulation_notifier.dart';
import 'package:app_primero_flutter_ble/view/screens/cuarto_screen.dart';
import 'package:app_primero_flutter_ble/view/screens/scanner_screen.dart';
import 'package:app_primero_flutter_ble/view/theme/app_theme.dart';
import 'package:app_primero_flutter_ble/view/widgets/app_bottom_nav.dart';

class HomeScreen extends StatefulWidget {
  final SimulationNotifier notifier;
  final ModeController modeController;
  final PermissionService permissionService;

  const HomeScreen({
    super.key,
    required this.notifier,
    required this.modeController,
    required this.permissionService,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const int _scannerTab = 0;
  int _currentTab = _scannerTab;

  @override
  void initState() {
    super.initState();
    // Boot directly into Real BLE: request permissions + start scanner
    // asynchronously. Failures are surfaced through the mode controller's
    // errors stream and shown on the Scanner tab.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Guard: only fire if not already in Real BLE (main() may have set
      // it up; we want this call to be idempotent).
      if (widget.notifier.mode != BeaconMode.realBle) {
        // Fire-and-forget; the ModeController handles errors internally.
        widget.modeController.switchTo(BeaconMode.realBle);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Emulador BLE Indoor',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        backgroundColor: AppColors.background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        actions: const [_ModeBadge()],
      ),
      body: IndexedStack(
        index: _currentTab,
        children: [
          // Scanner tab — pre-built so the BLE errors subscription is
          // mounted even while the user is on the Cuarto tab.
          ScannerScreen(
            notifier: widget.notifier,
            modeController: widget.modeController,
            permissionService: widget.permissionService,
          ),
          CuartoScreen(notifier: widget.notifier),
        ],
      ),
      bottomNavigationBar: AppBottomNav(
        currentIndex: _currentTab,
        onTap: (i) => setState(() => _currentTab = i),
        items: const [
          AppNavTab(
            label: 'Scanner',
            icon: Icons.sensors_outlined,
            activeIcon: Icons.sensors,
          ),
          AppNavTab(
            label: 'Cuarto',
            icon: Icons.map_outlined,
            activeIcon: Icons.map,
          ),
        ],
      ),
    );
  }
}

/// Top-right badge showing the current operating mode.
///
/// Always "REAL BLE" now (simulation is hidden from the UI) but we keep
/// the visual treatment in case the architecture is ever extended to
/// surface the simulated mode again.
class _ModeBadge extends StatelessWidget {
  const _ModeBadge();

  @override
  Widget build(BuildContext context) {
    return Selector<SimulationNotifier, BeaconMode>(
      selector: (_, n) => n.mode,
      builder: (context, mode, _) {
        final isReal = mode == BeaconMode.realBle;
        final label = isReal ? 'REAL BLE' : 'SIMULACIÓN';
        final color = isReal ? AppColors.success : AppColors.warning;
        return Padding(
          padding: const EdgeInsets.only(right: AppSpacing.lg),
          child: Container(
            key: ValueKey<String>('mode-badge-$label'),
            padding: const EdgeInsets.symmetric(
              horizontal: 10,
              vertical: 5,
            ),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: color.withValues(alpha: 0.4)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isReal ? Icons.sensors : Icons.science_outlined,
                  size: 14,
                  color: color,
                ),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: color,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          )
              .animate(key: ValueKey<String>('mode-badge-anim-$label'))
              .fadeIn(duration: 200.ms)
              .scale(
                begin: const Offset(1.15, 1.15),
                end: const Offset(1, 1),
                duration: 200.ms,
                curve: Curves.easeOutBack,
              ),
        );
      },
    );
  }
}
