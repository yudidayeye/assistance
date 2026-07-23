import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import '../core/module_system/module_registry.dart';
import '../core/settings/settings_service.dart';
import '../core/theme/theme_extension.dart';
import '../shared/widgets/featured_card.dart';
import '../shared/widgets/toolbox_bottom_nav.dart';
import 'profile_page.dart';

/// 主页面容器 — 管理工具箱和我的两个 tab
class MainShellPage extends StatefulWidget {
  const MainShellPage({super.key});

  @override
  State<MainShellPage> createState() => _MainShellPageState();
}

class _MainShellPageState extends State<MainShellPage> {
  int _currentIndex = 0;
  bool _isGrid = true;
  final SettingsController _settingsController = SettingsController.instance;

  @override
  void initState() {
    super.initState();
    _settingsController.addListener(_onSettingsChanged);
  }

  @override
  void dispose() {
    _settingsController.removeListener(_onSettingsChanged);
    super.dispose();
  }

  void _onSettingsChanged() {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final appTheme = Theme.of(context).appTheme;
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(gradient: appTheme.scaffoldGradient),
        child: IndexedStack(
          index: _currentIndex,
          children: [
            _buildToolboxPage(appTheme),
            const ProfilePageContent(),
          ],
        ),
      ),
      bottomNavigationBar: ToolboxBottomNav(
        selectedIndex: _currentIndex,
        onTap: (index) {
          if (index == _currentIndex) return;
          setState(() => _currentIndex = index);
        },
      ),
    );
  }

  Widget _buildToolboxPage(AppThemeExtension appTheme) {
    final enabledModules = ModuleRegistry.instance.getEnabledModules();
    final safeTop = MediaQuery.of(context).padding.top;

    return Column(
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(24, safeTop + 12, 24, 12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '工具箱',
                      style: TextStyle(
                        fontFamily: GoogleFonts.dmSans().fontFamily,
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: appTheme.earth,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '安静管理你的日常工具',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: appTheme.earthMedium,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: () => setState(() => _isGrid = !_isGrid),
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: appTheme.primary.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(appTheme.radiusMd),
                  ),
                  child: Icon(
                    _isGrid
                        ? Icons.grid_on_outlined
                        : Icons.apps_outlined,
                    color: appTheme.primaryDark,
                    size: 20,
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: _isGrid
              ? GridView.count(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                  crossAxisCount: 2,
                  mainAxisSpacing: 20,
                  crossAxisSpacing: 20,
                  childAspectRatio: 0.88,
                  children: enabledModules
                      .map((module) => FeaturedCard(module: module))
                      .toList(),
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                  itemCount: enabledModules.length,
                  separatorBuilder: (_, __) =>
                      const SizedBox(height: 12),
                  itemBuilder: (context, index) =>
                      FeaturedCard(module: enabledModules[index], isList: true),
                ),
        ),
      ],
    );
  }
}
