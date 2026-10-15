// Rows of a location and the cards of the home page
part of '../main.dart';

// ignore_for_file: invalid_use_of_protected_member, unused_element

extension _HomeCards on _Ads1115PageState {
  // ============================================================
  // HOME (main dashboard)
  // ============================================================
  List<Map<String, dynamic>> rowsFor(Device d) => d.mock
      ? (mockRows[d.id] ?? const [])
      : history.where((r) => r['sensor']?.toString() == d.id).toList();

  // number of green / yellow / red values in one row
  ({int green, int yellow, int red}) levelCounts(Map<String, dynamic> r) {
    var g = 0, y = 0, rd = 0;
    for (var i = 1; i <= channelCount; i++) {
      switch (voltLevel(r['ch$i'])) {
        case 'green':
          g++;
        case 'yellow':
          y++;
        case 'red':
          rd++;
      }
    }
    return (green: g, yellow: y, red: rd);
  }

  // HH:mm in Thai time
  String thaiClock(dynamic value, {bool seconds = false}) {
    final t = DateTime.tryParse(value?.toString() ?? '');
    if (t == null) return '-';
    final th = t.toUtc().add(const Duration(hours: 7));
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(th.hour)}:${two(th.minute)}${seconds ? ':${two(th.second)}' : ''}';
  }

  Widget homeCard({
    required String title,
    required Widget child,
    Widget? trailing,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: navyDark.withValues(alpha: 0.06),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: navyDark,
                  ),
                ),
              ),
              ?trailing,
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }

  Widget legendDot(Color c, String label) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(Icons.circle, size: 10, color: c),
      const SizedBox(width: 6),
      Text(label, style: const TextStyle(fontSize: 12, color: mutedText)),
    ],
  );

  // grouped bars: for every device 3 bars side by side (green / yellow / red)
  // with scale lines; hover a group to see how many points each color has
  Widget performanceCard() {
    const red = Color(0xFFE5484D);
    const yellow = Color(0xFFE0A100);

    final groups = <({Device device, int green, int yellow, int red})>[];
    for (final d in devices) {
      final r = rowsFor(d);
      if (r.isEmpty) continue;
      final c = levelCounts(r.first);
      groups.add((device: d, green: c.green, yellow: c.yellow, red: c.red));
    }

    var maxCount = 4;
    for (final g in groups) {
      maxCount = [maxCount, g.green, g.yellow, g.red].reduce(max);
    }
    // round the top of the scale up to a multiple of 4
    final top = (maxCount / 4).ceil() * 4;

    const chartH = 170.0;

    Widget bar(int n, Color color) => Container(
      width: 22,
      height: n == 0 ? 3 : (n / top * chartH).clamp(3, chartH),
      decoration: BoxDecoration(
        color: color,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
      ),
    );

    Widget group(({Device device, int green, int yellow, int red}) g) {
      return Expanded(
        child: Tooltip(
          waitDuration: Duration.zero,
          // bigger detail box when pointed at
          textStyle: const TextStyle(
            fontSize: 16,
            height: 1.5,
            color: Colors.white,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          message:
              '${g.device.name}\n'
              'ปกติ: ${g.green} จุด\n'
              'เฝ้าระวัง: ${g.yellow} จุด\n'
              'วิกฤต: ${g.red} จุด',
          child: Column(
            children: [
              SizedBox(
                height: chartH,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    bar(g.green, valueGreen),
                    const SizedBox(width: 2),
                    bar(g.yellow, yellow),
                    const SizedBox(width: 2),
                    bar(g.red, red),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                g.device.name,
                maxLines: 2,
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 11, color: mutedText),
              ),
            ],
          ),
        ),
      );
    }

    return homeCard(
      title: 'ตัวชี้วัดค่าแรงดัน',
      trailing: const Text(
        'ทุกอุปกรณ์ (ค่าล่าสุด)',
        style: TextStyle(fontSize: 12, color: mutedText),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 16,
            runSpacing: 4,
            children: [
              legendDot(valueGreen, 'ปกติ (> -0.20)'),
              legendDot(yellow, 'เฝ้าระวัง'),
              legendDot(red, 'วิกฤต (< -0.35)'),
            ],
          ),
          const SizedBox(height: 16),
          Stack(
            children: [
              // scale lines behind the bars
              Positioned(
                left: 0,
                right: 0,
                top: 0,
                height: chartH,
                child: CustomPaint(painter: BarGridPainter(top)),
              ),
              Padding(
                padding: const EdgeInsets.only(left: BarGridPainter.leftPad),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [for (final g in groups) group(g)],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // donut of the latest reading of the selected device
  Widget donutCard(Map<String, dynamic> latest) {
    final c = levelCounts(latest);
    final total = c.green + c.yellow + c.red;
    const red = Color(0xFFE5484D);
    const yellow = Color(0xFFE0A100);

    return homeCard(
      title: 'สัดส่วนสถานะ CH',
      child: Column(
        children: [
          SizedBox(
            height: 190,
            width: 190,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CustomPaint(
                  size: const Size(190, 190),
                  painter: DonutPainter(
                    [c.red, c.green, c.yellow],
                    [red, valueGreen, yellow],
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '$total',
                      style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        color: navyDark,
                      ),
                    ),
                    const Text(
                      'CH ทั้งหมด',
                      style: TextStyle(fontSize: 12, color: mutedText),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 14,
            runSpacing: 4,
            alignment: WrapAlignment.center,
            children: [
              legendDot(valueGreen, 'ปกติ ${c.green}'),
              legendDot(yellow, 'เฝ้าระวัง ${c.yellow}'),
              legendDot(red, 'วิกฤต ${c.red}'),
            ],
          ),
        ],
      ),
    );
  }

  // overview of EVERY location (not only the selected one)
  Widget reportSummary() {
    final all = devices;

    var green = 0, yellow = 0, redTotal = 0;
    for (final d in all) {
      final r = rowsFor(d);
      if (r.isEmpty) continue;

      final c = levelCounts(r.first);
      green += c.green;
      yellow += c.yellow;
      redTotal += c.red;
    }

    // icon first, then the text
    Widget stat(
      String label,
      String value,
      String sub,
      Color color,
      IconData icon,
      double w,
    ) => SizedBox(
      width: w,
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: Colors.white, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: navyDark,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: navyDark,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  sub,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF7C5CE0),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    return homeCard(
      title: 'สรุปรายงาน',
      trailing: InkWell(
        onTap: loadLatestData,
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'อัปเดตข้อมูล',
              style: TextStyle(fontSize: 12, color: mutedText),
            ),
            SizedBox(width: 4),
            Icon(Icons.refresh_rounded, size: 14, color: mutedText),
          ],
        ),
      ),
      child: LayoutBuilder(
        builder: (context, bc) {
          final cols = bc.maxWidth >= 420 ? 2 : 1;
          const gap = 24.0;
          final w = (bc.maxWidth - gap * (cols - 1)) / cols;

          return Wrap(
            spacing: gap,
            runSpacing: 20,
            children: [
              stat(
                'CH ที่ใช้งาน (ทุกสถานที่)',
                '${green + yellow + redTotal}',
                'ปกติ $green • เฝ้าระวัง $yellow',
                primaryBlue,
                Icons.electrical_services_rounded,
                w,
              ),
              stat(
                'พบค่าสีแดง',
                '$redTotal',
                'จากทุกอุปกรณ์ (ล่าสุด)',
                const Color(0xFFE5484D),
                Icons.warning_amber_rounded,
                w,
              ),
            ],
          );
        },
      ),
    );
  }

  Widget deviceTable() {
    const red = Color(0xFFE5484D);
    const yellow = Color(0xFFE0A100);

    Widget cell(Widget child, int flex) => Expanded(flex: flex, child: child);
    TextStyle head() => const TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w800,
      color: navyDark,
    );
    const body = TextStyle(fontSize: 13, color: navyDark);

    Widget badge(String? level) {
      final (label, color) = switch (level) {
        'red' => ('Critical', red),
        'yellow' => ('Warning', yellow),
        'green' => ('Normal', valueGreen),
        _ => ('No data', mutedText),
      };
      return Align(
        alignment: Alignment.centerLeft,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.16),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ),
      );
    }

    Widget line(Device d) {
      final r = rowsFor(d);
      final latest = r.isEmpty ? null : r.first;
      final chs = latest == null ? <int>[] : channelsIn([latest]);
      double? lowest;
      if (latest != null) {
        for (final i in chs) {
          final v = getValue(latest['ch$i']);
          if (lowest == null || v < lowest) lowest = v;
        }
      }

      return InkWell(
        onTap: () {
          setState(() {
            selectedDevice = d.id;
            selectedMenu = 0;
          });
          loadTrend();
        },
        child: Container(
          constraints: const BoxConstraints(minHeight: 52),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: const BoxDecoration(
            border: Border(top: BorderSide(color: Color(0xFFE6EAF5))),
          ),
          child: Row(
            children: [
              cell(Text(d.id, style: body), 2),
              cell(Text(d.name, style: body), 4),
              cell(Text('${chs.length}', style: body), 1),
              cell(
                Text(
                  lowest == null ? '-' : '${lowest.toStringAsFixed(3)} V',
                  style: body,
                ),
                2,
              ),
              cell(
                Text(
                  latest == null
                      ? '-'
                      : formatThaiTime(latest['created_at']?.toString()),
                  style: body,
                ),
                3,
              ),
              cell(badge(lowest == null ? null : voltLevel(lowest)), 2),
            ],
          ),
        ),
      );
    }

    return homeCard(
      title: 'รายการอุปกรณ์',
      trailing: InkWell(
        onTap: () => setState(() => selectedMenu = 0),
        child: const Text(
          'ดูแดชบอร์ด',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Color(0xFF7C5CE0),
          ),
        ),
      ),
      child: LayoutBuilder(
        builder: (context, bc) {
          final w = bc.maxWidth < 720 ? 720.0 : bc.maxWidth;
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: w,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      children: [
                        cell(Text('รหัสอุปกรณ์', style: head()), 2),
                        cell(Text('ชื่ออุปกรณ์', style: head()), 4),
                        cell(Text('จำนวน CH', style: head()), 1),
                        cell(Text('ค่าต่ำสุด', style: head()), 2),
                        cell(Text('เวลาล่าสุด', style: head()), 3),
                        cell(Text('สถานะ', style: head()), 2),
                      ],
                    ),
                  ),
                  for (final d in devices) line(d),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
