import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// 半透明玻璃卡片 + 蓝色细边框 + 四角 HUD 装饰。
/// 科技感仅作辅助，不影响内部核心信息可读性。
class HudCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final bool showCorners; // 是否画四角 HUD 线
  final VoidCallback? onTap;
  final Color? borderColor;
  final double? glowIntensity;

  const HudCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.radius = 18,
    this.showCorners = true,
    this.onTap,
    this.borderColor,
    this.glowIntensity,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppColors.cardDark : AppColors.cardLight;
    final border = borderColor ?? AppColors.hudLine;
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(radius),
          border: Border.all(color: border, width: 1),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withOpacity(glowIntensity ?? 0.05),
              blurRadius: 18,
              spreadRadius: 0,
            ),
          ],
        ),
        child: Stack(
          children: [
            if (showCorners)
              Positioned.fill(
                child: CustomPaint(painter: _CornerPainter(border)),
              ),
            Padding(padding: padding, child: child),
          ],
        ),
      ),
    );
  }
}

/// 四角 HUD 线条绘制
class _CornerPainter extends CustomPainter {
  final Color color;
  _CornerPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.6
      ..style = PaintingStyle.stroke;
    const len = 12.0;
    // 左上
    canvas.drawLine(const Offset(0, len), const Offset(0, 0), paint);
    canvas.drawLine(const Offset(0, 0), const Offset(len, 0), paint);
    // 右上
    canvas.drawLine(Offset(size.width - len, 0), Offset(size.width, 0), paint);
    canvas.drawLine(Offset(size.width, 0), Offset(size.width, len), paint);
    // 左下
    canvas.drawLine(Offset(0, size.height - len), Offset(0, size.height), paint);
    canvas.drawLine(Offset(0, size.height), Offset(len, size.height), paint);
    // 右下
    canvas.drawLine(Offset(size.width - len, size.height), Offset(size.width, size.height), paint);
    canvas.drawLine(Offset(size.width, size.height - len), Offset(size.width, size.height), paint);
  }

  @override
  bool shouldRepaint(covariant _CornerPainter old) => old.color != color;
}

/// HUD 英文小标签，如 "TODAY'S SCHEDULE"
class HudLabel extends StatelessWidget {
  final String text;
  final Color? color;
  final IconData? icon;
  const HudLabel(this.text, {super.key, this.color, this.icon});

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppColors.primary;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[
          Icon(icon, size: 12, color: c),
          const SizedBox(width: 5),
        ],
        Text(
          text.toUpperCase(),
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 2.2,
            color: c,
          ),
        ),
      ],
    );
  }
}

/// “正在上课”呼吸灯圆点
class LiveDot extends StatefulWidget {
  final Color color;
  final double size;
  const LiveDot({super.key, this.color = AppColors.live, this.size = 9});

  @override
  State<LiveDot> createState() => _LiveDotState();
}

class _LiveDotState extends State<LiveDot> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween(begin: 0.35, end: 1.0).animate(
        CurvedAnimation(parent: _c, curve: Curves.easeInOut),
      ),
      child: Container(
        width: widget.size,
        height: widget.size,
        decoration: BoxDecoration(
          color: widget.color,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(color: widget.color.withOpacity(0.6), blurRadius: 8),
          ],
        ),
      ),
    );
  }
}

/// 微弱网格背景（页面装饰，极低透明度，不影响阅读）
class GridBackground extends StatelessWidget {
  final Widget child;
  const GridBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: CustomPaint(painter: _GridPainter()),
        ),
        child,
      ],
    );
  }
}

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.gridLine
      ..strokeWidth = 0.6;
    const step = 28.0;
    for (var x = 0.0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (var y = 0.0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}
