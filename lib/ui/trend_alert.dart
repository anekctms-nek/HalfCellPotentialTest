// Past readings, degradation rates, period filter
part of '../main.dart';

// ignore_for_file: invalid_use_of_protected_member, unused_element

extension _TrendAlert on _Ads1115PageState {
  // loads the reading from 1 day / 1 week / 1 month / 3 / 6 months ago
  // of the selected device
  Future<void> loadTrend() async {
    final token = ++trendToken;
    final d = currentDevice;
    final now = DateTime.now().toUtc();

    setState(() => trendLoading = true);

    final result = <String, Map<String, dynamic>?>{};

    try {
      final rows = rowsFor(d);

      if (d.mock) {
        // simulated devices have no history: make up a past reading
        // (steady drift per CH) so the screen can be tried out
        if (rows.isNotEmpty) {
          for (final e in trendDays.entries) {
            final past = <String, dynamic>{
              'id': '-',
              'sensor': d.id,
              'created_at': now
                  .subtract(Duration(days: e.value))
                  .toIso8601String(),
            };
            for (final i in channelsIn([rows.first])) {
              final nowV = getValue(rows.first['ch$i']);
              past['ch$i'] = double.parse(
                mockPastValue(
                  d,
                  i,
                  nowV,
                  e.value.toDouble(),
                ).toStringAsFixed(4),
              );
            }
            result[e.key] = past;
          }
        }
      } else {
        await Future.wait([
          for (final e in trendDays.entries)
            supabase
                .from('ads1115_data')
                .select()
                .eq('sensor', d.id)
                .lte(
                  'created_at',
                  now.subtract(Duration(days: e.value)).toIso8601String(),
                )
                .order('created_at', ascending: false)
                .limit(1)
                .then((r) {
                  result[e.key] = r.isEmpty
                      ? null
                      : Map<String, dynamic>.from(r.first);
                }),
        ]);
      }
    } catch (e) {
      debugPrint('COMPARE ERROR = $e');
    }

    if (!mounted || token != trendToken) return;

    setState(() {
      pastRows = result;
      trendLoading = false;
    });
    if (latestOpen && !seriesCache.containsKey(seriesKey())) loadSeries();
    if (selectedMenu == 1) loadHistoryRows();
  }

  // segmented period selector (each card passes its own selection)
  Widget trendFilter({
    required String selected,
    required ValueChanged<String> onSelect,
    Map<String, String> options = trendRanges,
    Color accent = const Color(0xFFB42318),
    bool dense = false, // narrower buttons (alert card)
  }) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final e in options.entries)
            InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () => onSelect(e.key),
              child: Container(
                padding: EdgeInsets.symmetric(
                  horizontal: dense ? 8 : 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: selected == e.key
                      ? accent.withValues(alpha: 0.12)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  e.value,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: selected == e.key
                        ? FontWeight.w800
                        : FontWeight.w500,
                    color: selected == e.key ? accent : mutedText,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // the alert card's own filter: "ล่าสุด" (default) + the five periods
  Widget alertFilter() => trendFilter(
    selected: alertRange,
    options: alertRanges,
    onSelect: (k) => setState(() => alertRange = k),
    dense: true,
  );

  // change of every CH since the chosen period, in mV per day
  // (negative = the potential got more negative = getting worse)
  Map<int, double> degradeRates() {
    final rows = currentRows;
    final past = pastRows[alertRange];
    if (rows.isEmpty || past == null) return {};

    final latest = rows.first;
    final t1 = DateTime.tryParse(latest['created_at']?.toString() ?? '');
    final t0 = DateTime.tryParse(past['created_at']?.toString() ?? '');
    if (t1 == null || t0 == null) return {};

    // use the real distance in time between the two readings
    final days = (t1.difference(t0).inMinutes / 1440).clamp(1 / 1440, 1e6);

    return {
      for (final i in channelsIn([latest]))
        if (latest['ch$i'] != null && past['ch$i'] != null)
          i: (getValue(latest['ch$i']) - getValue(past['ch$i'])) * 1000 / days,
    };
  }

  String mvDay(double r) =>
      '${r >= 0 ? '+' : ''}${r.toStringAsFixed(2)} mV/วัน';

  // the fastest degrading CH of the chosen period
  Widget degradeSummary() {
    const redDark = Color(0xFFB42318);
    final rates = degradeRates();

    MapEntry<int, double>? worst;
    for (final e in rates.entries) {
      if (worst == null || e.value < worst.value) worst = e;
    }

    final text = worst == null
        ? '-'
        : '${chLabel(currentDevice.id, worst.key)}  ${mvDay(worst.value)}';

    return Text(
      text,
      style: TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.w800,
        color: worst != null && worst.value < 0 ? redDark : navyDark,
      ),
    );
  }

  // horizontal bars, one per CH: left = getting worse, right = recovering
  Widget degradationChart() {
    const red = Color(0xFFE5484D);
    final rates = degradeRates();
    final past = pastRows[alertRange];

    if (trendLoading && past == null) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(
          child: Text('กำลังโหลด...', style: TextStyle(color: mutedText)),
        ),
      );
    }

    if (rates.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(
          child: Text(
            'ยังไม่มีข้อมูลย้อนหลังถึงช่วงเวลานี้',
            style: TextStyle(color: mutedText),
          ),
        ),
      );
    }

    var maxAbs = 0.001;
    for (final v in rates.values) {
      if (v.abs() > maxAbs) maxAbs = v.abs();
    }

    final latest = currentRows.first;
    const rowH = 28.0;
    final boxH = (rates.length * rowH).clamp(rowH, 280.0);

    Widget line(int i, double r) {
      final bad = r < 0;
      final color = bad ? red : valueGreen;

      return Tooltip(
        waitDuration: Duration.zero,
        message:
            '${chLabel(currentDevice.id, i)}\n'
            'อัตราการเปลี่ยน: ${mvDay(r)}\n'
            'ก่อนหน้า ${getValue(past!['ch$i']).toStringAsFixed(3)} V → '
            'ตอนนี้ ${getValue(latest['ch$i']).toStringAsFixed(3)} V',
        child: SizedBox(
          height: rowH,
          child: Row(
            children: [
              SizedBox(
                width: 78,
                child: Text(
                  chLabel(currentDevice.id, i),
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Colors.black,
                  ),
                ),
              ),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, bc) {
                    final half = bc.maxWidth / 2;
                    final len = (r.abs() / maxAbs * half).clamp(2.0, half);

                    return Stack(
                      children: [
                        Positioned(
                          left: half - 0.5,
                          top: 0,
                          bottom: 0,
                          child: Container(
                            width: 1,
                            color: const Color(0xFFD0D5DD),
                          ),
                        ),
                        Positioned(
                          left: bad ? half - len : half,
                          width: len,
                          top: 6,
                          bottom: 6,
                          child: Container(
                            decoration: BoxDecoration(
                              color: color,
                              borderRadius: BorderRadius.horizontal(
                                left: Radius.circular(bad ? 4 : 0),
                                right: Radius.circular(bad ? 0 : 4),
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
              SizedBox(
                width: 112,
                child: Text(
                  mvDay(r),
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: bad ? const Color(0xFFB42318) : valueGreen,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            legendDot(red, 'เสื่อมลง (ค่าติดลบมากขึ้น)'),
            const SizedBox(width: 16),
            legendDot(valueGreen, 'ฟื้นตัว'),
          ],
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: boxH,
          child: ListView(
            children: [for (final e in rates.entries) line(e.key, e.value)],
          ),
        ),
      ],
    );
  }
}
