import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../models/car_state.dart';

class WaypointPlotSelection {
  const WaypointPlotSelection({
    required this.index,
    required this.plotX,
    required this.plotY,
    required this.original,
  });

  final int index;
  final double plotX;
  final double plotY;
  final Waypoint original;
}

class WaypointPlot extends StatefulWidget {
  const WaypointPlot({
    super.key,
    required this.waypoints,
    this.onPointSelected,
  });

  final List<Waypoint> waypoints;
  final ValueChanged<WaypointPlotSelection>? onPointSelected;

  @override
  State<WaypointPlot> createState() => _WaypointPlotState();
}

class _WaypointPlotState extends State<WaypointPlot> {
  static const double _minX = -3.0;
  static const double _maxX = 3.0;
  static const double _minY = 0.0;
  static const double _maxY = 3.0;

  int? _selectedIndex;

  @override
  void didUpdateWidget(covariant WaypointPlot oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!listEquals(oldWidget.waypoints, widget.waypoints)) {
      _selectedIndex = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        final points = _buildPoints(widget.waypoints);

        return GestureDetector(
          onTapDown: (details) {
            final selected = _findNearestPoint(
              details.localPosition,
              size,
              points,
            );
            setState(() {
              _selectedIndex = selected?.index;
            });
            if (selected != null) {
              widget.onPointSelected?.call(selected);
            }
          },
          child: CustomPaint(
            painter: _WaypointPlotPainter(
              points: points,
              selectedIndex: _selectedIndex,
              minX: _minX,
              maxX: _maxX,
              minY: _minY,
              maxY: _maxY,
            ),
            child: const SizedBox.expand(),
          ),
        );
      },
    );
  }

  List<WaypointPlotSelection> _buildPoints(List<Waypoint> waypoints) {
    final list = <WaypointPlotSelection>[];
    for (var i = 0; i < waypoints.length; i++) {
      final p = waypoints[i];
      list.add(
        WaypointPlotSelection(
          index: i,
          plotX: -p.y,
          plotY: p.x,
          original: p,
        ),
      );
    }
    return list;
  }

  WaypointPlotSelection? _findNearestPoint(
    Offset tap,
    Size size,
    List<WaypointPlotSelection> points,
  ) {
    if (points.isEmpty) {
      return null;
    }

    const threshold = 18.0;
    WaypointPlotSelection? best;
    var bestDistance = double.infinity;

    for (final p in points) {
      final offset = _toCanvasOffset(size, p.plotX, p.plotY);
      final distance = (offset - tap).distance;
      if (distance < bestDistance) {
        bestDistance = distance;
        best = p;
      }
    }

    if (bestDistance > threshold) {
      return null;
    }
    return best;
  }

  Offset _toCanvasOffset(Size size, double x, double y) {
    final px = ((x - _minX) / (_maxX - _minX)).clamp(0.0, 1.0) * size.width;
    final py = size.height -
        (((y - _minY) / (_maxY - _minY)).clamp(0.0, 1.0) * size.height);
    return Offset(px, py);
  }
}

class _WaypointPlotPainter extends CustomPainter {
  const _WaypointPlotPainter({
    required this.points,
    required this.selectedIndex,
    required this.minX,
    required this.maxX,
    required this.minY,
    required this.maxY,
  });

  final List<WaypointPlotSelection> points;
  final int? selectedIndex;
  final double minX;
  final double maxX;
  final double minY;
  final double maxY;

  @override
  void paint(Canvas canvas, Size size) {
    _drawBackground(canvas, size);
    _drawGrid(canvas, size);
    _drawAxes(canvas, size);
    _drawTrajectory(canvas, size);
    _drawTicks(canvas, size);
  }

  @override
  bool shouldRepaint(covariant _WaypointPlotPainter oldDelegate) {
    return oldDelegate.points != points || oldDelegate.selectedIndex != selectedIndex;
  }

  void _drawBackground(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final paint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: <Color>[Color(0xFFF8FAFC), Color(0xFFE9EEF3)],
      ).createShader(rect);
    canvas.drawRect(rect, paint);
  }

  void _drawGrid(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = const Color(0xFFD8E1E8)
      ..strokeWidth = 1;

    for (var x = -3; x <= 3; x++) {
      final px = _toOffset(size, x.toDouble(), 0).dx;
      canvas.drawLine(Offset(px, 0), Offset(px, size.height), gridPaint);
    }

    for (var y = 0; y <= 3; y++) {
      final py = _toOffset(size, 0, y.toDouble()).dy;
      canvas.drawLine(Offset(0, py), Offset(size.width, py), gridPaint);
    }
  }

  void _drawAxes(Canvas canvas, Size size) {
    final axisPaint = Paint()
      ..color = const Color(0xFF1F2F3A)
      ..strokeWidth = 1.6;

    final xAxisY = _toOffset(size, 0, 0).dy;
    final yAxisX = _toOffset(size, 0, 0).dx;

    canvas.drawLine(Offset(0, xAxisY), Offset(size.width, xAxisY), axisPaint);
    canvas.drawLine(Offset(yAxisX, 0), Offset(yAxisX, size.height), axisPaint);
  }

  void _drawTrajectory(Canvas canvas, Size size) {
    final linePaint = Paint()
      ..color = const Color(0xFF1B5E8A)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4;

    final normalPointPaint = Paint()..color = const Color(0xFF1B5E8A);
    final selectedPaint = Paint()..color = const Color(0xFFD94F2A);

    final path = Path();
    final origin = _toOffset(size, 0, 0);
    path.moveTo(origin.dx, origin.dy);

    for (final point in points) {
      final offset = _toOffset(size, point.plotX, point.plotY);
      path.lineTo(offset.dx, offset.dy);
    }

    canvas.drawPath(path, linePaint);

    canvas.drawCircle(origin, 4.2, Paint()..color = const Color(0xFF0F1E27));

    for (final point in points) {
      final offset = _toOffset(size, point.plotX, point.plotY);
      final isSelected = selectedIndex == point.index;
      canvas.drawCircle(offset, isSelected ? 6.0 : 4.0, isSelected ? selectedPaint : normalPointPaint);
    }
  }

  void _drawTicks(Canvas canvas, Size size) {
    const style = TextStyle(
      color: Color(0xFF415260),
      fontSize: 11,
      fontWeight: FontWeight.w600,
    );

    for (var x = -3; x <= 3; x++) {
      final offset = _toOffset(size, x.toDouble(), 0);
      _drawText(canvas, '$x', offset + const Offset(-8, 4), style);
    }

    for (var y = 0; y <= 3; y++) {
      final offset = _toOffset(size, 0, y.toDouble());
      _drawText(canvas, '$y', offset + const Offset(5, -8), style);
    }

    _drawText(
      canvas,
      'X = -waypoint.y',
      const Offset(10, 8),
      const TextStyle(fontSize: 12, color: Color(0xFF243845), fontWeight: FontWeight.w700),
    );
    _drawText(
      canvas,
      'Y = waypoint.x',
      const Offset(10, 24),
      const TextStyle(fontSize: 12, color: Color(0xFF243845), fontWeight: FontWeight.w700),
    );
  }

  Offset _toOffset(Size size, double x, double y) {
    final px = ((x - minX) / (maxX - minX)).clamp(0.0, 1.0) * size.width;
    final py = size.height - (((y - minY) / (maxY - minY)).clamp(0.0, 1.0) * size.height);
    return Offset(px, py);
  }

  void _drawText(Canvas canvas, String text, Offset position, TextStyle style) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: 260);
    painter.paint(canvas, position);
  }
}
