import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../styles/text_style/text_style_builder.dart';

class FLXTextField extends StatelessWidget {
  final bool hasClear;
  final bool isPassword;
  final Widget? clearIcon;
  final Widget? passwordVisibleIcon;
  final Widget? passwordInvisibleIcon;
  final String? hintText;
  final int? hintMaxLines;
  final TextInputType? keyboardType;
  final TextEditingController? controller;
  final int? maxLines;
  final int? minLines;
  final int? maxLength;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final Color? fillColor;
  final Color? focusedFillColor;
  final dynamic textStyle;
  final dynamic hintTextStyle;
  final FocusNode? focusNode;
  final bool autofocus;
  final bool? enabled;
  final List<TextInputFormatter>? inputFormatters;
  final InputBorder? errorBorder;
  final InputBorder? focusedBorder;
  final InputBorder? focusedErrorBorder;
  final InputBorder? disabledBorder;
  final InputBorder? enabledBorder;
  final InputBorder? border;
  final bool? filled;
  final TextAlign textAlign;
  final Widget? prefix;
  final Widget? prefixIcon;
  final BoxConstraints? prefixIconConstraints;
  final Widget? suffix;
  final Widget? suffixIcon;
  final BoxConstraints? suffixIconConstraints;
  final EdgeInsets? contentPadding;

  const FLXTextField({
    super.key,
    this.hasClear = false,
    this.isPassword = false,
    this.clearIcon,
    this.passwordVisibleIcon,
    this.passwordInvisibleIcon,
    this.hintText,
    this.hintMaxLines,
    this.keyboardType,
    this.controller,
    this.maxLines = 1,
    this.minLines = 1,
    this.maxLength,
    this.textInputAction,
    this.fillColor,
    this.focusedFillColor,
    this.textStyle,
    this.hintTextStyle,
    this.focusNode,
    this.autofocus = false,
    this.onChanged,
    this.onSubmitted,
    this.inputFormatters,
    this.enabled,
    this.errorBorder,
    this.focusedBorder,
    this.focusedErrorBorder,
    this.disabledBorder,
    this.enabledBorder,
    this.border,
    this.filled,
    this.textAlign = TextAlign.start,
    this.prefix,
    this.prefixIcon,
    this.prefixIconConstraints,
    this.suffix,
    this.suffixIcon,
    this.suffixIconConstraints,
    this.contentPadding,
  });

  @override
  Widget build(BuildContext context) {
    var focus = focusNode ?? FocusNode();
    final TextEditingController textCtr = controller ?? TextEditingController();
    final logic = _FLXTextFieldLogic();
    return ListenableBuilder(
      listenable: Listenable.merge([logic.showPwd, logic.hasFocus]),
      builder: (context, child) {
        final ts = TextStyleBuilder.buildStyle(textStyle);
        final hts = TextStyleBuilder.buildStyle(hintTextStyle);
        List<Widget> sfxList = [];
        if (hasClear) {
          sfxList.add(
            _buildClearIcon(
              textCtr: textCtr,
              color: hts?.color,
              onTap: () {
                textCtr.clear();
                onChanged?.call(textCtr.text);
              },
            ),
          );
        }
        if (isPassword) {
          sfxList.add(_buildPasswordIcon(logic: logic, color: hts?.color));
        }
        if (suffixIcon != null) {
          sfxList.add(suffixIcon!);
        }
        var sfxIcon = sfxList.isNotEmpty ? Row(mainAxisSize: MainAxisSize.min, children: sfxList) : null;
        return Focus(
          onFocusChange: (hasFocus) {
            logic.hasFocus.value = focus.hasPrimaryFocus;
          },
          child: TextField(
            textAlign: textAlign,
            enabled: enabled,
            onChanged: onChanged,
            maxLines: maxLines,
            minLines: minLines,
            maxLength: maxLength,
            focusNode: focus,
            onSubmitted: onSubmitted,
            inputFormatters: inputFormatters,
            autofocus: autofocus,
            cursorColor: ts?.color,
            controller: textCtr,
            keyboardType: keyboardType,
            obscureText: isPassword ? !logic.showPwd.value : false,
            textInputAction: textInputAction,
            style: ts,
            decoration: InputDecoration(
              isCollapsed: true,
              fillColor: logic.hasFocus.value ? focusedFillColor ?? fillColor : fillColor,
              filled: filled,
              contentPadding: contentPadding ?? EdgeInsets.zero,
              border: border,
              enabledBorder: enabledBorder,
              focusedBorder: focusedBorder,
              disabledBorder: disabledBorder,
              errorBorder: errorBorder,
              hintText: hintText,
              hintMaxLines: hintMaxLines,
              hintStyle: hts,
              prefix: prefix,
              prefixIcon: prefixIcon,
              prefixIconConstraints: prefixIconConstraints ?? const BoxConstraints(minWidth: 0, minHeight: 0),
              suffix: suffix,
              suffixIcon: sfxIcon,
              suffixIconConstraints: suffixIconConstraints ?? const BoxConstraints(minWidth: 0, minHeight: 0),
            ),
          ),
        );
      },
    );
  }

  Widget _buildPasswordIcon({required _FLXTextFieldLogic logic, Color? color}) {
    return GestureDetector(
      child: logic.showPwd.value
          ? passwordVisibleIcon ??
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 5.r),
                  child: Icon(Icons.visibility, size: 16.r, color: color),
                )
          : passwordInvisibleIcon ??
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 5.r),
                  child: Icon(Icons.visibility_off, size: 16.r, color: color),
                ),
      onTap: () {
        logic.switchShowPwd();
      },
    );
  }

  Widget _buildClearIcon({required TextEditingController textCtr, required Color? color, required VoidCallback? onTap}) {
    return ListenableBuilder(
      listenable: textCtr,
      builder: (context, child) {
        return textCtr.text.isNotEmpty
            ? GestureDetector(
                onTap: onTap,
                child:
                    clearIcon ??
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 5.r),
                      child: Icon(Icons.clear, size: 16.r, color: color),
                    ),
              )
            : Container();
      },
    );
  }
}

class _FLXTextFieldLogic {
  final showPwd = ValueNotifier<bool>(false);
  final hasFocus = ValueNotifier<bool>(false);

  void switchShowPwd() {
    showPwd.value = !showPwd.value;
  }
}
