import 'dart:ui';

extension FLXColorExt on Color {
  int get alpha255 => (a * 255.0).round() & 0xff;
  int get red255 => (r * 255.0).round() & 0xff;
  int get green255 => (g * 255.0).round() & 0xff;
  int get blue255 => (b * 255.0).round() & 0xff;

  /// Converts color to hex string in format #AARRGGBB
  String toHexString({bool leadingHashSign = true}) {
    final alpha = (alpha255).toRadixString(16).padLeft(2, '0');
    final red = (red255).toRadixString(16).padLeft(2, '0');
    final green = (green255).toRadixString(16).padLeft(2, '0');
    final blue = (blue255).toRadixString(16).padLeft(2, '0');

    return '${leadingHashSign ? '#' : ''}$alpha$red$green$blue';
  }

  /// Creates Color from hex integer (0xRRGGBB) with opacity
  static Color hex(int hexValue, [double opacity = 1]) {
    return Color(
        (((opacity * 0xFF).toInt() & 0xFF) << 24) | // Alpha channel
        (hexValue & 0xFFFFFF)                      // RGB channels
    );
  }

  /// Creates Color from hex string (supports #RGB, #ARGB, #RRGGBB, #AARRGGBB)
  static Color hexString(String hexStr, [double opacity = 1]) {
    String hex = hexStr.trim().replaceFirst(RegExp(r'^#'), '');

    // Handle short formats
    if (hex.length == 3 || hex.length == 4) {
      hex = hex.split('').map((c) => '$c$c').join();
    }

    // Pad to 8 characters if missing alpha
    if (hex.length == 6) hex = 'FF$hex';

    // Parse as 32-bit integer
    final value = int.tryParse(hex, radix: 16) ?? 0x00000000;

    // Apply opacity if needed
    return opacity != 1
        ? Color(value).withOpacity(opacity)
        : Color(value);
  }
}
