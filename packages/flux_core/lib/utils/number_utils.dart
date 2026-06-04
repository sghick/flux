import 'dart:math';

extension FLXIntExt on int {
  int between(int minLimit, int maxLimit) {
    return min(max(this, minLimit), maxLimit);
  }

  List<int> dissolveOptions() {
    List<int> ret = [];
    int source = 1;
    while (source <= this) {
      if (source == source & this) {
        ret.add(source);
      }
      source *= 2;
    }
    return ret;
  }

  bool containsOption(int option) {
    return this & option == option;
  }
}

extension ListSolveOptionExt on List<int> {
  int solveOptions() {
    int ret = 0;
    forEach((e) => ret += e);
    return ret;
  }
}
