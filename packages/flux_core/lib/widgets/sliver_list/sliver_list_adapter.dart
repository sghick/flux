import 'package:flutter/cupertino.dart';

class FLXSliverToListAdapter extends StatelessWidget {
  /// The widget like swiper
  final Widget child;

  const FLXSliverToListAdapter({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return SliverList(
      delegate: SliverChildListDelegate(
        List.generate(1, (int index) {
          return child;
        }),
      ),
    );
  }
}
