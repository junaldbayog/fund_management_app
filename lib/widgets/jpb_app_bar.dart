import 'package:flutter/material.dart';

class JPBAppBar extends StatelessWidget implements PreferredSizeWidget {
  final bool showBackButton;
  final List<Widget>? actions;

  const JPBAppBar({
    super.key,
    this.showBackButton = true,
    this.actions,
  });

  @override
  Widget build(BuildContext context) {
    return AppBar(
      automaticallyImplyLeading: showBackButton,
      backgroundColor: Colors.black,
      title: Image.asset(
        'assets/images/jpb-capital-logo.png',
        height: 40,
        fit: BoxFit.contain,
      ),
      centerTitle: true,
      actions: actions,
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
} 