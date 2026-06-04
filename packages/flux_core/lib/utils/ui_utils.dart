import 'package:flutter/cupertino.dart';

typedef FLXUILayoutWidgetBuilder = Widget Function();
typedef FLXUILayoutListWidgetBuilder<T> = Widget Function(T child);

extension FLXUILayoutWidgetExt on Widget? {
  Widget lkBuild(bool condition, FLXUILayoutWidgetBuilder builder) =>
      condition ? builder() : this!;

  Widget lkPadding(EdgeInsets? padding) => lkBuild(
      padding != null,
      () => Padding(
            padding: padding ?? EdgeInsets.zero,
            child: this,
          ));

  Widget lkSafeArea({
    bool? left,
    bool? top,
    bool? right,
    bool? bottom,
    EdgeInsets? minimum,
    bool enable = true,
  }) =>
      lkBuild(
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
  List<Widget> lkAddAll(bool condition, FLXUILayoutListWidgetBuilder builder) =>
      condition ? this!.map((e) => builder(e)).toList() : this!;

  List<Widget> lkPaddingAll(EdgeInsets? padding) => lkAddAll(
      padding != null,
      (child) => Padding(
            padding: padding ?? EdgeInsets.zero,
            child: child,
          ));
}
