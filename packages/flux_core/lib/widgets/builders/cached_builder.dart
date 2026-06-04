import 'package:flutter/material.dart';

class FLXCachedBuilder {
  final IndexedWidgetBuilder builder;
  final Map<int, Widget> cached = {};

  FLXCachedBuilder({required this.builder});

  Widget build(BuildContext context, int index) {
    var item = cached[index];
    if (item == null) {
      item = builder(context, index);
      cached[index] = item;
    }
    return item;
  }

  void clear() => cached.clear();
}
