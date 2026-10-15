// History page (table + voltage chart)
part of '../main.dart';

// ignore_for_file: invalid_use_of_protected_member, unused_element

extension _HistoryPage on _Ads1115PageState {
  String histKey() => '${currentDevice.id}|$histRange';

  Future<void> loadHistoryRows() async {
    final d = currentDevice;
    final key = histKey();
    final days = trendDays[histRange] ?? 1;

    setState(() => histLoading = true);

    var rows = <Map<String, dynamic>>[];

    try {
      if (d.mock) {
        rows = [...rowsFor(d)];
      } else {
        final start = DateTime.now().toUtc().subtract(Duration(days: days));
        final res = await supabase
            .from('ads1115_data')
            .select()
            .eq('sensor', d.id)
            .gte('created_at', start.toIso8601String())
            .order('created_at', ascending: false)
            .limit(histMax);

        rows = res.map((e) => Map<String, dynamic>.from(e)).toList();
      }
    } catch (e) {
      debugPrint('HISTORY ERROR = $e');
    }

    if (!mounted) return;

    setState(() {
      histCache[key] = rows;
      histLoading = false;
    });
  }

  Widget historyPicker(List<int> channels, Set<int> selected) => chTickMenu(
    channels: channels,
    selected: selected,
    label: 'เปรียบเทียบ CH',
    icon: Icons.add_chart_rounded,
    onChanged: (s) => setState(() {
      historyTouched = true;
      historyChs
        ..clear()
        ..addAll(s);
    }),
  );

  // history page: point chart of the ticked CH (one or several to compare);
  // pointing at a point explains it, every line carries its CH name
  Widget historyChartCard(List<Map<String, dynamic>> rows, Set<int> chosen) {
    final channels = channelsOf(currentDevice, rows);
    final shown = [
      for (final i in channels)
        if (chosen.contains(i)) i,
    ];

    // oldest -> newest
    final ordered = rows.reversed.toList();
    final lines = <List<double?>>[
      for (final ch in shown)
        [
          for (final r in ordered)
            r['ch$ch'] == null ? null : getValue(r['ch$ch']),
        ],
    ];
    final labels = [
      for (final r in ordered) thaiClock(r['created_at'], seconds: true),
    ];
    final colors = [for (final ch in shown) chColor(ch)];
    final single = shown.length == 1;

    // details of one point, shown when the mouse is on it
    String detail(int c, int i) {
      final r = ordered[i];
      final v = lines[c][i]!;
      final level = switch (voltLevel(v)) {
        'green' => 'ปกติ',
        'yellow' => 'เฝ้าระวัง',
        _ => 'วิกฤต',
      };

      // change against the previous reading of this CH
      double? before;
      for (var k = i - 1; k >= 0; k--) {
        if (lines[c][k] != null) {
          before = lines[c][k];
          break;
        }
      }
      final change = before == null
          ? 'จุดแรกของช่วงนี้'
          : 'เทียบจุดก่อนหน้า: ${v - before >= 0 ? '+' : ''}'
                '${((v - before) * 1000).toStringAsFixed(1)} mV';

      return '${chLabel(currentDevice.id, shown[c])}  •  ID ${r['id'] ?? '-'}\n'
          'ค่า: ${v.toStringAsFixed(3)} V ($level)\n'
          'เวลา: ${formatThaiTime(r['created_at']?.toString())}\n'
          '$change';
    }

    final hasData = lines.any((l) => l.any((v) => v != null));

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: panelDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 12,
            runSpacing: 10,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'กราฟค่าแรงดัน',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: navyDark,
                    ),
                  ),
                  Text(
                    '${ordered.length} จุด • ค่าต่ำกว่าอยู่ด้านบน • '
                    'ชี้ที่จุดเพื่อดูรายละเอียด • ติ๊กเพิ่ม CH เพื่อเปรียบเทียบ',
                    style: const TextStyle(fontSize: 12, color: mutedText),
                  ),
                ],
              ),
              historyPicker(channels, {...shown}),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 14,
            runSpacing: 4,
            children: [
              if (single) ...[
                legendDot(valueGreen, 'ปกติ (> -0.20)'),
                legendDot(const Color(0xFFE0A100), 'เฝ้าระวัง'),
                legendDot(const Color(0xFFE5484D), 'วิกฤต (< -0.35)'),
              ] else
                for (final ch in shown)
                  legendDot(chColor(ch), chLabel(currentDevice.id, ch)),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 360,
            width: double.infinity,
            child: !hasData
                ? Center(
                    child: Text(
                      shown.isEmpty
                          ? 'ยังไม่ได้เลือก CH ที่ต้องการดู'
                          : 'ไม่มีข้อมูลของ CH ที่เลือก',
                      style: const TextStyle(color: mutedText),
                    ),
                  )
                : LayoutBuilder(
                    builder: (context, bc) {
                      final size = Size(bc.maxWidth, bc.maxHeight);
                      final names = [
                        for (final ch in shown) chLabel(currentDevice.id, ch),
                      ];

                      return Stack(
                        children: [
                          Positioned.fill(
                            child: CustomPaint(
                              painter: PointLabelPainter(
                                lines,
                                colors,
                                names,
                                labels,
                              ),
                            ),
                          ),
                          // a hover spot on every point: shows its details
                          for (var c = 0; c < lines.length; c++)
                            for (var i = 0; i < ordered.length; i++)
                              if (lines[c][i] != null &&
                                  i %
                                          PointLabelPainter.dotEvery(
                                            ordered.length,
                                            size,
                                          ) ==
                                      0)
                                Positioned(
                                  left:
                                      PointLabelPainter.position(
                                        lines,
                                        size,
                                        i,
                                        lines[c][i]!,
                                      ).dx -
                                      9,
                                  top:
                                      PointLabelPainter.position(
                                        lines,
                                        size,
                                        i,
                                        lines[c][i]!,
                                      ).dy -
                                      9,
                                  width: 18,
                                  height: 18,
                                  child: Tooltip(
                                    waitDuration: Duration.zero,
                                    message: detail(c, i),
                                    textStyle: const TextStyle(
                                      fontSize: 14.5,
                                      height: 1.5,
                                      color: Colors.white,
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 10,
                                    ),
                                    child: MouseRegion(
                                      cursor: SystemMouseCursors.click,
                                      child: Container(
                                        color: Colors.transparent,
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

  Widget historyPage(List<Map<String, dynamic>> rows) {
    // rows of the chosen period (the loaded recent rows until they arrive)
    final data = histCache[histKey()] ?? rows;
    var channels = channelsOf(currentDevice, data);
    if (channels.isEmpty) channels = channelsOf(currentDevice, rows);

    // nothing ticked (or CH of another device): start with the first CH
    var chosen = historyChs.where(channels.contains).toSet();
    if (chosen.isEmpty && !historyTouched) chosen = {channels.first};

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        pageTitle('ประวัติข้อมูล • ${currentDevice.name}'),
        const SizedBox(height: 16),
        // the table comes first, the voltage chart under it
        SizedBox(height: 560, child: historyCard(data)),
        const SizedBox(height: 16),
        historyChartCard(data, chosen),
      ],
    );
  }
}
