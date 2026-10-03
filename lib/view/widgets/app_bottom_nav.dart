/// Custom 2-tab bottom navigation.
///
/// Built from scratch (not using Flutter's [BottomNavigationBar]) so the
/// active tab can show a colored pill background and an indicator dot —
/// a look that doesn't match the default Material 3 bottom nav.
///
/// The widget is intentionally lightweight: callers pass [items] with
/// title + icon and an [onTap] handler. It does NOT own any state.
library;

import 'package:flutter/material.dart';

import 'package:app_primero_flutter_ble/view/theme/app_theme.dart';

class AppNavTab {
  final String label;
  final IconData icon;
  final IconData activeIcon;

  const AppNavTab({
    required this.label,
    required this.icon,
    required this.activeIcon,
  });
}

class AppBottomNav extends StatelessWidget {
  final List<AppNavTab> items;
  final int currentIndex;
  final ValueChanged<int> onTap;

  const AppBottomNav({
    super.key,
    required this.items,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.cardBackground,
        border: Border(
          top: BorderSide(color: AppColors.divider, width: 1),
        ),
      ),
      // SafeArea + small vertical padding keeps the bar above the home
      // indicator on iOS-style devices.
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.sm,
          ),
          child: Row(
            children: [
              for (var i = 0; i < items.length; i++)
                Expanded(
                  child: _NavItem(
                    tab: items[i],
                    isActive: i == currentIndex,
                    onTap: () => onTap(i),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final AppNavTab tab;
  final bool isActive;
  final VoidCallback onTap;

  const _NavItem({
    required this.tab,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final fg = isActive ? AppColors.primary : AppColors.textMuted;
    final bg = isActive ? AppColors.primaryLight : Colors.transparent;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              alignment: Alignment.center,
              clipBehavior: Clip.none,
              children: [
                Icon(
                  isActive ? tab.activeIcon : tab.icon,
                  color: fg,
                  size: 24,
                ),
                if (isActive)
                  Positioned(
                    top: -2,
                    right: -6,
                    child: Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              tab.label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                color: fg,
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
