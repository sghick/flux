import 'dart:async';

typedef FilterListCondition<V, T> = V? Function(T obj);
typedef ListToMapCondition<T> = MapEntry? Function(T obj);
typedef CBListIndexedBuilder = Function(int index);

List<T>? toNullableList<T>(dynamic obj) {
  if (obj is T) {
    return [obj];
  }
  if (obj is List<T>) {
    return obj;
  }
  return null;
}

extension FLXListExt<T> on List<T> {
  List<V> picker<V>(FilterListCondition<V, T> condition) {
    List<V> list = [];
    forEach((e) {
      V? result = condition(e);
      if (result != null) {
        list.add(result);
      }
    });
    return list;
  }

  List<V> pickerNonnull<V>() {
    return picker((v) => v as V);
  }

  Map<K, V> toMap<K, V>(ListToMapCondition<T> condition) {
    Map<K, V> ret = {};
    forEach((e) {
      var obj = condition(e);
      if (obj != null) {
        ret[obj.key] = obj.value;
      }
    });
    return ret;
  }

  List<T> joinSeparator(CBListIndexedBuilder builder) {
    List<T> list = [];
    for (var i = 0; i < length; i++) {
      var e = this[i];
      list.add(e);
      if (last != e) {
        list.add(builder(i));
      }
    }
    return list;
  }

  Future<List<M>> mapFuture<M>(Future<M?> Function(T e) handler) async {
    List<M> list = [];
    for (var e in this) {
      var o = await handler(e);
      o != null ? list.add(o) : null;
    }
    return list;
  }

  List<T> getRandomElements(int count) {
    if (count > length) {
      return [...this];
    }

    // 创建列表的副本以避免修改原数组
    final shuffled = List<T>.from(this);
    // 随机打乱数组
    shuffled.shuffle();
    // 返回前count个元素
    return shuffled.take(count).toList();
  }
}
