import 'dart:math' as math;

/// 版本号比较工具类
class VersionComparator {
  /// 比较两个语义化版本号（支持null和空字符串处理）
  /// 参数说明：
  ///   - newVersion: 新版本号（null或空字符串视为0）
  ///   - oldVersion: 旧版本号（null或空字符串视为0）
  /// 返回值：
  ///   1 - 新版本更高
  ///   0 - 版本相同
  ///  -1 - 旧版本更高
  static int compareVersions(String? newVersion, String? oldVersion) {
    // 处理null或空字符串，将其视为版本号0
    final newVersionStr = newVersion ?? '';
    final oldVersionStr = oldVersion ?? '';

    // 分割版本号部分
    final newParts = newVersionStr.split('.');
    final oldParts = oldVersionStr.split('.');

    // 逐段比较版本号
    for (var i = 0; i < math.max(newParts.length, oldParts.length); i++) {
      // 解析当前段（解析失败时默认为0）
      final newPart = i < newParts.length ? int.tryParse(newParts[i]) ?? 0 : 0;
      final oldPart = i < oldParts.length ? int.tryParse(oldParts[i]) ?? 0 : 0;

      // 比较当前段
      if (newPart > oldPart) return 1;
      if (newPart < oldPart) return -1;
    }

    return 0; // 所有段都相同
  }
}
