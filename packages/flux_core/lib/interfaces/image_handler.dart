import 'package:flutter/material.dart';

/// 图片加载处理抽象接口
/// 核心包只定义接口，使用者通过 [imageHandler] 注入具体实现（如 extended_image、cached_network_image 等）
abstract class FLXImageHandler {
  /// 加载网络图片
  Widget loadImage(
    String url, {
    BoxFit? fit,
    double? width,
    double? height,
    BorderRadius? borderRadius,
    Widget? placeholder,
    Widget? errorWidget,
  });
}

/// Image 全局单例代理
final FLXImageHandler imageHandler = FLXDefaultImageHandler();

/// 默认图片加载实现 — 使用 Flutter 原生 Image.network
class FLXDefaultImageHandler implements FLXImageHandler {
  @override
  Widget loadImage(
    String url, {
    BoxFit? fit,
    double? width,
    double? height,
    BorderRadius? borderRadius,
    Widget? placeholder,
    Widget? errorWidget,
  }) {
    Widget image = Image.network(
      url,
      fit: fit ?? BoxFit.cover,
      width: width,
      height: height,
      errorBuilder: (context, error, stackTrace) {
        return errorWidget ??
            const Center(
              child: Icon(Icons.broken_image, color: Colors.grey),
            );
      },
    );

    if (borderRadius != null) {
      image = ClipRRect(borderRadius: borderRadius, child: image);
    }

    return image;
  }
}