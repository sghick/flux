import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

class FLXWheelPicker extends StatelessWidget {
  final FixedExtentScrollController controller;
  final double itemHeight;
  final double magnification;
  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;
  final ValueChanged<int>? onSelectedItemChanged;

  const FLXWheelPicker({
    super.key,
    required this.controller,
    required this.itemHeight,
    this.magnification = 1.0,
    required this.itemCount,
    required this.itemBuilder,
    this.onSelectedItemChanged,
  });

  @override
  Widget build(BuildContext context) {
    return _buildPickerList();
  }

  Widget _buildPickerList() {
    return NotificationListener(
      child: ListWheelScrollView.useDelegate(
        physics: const FixedExtentScrollPhysics(),
        controller: controller,
        itemExtent: itemHeight,
        diameterRatio: 1.2,
        overAndUnderCenterOpacity: 0.7,
        magnification: magnification,
        useMagnifier: true,
        childDelegate: ListWheelChildBuilderDelegate(
          childCount: itemCount,
          builder: itemBuilder,
        ),
      ),
      onNotification: (notification) {
        if (notification is UserScrollNotification &&
            notification.direction == ScrollDirection.idle) {
          onSelectedItemChanged?.call(controller.selectedItem);
        }
        return true;
      },
    );
  }
}
