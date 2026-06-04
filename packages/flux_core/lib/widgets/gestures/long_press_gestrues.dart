import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

class FLXLongPressGestureDetector extends StatelessWidget {
  final Widget child;
  final Duration pressDuration;
  final VoidCallback? onLongPress;
  final GestureLongPressStartCallback? onLongPressStart;
  final GestureLongPressMoveUpdateCallback? onLongPressMoveUpdate;
  final GestureLongPressEndCallback? onLongPressEnd;
  final GestureLongPressCancelCallback? onLongPressCancel;

  const FLXLongPressGestureDetector({
    super.key,
    required this.child,
    this.pressDuration = const Duration(milliseconds: 300),
    this.onLongPress,
    this.onLongPressStart,
    this.onLongPressMoveUpdate,
    this.onLongPressEnd,
    this.onLongPressCancel,
  });

  @override
  Widget build(BuildContext context) {
    return RawGestureDetector(
      gestures: {
        LongPressGestureRecognizer: GestureRecognizerFactoryWithHandlers<LongPressGestureRecognizer>(
          () => LongPressGestureRecognizer(duration: pressDuration),
          (LongPressGestureRecognizer instance) {
            instance
              ..onLongPress = onLongPress
              ..onLongPressStart = onLongPressStart
              ..onLongPressMoveUpdate = onLongPressMoveUpdate
              ..onLongPressEnd = onLongPressEnd
              ..onLongPressCancel = onLongPressCancel;
          },
        ),
      },
      behavior: HitTestBehavior.opaque,
      child: child,
    );
  }
}
