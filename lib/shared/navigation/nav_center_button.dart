import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_assets.dart';
import '../theme/app_colors.dart';

/// The app logo as a nav item. Fills the `width × height` cell it is given
/// (matching [NavIconButton]) and is focusable for gamepad via [InkResponse].
class NavCenterButton extends StatefulWidget {
  const NavCenterButton({
    required this.onTap,
    required this.tooltip,
    required this.width,
    required this.height,
    this.active = false,
    super.key,
  });

  final VoidCallback onTap;

  /// Tooltip / accessibility label.
  final String tooltip;

  /// Cell width.
  final double width;

  /// Cell height.
  final double height;
  final bool active;

  @override
  State<NavCenterButton> createState() => _NavCenterButtonState();
}

class _NavCenterButtonState extends State<NavCenterButton> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final double cell = math.min(widget.width, widget.height);
    final double logoSize = math.min(cell * 0.78, 44);

    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: Tooltip(
        message: widget.tooltip,
        waitDuration: const Duration(milliseconds: 400),
        child: InkResponse(
          onTap: widget.onTap,
          onFocusChange: (bool focused) => setState(() => _focused = focused),
          focusColor: Colors.transparent,
          radius: cell * 0.5,
          containedInkWell: false,
          highlightShape: BoxShape.circle,
          child: Container(
            margin: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: _focused
                  ? AppColors.brand.withAlpha(36)
                  : widget.active
                  ? AppColors.surfaceLight
                  : Colors.transparent,
              border: Border.all(
                color: _focused ? AppColors.brand : Colors.transparent,
                width: 3,
              ),
            ),
            child: Center(
              child: Image.asset(
                AppAssets.logo,
                width: logoSize,
                height: logoSize,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
