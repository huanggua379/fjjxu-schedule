import 'package:flutter/material.dart';

/// 蓝白未来科技风配色。以白 + 极浅蓝 + 蓝 + 深蓝为主，
/// 避免大面积黑、霓虹、高饱和多色。
class AppColors {
  AppColors._();

  // 主色阶（蓝）
  static const Color primary = Color(0xFF2563EB); // 主蓝
  static const Color primaryDark = Color(0xFF1E3A8A); // 深蓝
  static const Color primaryLight = Color(0xFF60A5FA); // 亮蓝
  static const Color accent = Color(0xFF0EA5E9); // 科技青蓝（点缀）

  // 背景（白 / 极浅蓝）
  static const Color bgLight = Color(0xFFF5F8FF); // 极浅蓝白背景
  static const Color surfaceLight = Color(0xFFFFFFFF);
  static const Color cardLight = Color(0xF2FFFFFF); // 半透明白卡片
  static const Color gridLine = Color(0x142563EB); // 微弱网格线

  // 深色模式（深蓝灰，不用纯黑）
  static const Color bgDark = Color(0xFF0B1220);
  static const Color surfaceDark = Color(0xFF111A2E);
  static const Color cardDark = Color(0xE616213A);
  static const Color primaryDarkMode = Color(0xFF60A5FA);

  // 文本
  static const Color textPrimaryLight = Color(0xFF0F172A);
  static const Color textSecondaryLight = Color(0xFF64748B);
  static const Color textPrimaryDark = Color(0xFFE6EDF7);
  static const Color textSecondaryDark = Color(0xFF93A4BF);

  // 状态
  static const Color success = Color(0xFF10B981);
  static const Color warning = Color(0xFFF59E0B);
  static const Color danger = Color(0xFFEF4444);
  static const Color live = Color(0xFF22D3EE); // “正在上课”呼吸灯

  // HUD 装饰
  static const Color hudLine = Color(0x332563EB); // 蓝色细边框
  static const Color hudGlow = Color(0x1F60A5FA);
}
