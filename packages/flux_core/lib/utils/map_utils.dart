typedef FilterMapCondition<K, V> = bool Function(K key, V value);

extension FLXMapExt<K, V> on Map<K, V> {
  Map<K, V> picker(FilterMapCondition<K, V> condition) {
    Map<K, V> map = {};
    forEach((key, value) {
      if (condition(key, value)) {
        map[key] = value;
      }
    });
    return map;
  }
  
  Map<K, V> pickerNonnull() {
    return picker((k, v) => v != null);
  }

  Map<String, V> formFilter(String format,
      {String symbol = '@', FilterMapCondition? condition}) {
    Map<String, V> map = {};
    forEach((key, value) {
      if (key is! String) {
        throw Exception(
            'Can not form filter the key witch is not String type!');
      }
      if (condition != null) {
        if (condition(key, value)) {
          map[_formKey(key, format, symbol)] = value;
        } else {
          // Ignore condition's key-value
        }
      } else {
        map[_formKey(key, format, symbol)] = value;
      }
    });
    return map;
  }

  String _formKey(String key, String format, String symbol) {
    return format.replaceAll(symbol, key);
  }
}
