import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../../constants/colors.dart';
import '../../constants/app_colors.dart';

// ─────────────────────────────────────────────────────────────
// Painters
// ─────────────────────────────────────────────────────────────

class DonutPainter extends CustomPainter {
  final int inProgress;
  final int completed;
  final int notStarted;
  final int total;

  const DonutPainter({
    required this.inProgress,
    required this.completed,
    required this.notStarted,
    required this.total,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 14;
    const stroke = 20.0;
    const pi = math.pi;
    final rect = Rect.fromCircle(center: center, radius: radius);

    // Grey track ring (always drawn)
    canvas.drawArc(rect, 0, 2 * pi, false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke
          ..color = AppColors.lightFill);

    if (total == 0) return;

    void arc(double start, double sweep, Color color) {
      if (sweep <= 0) return;
      canvas.drawArc(rect, start, sweep, false,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = stroke
            ..strokeCap = StrokeCap.round
            ..color = color);
    }

    double start = -pi / 2;
    final ipSweep = 2 * pi * (inProgress / total);
    final nsSweep = 2 * pi * (notStarted / total);
    final cSweep  = 2 * pi * (completed / total);

    arc(start, ipSweep, AppColors.link);
    start += ipSweep + 0.05;
    arc(start, nsSweep, AppColors.subtitle);
    start += nsSweep + 0.05;
    arc(start, cSweep, const Color(0xFF3BBFA3));
  }

  @override
  bool shouldRepaint(covariant CustomPainter _) => true;
}

class SemiGaugePainter extends CustomPainter {
  final int completed;
  final int total;
  final Color accentColor;

  const SemiGaugePainter({
    required this.completed,
    required this.total,
    required this.accentColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height);
    final radius = size.width / 2 - 14;
    const stroke = 24.0;
    final rect = Rect.fromCircle(center: center, radius: radius);

    canvas.drawArc(rect, math.pi, math.pi, false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke
          ..strokeCap = StrokeCap.round
          ..color = AppColors.text.withOpacity(0.18));

    if (total > 0) {
      final done = math.pi * (completed / total);
      canvas.drawArc(rect, math.pi, done, false,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = stroke
            ..strokeCap = StrokeCap.round
            ..color = accentColor);

      canvas.drawArc(rect, math.pi + done, math.pi - done, false,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = stroke
            ..strokeCap = StrokeCap.round
            ..color = AppColors.accent);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter _) => true;
}

class DashedLinePainter extends CustomPainter {
  final Color color;
  const DashedLinePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withOpacity(0.35)
      ..strokeWidth = 2;
    const dash = 5.0, gap = 4.0;
    double y = 0;
    final x = size.width / 2;
    while (y < size.height) {
      canvas.drawLine(
          Offset(x, y), Offset(x, math.min(y + dash, size.height)), paint);
      y += dash + gap;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter _) => true;
}

// ─────────────────────────────────────────────────────────────
// Small reusable widgets
// ─────────────────────────────────────────────────────────────

class SpaceSummaryChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const SpaceSummaryChip({
    super.key,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value,
            style: TextStyle(
                color: color, fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 2),
        Text(label,
            style: TextStyle(color: AppColors.icon, fontSize: 10)),
      ],
    );
  }
}

class SpaceVerticalDivider extends StatelessWidget {
  const SpaceVerticalDivider({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(width: 1, height: 28, color: AppColors.lightFill);
  }
}

class EmptyTasksPlaceholder extends StatelessWidget {
  const EmptyTasksPlaceholder({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Center(
        child: Column(
          children: [
            Icon(Icons.task_alt_rounded,
                size: 52, color: AppColors.bg.withOpacity(0.12)),
            const SizedBox(height: 12),
            Text('No tasks yet',
                style: TextStyle(
                    color: AppColors.bg.withOpacity(0.4),
                    fontSize: 15,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text('Add the first task for this space',
                style: TextStyle(
                    color: AppColors.bg.withOpacity(0.25), fontSize: 12)),
          ],
        ),
      ),
    );
  }
}



  @override
  Widget build(BuildContext context) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: AppColors.accent,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
              color: AppColors.accent.withOpacity(0.4),
              blurRadius: 10,
              offset: const Offset(0, 4)),
        ],
      ),
      child: Icon(Icons.chat_bubble_rounded, color: AppColors.text, size: 22),
    );
  }
