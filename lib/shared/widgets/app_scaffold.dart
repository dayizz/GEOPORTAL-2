import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_strings.dart';
import '../../features/auth/providers/user_management_provider.dart';

class AppScaffold extends ConsumerWidget {
  final Widget child;
  final int currentIndex;
  final String title;
  final List<Widget>? actions;
  final Widget? floatingActionButton;

  const AppScaffold({
    super.key,
    required this.child,
    required this.currentIndex,
    required this.title,
    this.actions,
    this.floatingActionButton,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final canAccessEstructura = ref.watch(canAccessEstructuraProvider);
    final navItems = <({IconData icon, String label, String route})>[
      (icon: Icons.map_outlined, label: AppStrings.mapa, route: '/mapa'),
      (icon: Icons.folder_outlined, label: 'Gestion', route: '/tabla'),
      (icon: Icons.analytics_outlined, label: 'Balance', route: '/reportes'),
      (icon: Icons.upload_file_outlined, label: 'Archivos', route: '/carga'),
      (icon: Icons.person_outline, label: 'Perfil', route: '/perfil'),
      if (canAccessEstructura)
        (icon: Icons.settings_outlined, label: 'Estructura', route: '/estructura'),
    ];

    final selectedIndex =
        currentIndex >= 0 && currentIndex < navItems.length ? currentIndex : 0;

    final width = MediaQuery.of(context).size.width;
    final isWide = width > 768;
    final isVeryWide = width > 1200;

    if (isWide) {
      return Scaffold(
        appBar: AppBar(title: Text(title), actions: actions),
        body: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            NavigationRail(
              extended: isVeryWide,
              selectedIndex: selectedIndex,
              onDestinationSelected: (i) {
                ref.read(userManagementProvider.notifier).markCurrentUserOperation();
                context.go(navItems[i].route);
              },
              labelType: isVeryWide
                  ? NavigationRailLabelType.none
                  : NavigationRailLabelType.all,
              leading: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.map, color: Colors.white, size: 22),
                    ),
                  ],
                ),
              ),
                destinations: navItems
                  .map((item) => NavigationRailDestination(
                        icon: Icon(item.icon),
                        selectedIcon: Icon(
                          item.icon,
                          color: AppColors.primary,
                        ),
                        label: Text(item.label, style: const TextStyle(fontSize: 11)),
                      ))
                  .toList(),
            ),
            const VerticalDivider(width: 1),
            Expanded(child: child),
          ],
        ),
        floatingActionButton: floatingActionButton,
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(title), actions: actions),
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: selectedIndex,
        onDestinationSelected: (i) {
          ref.read(userManagementProvider.notifier).markCurrentUserOperation();
          context.go(navItems[i].route);
        },
        labelBehavior: NavigationDestinationLabelBehavior.onlyShowSelected,
        destinations: navItems
            .map((item) => NavigationDestination(
                  icon: Icon(item.icon),
                  selectedIcon: Icon(item.icon, color: AppColors.primary),
                  label: item.label,
                ))
            .toList(),
      ),
      floatingActionButton: floatingActionButton,
    );
  }
}
