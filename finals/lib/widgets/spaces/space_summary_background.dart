import 'package:flutter/material.dart';
import '../../constants/colors.dart';
import 'space_painters.dart'; // DonutPainter

// ─────────────────────────────────────────────────────────────
// Summary background (no space selected)
// ─────────────────────────────────────────────────────────────
class SummaryBackground extends StatelessWidget {
  final int inProgress;
  final int completed;
  final int notStarted;
  final int totalSpaces;
  final double overallProgress;

  const SummaryBackground({
    super.key,
    required this.inProgress,
    required this.completed,
    required this.notStarted,
    required this.totalSpaces,
    required this.overallProgress,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title
          const Text('Overview',
              style: TextStyle(
                  color: kWhite,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.5)),
          const SizedBox(height: 2),
          Text(
            totalSpaces == 0
                ? 'No active projects'
                : '$totalSpaces active projects',
            style: const TextStyle(color: kSubtitle, fontSize: 13),
          ),

          const SizedBox(height: 20),

          // Donut + legend row
          Row(
            children: [
              // Donut
              SizedBox(
                width: 130,
                height: 130,
                child: CustomPaint(
                  painter: DonutPainter(
                    inProgress: inProgress,
                    completed: completed,
                    notStarted: notStarted,
                    total: totalSpaces,
                  ),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${(overallProgress * 100).round()}%',
                          style: const TextStyle(
                              color: kWhite,
                              fontSize: 22,
                              fontWeight: FontWeight.bold),
                        ),
                        const Text('overall',
                            style: TextStyle(color: kSubtitle, fontSize: 10)),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(width: 24),

              // Stats column
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    StatRow(
                      color: const Color(0xFF4A90D9),
                      label: 'In Progress',
                      count: inProgress,
                      total: totalSpaces,
                    ),
                    const SizedBox(height: 14),
                    StatRow(
                      color: const Color(0xFFB0BAD3),
                      label: 'Not Started',
                      count: notStarted,
                      total: totalSpaces,
                    ),
                    const SizedBox(height: 14),
                    StatRow(
                      color: const Color(0xFF3BBFA3),
                      label: 'Completed',
                      count: completed,
                      total: totalSpaces,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Stat row (label + progress bar)
// ─────────────────────────────────────────────────────────────
class StatRow extends StatelessWidget {
  final Color color;
  final String label;
  final int count;
  final int total;

  const StatRow({
    super.key,
    required this.color,
    required this.label,
    required this.count,
    required this.total,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                    width: 8,
                    height: 8,
                    decoration:
                        BoxDecoration(color: color, shape: BoxShape.circle)),
                const SizedBox(width: 6),
                Text(label,
                    style: const TextStyle(color: kSubtitle, fontSize: 11)),
              ],
            ),
            Text('$count/$total',
                style: const TextStyle(
                    color: kWhite,
                    fontSize: 11,
                    fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: LinearProgressIndicator(
            value: total > 0 ? count / total : 0,
            minHeight: 4,
            backgroundColor: kWhite.withOpacity(0.1),
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }
}