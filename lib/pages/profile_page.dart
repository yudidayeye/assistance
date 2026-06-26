import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/theme/theme_extension.dart';
import '../core/storage/database_service.dart';

/// 我的页面内容 — 用户卡片 + 名称编辑
class ProfilePageContent extends StatefulWidget {
  const ProfilePageContent({super.key});

  @override
  State<ProfilePageContent> createState() => _ProfilePageContentState();
}

class _ProfilePageContentState extends State<ProfilePageContent> {
  String _userName = '用户';

  @override
  void initState() {
    super.initState();
    _loadName();
  }

  Future<void> _loadName() async {
    final rows = await DatabaseService.instance
        .rawQuery("SELECT value FROM app_settings WHERE key = 'user_name'");
    if (rows.isNotEmpty && mounted) {
      setState(() => _userName = rows.first['value'] as String);
    }
  }

  Future<void> _editName() async {
    final appTheme = Theme.of(context).appTheme;
    final ctrl = TextEditingController(text: _userName);

    await showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: appTheme.cream,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '编辑用户名',
                style: TextStyle(
                  fontFamily: GoogleFonts.playfairDisplay().fontFamily,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: appTheme.earth,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: ctrl,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: '输入用户名',
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
                style: TextStyle(color: appTheme.earth, fontSize: 15),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => Navigator.pop(ctx),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          color: appTheme.creamDark,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: appTheme.earthMedium.withAlpha(30),
                          ),
                        ),
                        child: const Center(
                          child: Text('取消',
                              style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF8B6F5C))),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: GestureDetector(
                      onTap: () async {
                        final name = ctrl.text.trim();
                        if (name.isEmpty) return;
                        await DatabaseService.instance.upsertSetting(
                            'user_name', name);
                        if (mounted) {
                          setState(() => _userName = name);
                        }
                        if (ctx.mounted) Navigator.pop(ctx);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [appTheme.primary, appTheme.primaryDark],
                          ),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Center(
                          child: Text('保存',
                              style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white)),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final appTheme = theme.appTheme;

    return Scaffold(
      backgroundColor: appTheme.cream,
      body: Column(
        children: [
          Container(
            padding: EdgeInsets.fromLTRB(
                24, MediaQuery.of(context).padding.top + 16, 24, 24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '我的',
                  style: TextStyle(
                    fontFamily: GoogleFonts.playfairDisplay().fontFamily,
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    color: appTheme.earth,
                    letterSpacing: -0.5,
                  ),
                ),
                GestureDetector(
                  onTap: () => context.push('/settings'),
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: appTheme.creamDark,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: appTheme.earthMedium.withAlpha(30),
                      ),
                    ),
                    child: Icon(
                      Icons.settings_outlined,
                      color: appTheme.earthMedium,
                      size: 20,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
            child: GestureDetector(
              onTap: _editName,
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: appTheme.earth.withAlpha(8),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: appTheme.primary.withAlpha(20),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Icon(
                        Icons.person_rounded,
                        color: appTheme.primary,
                        size: 32,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _userName,
                            style: TextStyle(
                              fontFamily:
                                  GoogleFonts.playfairDisplay().fontFamily,
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: appTheme.earth,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '点击编辑个人信息',
                            style: TextStyle(
                              fontSize: 13,
                              color: appTheme.earthMedium,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.chevron_right_rounded,
                      color: appTheme.earthMedium.withAlpha(100),
                      size: 20,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
