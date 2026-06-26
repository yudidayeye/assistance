import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import '../core/module_system/module_registry.dart';
import '../core/settings/settings_service.dart';
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
    return Scaffold(
      backgroundColor: const Color(0xFFf5f6fa),
      body: IndexedStack(
        index: _currentIndex,
        children: [
          // 工具箱页
          _buildToolboxPage(),

          // 我的页
          const ProfilePageContent(),
        ],
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

  Widget _buildToolboxPage() {
    final enabledModules = ModuleRegistry.instance.getEnabledModules();

    return Column(
      children: [
        // 头部区域
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 56, 20, 16),
          child: Row(
            children: [
              // 左侧标题
              Expanded(
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

              // 右侧设置按钮
              GestureDetector(
                onTap: () => context.push('/settings'),
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: const Color(0xFF8892a4).withAlpha(30),
                    ),
                  ),
                  child: const Icon(
                    Icons.settings_outlined,
                    color: Color(0xFF8892a4),
                    size: 22,
                  ),
                ),
              ),
            ],
          ),
        ),

        // 两列特色功能卡片
        Expanded(
          child: GridView.count(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
            crossAxisCount: 2,
            mainAxisSpacing: 16,
            crossAxisSpacing: 16,
            childAspectRatio: 0.82,
            children: enabledModules
                .map((module) => FeaturedCard(module: module))
                .toList(),
          ),
        ),
      ],
    );
  }
}
