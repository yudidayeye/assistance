import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/module_system/module_registry.dart';
import '../core/module_system/tool_module.dart';
import '../core/settings/settings_service.dart';
import '../shared/widgets/featured_card.dart';
import '../shared/widgets/toolbox_bottom_nav.dart';

/// 首页 — 工具箱展示页
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedTabIndex = 0;
  final SettingsService _settings = SettingsService.instance;

  @override
  void initState() {
    super.initState();
    _selectedTabIndex = 0;
  }

  @override
  Widget build(BuildContext context) {
    final enabledModules = ModuleRegistry.instance.getEnabledModules(_settings);

    return Scaffold(
      backgroundColor: const Color(0xFFf5f6fa),
      body: Column(
        children: [
          // 头部区域
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 56, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '欢迎使用',
                  style: TextStyle(
                    fontFamily: GoogleFonts.dmSans().fontFamily,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFF8892a4),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '工具箱',
                  style: TextStyle(
                    fontFamily: GoogleFonts.robotoSlab().fontFamily,
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF1a1d2e),
                    height: 1.33,
                    letterSpacing: -0.5,
                  ),
                ),
              ],
            ),
          ),

          // 特色功能卡片列表
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              children: _buildFeaturedCards(enabledModules),
            ),
          ),

          // 底部导航栏
          ToolboxBottomNav(
            selectedIndex: _selectedTabIndex,
            onTap: (index) {
              if (index == _selectedTabIndex) return;
              setState(() => _selectedTabIndex = index);
              if (index == 1) {
                context.push('/settings');
              }
            },
          ),
        ],
      ),
    );
  }

  List<Widget> _buildFeaturedCards(List<ToolModule> modules) {
    if (modules.isEmpty) return [];

    final widgets = <Widget>[];

    for (final module in modules) {
      widgets.add(
        FeaturedCard(
          module: module,
          categoryLabel: _getCategoryLabel(module),
          gradient: _getGradient(module),
        ),
      );
      widgets.add(const SizedBox(height: 16));
    }

    // Remove last SizedBox
    if (widgets.isNotEmpty) {
      widgets.removeLast();
    }

    return widgets;
  }

  String _getCategoryLabel(ToolModule module) {
    switch (module.moduleId) {
      case 'accounting':
        return '财务';
      case 'period_tracker':
        return '健康';
      default:
        return '工具';
    }
  }

  LinearGradient _getGradient(ToolModule module) {
    switch (module.moduleId) {
      case 'accounting':
        return const LinearGradient(
          colors: [Color(0xFF10b981), Color(0xFF059669)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
      case 'period_tracker':
        return const LinearGradient(
          colors: [Color(0xFFf472b6), Color(0xFFec4899)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
      default:
        return LinearGradient(
          colors: [module.themeColor, module.themeColor.withAlpha(0xB4)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
    }
  }
}
