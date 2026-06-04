import 'dart:ui';

mixin FLXChangeNotifier {
  final Map<String, Function> _updateStateMap = {};

  void addListener({required Function handler, String? id}) {
    _updateStateMap[id ?? ''] = handler;
  }

  void removeListener(String? id) {
    _updateStateMap.remove(id ?? '');
  }

  void removeAllListeners() {
    _updateStateMap.clear();
  }

  void notifyListeners({String? id, List<String>? ids}) {
    if (ids != null && ids.isNotEmpty) {
      for (var e in ids) {
        _updateStateMap[e]?.call();
      }
    } else {
      _updateStateMap.forEach((key, value) => value.call());
    }
  }
}
