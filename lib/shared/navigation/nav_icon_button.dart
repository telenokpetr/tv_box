import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import 'nav_tab.dart';

class NavDestination {
  const NavDestination({
    required this.tab,
    required this.icon,
    required this.selectedIcon,
    required this.label,
    this.badgeCount = 0,
  });

  final NavTab tab;

  final IconData icon;

  final IconData selectedIcon;

  final String label;

  /// 0 hides the badge.
  final int badgeCount;
}

/// `width × height` is the cell, not the icon — the icon centers inside it.
class NavIconButton extends StatefulWidget {
  const NavIconButton({
    required this.destination,
    required this.active,
    required this.width,
    required this.height,
    required this.onTap,
    this.autofocus = false,
    super.key,
  });

  final NavDestination destination;

  final bool active;

  final double width;

  final double height;

  final VoidCallback onTap;
  final bool autofocus;

  @override
  State<NavIconButton> createState() => _NavIconButtonState();
}

class _NavIconButtonState extends State<NavIconButton> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final Color iconColor = widget.active
        ? AppColors.textPrimary.withAlpha(230)
        : AppColors.textTertiary;

    Widget icon = Icon(
      widget.active ? widget.destination.selectedIcon : widget.destination.icon,
      size: 28,
      color: iconColor,
    );

    if (widget.destination.badgeCount > 0) {
      icon = Badge(
        label: Text('${widget.destination.badgeCount}'),
        child: icon,
      );
    }

    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: Tooltip(
        message: widget.destination.label,
        waitDuration: const Duration(milliseconds: 400),
        child: InkResponse(
          autofocus: widget.autofocus,
          onTap: widget.onTap,
          radius: 28,
          containedInkWell: false,
          highlightShape: BoxShape.circle,
          onFocusChange: (bool focused) => setState(() => _focused = focused),
          focusColor: Colors.transparent,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            margin: const EdgeInsets.all(4),
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              color: _focused
                  ? AppColors.brand.withAlpha(36)
                  : widget.active
                  ? AppColors.surfaceLight
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _focused ? AppColors.brand : Colors.transparent,
                width: 3,
              ),
            ),
            child: widget.width >= 140
                ? Row(
                    children: <Widget>[
                      icon,
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          widget.destination.label,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 14,
                            color: iconColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  )
                : Center(child: icon),
          ),
        ),
      ),
    );
  }
}

class NavPulsingBadge extends StatefulWidget {
  const NavPulsingBadge({required this.child, super.key});

  final Widget child;

  @override
  State<NavPulsingBadge> createState() => _NavPulsingBadgeState();
}

class _NavPulsingBadgeState extends State<NavPulsingBadge>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _animation = Tween<double>(
      begin: 0.4,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (BuildContext context, Widget? child) {
        return Badge(
          backgroundColor: AppColors.statusInProgress.withAlpha(
            (_animation.value * 255).round(),
          ),
          smallSize: 8,
          child: child,
        );
      },
      child: widget.child,
    );
  }
}
