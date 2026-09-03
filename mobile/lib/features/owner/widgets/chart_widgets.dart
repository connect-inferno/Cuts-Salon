import 'package:flutter/material.dart';

import '../../../theme.dart';

class CustomLineChart extends StatelessWidget {
  final List<double> values;
  final List<String> labels;
  final String title;
  final String subtitle;
  final Color color;

  const CustomLineChart({
    super.key,
    required this.values,
    required this.labels,
    required this.title,
    required this.subtitle,
    this.color = AppTheme.primaryBlue,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                letterSpacing: 0.2,
                color: AppTheme.slateDark,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: const TextStyle(
                fontSize: 12,
                color: AppTheme.slateMedium,
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 160,
              child: CustomPaint(
                size: Size.infinite,
                painter: LineChartPainter(
                  values: values,
                  labels: labels,
                  color: color,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: labels.map((label) {
                return Text(
                  label,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.slateLight,
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}

class LineChartPainter extends CustomPainter {
  final List<double> values;
  final List<String> labels;
  final Color color;

  LineChartPainter({
    required this.values,
    required this.labels,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;

    final paintLine = Paint()
      ..color = color
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..isAntiAlias = true;

    final paintFill = Paint()
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    final double maxVal = values.reduce((curr, next) => curr > next ? curr : next);
    final double minVal = values.reduce((curr, next) => curr < next ? curr : next);
    final double range = (maxVal - minVal) == 0 ? 1 : (maxVal - minVal);
    
    // Scale max val a bit so it doesn't touch the absolute top
    final double scaleMax = maxVal + range * 0.15;
    final double scaleMin = minVal - range * 0.05;
    final double scaleRange = scaleMax - scaleMin;

    final double stepX = size.width / (values.length - 1);
    
    final path = Path();
    final fillPath = Path();

    // Start coordinates
    double startX = 0;
    double startY = size.height - ((values[0] - scaleMin) / scaleRange) * size.height;
    
    path.moveTo(startX, startY);
    fillPath.moveTo(startX, size.height);
    fillPath.lineTo(startX, startY);

    for (int i = 1; i < values.length; i++) {
      double nextX = i * stepX;
      double nextY = size.height - ((values[i] - scaleMin) / scaleRange) * size.height;

      // Draw smooth curve using cubic bezier control points
      double prevX = (i - 1) * stepX;
      double prevY = size.height - ((values[i - 1] - scaleMin) / scaleRange) * size.height;

      double cpX1 = prevX + stepX * 0.5;
      double cpY1 = prevY;
      double cpX2 = prevX + stepX * 0.5;
      double cpY2 = nextY;

      path.cubicTo(cpX1, cpY1, cpX2, cpY2, nextX, nextY);
      fillPath.cubicTo(cpX1, cpY1, cpX2, cpY2, nextX, nextY);
    }

    fillPath.lineTo(size.width, size.height);
    fillPath.close();

    // Draw shaded background under line
    final gradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        color.withValues(alpha: 0.3),
        color.withValues(alpha: 0.01),
      ],
    );
    paintFill.shader = gradient.createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawPath(fillPath, paintFill);

    // Draw line
    canvas.drawPath(path, paintLine);

    // Draw points
    final pointPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    final pointBorderPaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    for (int i = 0; i < values.length; i++) {
      double x = i * stepX;
      double y = size.height - ((values[i] - scaleMin) / scaleRange) * size.height;
      canvas.drawCircle(Offset(x, y), 5, pointPaint);
      canvas.drawCircle(Offset(x, y), 5, pointBorderPaint);
    }
  }

  @override
  bool shouldRepaint(covariant LineChartPainter oldDelegate) =>
      oldDelegate.values != values || oldDelegate.color != color;
}

class CustomBarChart extends StatelessWidget {
  final List<double> values;
  final List<String> labels;
  final String title;
  final String subtitle;
  final Color color;

  const CustomBarChart({
    super.key,
    required this.values,
    required this.labels,
    required this.title,
    required this.subtitle,
    this.color = AppTheme.slateMedium,
  });

  @override
  Widget build(BuildContext context) {
    final double maxVal = values.reduce((a, b) => a > b ? a : b);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                letterSpacing: 0.2,
                color: AppTheme.slateDark,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: const TextStyle(
                fontSize: 12,
                color: AppTheme.slateMedium,
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 160,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: List.generate(values.length, (index) {
                  final double val = values[index];
                  final String label = labels[index];
                  final double heightRatio = maxVal == 0 ? 0.0 : val / maxVal;

                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Text(
                            '₹${(val / 1000).toStringAsFixed(0)}k',
                            style: const TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.slateDark,
                            ),
                          ),
                          const SizedBox(height: 6),
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 500),
                            height: heightRatio * 110,
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: index == values.length - 1 ? 1.0 : 0.7),
                              borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(6),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            label,
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.slateLight,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
