bool isEmptyList(List? obj) => FLXEmptyUtils.isEmptyList(obj);

bool isEmptyString(String? obj) => FLXEmptyUtils.isEmptyString(obj);

class FLXEmptyUtils {
  static bool isEmptyList(dynamic obj) {
    if (obj == null) return true;
    if (obj is List) return obj.isEmpty;
    return false;
  }

  static bool isEmptyString(dynamic obj) {
    if (obj == null) return true;
    if (obj is String) return obj.isEmpty;
    return false;
  }
}
