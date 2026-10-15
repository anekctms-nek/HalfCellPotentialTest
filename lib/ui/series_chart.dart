// Line chart of the latest-data card
part of '../main.dart';

// ignore_for_file: invalid_use_of_protected_member, unused_element

extension _SeriesChart on _Ads1115PageState {
  String seriesKey() => '${currentDevice.id}|$seriesRange';

  Future<void> loadSeries() async {
    final d = currentDevice;
    final key = seriesKey();
    final spec = seriesSpec(seriesRange);
    final now = DateTime.now().toUtc();
    final times = [
      for (var k = 0; k < spec.points; k++)
        now.subtract(spec.span * (spec.points - 1 - k)),
    ];

    setState(() => seriesLoading = true);

    final out = <({DateTime t, Map<String, dynamic>? row})>[];

    try {
      final rows = rowsFor(d);

      if (d.mock) {
        // simulated devices have no history: make up a steady drift + noise
        if (rows.isNotEmpty) {
          final latest = rows.first;
          for (var k = 0; k < times.length; k++) {
            final daysAgo = now.difference(times[k]).inSeconds / 86400;
            final row = <String, dynamic>{
              'id': '-',
              'sensor': d.id,
              'created_at': times[k].toIso8601String(),
            };
            for (final i in channelsIn([latest])) {
              row['ch$i'] = mockPastValue(
                d,
                i,
                getValue(latest['ch$i']),
                daysAgo,
              );
            }
            out.add((t: times[k], row: row));
          }
        }
      } else {
        final results = await Future.wait([
          for (final t in times)
            supabase
                .from('ads1115_data')
                .select()
                .eq('sensor', d.id)
                .lte('created_at', t.toIso8601String())
                .gte('created_at', t.subtract(spec.span).toIso8601String())
                .order('created_at', ascending: false)
                .limit(1),
        ]);

        for (var k = 0; k < times.length; k++) {
          out.add((
            t: times[k],
            row: results[k].isEmpty
                ? null
                : Map<String, dynamic>.from(results[k].first),
          ));
        }
      }
    } catch (e) {
      debugPrint('SERIES ERROR = $e');
    }

    if (!mounted) return;

    setState(() {
      seriesCache[key] = out;
      seriesLoading = false;
    });
  }

  // tick-box dropdown shared by the data page and the history page:
  // "เลือกทั้งหมด" and "ล้างตัวเลือก" on top, then one tick box per CH
  Widget chTickMenu({
    required List<int> channels,
    required Set<int> selected,
    required ValueChanged<Set<int>> onChanged,
    required String label,
    IconData icon = Icons.checklist_rounded,
  }) {
    if (channels.isEmpty) return const SizedBox.shrink();

    return MenuAnchor(
      style: const MenuStyle(
        backgroundColor: WidgetStatePropertyAll(Colors.white),
        maximumSize: WidgetStatePropertyAll(Size(300, 420)),
      ),
      menuChildren: [
        SizedBox(
          width: 250,
          child: Row(
            children: [
              TextButton(
                onPressed: () => onChanged({...channels}),
                child: const Text('เลือกทั้งหมด'),
              ),
              const Spacer(),
              TextButton(
                onPressed: () => onChanged({}),
                child: const Text('ล้างตัวเลือก'),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        for (final i in channels)
          CheckboxMenuButton(
            closeOnActivate: false,
            value: selected.contains(i),
            onChanged: (on) => onChanged(
              on == true ? {...selected, i} : ({...selected}..remove(i)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.circle, size: 10, color: chColor(i)),
                const SizedBox(width: 8),
                Text(chLabel(currentDevice.id, i)),
              ],
            ),
          ),
      ],
      builder: (context, controller, _) => OutlinedButton.icon(
        onPressed: () =>
            controller.isOpen ? controller.close() : controller.open(),
        icon: Icon(icon, size: 18),
        label: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('$label (${selected.length}/${channels.length})'),
            const Icon(Icons.arrow_drop_down_rounded, size: 22),
          ],
        ),
        style: OutlinedButton.styleFrom(
          foregroundColor: navyDark,
          backgroundColor: tileColor,
          side: BorderSide.none,
          minimumSize: const Size(0, 40),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),
    );
  }

  // data page: the CH that are NOT ticked are hidden from the chart
  Widget chPicker(List<int> channels) => chTickMenu(
    channels: channels,
    selected: {
      for (final i in channels)
        if (!hiddenCh.contains(i)) i,
    },
    label: 'เลือก CH',
    onChanged: (s) => setState(() {
      hiddenCh
        ..clear()
        ..addAll(channels.where((i) => !s.contains(i)));
    }),
  );

  // a different color for every CH
  Color chColor(int i) => HSLColor.fromAHSL(
    1,
    ((i - 1) * 47 % 360).toDouble(),
    0.65,
    0.48,
  ).toColor();

  // the chart of the "latest data" card: ALL CH of the device, one line each
  Widget compareSection(Map<String, dynamic> latest) {
    final channels = channelsOf(currentDevice, [latest]);
    if (channels.isEmpty) return const SizedBox.shrink();
    final shown = [
      for (final i in channels)
        if (!hiddenCh.contains(i)) i,
    ]; // the CH ticked in the dropdown

    final points = seriesCache[seriesKey()];

    String two(int n) => n.toString().padLeft(2, '0');
    String label(DateTime t) {
      final a = t.add(const Duration(hours: 7));
      return seriesRange == 'day'
          ? '${two(a.hour)}:00'
          : '${two(a.day)}/${two(a.month)}';
    }

    String full(DateTime t) {
      final a = t.add(const Duration(hours: 7));
      return '${two(a.day)}/${two(a.month)}/${a.year} '
          '${two(a.hour)}:${two(a.minute)}';
    }

    // one list of values per CH
    // every line is continuous; a dot is drawn only where the value got
    // smaller than in the slot before (a "drop")
    final lines = <List<double?>>[
      if (points != null)
        for (final ch in shown)
          [
            for (final p in points)
              p.row?['ch$ch'] == null ? null : getValue(p.row!['ch$ch']),
          ],
    ];
    final drops = <List<bool>>[
      for (final l in lines)
        [
          for (var k = 0; k < l.length; k++)
            k > 0 && l[k] != null && l[k - 1] != null && l[k]! < l[k - 1]!,
        ],
    ];

    Widget chart() {
      if (shown.isEmpty) {
        return const SizedBox(
          height: 120,
          child: Center(
            child: Text(
              'ยังไม่ได้เลือก CH ที่ต้องการแสดง',
              style: TextStyle(color: mutedText),
            ),
          ),
        );
      }

      if (points == null) {
        return const SizedBox(
          height: 260,
          child: Center(
            child: Text('กำลังโหลด...', style: TextStyle(color: mutedText)),
          ),
        );
      }

      if (lines.every((l) => l.every((v) => v == null))) {
        return const SizedBox(
          height: 260,
          child: Center(
            child: Text(
              'ไม่มีข้อมูลในช่วงเวลานี้',
              style: TextStyle(color: mutedText),
            ),
          ),
        );
      }

      // the chart fills the card (taller with more CH); no scrolling inside
      final chartH = (420 + (shown.length - 6).clamp(0, 40) * 28).toDouble();

      return SizedBox(
        height: chartH,
        child: Stack(
          children: [
            Positioned.fill(
              child: CustomPaint(
                painter: SeriesLinePainter(
                  lines,
                  [for (final ch in shown) chColor(ch)],
                  [for (final p in points) label(p.t)],
                  invert: true,
                  highlight: shown.indexOf(hoverCh ?? -1),
                  dots: drops,
                ),
              ),
            ),
            // invisible hover spots on the points where the value dropped:
            // pointing at one shows ONLY that point and picks out its line
            Positioned.fill(
              child: LayoutBuilder(
                builder: (context, bc) {
                  final size = Size(bc.maxWidth, bc.maxHeight);
                  // the CH whose line passes within a few pixels of [p]
                  int? lineAt(Offset p) {
                    double dist(Offset a, Offset b) {
                      final ab = b - a;
                      final len2 = ab.dx * ab.dx + ab.dy * ab.dy;
                      if (len2 == 0) return (p - a).distance;
                      final t =
                          (((p - a).dx * ab.dx + (p - a).dy * ab.dy) / len2)
                              .clamp(0.0, 1.0);
                      return (p - (a + ab * t)).distance;
                    }

                    int? best;
                    var bestD = 12.0;
                    for (var c = 0; c < shown.length; c++) {
                      Offset? prev;
                      for (var k = 0; k < points.length; k++) {
                        final v = lines[c][k];
                        if (v == null) {
                          prev = null;
                          continue;
                        }
                        final cur = SeriesLinePainter.position(
                          lines,
                          size,
                          true,
                          k,
                          v,
                        );
                        final d = prev == null
                            ? (p - cur).distance
                            : dist(prev, cur);
                        if (d < bestD) {
                          bestD = d;
                          best = shown[c];
                        }
                        prev = cur;
                      }
                    }
                    return best;
                  }

                  return Stack(
                    children: [
                      // empty chart space: a click picks the line under it,
                      // or clears the highlight when there is no line there
                      Positioned.fill(
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTapUp: (d) =>
                              setState(() => hoverCh = lineAt(d.localPosition)),
                        ),
                      ),
                      for (var c = 0; c < shown.length; c++)
                        for (var k = 0; k < points.length; k++)
                          if (drops[c][k])
                            Positioned(
                              left:
                                  SeriesLinePainter.position(
                                    lines,
                                    size,
                                    true,
                                    k,
                                    lines[c][k]!,
                                  ).dx -
                                  9,
                              top:
                                  SeriesLinePainter.position(
                                    lines,
                                    size,
                                    true,
                                    k,
                                    lines[c][k]!,
                                  ).dy -
                                  9,
                              width: 18,
                              height: 18,
                              child: Tooltip(
                                waitDuration: Duration.zero,
                                message:
                                    '${chLabel(currentDevice.id, shown[c])}\n'
                                    '${lines[c][k]!.toStringAsFixed(3)} V\n'
                                    '${full(points[k].t)}',
                                child: MouseRegion(
                                  cursor: SystemMouseCursors.click,
                                  // a click keeps this CH's line highlighted
                                  child: GestureDetector(
                                    behavior: HitTestBehavior.opaque,
                                    onTap: () =>
                                        setState(() => hoverCh = shown[c]),
                                    child: Container(color: Colors.transparent),
                                  ),
                                ),
                              ),
                            ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 6,
            children: [
              for (final ch in shown)
                // click a name: its line stays highlighted (click again or
                // click empty chart space to clear)
                MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: GestureDetector(
                    onTap: () =>
                        setState(() => hoverCh = hoverCh == ch ? null : ch),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: hoverCh == ch
                            ? chColor(ch).withValues(alpha: 0.16)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: legendDot(
                        chColor(ch),
                        chLabel(currentDevice.id, ch),
                      ),
                    ),
                  ),
                ),
              legendDot(const Color(0xFFE0A100), 'เส้นเฝ้าระวัง -0.20 V'),
              legendDot(const Color(0xFFE5484D), 'เส้นวิกฤต -0.35 V'),
            ],
          ),
          const SizedBox(height: 10),
          chart(),
        ],
      ),
    );
  }
}
