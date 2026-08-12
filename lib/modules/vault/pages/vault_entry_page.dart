import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/theme_extension.dart';
import '../../../shared/foundation/app_typography.dart';
import '../../../shared/widgets/app_scaffold.dart';
import '../../../shared/widgets/app_snack_bar.dart';
import '../models/vault_category.dart';
import '../services/vault_service.dart';
import '../services/vault_session.dart';
import 'master_password_page.dart';

/// 图标选项（key 与 _presetIcons 中的键一致，label 用于弹窗展示）
class _IconChoice {
  final String key;
  final String label;

  const _IconChoice(this.key, this.label);
}

/// 图标分组，用于分类弹窗中分组展示图标
class _IconGroup {
  final String label;
  final List<_IconChoice> choices;

  const _IconGroup(this.label, this.choices);
}

/// 密码保险箱入口页 — 分类列表
class VaultEntryPage extends StatefulWidget {
  const VaultEntryPage({super.key});

  @override
  State<VaultEntryPage> createState() => _VaultEntryPageState();
}

class _VaultEntryPageState extends State<VaultEntryPage> {
  List<VaultCategory> _categories = [];
  bool _loading = true;
  bool _needSetup = false;
  bool _isSetup = false;
  bool _navigating = false;
  bool _isSorting = false;

  // 预置分类图标映射（key 持久化到数据库，新增图标时在此追加即可）
  static const _presetIcons = <String, IconData>{
    // 常用
    'folder': Icons.folder_rounded,
    'lock': Icons.lock_rounded,
    'key': Icons.vpn_key_rounded,
    'star': Icons.star_rounded,
    'bookmark': Icons.bookmark_rounded,
    'favorite': Icons.favorite_rounded,
    // 账户身份
    'email': Icons.email_rounded,
    'contact': Icons.contact_mail_rounded,
    'badge': Icons.badge_rounded,
    'fingerprint': Icons.fingerprint_rounded,
    'person': Icons.person_rounded,
    // 技术开发
    'git': Icons.code_rounded,
    'cloud': Icons.cloud_rounded,
    'server': Icons.dns_rounded,
    'database': Icons.storage_rounded,
    'router': Icons.router_rounded,
    'wifi': Icons.wifi_rounded,
    'terminal': Icons.terminal_rounded,
    'bug': Icons.bug_report_rounded,
    'memory': Icons.memory_rounded,
    // 设备
    'phone': Icons.phone_android_rounded,
    'phone_iphone': Icons.phone_iphone_rounded,
    'computer': Icons.computer_rounded,
    'laptop': Icons.laptop_mac_rounded,
    'tablet': Icons.tablet_android_rounded,
    'watch': Icons.watch_rounded,
    'sim': Icons.sim_card_rounded,
    'headphones': Icons.headphones_rounded,
    // 社交
    'social': Icons.people_rounded,
    'forum': Icons.forum_rounded,
    'chat': Icons.chat_rounded,
    'groups': Icons.groups_rounded,
    'voice': Icons.record_voice_over_rounded,
    // 金融
    'finance': Icons.account_balance_rounded,
    'credit_card': Icons.credit_card_rounded,
    'wallet': Icons.wallet_rounded,
    'savings': Icons.savings_rounded,
    'currency': Icons.currency_yuan_rounded,
    'payments': Icons.payments_rounded,
    // 购物
    'shopping': Icons.shopping_bag_rounded,
    'shopping_cart': Icons.shopping_cart_rounded,
    'storefront': Icons.storefront_rounded,
    'basket': Icons.shopping_basket_rounded,
    'mall': Icons.local_mall_rounded,
    // 娱乐
    'game': Icons.sports_esports_rounded,
    'movie': Icons.movie_rounded,
    'music': Icons.music_note_rounded,
    'theater': Icons.theater_comedy_rounded,
    'camera': Icons.photo_camera_rounded,
    'casino': Icons.casino_rounded,
    // 工作
    'work': Icons.work_rounded,
    'business': Icons.business_center_rounded,
    'construction': Icons.construction_rounded,
    'assignment': Icons.assignment_rounded,
    'event': Icons.event_available_rounded,
    // 生活
    'home': Icons.home_rounded,
    'restaurant': Icons.restaurant_rounded,
    'cafe': Icons.local_cafe_rounded,
    'car': Icons.directions_car_rounded,
    'flight': Icons.flight_rounded,
    'fitness': Icons.fitness_center_rounded,
    'pets': Icons.pets_rounded,
    'school': Icons.school_rounded,
    'lightbulb': Icons.lightbulb_rounded,
    'park': Icons.park_rounded,
    // 其他
    'extension': Icons.extension_rounded,
    'public': Icons.public_rounded,
    'schedule': Icons.schedule_rounded,
    'science': Icons.science_rounded,
    'rocket': Icons.rocket_launch_rounded,
    'translate': Icons.translate_rounded,
  };

  // 图标分组（弹窗内按组展示，key 与 _presetIcons 保持一致）
  static const _iconGroups = <_IconGroup>[
    _IconGroup('常用', [
      _IconChoice('folder', '文件夹'),
      _IconChoice('lock', '锁定'),
      _IconChoice('key', '密钥'),
      _IconChoice('star', '星标'),
      _IconChoice('bookmark', '书签'),
      _IconChoice('favorite', '收藏'),
    ]),
    _IconGroup('账户身份', [
      _IconChoice('email', '邮箱'),
      _IconChoice('contact', '联系人'),
      _IconChoice('badge', '证件'),
      _IconChoice('fingerprint', '指纹'),
      _IconChoice('person', '个人'),
    ]),
    _IconGroup('技术开发', [
      _IconChoice('git', '代码'),
      _IconChoice('cloud', '云端'),
      _IconChoice('server', '服务器'),
      _IconChoice('database', '数据库'),
      _IconChoice('router', '路由器'),
      _IconChoice('wifi', '无线'),
      _IconChoice('terminal', '终端'),
      _IconChoice('bug', '调试'),
      _IconChoice('memory', '内存'),
    ]),
    _IconGroup('设备', [
      _IconChoice('phone', '安卓'),
      _IconChoice('phone_iphone', 'iPhone'),
      _IconChoice('computer', '电脑'),
      _IconChoice('laptop', '笔记本'),
      _IconChoice('tablet', '平板'),
      _IconChoice('watch', '手表'),
      _IconChoice('sim', 'SIM卡'),
      _IconChoice('headphones', '耳机'),
    ]),
    _IconGroup('社交', [
      _IconChoice('social', '社交'),
      _IconChoice('forum', '论坛'),
      _IconChoice('chat', '聊天'),
      _IconChoice('groups', '群组'),
      _IconChoice('voice', '语音'),
    ]),
    _IconGroup('金融', [
      _IconChoice('finance', '银行'),
      _IconChoice('credit_card', '信用卡'),
      _IconChoice('wallet', '钱包'),
      _IconChoice('savings', '储蓄'),
      _IconChoice('currency', '货币'),
      _IconChoice('payments', '支付'),
    ]),
    _IconGroup('购物', [
      _IconChoice('shopping', '购物'),
      _IconChoice('shopping_cart', '购物车'),
      _IconChoice('storefront', '店铺'),
      _IconChoice('basket', '购物篮'),
      _IconChoice('mall', '商场'),
    ]),
    _IconGroup('娱乐', [
      _IconChoice('game', '游戏'),
      _IconChoice('movie', '影视'),
      _IconChoice('music', '音乐'),
      _IconChoice('theater', '影剧院'),
      _IconChoice('camera', '相机'),
      _IconChoice('casino', '棋牌'),
    ]),
    _IconGroup('工作', [
      _IconChoice('work', '工作'),
      _IconChoice('business', '公文包'),
      _IconChoice('construction', '工程'),
      _IconChoice('assignment', '任务'),
      _IconChoice('event', '日程'),
    ]),
    _IconGroup('生活', [
      _IconChoice('home', '家'),
      _IconChoice('restaurant', '餐饮'),
      _IconChoice('cafe', '咖啡'),
      _IconChoice('car', '汽车'),
      _IconChoice('flight', '出行'),
      _IconChoice('fitness', '健身'),
      _IconChoice('pets', '宠物'),
      _IconChoice('school', '教育'),
      _IconChoice('lightbulb', '灵感'),
      _IconChoice('park', '公园'),
    ]),
    _IconGroup('其他', [
      _IconChoice('extension', '组件'),
      _IconChoice('public', '全球'),
      _IconChoice('schedule', '时钟'),
      _IconChoice('science', '科学'),
      _IconChoice('rocket', '火箭'),
      _IconChoice('translate', '翻译'),
    ]),
  ];

  @override
  void initState() {
    super.initState();
    _checkAndLoad();
    VaultService.instance.addListener(_onVaultChanged);
  }

  @override
  void dispose() {
    VaultService.instance.removeListener(_onVaultChanged);
    super.dispose();
  }

  void _onVaultChanged() {
    if (mounted) {
      _loadCategories();
    }
  }

  Future<void> _checkAndLoad() async {
    final hasMaster = await VaultService.instance.hasMasterPassword();
    if (!hasMaster) {
      if (mounted) {
        setState(() {
          _isSetup = true;
          _needSetup = true;
          _loading = false;
        });
      }
      return;
    }

    await _loadCategories();
  }

  Future<void> _loadCategories() async {
    final categories = await VaultService.instance.getAllCategories();
    if (mounted) {
      setState(() {
        _categories = categories;
        _loading = false;
        _needSetup = false;
      });
    }
  }

  Future<void> _navigateToUnlock() async {
    if (_navigating) return;
    setState(() => _navigating = true);
    try {
      final result = await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (_) => MasterPasswordPage(
            isSetup: _isSetup,
            onSuccess: () {},
          ),
        ),
      );
      if (result == true) {
        await _loadCategories();
      }
    } finally {
      if (mounted) setState(() => _navigating = false);
    }
  }

  IconData _getIcon(String iconName) {
    return _presetIcons[iconName] ?? Icons.folder_rounded;
  }

  Future<void> _showAddCategoryDialog() async {
    final result = await _showCategoryFormDialog(title: '新增分类');
    if (result == null || !mounted) return;

    final now = DateTime.now().toIso8601String();
    await VaultService.instance.insertCategory(VaultCategory(
      name: result.name,
      icon: result.icon,
      isEncrypted: result.encrypted,
      sortOrder: _categories.length,
      createdAt: now,
      updatedAt: now,
    ));
    await _loadCategories();
  }

  Future<void> _showEditCategoryDialog(VaultCategory category) async {
    final result = await _showCategoryFormDialog(
      title: '编辑分类',
      initialName: category.name,
      initialIcon: category.icon,
      initialEncrypted: category.isEncrypted,
    );
    if (result == null || !mounted) return;

    // 切换加密状态且有密码条目时，需要会话已解锁才能迁移存储格式
    if (category.isEncrypted != result.encrypted) {
      final count = await VaultService.instance
          .getCategoryEntryCount(category.id!);
      if (count > 0 && VaultSession.instance.isLocked) {
        if (!mounted) return;
        AppSnackBar.show(context, '请先解锁后再修改分类的加密状态');
        return;
      }
    }
    await VaultService.instance.updateCategory(category.copyWith(
      name: result.name,
      icon: result.icon,
      isEncrypted: result.encrypted,
      updatedAt: DateTime.now().toIso8601String(),
    ));
    await _loadCategories();
  }

  /// 新增 / 编辑分类弹窗（共用表单：实时预览 + 名称输入 + 分组图标选择 + 加密开关）
  ///
  /// 返回 (name, icon, encrypted)；取消或名称为空时返回 null。
  Future<({String name, String icon, bool encrypted})?> _showCategoryFormDialog({
    required String title,
    String initialName = '',
    String initialIcon = 'folder',
    bool initialEncrypted = true,
  }) async {
    final nameController = TextEditingController(text: initialName);
    String selectedIcon = initialIcon;
    bool isEncrypted = initialEncrypted;

    final result = await showDialog<({String name, String icon, bool encrypted})>(
      context: context,
      builder: (ctx) {
        final appTheme = Theme.of(ctx).appTheme;
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              backgroundColor: appTheme.cardBackground,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(appTheme.radiusLg),
              ),
              title: Text(
                title,
                style: AppTypography.displayMd.copyWith(color: appTheme.earth),
              ),
              content: ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(ctx).size.height * 0.62,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // 实时预览：图标 + 名称
                    _buildCategoryPreview(
                      name: nameController.text.trim(),
                      iconKey: selectedIcon,
                      appTheme: appTheme,
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: nameController,
                      style: TextStyle(color: appTheme.earth),
                      onChanged: (_) => setDialogState(() {}),
                      decoration: InputDecoration(
                        labelText: '分类名称',
                        labelStyle: TextStyle(color: appTheme.earthLight),
                        filled: true,
                        fillColor: appTheme.cream,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(appTheme.radiusMd),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      autofocus: initialName.isEmpty,
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Text(
                          '选择图标',
                          style: AppTypography.bodyMd.copyWith(color: appTheme.earth),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '${_iconGroups.fold<int>(0, (sum, g) => sum + g.choices.length)} 种可选',
                          style: AppTypography.caption.copyWith(color: appTheme.earthMedium),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    // 图标分组选择（可滚动，避免小屏溢出）
                    Flexible(
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            for (final group in _iconGroups)
                              _buildIconGroup(
                                group: group,
                                selectedIcon: selectedIcon,
                                appTheme: appTheme,
                                onSelect: (key) =>
                                    setDialogState(() => selectedIcon = key),
                              ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    SwitchListTile(
                      value: isEncrypted,
                      onChanged: (v) => setDialogState(() => isEncrypted = v),
                      contentPadding: EdgeInsets.zero,
                      activeThumbColor: appTheme.primary,
                      title: Text(
                        '加密存储',
                        style: AppTypography.bodyMd.copyWith(color: appTheme.earth),
                      ),
                      subtitle: Text(
                        isEncrypted ? '密码将加密保存' : '密码将明文保存',
                        style: AppTypography.bodySm
                            .copyWith(color: appTheme.earthLight),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text('取消',
                      style: AppTypography.bodyMd.copyWith(color: appTheme.earthLight)),
                ),
                TextButton(
                  onPressed: () {
                    if (nameController.text.trim().isEmpty) return;
                    Navigator.pop(ctx, (
                      name: nameController.text.trim(),
                      icon: selectedIcon,
                      encrypted: isEncrypted,
                    ));
                  },
                  child: Text('确定',
                      style: AppTypography.bodyMd.copyWith(color: appTheme.primary)),
                ),
              ],
            );
          },
        );
      },
    );

    return result;
  }

  /// 分类实时预览条（左侧图标 + 右侧名称）
  Widget _buildCategoryPreview({
    required String name,
    required String iconKey,
    required AppThemeExtension appTheme,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: appTheme.cream,
        borderRadius: BorderRadius.circular(appTheme.radiusMd),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              gradient: appTheme.gradientPrimary,
              borderRadius: BorderRadius.circular(appTheme.radiusMd),
            ),
            child: Icon(_getIcon(iconKey), size: 24, color: Colors.white),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '分类预览',
                  style: AppTypography.caption.copyWith(color: appTheme.earthMedium),
                ),
                const SizedBox(height: 2),
                Text(
                  name.isEmpty ? '分类名称' : name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.bodyLg.copyWith(color: appTheme.earth),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 图标分组区块（组标题 + 图标列表）
  Widget _buildIconGroup({
    required _IconGroup group,
    required String selectedIcon,
    required AppThemeExtension appTheme,
    required ValueChanged<String> onSelect,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 2, bottom: 8),
            child: Text(
              group.label,
              style: AppTypography.label.copyWith(color: appTheme.earthMedium),
            ),
          ),
          Wrap(
            spacing: 4,
            runSpacing: 4,
            children: [
              for (final choice in group.choices)
                _buildIconTile(
                  choice: choice,
                  isSelected: choice.key == selectedIcon,
                  appTheme: appTheme,
                  onTap: () => onSelect(choice.key),
                ),
            ],
          ),
        ],
      ),
    );
  }

  /// 单个图标选项（图标 + 文字标签，选中态带主色边框与对勾角标）
  Widget _buildIconTile({
    required _IconChoice choice,
    required bool isSelected,
    required AppThemeExtension appTheme,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 60,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 48,
              height: 48,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: isSelected
                          ? appTheme.primary.withValues(alpha: 0.14)
                          : appTheme.cream,
                      borderRadius: BorderRadius.circular(appTheme.radiusMd),
                      border: Border.all(
                        color: isSelected ? appTheme.primary : appTheme.cardBorder,
                        width: isSelected ? 1.5 : 1,
                      ),
                    ),
                    child: Icon(
                      _getIcon(choice.key),
                      size: 24,
                      color: isSelected ? appTheme.primary : appTheme.earthMedium,
                    ),
                  ),
                  if (isSelected)
                    Positioned(
                      right: -3,
                      top: -3,
                      child: Container(
                        width: 16,
                        height: 16,
                        decoration: BoxDecoration(
                          color: appTheme.primary,
                          shape: BoxShape.circle,
                          border: Border.all(color: appTheme.cardBackground, width: 1.5),
                        ),
                        child: const Icon(Icons.check_rounded, size: 11, color: Colors.white),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            Text(
              choice.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.caption.copyWith(
                color: isSelected ? appTheme.primary : appTheme.earthMedium,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDeleteCategory(VaultCategory category) async {
    final count = await VaultService.instance.getCategoryEntryCount(category.id!);
    if (!mounted) return;

    final appTheme = Theme.of(context).appTheme;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: appTheme.cardBackground,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(appTheme.radiusLg),
        ),
        title: Text('删除分类',
            style: AppTypography.displayMd.copyWith(color: appTheme.earth)),
        content: Text(
          count > 0
              ? '「${category.name}」下有 $count 条密码记录，删除分类将同时删除所有记录，确定删除？'
              : '确定删除「${category.name}」？',
          style: AppTypography.bodyMd.copyWith(color: appTheme.earthLight),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('取消',
                style: AppTypography.bodyMd.copyWith(color: appTheme.earthLight)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('删除',
                style: AppTypography.bodyMd.copyWith(color: appTheme.rose)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await VaultService.instance.deleteCategory(category.id!);
      await _loadCategories();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final appTheme = theme.appTheme;

    // 首次使用，需设置主密码
    if (_needSetup) {
      return _buildSetupScreen(appTheme);
    }

    if (_loading) {
      return AppScaffold(
        appBar: AppBar(
          backgroundColor: appTheme.cream,
          elevation: 0,
          centerTitle: false,
          titleSpacing: 0,
          automaticallyImplyLeading: true,
          title: Text(
            '密码保险箱',
            style: AppTypography.headerTitle.copyWith(color: appTheme.earth),
          ),
        ),
        body: Center(
          child: CircularProgressIndicator(color: appTheme.primary),
        ),
      );
    }

    return PopScope(
      canPop: !_isSorting,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _isSorting) {
          setState(() => _isSorting = false);
        }
      },
      child: AppScaffold(
        appBar: AppBar(
          backgroundColor: appTheme.cream,
          elevation: 0,
          centerTitle: false,
          titleSpacing: 0,
          automaticallyImplyLeading: true,
          title: Text(
            '密码保险箱',
            style: AppTypography.headerTitle.copyWith(color: appTheme.earth),
          ),
          actions: _categories.isEmpty
            ? []
            : [
                if (_isSorting)
                  TextButton(
                    onPressed: _exitSorting,
                    child: Text(
                      '完成',
                      style: AppTypography.bodyMd.copyWith(
                        color: appTheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  )
                else
                  IconButton(
                    tooltip: '排序',
                    icon: Icon(
                      Icons.swap_vert_rounded,
                      color: appTheme.earthMedium,
                    ),
                    onPressed: _enterSorting,
                  ),
              ],
          ),
          body: _categories.isEmpty
              ? _buildEmptyState(appTheme)
              : _buildCategoryList(appTheme),
          floatingActionButton: _isSorting
              ? null
              : Padding(
                  padding: const EdgeInsets.only(bottom: 40),
                  child: _buildFab(appTheme),
                ),
      ),
    );
  }

  Widget _buildSetupScreen(AppThemeExtension appTheme) {
    return AppScaffold(
      appBar: AppBar(
        backgroundColor: appTheme.cream,
        elevation: 0,
        centerTitle: false,
        titleSpacing: 0,
        automaticallyImplyLeading: true,
        title: Text(
          '密码保险箱',
          style: AppTypography.headerTitle.copyWith(color: appTheme.earth),
        ),
      ),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.lock_rounded, size: 64, color: appTheme.primary),
            const SizedBox(height: 16),
            Text(
              '欢迎使用密码保险箱',
              style: AppTypography.displayMd.copyWith(color: appTheme.earth),
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 46,
              child: ElevatedButton(
                onPressed: _navigating ? null : _navigateToUnlock,
                style: ElevatedButton.styleFrom(
                  backgroundColor: appTheme.primary,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: appTheme.primary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(appTheme.radiusPill),
                  ),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                  elevation: 0,
                ),
                child: _navigating
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        _isSetup ? '设置主密码' : '解锁',
                        style:
                            AppTypography.bodyLg.copyWith(color: Colors.white),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(AppThemeExtension appTheme) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.folder_open_rounded, size: 56, color: appTheme.earthMedium),
          const SizedBox(height: 12),
          Text(
            '还没有分类',
            style: AppTypography.bodyLg.copyWith(color: appTheme.earthLight),
          ),
          const SizedBox(height: 4),
          Text(
            '点击右下角 + 创建第一个分类',
            style: AppTypography.bodySm.copyWith(color: appTheme.earthMedium),
          ),
        ],
      ),
    );
  }

  Widget _buildFab(AppThemeExtension appTheme) {
    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [appTheme.primary, appTheme.primaryDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: appTheme.primary.withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: _showAddCategoryDialog,
          child: const Icon(Icons.add_rounded, color: Colors.white, size: 26),
        ),
      ),
    );
  }

  Widget _buildCategoryList(AppThemeExtension appTheme) {
    if (!_isSorting) {
      return ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 80),
        itemCount: _categories.length,
        itemBuilder: (context, index) {
          final category = _categories[index];
          return _buildCategoryCard(category, appTheme);
        },
      );
    }
    return ReorderableListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 80),
      buildDefaultDragHandles: false,
      onReorderItem: _onCategoryReorder,
      proxyDecorator: (child, index, animation) =>
          _buildSortableDragProxy(index, appTheme),
      itemCount: _categories.length,
      itemBuilder: (context, index) {
        final category = _categories[index];
        return _buildSortableCategoryCard(category, index, appTheme);
      },
    );
  }

  Widget _buildCategoryCard(
    VaultCategory category,
    AppThemeExtension appTheme, {
    VoidCallback? onTap,
    VoidCallback? onLongPress,
    Widget? leading,
    double bottomSpacing = 8,
    bool isSorting = false,
  }) {
    final borderColor = isSorting
        ? appTheme.primary.withValues(alpha: 0.35)
        : appTheme.earthMedium.withValues(alpha: 0.15);
    return Padding(
      padding: EdgeInsets.only(bottom: bottomSpacing),
      child: Material(
        color: appTheme.cardBackground,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(appTheme.radiusMd),
          side: BorderSide(color: borderColor, width: isSorting ? 1.2 : 0.5),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(appTheme.radiusMd),
          hoverColor: Colors.transparent,
          splashColor: Colors.transparent,
          highlightColor: Colors.transparent,
          onTap: onTap ??
              () {
                context.push('/vault/category/${category.id}');
              },
          onLongPress: onLongPress ?? () => _showCategoryActions(category),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            child: Row(
              children: [
                if (leading != null) ...[leading, const SizedBox(width: 8)],
                // 图标
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: appTheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(appTheme.radiusSm),
                  ),
                  child: Icon(
                    _getIcon(category.icon),
                    color: appTheme.primary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 14),
                // 名称
                Expanded(
                  child: Text(
                    category.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.bodyLg.copyWith(color: appTheme.earth),
                  ),
                ),
                // 条目数徽标
                FutureBuilder<int>(
                  future:
                      VaultService.instance.getCategoryEntryCount(category.id!),
                  builder: (context, snapshot) {
                    final count = snapshot.data ?? 0;
                    if (count <= 0) return const SizedBox.shrink();
                    return _buildCountBadge(count, appTheme);
                  },
                ),
                const SizedBox(width: 4),
                // 箭头
                Icon(
                  Icons.chevron_right_rounded,
                  color: appTheme.earthMedium,
                  size: 22,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 条目数徽标（浅色圆角底 + 主色文字）
  Widget _buildCountBadge(int count, AppThemeExtension appTheme) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: appTheme.primary.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(appTheme.radiusPill),
        ),
        child: Text(
          '$count',
          style: AppTypography.bodySm.copyWith(
            color: appTheme.primary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  /// 进入排序模式
  void _enterSorting() {
    setState(() => _isSorting = true);
  }

  /// 退出排序模式（顺序已在拖拽时实时持久化）
  void _exitSorting() {
    setState(() => _isSorting = false);
  }

  /// 拖拽排序回调 — 更新本地顺序并后台持久化
  ///
  /// onReorderItem 传入的 newIndex 已由框架修正（无需再减一）。
  void _onCategoryReorder(int oldIndex, int newIndex) {
    if (oldIndex == newIndex) return;
    final updated = List<VaultCategory>.from(_categories);
    final moved = updated.removeAt(oldIndex);
    updated.insert(newIndex, moved);
    setState(() => _categories = updated);
    VaultService.instance.updateCategoriesOrder(updated);
  }

  /// 排序模式下的分类卡片（带拖拽手柄，点击不响应）
  Widget _buildSortableCategoryCard(
    VaultCategory category,
    int index,
    AppThemeExtension appTheme,
  ) {
    return KeyedSubtree(
      key: ValueKey(category.id),
      child: _buildCategoryCard(
        category,
        appTheme,
        onTap: () {},
        onLongPress: () {},
        isSorting: true,
        leading: _buildDragHandle(index, appTheme),
      ),
    );
  }

  /// 拖拽手柄
  Widget _buildDragHandle(int index, AppThemeExtension appTheme) {
    return ReorderableDragStartListener(
      index: index,
      child: Padding(
        padding: const EdgeInsets.only(right: 2),
        child: Icon(
          Icons.drag_indicator_rounded,
          size: 24,
          color: appTheme.earthMedium.withValues(alpha: 0.4),
        ),
      ),
    );
  }

  /// 拖拽代理：仅展示卡片本体，去掉底部间距
  Widget _buildSortableDragProxy(
    int index,
    AppThemeExtension appTheme,
  ) {
    final category = _categories[index];
    return _buildCategoryCard(
      category,
      appTheme,
      bottomSpacing: 0,
      onTap: () {},
      onLongPress: () {},
      isSorting: true,
      leading: _buildDragHandle(index, appTheme),
    );
  }

  void _showCategoryActions(VaultCategory category) {
    final appTheme = Theme.of(context).appTheme;
    showModalBottomSheet(
      context: context,
      backgroundColor: appTheme.cardBackground,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
            top: Radius.circular(appTheme.radiusLg)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: appTheme.earthMedium.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 12),
            ListTile(
              leading: Icon(Icons.edit_rounded, color: appTheme.primary),
              title: Text('编辑',
                  style: AppTypography.bodyMd.copyWith(color: appTheme.earth)),
              onTap: () {
                Navigator.pop(ctx);
                _showEditCategoryDialog(category);
              },
            ),
            ListTile(
              leading: Icon(Icons.delete_outline_rounded, color: appTheme.rose),
              title: Text('删除',
                  style: AppTypography.bodyMd.copyWith(color: appTheme.rose)),
              onTap: () {
                Navigator.pop(ctx);
                _confirmDeleteCategory(category);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
