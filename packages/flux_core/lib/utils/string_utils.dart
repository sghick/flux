import 'dart:convert';

import '../log/logger.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';

extension FLXStringExt on String {
  String md5Hex() => md5.convert(utf8.encode(this)).toString();

  int toInt({int defaultKey = 0}) {
    if (isEmpty) {
      return defaultKey;
    }
    var intKey = defaultKey;
    try {
      intKey =
          int.tryParse(this) ?? double.tryParse(this)?.toInt() ?? defaultKey;
    } catch (e) {
      logT(e);
    }
    return intKey;
  }

  bool toBool({bool defaultKey = false}) {
    if (isEmpty) {
      return defaultKey;
    }
    var boolKey = defaultKey;
    try {
      boolKey = toInt() > 0 ? true : false;
    } catch (e) {
      logT(e);
    }
    return boolKey;
  }

  double toDouble({double defaultKey = 0}) {
    if (isEmpty) {
      return defaultKey;
    }
    var doubleKey = defaultKey;
    try {
      doubleKey = double.tryParse(this) ?? defaultKey;
    } catch (e) {
      logT(e);
    }
    return doubleKey;
  }

  Image toImage(
          {String? package,
          BoxFit? fit,
          double? width,
          double? height,
          Color? color}) =>
      Image.asset(this,
          package: package,
          fit: fit,
          width: width,
          height: height,
          color: color);

  Image toNetImage(
          {String? package,
          BoxFit? fit,
          double? width,
          double? height,
          Color? color}) =>
      Image.network(this, fit: fit, width: width, height: height, color: color);
}

extension CBStringTrimEx on String? {
  bool isNullOrEmpty() {
    if (this == null) {
      return true;
    }
    return this!.trim().isEmpty;
  }

  ///替换多余的回车字符
  String? replaceBreak() {
    if (this == null || this!.isEmpty) {
      return this;
    }
    return this!.replaceAll(RegExp("\\s{2,}|\t|\r|\n"), '\n');
  }
}
