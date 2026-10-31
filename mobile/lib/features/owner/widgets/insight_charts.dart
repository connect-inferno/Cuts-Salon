import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../data/money.dart';
import '../../../theme.dart';
import '../../../widgets/ds.dart';

/// Chart building blocks for Reports' insight cards.
///
/// Colour rules (CLAUDE.md "Look" + the dataviz checks):
///  * one series = navy, always;
///  * several categories = [kChartCategorical] in this fixed order, never
///    cycled, with the rest folded into a grey "Other". The order was run
///    through a colour-blindness validator; it relies on the legend and
///    percentages every chart here prints, never colour alone;
///  * amber / red only where the figure is a status (a loss, money overdue).
const List<Color> kChartCategorical = [
  Color(0xFF2F6FED), // blue
  Color(0xFFE07B1F), // orange
  Color(0xFF1A9E70), // green
  Color(0xFF7C5CFA), // violet
  Color(0xFFE0A100), // gold
];
const Color kChartOther = Color(0xFFCBD5E1);
const Color kChartNavy = AppTheme.primaryBlue;
const Color kChartNavySoft = Color(0xFF9DB0C9);
const Color kChartGrid = Color(0xFFEEF1F5);

const _titleStyle = TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: AppTheme.slateDark);
const _subStyle = TextStyle(fontSize: 11.5, fontWeight: FontWeight.w500, color: AppTheme.slateLight);
const _labelStyle = TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: AppTheme.slateLight);
const _valueStyle = TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppTheme.slateDark);

/// The card every insight sits in: title, one-line explanation, an optional
/// headline figure on the right, then the chart.
class InsightCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final String? headline;
  final String? headlineCaption;
  final Color? headlineColor;
  /// Small grey pill under the title - e.g. "All branches" when the branch
  /// pill can't narrow this card.
  final String? scopeNote;
  final Widget child;

  const InsightCard({
    super.key,
    required this.title,
    required this.subtitle,
    this.headline,
    this.headlineCaption,
    this.headlineColor,
    this.scopeNote,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return DsCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: _titleStyle, maxLines: 1, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 2),
                    Text(subtitle, style: _subStyle),
                    if (scopeNote != null) ...[
                      const SizedBox(height: 6),
                      DsPill(scopeNote!),
                    ],
                  ],
                ),
              ),
              if (headline != null) ...[
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      headline!,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: headlineColor ?? AppTheme.slateDark,
                        letterSpacing: -0.5,
                      ),
                    ),
                    if (headlineCaption != null)
                      Text(headlineCaption!,
                          style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: AppTheme.textMuted)),
                  ],
                ),
              ],
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

/// An honest "nothing to chart yet" line, in place of a chart.
class InsightEmpty extends StatelessWidget {
  final String text;
  const InsightEmpty(this.text, {super.key});

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 18),
        decoration: BoxDecoration(color: AppTheme.bgSurface, borderRadius: BorderRadius.circular(12)),
        child: Text(text, style: _subStyle, textAlign: TextAlign.center),
      );
}

/// A row of 2-3 small figures under a chart.
class InsightFigures extends StatelessWidget {
  final List<(String label, String value, String? caption)> figures;
  const InsightFigures(this.figures, {super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < figures.length; i++) ...[
          if (i > 0) Container(width: 1, height: 34, color: AppTheme.borderSubtle, margin: const EdgeInsets.symmetric(horizontal: 12)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(figures[i].$1, style: _labelStyle, maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 3),
                Text(figures[i].$2,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppTheme.slateDark),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                if (figures[i].$3 != null)
                  Text(figures[i].$3!, style: const TextStyle(fontSize: 10.5, color: AppTheme.textMuted), maxLines: 2),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Donut
// ---------------------------------------------------------------------------

class DonutSlice {
  final String label;
  final double value;
  final Color color;
  /// What the legend prints beside the percentage; defaults to the value
  /// as rupees.
  final String? valueText;
  const DonutSlice(this.label, this.value, this.color, {this.valueText});
}

/// Builds slices in the fixed categorical order, folding everything past
/// [maxSlices] into a grey "Other".
List<DonutSlice> categoricalSlices(
  List<(String label, double value)> entries, {
  int maxSlices = 5,
  String Function(double)? format,
}) {
  final sorted = entries.where((e) => e.$2 > 0).toList()..sort((a, b) => b.$2.compareTo(a.$2));
  final keep = sorted.length > maxSlices ? sorted.take(maxSlices - 1).toList() : sorted;
  final rest = sorted.skip(keep.length).fold<double>(0, (s, e) => s + e.$2);
  return [
    for (var i = 0; i < keep.length; i++)
      DonutSlice(keep[i].$1, keep[i].$2, kChartCategorical[i], valueText: format?.call(keep[i].$2)),
    if (rest > 0) DonutSlice('Other', rest, kChartOther, valueText: format?.call(rest)),
  ];
}

/// Donut with a centre figure and a legend that carries every slice's value
/// and share - so nothing depends on telling colours apart. Side by side on
/// wide cards, stacked on phones.
class DonutChart extends StatelessWidget {
  final List<DonutSlice> slices;
  final String centerValue;
  final String centerCaption;
  final double size;

  const DonutChart({
    super.key,
    required this.slices,
    required this.centerValue,
    required this.centerCaption,
    this.size = 132,
  });

  @override
  Widget build(BuildContext context) {
    final total = slices.fold<double>(0, (s, x) => s + x.value);
    final donut = SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(size: Size.square(size), painter: _DonutPainter(slices, total)),
          Padding(
            padding: EdgeInsets.all(size * 0.2),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                FittedBox(
                  child: Text(centerValue,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppTheme.slateDark, letterSpacing: -0.4)),
                ),
                Text(centerCaption, style: const TextStyle(fontSize: 10, color: AppTheme.slateLight), textAlign: TextAlign.center, maxLines: 2),
              ],
            ),
          ),
        ],
      ),
    );
    final legend = Column(
      children: [
        for (final s in slices)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                Container(width: 10, height: 10, decoration: BoxDecoration(color: s.color, borderRadius: BorderRadius.circular(3))),
                const SizedBox(width: 8),
                Expanded(child: Text(s.label, style: const TextStyle(fontSize: 12.5, color: AppTheme.slateMedium), maxLines: 1, overflow: TextOverflow.ellipsis)),
                const SizedBox(width: 8),
                Text(s.valueText ?? formatInr(s.value), style: _valueStyle),
                SizedBox(
                  width: 44,
                  child: Text(
                    total <= 0 ? '0%' : '${(s.value / total * 100).round()}%',
                    textAlign: TextAlign.right,
                    style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: AppTheme.textMuted),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
    return LayoutBuilder(builder: (context, c) {
      if (c.maxWidth < 360) {
        return Column(children: [donut, const SizedBox(height: 14), legend]);
      }
      return Row(children: [donut, const SizedBox(width: 20), Expanded(child: legend)]);
    });
  }
}

class _DonutPainter extends CustomPainter {
  final List<DonutSlice> slices;
  final double total;
  _DonutPainter(this.slices, this.total);

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 18.0;
    final rect = Offset.zero & size;
    final arcRect = rect.deflate(stroke / 2);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.butt;
    if (total <= 0) {
      canvas.drawArc(arcRect, 0, math.pi * 2, false, paint..color = kChartGrid);
      return;
    }
    // A 2px surface gap between slices, as an angle at the ring's radius.
    final gap = slices.where((s) => s.value > 0).length > 1 ? 2.5 / (arcRect.width / 2) : 0.0;
    var start = -math.pi / 2;
    for (final s in slices) {
      if (s.value <= 0) continue;
      final sweep = s.value / total * math.pi * 2;
      canvas.drawArc(arcRect, start + gap / 2, math.max(0.001, sweep - gap), false, paint..color = s.color);
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(_DonutPainter old) => old.slices != slices || old.total != total;
}

// ---------------------------------------------------------------------------
// Column chart (months / days), optionally two stacked series
// ---------------------------------------------------------------------------

class ColumnSeries {
  final String label;
  final Color color;
  final List<double> values;
  const ColumnSeries(this.label, this.color, this.values);
}

/// Vertical bars over time. Tap (or hover) a bar for its exact figures; the
/// latest bar starts selected. Negative values hang below a zero line and are
/// drawn in [negativeColor] (a loss is a status).
class ColumnChart extends StatefulWidget {
  final List<String> labels;
  /// One series, or two stacked (bottom first). A third neutral series can
  /// stand for "not split" days.
  final List<ColumnSeries> series;
  final double height;
  final String Function(double) format;
  final Color negativeColor;
  /// Text for the selected bar's tooltip line; defaults to each series'
  /// value and the total.
  final String Function(int index)? describe;
  /// Show only every n-th x label (30 days don't fit).
  final int labelEvery;
  /// Told which bar is selected (tap / hover), for a card that shows more
  /// detail for that period.
  final ValueChanged<int>? onSelect;

  const ColumnChart({
    super.key,
    required this.labels,
    required this.series,
    this.height = 150,
    this.format = formatInrCompact,
    this.negativeColor = AppTheme.accentRed,
    this.describe,
    this.labelEvery = 1,
    this.onSelect,
  });

  @override
  State<ColumnChart> createState() => _ColumnChartState();
}

class _ColumnChartState extends State<ColumnChart> {
  int? _selected;

  double _total(int i) => widget.series.fold<double>(0, (s, x) => s + (i < x.values.length ? x.values[i] : 0));

  @override
  Widget build(BuildContext context) {
    final n = widget.labels.length;
    if (n == 0) return const SizedBox.shrink();
    final selected = (_selected ?? n - 1).clamp(0, n - 1);

    final totals = [for (var i = 0; i < n; i++) _total(i)];
    final maxV = totals.fold<double>(0, math.max);
    final minV = totals.fold<double>(0, math.min);
    final top = _niceCeil(maxV);
    final bottom = minV < 0 ? -_niceCeil(-minV) : 0.0;

    String describe(int i) {
      if (widget.describe != null) return widget.describe!(i);
      if (widget.series.length == 1) return widget.format(totals[i]);
      final parts = [
        for (final s in widget.series)
          if (s.values[i] != 0) '${s.label} ${widget.format(s.values[i])}',
      ];
      return '${parts.join(' · ')}${parts.length > 1 ? '  =  ${widget.format(totals[i])}' : ''}';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // The selected bar's figures, in one fixed place above the plot
        // rather than a floating tooltip that can cover neighbouring bars.
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(color: AppTheme.bgSurface, borderRadius: BorderRadius.circular(10)),
          child: Text.rich(
            TextSpan(children: [
              TextSpan(text: '${widget.labels[selected]}   ', style: const TextStyle(fontWeight: FontWeight.w700, color: AppTheme.slateDark)),
              TextSpan(text: describe(selected), style: const TextStyle(color: AppTheme.slateMedium)),
            ]),
            style: const TextStyle(fontSize: 12),
            maxLines: 2,
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: widget.height,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Y ticks: top, zero (and bottom when there are losses).
              SizedBox(
                width: 40,
                child: CustomPaint(painter: _YTicksPainter(top, bottom, widget.format)),
              ),
              Expanded(
                child: LayoutBuilder(builder: (context, c) {
                  void pick(Offset p) {
                    final i = (p.dx / c.maxWidth * n).floor().clamp(0, n - 1);
                    if (i != _selected) {
                      setState(() => _selected = i);
                      widget.onSelect?.call(i);
                    }
                  }

                  return MouseRegion(
                    onHover: (e) => pick(e.localPosition),
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTapDown: (d) => pick(d.localPosition),
                      onHorizontalDragUpdate: (d) => pick(d.localPosition),
                      child: CustomPaint(
                        size: Size(c.maxWidth, c.maxHeight),
                        painter: _ColumnPainter(
                          series: widget.series,
                          count: n,
                          top: top,
                          bottom: bottom,
                          selected: selected,
                          negativeColor: widget.negativeColor,
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        // Labels centred under their bar but free to be wider than it, so
        // "28 Sep" under a 30-day chart isn't cut to "2".
        Padding(
          padding: const EdgeInsets.only(left: 40),
          child: LayoutBuilder(builder: (context, c) {
            final slot = c.maxWidth / n;
            const w = 56.0;
            return SizedBox(
              height: 16,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  for (var i = 0; i < n; i++)
                    if (i % widget.labelEvery == 0 || i == n - 1 || i == selected)
                      if (!(i != n - 1 && i != selected && (n - 1 - i) < widget.labelEvery && widget.labelEvery > 1))
                        Positioned(
                          left: (slot * (i + 0.5) - w / 2).clamp(-8.0, c.maxWidth - w + 8),
                          width: w,
                          child: Text(
                            widget.labels[i],
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: i == selected ? FontWeight.w700 : FontWeight.w500,
                              color: i == selected ? AppTheme.slateDark : AppTheme.textMuted,
                            ),
                          ),
                        ),
                ],
              ),
            );
          }),
        ),
        if (widget.series.length > 1) ...[
          const SizedBox(height: 10),
          Wrap(
            spacing: 14,
            runSpacing: 6,
            children: [
              for (final s in widget.series)
                Row(mainAxisSize: MainAxisSize.min, children: [
                  Container(width: 10, height: 10, decoration: BoxDecoration(color: s.color, borderRadius: BorderRadius.circular(3))),
                  const SizedBox(width: 6),
                  Text(s.label, style: const TextStyle(fontSize: 11.5, color: AppTheme.slateMedium)),
                ]),
            ],
          ),
        ],
      ],
    );
  }

}

double _niceCeil(double v) {
  if (v <= 0) return 1;
  final exp = math.pow(10, (math.log(v) / math.ln10).floor()).toDouble();
  // Steps whose half is still a round number (the middle grid line).
  for (final m in [1, 2, 4, 5, 6, 8, 10]) {
    if (m * exp >= v) return m * exp;
  }
  return 10 * exp;
}

class _YTicksPainter extends CustomPainter {
  final double top;
  final double bottom;
  final String Function(double) format;
  _YTicksPainter(this.top, this.bottom, this.format);

  @override
  void paint(Canvas canvas, Size size) {
    final range = top - bottom;
    void tick(double v) {
      final y = size.height * (top - v) / range;
      final tp = TextPainter(
        text: TextSpan(text: format(v), style: const TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 9.5, color: AppTheme.textMuted)),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: size.width - 4);
      tp.paint(canvas, Offset(size.width - tp.width - 6, (y - tp.height / 2).clamp(0, size.height - tp.height)));
    }

    tick(top);
    tick(top / 2);
    if (bottom < 0) tick(bottom);
    tick(0);
  }

  @override
  bool shouldRepaint(_YTicksPainter old) => old.top != top || old.bottom != bottom;
}

class _ColumnPainter extends CustomPainter {
  final List<ColumnSeries> series;
  final int count;
  final double top;
  final double bottom;
  final int selected;
  final Color negativeColor;

  _ColumnPainter({
    required this.series,
    required this.count,
    required this.top,
    required this.bottom,
    required this.selected,
    required this.negativeColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final range = top - bottom;
    double yOf(double v) => size.height * (top - v) / range;
    final grid = Paint()
      ..color = kChartGrid
      ..strokeWidth = 1;
    for (final v in [top, top / 2, if (bottom < 0) bottom]) {
      canvas.drawLine(Offset(0, yOf(v)), Offset(size.width, yOf(v)), grid);
    }

    final slot = size.width / count;
    final barW = math.min(28.0, slot * 0.62);
    final selectedBg = Paint()..color = AppTheme.primaryLight;
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(slot * selected + (slot - barW) / 2 - 4, 0, barW + 8, size.height), const Radius.circular(6)),
      selectedBg,
    );

    for (var i = 0; i < count; i++) {
      final x = slot * i + (slot - barW) / 2;
      var pos = 0.0; // running stack above zero
      var neg = 0.0;
      final drawn = <(double from, double to, Color color)>[];
      for (final s in series) {
        final v = i < s.values.length ? s.values[i] : 0.0;
        if (v == 0) continue;
        if (v > 0) {
          drawn.add((pos, pos + v, s.color));
          pos += v;
        } else {
          drawn.add((neg, neg + v, negativeColor));
          neg += v;
        }
      }
      for (var k = 0; k < drawn.length; k++) {
        final (from, to, color) = drawn[k];
        final yA = yOf(from), yB = yOf(to);
        final up = to > from;
        // Is this the outermost segment in its direction? It gets the
        // rounded data end; inner joins are square with a 2px gap.
        final outer = !drawn.skip(k + 1).any((d) => (d.$2 > d.$1) == up);
        var rect = Rect.fromLTRB(x, math.min(yA, yB), x + barW, math.max(yA, yB));
        if (k > 0 && rect.height > 3) rect = up ? rect.copyWith(bottom: rect.bottom - 2) : rect.copyWith(top: rect.top + 2);
        final r = const Radius.circular(4);
        final rr = up
            ? RRect.fromRectAndCorners(rect, topLeft: outer ? r : Radius.zero, topRight: outer ? r : Radius.zero)
            : RRect.fromRectAndCorners(rect, bottomLeft: outer ? r : Radius.zero, bottomRight: outer ? r : Radius.zero);
        canvas.drawRRect(rr, Paint()..color = color);
      }
    }
    canvas.drawLine(Offset(0, yOf(0)), Offset(size.width, yOf(0)), Paint()
      ..color = AppTheme.borderStrong
      ..strokeWidth = 1);
  }

  @override
  bool shouldRepaint(_ColumnPainter old) => true;
}

extension on Rect {
  Rect copyWith({double? top, double? bottom}) => Rect.fromLTRB(left, top ?? this.top, right, bottom ?? this.bottom);
}

// ---------------------------------------------------------------------------
// Horizontal bars (ranked lists)
// ---------------------------------------------------------------------------

class HBarItem {
  final String label;
  final double value;
  final String valueText;
  final String? caption;
  final Color color;
  const HBarItem(this.label, this.value, this.valueText, {this.caption, this.color = kChartNavy});
}

/// A ranked list where each row's bar is scaled to the largest row.
class HBarList extends StatelessWidget {
  final List<HBarItem> items;
  const HBarList(this.items, {super.key});

  @override
  Widget build(BuildContext context) {
    final maxV = items.fold<double>(0, (m, i) => math.max(m, i.value));
    return Column(
      children: [
        for (var k = 0; k < items.length; k++) ...[
          if (k > 0) const SizedBox(height: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(items[k].label,
                        style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppTheme.slateDark),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                  ),
                  Text(items[k].valueText, style: _valueStyle),
                ],
              ),
              const SizedBox(height: 5),
              LayoutBuilder(builder: (context, c) {
                final f = maxV <= 0 ? 0.0 : (items[k].value / maxV).clamp(0.0, 1.0);
                return Stack(children: [
                  Container(height: 8, decoration: BoxDecoration(color: kChartGrid, borderRadius: BorderRadius.circular(4))),
                  Container(
                    height: 8,
                    width: math.max(f > 0 ? 4 : 0, c.maxWidth * f),
                    decoration: BoxDecoration(color: items[k].color, borderRadius: BorderRadius.circular(4)),
                  ),
                ]);
              }),
              if (items[k].caption != null) ...[
                const SizedBox(height: 4),
                Text(items[k].caption!, style: const TextStyle(fontSize: 11, color: AppTheme.slateLight)),
              ],
            ],
          ),
        ],
      ],
    );
  }
}

/// One proportion as a labelled bar ("WhatsApp OK - 62%").
class ShareBar extends StatelessWidget {
  final String label;
  final int part;
  final int whole;
  final String? hint;
  const ShareBar({super.key, required this.label, required this.part, required this.whole, this.hint});

  @override
  Widget build(BuildContext context) {
    final f = whole == 0 ? 0.0 : part / whole;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Expanded(child: Text(label, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppTheme.slateDark))),
          Text('${(f * 100).round()}%', style: _valueStyle),
          Text('  $part of $whole', style: const TextStyle(fontSize: 11, color: AppTheme.textMuted)),
        ]),
        const SizedBox(height: 5),
        DsProgressBar(value: f),
        if (hint != null) ...[
          const SizedBox(height: 4),
          Text(hint!, style: const TextStyle(fontSize: 11, color: AppTheme.slateLight)),
        ],
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Busy-hours heatmap
// ---------------------------------------------------------------------------

/// Weekday x hour grid of bill counts, in one hue (navy) from light to dark.
/// Tap a cell for its count; the busiest slot is named underneath.
class BusyHoursHeatmap extends StatefulWidget {
  /// 'weekday_HH' (1 = Monday) -> bills.
  final Map<String, double> slots;
  const BusyHoursHeatmap({super.key, required this.slots});

  @override
  State<BusyHoursHeatmap> createState() => _BusyHoursHeatmapState();
}

const _kDays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

String hourLabel(int h) {
  final h12 = h % 12 == 0 ? 12 : h % 12;
  return '$h12${h < 12 ? 'am' : 'pm'}';
}

class _BusyHoursHeatmapState extends State<BusyHoursHeatmap> {
  String? _picked;

  @override
  Widget build(BuildContext context) {
    final counts = <(int, int), double>{};
    var lo = 24, hi = -1;
    widget.slots.forEach((k, v) {
      final parts = k.split('_');
      if (parts.length != 2) return;
      final d = int.tryParse(parts[0]), h = int.tryParse(parts[1]);
      if (d == null || h == null || v <= 0) return;
      counts[(d, h)] = v;
      lo = math.min(lo, h);
      hi = math.max(hi, h);
    });
    if (counts.isEmpty) {
      return const InsightEmpty('Busy hours appear here once a few bills have been raised with this version of the app.');
    }
    // Show the salon's working day: at least 10am-8pm, widened to fit.
    lo = math.min(lo, 10);
    hi = math.max(hi, 19);
    final hours = [for (var h = lo; h <= hi; h++) h];
    final maxC = counts.values.fold<double>(0, math.max);
    final busiest = counts.entries.reduce((a, b) => a.value >= b.value ? a : b);

    Color cellColor(double v) {
      if (v <= 0) return AppTheme.bgSurface;
      final t = (v / maxC).clamp(0.0, 1.0);
      return Color.lerp(const Color(0xFFD6DFEB), kChartNavy, t)!;
    }

    String slotText((int, int) key) {
      final v = counts[key] ?? 0;
      return '${_kDays[key.$1 - 1]} ${hourLabel(key.$2)}-${hourLabel(key.$2 + 1)} · ${v.round()} bill${v.round() == 1 ? '' : 's'}';
    }

    final picked = _picked == null
        ? null
        : () {
            final p = _picked!.split('_');
            return (int.parse(p[0]), int.parse(p[1]));
          }();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(color: AppTheme.bgSurface, borderRadius: BorderRadius.circular(10)),
          child: Text(
            picked != null ? slotText(picked) : 'Busiest: ${slotText(busiest.key)}',
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.slateDark),
          ),
        ),
        const SizedBox(height: 10),
        for (var d = 1; d <= 7; d++)
          Padding(
            padding: const EdgeInsets.only(bottom: 3),
            child: Row(
              children: [
                SizedBox(width: 32, child: Text(_kDays[d - 1], style: _labelStyle)),
                for (final h in hours)
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _picked = '${d}_$h'),
                      child: MouseRegion(
                        onEnter: (_) => setState(() => _picked = '${d}_$h'),
                        child: Container(
                          height: 20,
                          margin: const EdgeInsets.symmetric(horizontal: 1.5),
                          decoration: BoxDecoration(
                            color: cellColor(counts[(d, h)] ?? 0),
                            borderRadius: BorderRadius.circular(4),
                            border: _picked == '${d}_$h' ? Border.all(color: AppTheme.accentAmber, width: 2) : null,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        const SizedBox(height: 4),
        Row(
          children: [
            const SizedBox(width: 32),
            for (final h in hours)
              Expanded(
                child: Text(
                  (h - lo) % 3 == 0 ? hourLabel(h) : '',
                  maxLines: 1,
                  overflow: TextOverflow.visible,
                  softWrap: false,
                  style: const TextStyle(fontSize: 9.5, color: AppTheme.textMuted),
                ),
              ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            const Text('Quiet', style: TextStyle(fontSize: 10.5, color: AppTheme.textMuted)),
            const SizedBox(width: 6),
            for (final t in [0.15, 0.4, 0.65, 0.9])
              Container(
                width: 16,
                height: 10,
                margin: const EdgeInsets.symmetric(horizontal: 1.5),
                decoration: BoxDecoration(color: cellColor(t * maxC), borderRadius: BorderRadius.circular(3)),
              ),
            const SizedBox(width: 6),
            const Text('Busy', style: TextStyle(fontSize: 10.5, color: AppTheme.textMuted)),
          ],
        ),
      ],
    );
  }
}
