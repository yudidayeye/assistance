import 'package:flutter/material.dart';
import '../../core/theme/theme_extension.dart';

/// 统一的应用脚手架
///
/// Apple 风格：纯色背景，无渐变。
class AppScaffold extends StatelessWidget {
  final Widget body;
  final Widget? bottomNavigationBar;
  final Widget? floatingActionButton;
  final PreferredSizeWidget? appBar;

  const AppScaffold({
    super.key,
    required this.body,
    this.bottomNavigationBar,
    this.floatingActionButton,
    this.appBar,
  });

  @override
  Widget build(BuildContext context) {
    final appTheme = Theme.of(context).appTheme;

    return Scaffold(
      backgroundColor: appTheme.cream,
      appBar: appBar,
      body: body,
      bottomNavigationBar: bottomNavigationBar,
      floatingActionButton: floatingActionButton,
    );
  }
}

/// 滚动版本的 AppScaffold
///
/// Apple 风格：纯色背景 + BouncingScrollPhysics。
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
      body: CustomScrollView(
        controller: controller,
        physics: const BouncingScrollPhysics(),
        slivers: slivers,
      ),
      bottomNavigationBar: bottomNavigationBar,
    );
  }
}
