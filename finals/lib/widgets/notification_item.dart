import 'package:flutter/material.dart';
import '../constants/colors.dart';
import '../models/task.dart';

class NotificationItem extends StatelessWidget {
  final IconData icon;
  final Color iconBgColor;
  final Color iconColor;
  final String subtitle;
  final String title;
  final String detail;
  final bool showDashedLine;
  final TaskPriority? priority;
  final bool isRead;

  /// Called when the user taps the notification row.
  /// The caller (home_screen _NotificationSheetState) is responsible for
  /// invoking NotificationRouter.instance.route(context, notification).
  final VoidCallback? onTap;

  const NotificationItem({
    super.key,
    required this.icon,
    required this.iconBgColor,
    required this.iconColor,
    required this.subtitle,
    required this.title,
    required this.detail,
    this.showDashedLine = true,
    this.priority,
    this.isRead = true,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final content = Container(
      decoration: isRead
          ? null
          : BoxDecoration(
              color: iconColor.withOpacity(0.05),
              borderRadius: BorderRadius.circular(12),
            ),
      padding: isRead ? EdgeInsets.zero : const EdgeInsets.fromLTRB(8, 6, 8, 0),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Unread accent bar
            if (!isRead)
              Container(
                width: 3,
                margin: const EdgeInsets.only(right: 8, top: 10, bottom: 24),
                decoration: BoxDecoration(
                  color: iconColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            // Icon + dashed line column
            SizedBox(
              width: 52,
              child: Column(
                children: [
                  // Icon with priority dot badge
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: iconBgColor,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(icon, color: iconColor, size: 22),
                      ),
                      if (priority != null)
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Container(
                            width: 13,
                            height: 13,
                            decoration: BoxDecoration(
                              color: priority!.color,
                              shape: BoxShape.circle,
                              border: Border.all(color: kWhite, width: 2),
                            ),
                          ),
                        ),
                    ],
                  ),
                  if (showDashedLine)
                    Expanded(
                      child: CustomPaint(
                        painter: _DashedLinePainter(
                            color: iconColor.withOpacity(0.5)),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            // Text content
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Expanded(
                          child: Text(subtitle,
                              style: const TextStyle(
                                  color: Color(0xFF6B7A99), fontSize: 13)),
                        ),
                        if (priority != null)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: priority!.color.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                  color: priority!.color.withOpacity(0.35)),
                            ),
                            child: Text(
                              priority!.label,
                              style: TextStyle(
                                color: priority!.color,
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(title,
                        style: const TextStyle(
                            color: Color(0xFF1A2A5E),
                            fontSize: 16,
                            fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text(detail,
                        style: const TextStyle(
                            color: Color(0xFF6B7A99), fontSize: 12)),
                    // Tap hint for tappable notifications
                    if (onTap != null) ...[
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(
                            Icons.open_in_new_rounded,
                            size: 11,
                            color: iconColor.withOpacity(0.55),
                          ),
                          const SizedBox(width: 3),
                          Text(
                            'Tap to open',
                            style: TextStyle(
                              color: iconColor.withOpacity(0.55),
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );

    // Wrap in InkWell only when a tap handler is provided.
    if (onTap == null) return content;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: content,
      ),
    );
  }
}

class _DashedLinePainter extends CustomPainter {
  final Color color;
  const _DashedLinePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    const dashHeight = 6.0;
    const dashSpace = 4.0;
    double startY = 0;
    final x = size.width / 2;

    while (startY < size.height) {
      canvas.drawLine(
          Offset(x, startY), Offset(x, startY + dashHeight), paint);
      startY += dashHeight + dashSpace;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}