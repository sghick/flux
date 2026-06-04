import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../utils/screen_utils.dart';

class FLXSwitch extends StatelessWidget {
  final double? width;
  final double? height;
  final double? scale;
  final Color? activeColor;
  final bool isOn;
  final ValueChanged<bool>? onChanged;

  const FLXSwitch({super.key, this.width, this.height, this.scale, this.activeColor, required this.isOn, this.onChanged});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: Transform.scale(
        scale: scale,
        child: CupertinoSwitch(value: isOn, activeTrackColor: activeColor, onChanged: onChanged),
      ),
    );
  }

  static FLXSwitch defaultSwitch({Color? activeColor, required bool isOn, ValueChanged<bool>? onChanged}) =>
      FLXSwitch(width: 33.dp, height: 19.dp, scale: 0.65, activeColor: activeColor ?? const Color(0xFF009CFF), isOn: isOn, onChanged: onChanged);
}
