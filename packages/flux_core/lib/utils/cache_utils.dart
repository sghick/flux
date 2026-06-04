class FLXCacheUtils {
  static Future<T?> cachedValue<T>({
    required Future<T?> cached,
    required Future<T?> future,
  }) {
    return cached.then((ct) {
      if (ct != null) {
        return ct;
      } else {
        return future;
      }
    });
  }
}
