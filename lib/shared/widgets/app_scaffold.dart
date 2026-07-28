import 'package:flutter/material.dart';
import '../../core/theme/theme_extension.dart';

/// 统一的应用脚手架
///
/// 自动添加背景渐变，简化页面构建。
class AppScaffold extends StatelessWidget {
  final Widget body;
  final Widget? bottomNavigationBar;
  final Widget? floatingActionButton;

  const AppScaffold({
    super.key,
    required this.body,
    this.bottomNavigationBar,
    this.floatingActionButton,
  });

  @override
  Widget build(BuildContext context) {
    final appTheme = Theme.of(context).appTheme;

    return Scaffold(
      backgroundColor: appTheme.cream,
      body: Container(
        decoration: BoxDecoration(gradient: appTheme.scaffoldGradient),
        child: body,
      ),
      bottomNavigationBar: bottomNavigationBar,
      floatingActionButton: floatingActionButton,
    );
  }
}

/// 滚动版本的 AppScaffold
///
/// 自动添加 CustomScrollView + BouncingScrollPhysics。
class AppScrollScaffold extends StatelessWidget {
  final List<Widget> slivers;
  final Widget? bottomNavigationBar;
  final ScrollController? controller;

  const AppScrollScaffold({
    super.key,
    required this.slivers,
    this.bottomNavigationBar,
    this.controller,
  });

  @override
  Widget build(BuildContext context) {
    final appTheme = Theme.of(context).appTheme;

    return Scaffold(
      backgroundColor: appTheme.cream,
      body: Container(
        decoration: BoxDecoration(gradient: appTheme.scaffoldGradient),
        child: CustomScrollView(
          controller: controller,
          physics: const BouncingScrollPhysics(),
          slivers: slivers,
        ),
      ),
      bottomNavigationBar: bottomNavigationBar,
    );
  }
}
