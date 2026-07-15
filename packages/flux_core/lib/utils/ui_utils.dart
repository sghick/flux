import 'package:flutter/cupertino.dart';

typedef FLXUILayoutWidgetBuilder = Widget Function();
typedef FLXUILayoutListWidgetBuilder<T> = Widget Function(T child);

extension FLXUILayoutWidgetExt on Widget? {
  Widget flxBuild(bool condition, FLXUILayoutWidgetBuilder builder) =>
      condition ? builder() : this!;

  Widget flxPadding(EdgeInsets? padding) => flxBuild(
      padding != null,
      () => Padding(
            padding: padding ?? EdgeInsets.zero,
            child: this,
          ));

  Widget flxSafeArea({
    bool? left,
    bool? top,
    bool? right,
    bool? bottom,
    EdgeInsets? minimum,
    bool enable = true,
  }) =>
      flxBuild(
          enable,
          () => SafeArea(
                left: left ?? true,
                top: top ?? true,
                right: right ?? true,
                bottom: bottom ?? true,
                minimum: minimum ?? EdgeInsets.zero,
                child: this!,
              ));
}

extension FLXUILayoutListWidgetExt on List<Widget>? {
  List<Widget> flxAddAll(bool condition, FLXUILayoutListWidgetBuilder builder) =>
      condition ? this!.map((e) => builder(e)).toList() : this!;

  List<Widget> flxPaddingAll(EdgeInsets? padding) => flxAddAll(
      padding != null,
      (child) => Padding(
            padding: padding ?? EdgeInsets.zero,
            child: child,
          ));
}
