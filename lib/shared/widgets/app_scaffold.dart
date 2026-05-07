import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_strings.dart';

class AppScaffold extends StatelessWidget {
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

  static const _navItems = [
    (icon: Icons.map_outlined, label: AppStrings.mapa, route: '/mapa'),
    (icon: Icons.analytics_outlined, label: 'Balance', route: '/reportes'),
    (icon: Icons.upload_file_outlined, label: 'Archivos', route: '/carga'),
    (icon: Icons.folder_outlined, label: 'Gestion', route: '/tabla'),
  ];

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width > 768;

    if (isWide) {
      return Scaffold(
        appBar: AppBar(title: Text(title), actions: actions),
        body: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            NavigationRail(
              selectedIndex: currentIndex,
              onDestinationSelected: (i) => context.go(_navItems[i].route),
              labelType: NavigationRailLabelType.all,
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
              destinations: _navItems
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
        selectedIndex: currentIndex,
        onDestinationSelected: (i) => context.go(_navItems[i].route),
        labelBehavior: NavigationDestinationLabelBehavior.onlyShowSelected,
        destinations: _navItems
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
