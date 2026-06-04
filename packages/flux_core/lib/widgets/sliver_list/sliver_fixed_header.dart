import 'package:flutter/material.dart';

class FLXSliverFixedHeaderDelegate extends SliverPersistentHeaderDelegate {
  final Widget child;
  final double? maxExt;
  final double? minExt;

  const FLXSliverFixedHeaderDelegate(
      {required this.child, this.maxExt, this.minExt});

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    return child;
  }

  @override
  bool shouldRebuild(FLXSliverFixedHeaderDelegate oldDelegate) {
    return false;
  }

  @override
  double get maxExtent => maxExt ?? double.maxFinite;

  @override
  double get minExtent => minExt ?? double.infinity;
}
