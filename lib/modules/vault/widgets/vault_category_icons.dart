import 'package:flutter/material.dart';

/// 密码保险箱分类图标注册表。
///
/// 分类只在数据库中保存图标 key，实际的 Material 图标统一由这里解析，
/// 这样分类页面和 Windows 桌面快捷方式可以使用同一套图标定义。
class VaultCategoryIcons {
  VaultCategoryIcons._();

  static const presetIcons = <String, IconData>{
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

  static IconData resolve(String iconKey) {
    return presetIcons[iconKey] ?? Icons.folder_rounded;
  }
}
