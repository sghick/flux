import 'package:flutter/material.dart';

class FLXLoadingIndicator extends StatelessWidget {
  const FLXLoadingIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.transparent,
      alignment: Alignment.center,
      child: Container(
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(15), color: const Color(0xa0e0e0e0)),
        padding: EdgeInsets.all(20),
        child: const CircularProgressIndicator(backgroundColor: Colors.transparent),
      ),
    );
  }
}
