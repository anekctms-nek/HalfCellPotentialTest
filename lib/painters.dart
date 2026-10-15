import 'dart:math';

import 'package:flutter/material.dart';

// ring chart: slices proportional to [values]
class DonutPainter extends CustomPainter {
  DonutPainter(this.values, this.colors);

  final List<int> values;
  final List<Color> colors;

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 26.0;
    final rect = Rect.fromLTWH(
      stroke / 2,
      stroke / 2,
      size.width - stroke,
      size.height - stroke,
    );
    final total = values.fold<int>(0, (a, b) => a + b);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke;

    if (total == 0) {
      canvas.drawArc(
        rect,
        0,
        2 * pi,
        false,
        paint..color = const Color(0xFFE6EAF5),
      );
      return;
    }

    var start = -pi / 2;
    for (var i = 0; i < values.length; i++) {
      if (values[i] == 0) continue;
      final sweep = 2 * pi * values[i] / total;
      canvas.drawArc(rect, start, sweep, false, paint..color = colors[i]);
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(DonutPainter old) =>
      old.values.toString() != values.toString();
}

// scale lines + numbers behind the grouped bars
class BarGridPainter extends CustomPainter {
  BarGridPainter(this.top);

  static const leftPad = 34.0;

  final int top;

  @override
  void paint(Canvas canvas, Size size) {
    final grid = Paint()
      ..color = const Color(0xFFE6EAF5)
      ..strokeWidth = 1;

    for (var k = 0; k <= 4; k++) {
      final y = size.height * k / 4;
      canvas.drawLine(
        Offset(leftPad - 4, y),
        Offset(size.width, y),
        k == 4 ? (Paint()..color = const Color(0xFF8F9BB3)) : grid,
      );

      final tp = TextPainter(
        text: TextSpan(
          text: '${top - top * k ~/ 4}',
          style: const TextStyle(fontSize: 11, color: Color(0xFF8F9BB3)),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(leftPad - 10 - tp.width, y - tp.height / 2));
    }
  }

  @override
  bool shouldRepaint(BarGridPainter old) => old.top != top;
}

// smooth multi-line chart with y-axis, dashed grid, the -0.20 / -0.35 limits
// and gaps where a time slot has no data
class SeriesLinePainter extends CustomPainter {
  SeriesLinePainter(
    this.lines,
    this.colors,
    this.labels, {
    this.invert = false,
    this.highlight = -1,
    this.dots,
  });

  static const leftPad = 52.0;
  static const bottomPad = 22.0;

  final List<List<double?>> lines;
  final List<Color> colors;
  final List<String> labels;
  final bool invert; // true: smallest value on top
  final int highlight; // index of the line to pick out (-1 = none)
  final List<List<bool>>? dots; // where to draw a dot (null = everywhere)

  void text(Canvas canvas, String s, Offset at, {bool center = false}) {
    final tp = TextPainter(
      text: TextSpan(
        text: s,
        style: const TextStyle(fontSize: 10, color: Color(0xFF8F9BB3)),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final dx = center ? at.dx - tp.width / 2 : at.dx - tp.width;
    tp.paint(canvas, Offset(dx, at.dy - tp.height / 2));
  }

  // value range of the y axis (the -0.20 / -0.35 limits are kept in view
  // when the data is near them)
  static (double, double) range(List<List<double?>> lines) {
    final data = [
      for (final l in lines)
        for (final v in l) ?v,
    ];
    var lo = data.isEmpty ? -0.5 : data.reduce(min);
    var hi = data.isEmpty ? 0.0 : data.reduce(max);

    for (final limit in [-0.20, -0.35]) {
      if (limit > lo - 0.12 && limit < hi + 0.12) {
        lo = min(lo, limit);
        hi = max(hi, limit);
      }
    }

    var span = hi - lo;
    if (span < 0.02) span = 0.02;
    return (lo - span * 0.12, hi + span * 0.12);
  }

  // pixel position of one point (used to place the hover areas)
  static Offset position(
    List<List<double?>> lines,
    Size size,
    bool invert,
    int slot,
    double v,
  ) {
    final (lo, hi) = range(lines);
    const padTop = 8.0;
    final plotW = size.width - leftPad;
    final plotH = size.height - padTop - bottomPad;
    final x = leftPad + plotW / lines.first.length * (slot + 0.5);
    final y = invert
        ? padTop + (v - lo) / (hi - lo) * plotH
        : padTop + plotH - (v - lo) / (hi - lo) * plotH;
    return Offset(x, y);
  }

  void dashed(Canvas canvas, double y, double x0, double x1, Paint p) {
    for (var x = x0; x < x1; x += 8) {
      canvas.drawLine(Offset(x, y), Offset(x + 4, y), p);
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    final data = [
      for (final l in lines)
        for (final v in l) ?v,
    ];
    if (data.isEmpty) return;

    final (lo, hi) = range(lines);

    final count = lines.first.length;
    const padTop = 8.0;
    final plotW = size.width - leftPad;
    final plotH = size.height - padTop - bottomPad;
    final step = plotW / count;

    double yOf(double v) => invert
        ? padTop + (v - lo) / (hi - lo) * plotH
        : padTop + plotH - (v - lo) / (hi - lo) * plotH;
    double xOf(int i) => leftPad + step * (i + 0.5);

    // grid + y labels
    final grid = Paint()
      ..color = const Color(0xFFE6EAF5)
      ..strokeWidth = 1;
    for (var k = 0; k <= 4; k++) {
      // inverted: the smallest value is at the top
      final v = invert ? lo + (hi - lo) * k / 4 : hi - (hi - lo) * k / 4;
      final y = yOf(v);
      dashed(canvas, y, leftPad, size.width, grid);
      text(canvas, v.toStringAsFixed(3), Offset(leftPad - 8, y));
    }

    // limits
    void limitLine(double v, Color c) {
      if (v < lo || v > hi) return;
      dashed(
        canvas,
        yOf(v),
        leftPad,
        size.width,
        Paint()
          ..color = c
          ..strokeWidth = 1.5,
      );
    }

    limitLine(-0.20, const Color(0xFFE0A100));
    limitLine(-0.35, const Color(0xFFE5484D));

    // x labels (about 6 of them)
    final every = (count / 6).ceil();
    for (var i = 0; i < labels.length; i += every) {
      text(
        canvas,
        labels[i],
        Offset(xOf(i), size.height - bottomPad / 2 + 2),
        center: true,
      );
    }

    final single = lines.length == 1;

    // smooth curve for every run of points without a gap, for every CH
    for (var n = 0; n < lines.length; n++) {
      final values = lines[n];
      // the line the mouse is on is picked out, the others fade
      final lit = highlight == n;
      final dim = highlight >= 0 && !lit;
      final color = dim ? colors[n].withValues(alpha: 0.10) : colors[n];
      final linePaint = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = lit ? 3.6 : (single ? 2.5 : 1.6)
        ..strokeCap = StrokeCap.round;

      var i = 0;
      while (i < values.length) {
        if (values[i] == null) {
          i++;
          continue;
        }
        var j = i;
        while (j + 1 < values.length && values[j + 1] != null) {
          j++;
        }

        final pts = [
          for (var k = i; k <= j; k++) Offset(xOf(k), yOf(values[k]!)),
        ];

        if (pts.length > 1) {
          final path = Path()..moveTo(pts.first.dx, pts.first.dy);
          for (var k = 0; k < pts.length - 1; k++) {
            final p0 = pts[k == 0 ? 0 : k - 1];
            final p1 = pts[k];
            final p2 = pts[k + 1];
            final p3 = pts[k + 2 < pts.length ? k + 2 : k + 1];
            path.cubicTo(
              p1.dx + (p2.dx - p0.dx) / 6,
              p1.dy + (p2.dy - p0.dy) / 6,
              p2.dx - (p3.dx - p1.dx) / 6,
              p2.dy - (p3.dy - p1.dy) / 6,
              p2.dx,
              p2.dy,
            );
          }

          if (single && !invert) {
            final area = Path.from(path)
              ..lineTo(pts.last.dx, padTop + plotH)
              ..lineTo(pts.first.dx, padTop + plotH)
              ..close();
            canvas.drawPath(
              area,
              Paint()
                ..shader = LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    color.withValues(alpha: 0.18),
                    color.withValues(alpha: 0.01),
                  ],
                ).createShader(Rect.fromLTWH(leftPad, padTop, plotW, plotH)),
            );
          }
          canvas.drawPath(path, linePaint);
        }

        for (var q = 0; q < pts.length; q++) {
          final p = pts[q];
          // dots only where the value dropped (when a mask is given)
          if (dots != null && !dots![n][i + q]) continue;
          if (single) canvas.drawCircle(p, 4, Paint()..color = Colors.white);
          canvas.drawCircle(
            p,
            single ? 2.8 : (lit ? 3.6 : 2.4),
            Paint()..color = color,
          );
        }

        i = j + 1;
      }
    }
  }

  @override
  bool shouldRepaint(SeriesLinePainter old) =>
      old.lines.toString() != lines.toString() ||
      old.labels.toString() != labels.toString() ||
      old.highlight != highlight;
}

// one or several lines of points. The smallest value is at the TOP.
// With one line the dots are colored by level (green / yellow / red) and the
// min and max are written; with several lines every line has its own color.
// The CH name is written at the end of every line.
class PointLabelPainter extends CustomPainter {
  PointLabelPainter(this.lines, this.colors, this.names, this.labels);

  static const leftPad = 52.0;
  static const rightPad = 64.0; // room for the CH name at the line end
  static const bottomPad = 24.0;
  static const topPad = 26.0;

  final List<List<double?>> lines;
  final List<Color> colors;
  final List<String> names;
  final List<String> labels;

  static Color levelColor(double v) => v > -0.20
      ? const Color(0xFF16C784)
      : (v >= -0.35 ? const Color(0xFFE0A100) : const Color(0xFFE5484D));

  // y range (the -0.20 / -0.35 limits stay in view when the data is near)
  static (double, double) range(List<List<double?>> lines) {
    final data = [
      for (final l in lines)
        for (final v in l) ?v,
    ];
    var lo = data.isEmpty ? -0.5 : data.reduce(min);
    var hi = data.isEmpty ? 0.0 : data.reduce(max);

    for (final limit in [-0.20, -0.35]) {
      if (limit > lo - 0.08 && limit < hi + 0.08) {
        lo = min(lo, limit);
        hi = max(hi, limit);
      }
    }

    var span = hi - lo;
    if (span < 0.02) span = 0.02;
    return (lo - span * 0.12, hi + span * 0.12);
  }

  // draw / hover a point only every [dotEvery] values, so the dots keep at
  // least about 18px between them
  static int dotEvery(int n, Size size) {
    if (n < 2) return 1;
    final step = (size.width - leftPad - rightPad) / (n - 1);
    return max(1, (18 / step).ceil());
  }

  // pixel position of a point (also used to place the hover spots)
  static Offset position(
    List<List<double?>> lines,
    Size size,
    int slot,
    double v,
  ) {
    final (lo, hi) = range(lines);
    final n = lines.first.length;
    final plotW = size.width - leftPad - rightPad;
    final plotH = size.height - topPad - bottomPad;
    final x = leftPad + (n > 1 ? plotW / (n - 1) * slot : plotW / 2);
    // smallest value on top
    final y = topPad + (v - lo) / (hi - lo) * plotH;
    return Offset(x, y);
  }

  void text(
    Canvas canvas,
    String s,
    Offset at, {
    bool center = false,
    bool left = false,
    bool bold = false,
    Color color = const Color(0xFF8F9BB3),
    double size = 10,
  }) {
    final tp = TextPainter(
      text: TextSpan(
        text: s,
        style: TextStyle(
          fontSize: size,
          color: color,
          fontWeight: bold ? FontWeight.w800 : FontWeight.w500,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    var dx = at.dx - tp.width; // default: text ends at the point
    if (center) dx = at.dx - tp.width / 2;
    if (left) dx = at.dx; // text starts at the point
    tp.paint(canvas, Offset(dx, at.dy - tp.height / 2));
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (lines.isEmpty || lines.first.isEmpty) return;

    final (lo, hi) = range(lines);
    final n = lines.first.length;
    final plotH = size.height - topPad - bottomPad;
    final right = size.width - rightPad + 8;

    double yOf(double v) => topPad + (v - lo) / (hi - lo) * plotH;
    Offset at(int slot, double v) => position(lines, size, slot, v);

    // grid + y labels (smallest value at the top)
    final grid = Paint()
      ..color = const Color(0xFFE6EAF5)
      ..strokeWidth = 1;
    for (var k = 0; k <= 4; k++) {
      final v = lo + (hi - lo) * k / 4;
      final y = yOf(v);
      for (var x = leftPad; x < right; x += 8) {
        canvas.drawLine(Offset(x, y), Offset(x + 4, y), grid);
      }
      text(canvas, v.toStringAsFixed(3), Offset(leftPad - 8, y));
    }

    // limits
    void limitLine(double v, Color c) {
      if (v < lo || v > hi) return;
      final y = yOf(v);
      final p = Paint()
        ..color = c
        ..strokeWidth = 1.5;
      for (var x = leftPad; x < right; x += 8) {
        canvas.drawLine(Offset(x, y), Offset(x + 4, y), p);
      }
    }

    limitLine(-0.20, const Color(0xFFE0A100));
    limitLine(-0.35, const Color(0xFFE5484D));

    // x labels (about 7 of them)
    final firstLine = lines.first;
    final xEvery = (n / 7).ceil().clamp(1, n);
    for (var i = 0; i < n; i += xEvery) {
      final base = firstLine.firstWhere((v) => v != null, orElse: () => 0)!;
      text(
        canvas,
        labels[i],
        Offset(at(i, base).dx, size.height - bottomPad / 2 + 2),
        center: true,
      );
    }

    final single = lines.length == 1;
    final every = dotEvery(n, size);

    for (var c = 0; c < lines.length; c++) {
      final values = lines[c];
      final color = colors[c];

      // thin line through the points that have a value
      final line = Path();
      var started = false;
      for (var i = 0; i < n; i++) {
        final v = values[i];
        if (v == null) continue;
        final p = at(i, v);
        if (!started) {
          line.moveTo(p.dx, p.dy);
          started = true;
        } else {
          line.lineTo(p.dx, p.dy);
        }
      }
      canvas.drawPath(
        line,
        Paint()
          ..color = single
              ? const Color(0xFF3F6BF0).withValues(alpha: 0.45)
              : color.withValues(alpha: 0.75)
          ..style = PaintingStyle.stroke
          ..strokeWidth = single ? 1.6 : 2,
      );

      // dots
      int? last;
      for (var i = 0; i < n; i++) {
        final v = values[i];
        if (v == null) continue;
        last = i;
        // dense data: a dot only every few points, so they do not touch
        // each other (no "centipede")
        if (i % every != 0) continue;
        final p = at(i, v);
        canvas.drawCircle(
          p,
          every > 1 ? 4.2 : 5.5,
          Paint()..color = Colors.white,
        );
        canvas.drawCircle(
          p,
          every > 1 ? 3 : 4,
          Paint()..color = single ? levelColor(v) : color,
        );
      }

      // min and max of a single line
      if (single) {
        final data = [
          for (var i = 0; i < n; i++)
            if (values[i] != null) i,
        ];
        if (data.isNotEmpty) {
          final iMin = data.reduce((a, b) => values[a]! <= values[b]! ? a : b);
          final iMax = data.reduce((a, b) => values[a]! >= values[b]! ? a : b);
          for (final i in {iMin, iMax}) {
            final p = at(i, values[i]!);
            text(
              canvas,
              values[i]!.toStringAsFixed(3),
              Offset(p.dx, i == iMin ? p.dy + 16 : p.dy - 15),
              center: true,
              bold: true,
              color: const Color(0xFF1B2559),
              size: 11.5,
            );
          }
        }
      }

      // CH name at the end of the line
      if (last != null) {
        final p = at(last, values[last]!);
        text(
          canvas,
          names[c],
          Offset(p.dx + 10, p.dy),
          left: true,
          bold: true,
          color: color,
          size: 12,
        );
      }
    }
  }

  @override
  bool shouldRepaint(PointLabelPainter old) =>
      old.lines.toString() != lines.toString() ||
      old.labels.toString() != labels.toString() ||
      old.names.toString() != names.toString();
}
