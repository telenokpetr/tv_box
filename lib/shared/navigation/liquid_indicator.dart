import 'package:flutter/material.dart';

/// Selection is now painted by each navigation destination.
class LiquidIndicator extends StatelessWidget {
  const LiquidIndicator({
    required this.selectedIndex,
    required this.itemExtent,
    required this.crossExtent,
    this.axis = Axis.vertical,
    this.size = 40,
    this.rainbow = false,
    super.key,
  });
  final int selectedIndex;
  final double itemExtent;
  final double crossExtent;
  final Axis axis;
  final double size;
  final bool rainbow;
  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
