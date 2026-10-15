// Priority list, online status, connection and alert cards
part of '../main.dart';

// ignore_for_file: invalid_use_of_protected_member, unused_element

extension _AlertAndConnection on _Ads1115PageState {
  // ---------- which point to fix first ----------
  String daysText(double d) {
    if (d < 1) return 'ไม่ถึง 1 วัน';
    if (d < 60) return 'ประมาณ ${d.round()} วัน';
    return 'ประมาณ ${(d / 30).round()} เดือน';
  }

  // a plain-language list of the CH that need attention first
  Widget scrollIf(bool on, Widget c) =>
      on ? SingleChildScrollView(child: c) : c;

  // [fill]: the white box stretches to the bottom of the alert card
  Widget priorityBox({bool fill = false}) {
    const redDark = Color(0xFFB42318);
    final rows = currentRows;
    if (rows.isEmpty) return const SizedBox.shrink();

    // "ล่าสุด" (default): judge by the latest values only, no comparison
    final latestOnly = alertRange == 'latest';
    final rates = latestOnly
        ? {
            for (final i in channelsIn([rows.first])) i: 0.0,
          }
        : degradeRates();
    if (rates.isEmpty) return const SizedBox.shrink();

    final latest = rows.first;
    final items =
        <({int ch, double v, double rate, String level, double? days})>[];

    for (final e in rates.entries) {
      final v = getValue(latest['ch${e.key}']);
      final level = voltLevel(v)!;

      if (latestOnly) {
        if (level != 'green') {
          items.add((ch: e.key, v: v, rate: 0, level: level, days: null));
        }
        continue;
      }

      // days left until the next worse level, at the current rate
      double? days;
      if (e.value < 0) {
        final limit = level == 'green'
            ? -0.20
            : (level == 'yellow' ? -0.35 : null);
        if (limit != null) days = (v - limit) * 1000 / -e.value;
      }

      if (level == 'red' || (days != null && days < 365)) {
        items.add((ch: e.key, v: v, rate: e.value, level: level, days: days));
      }
    }

    // red first (fastest falling first), then the soonest to get worse
    double rank(
      ({int ch, double v, double rate, String level, double? days}) x,
    ) => latestOnly
        ? x
              .v // most negative first
        : (x.level == 'red' ? -1e9 + x.rate : (x.days ?? 1e9));
    items.sort((a, b) => rank(a).compareTo(rank(b)));

    String describe(
      ({int ch, double v, double rate, String level, double? days}) x,
    ) {
      final name = chLabel(currentDevice.id, x.ch);
      final value = '${x.v.toStringAsFixed(3)} V';

      if (latestOnly) {
        return x.level == 'red'
            ? '$name อยู่ในระดับวิกฤต ($value) → ควรแก้ไขก่อน'
            : '$name อยู่ในระดับเฝ้าระวัง ($value) → ควรเฝ้าติดตามต่อ';
      }

      if (x.level == 'red') {
        return x.rate < 0
            ? '$name อยู่ในระดับวิกฤต ($value) และยังเสื่อมลง ${mvDay(x.rate)} '
                  '→ ควรแก้ไขก่อน'
            : '$name อยู่ในระดับวิกฤต ($value) แม้ค่าจะคงที่หรือฟื้นตัว '
                  '(${mvDay(x.rate)}) → ควรตรวจสอบสาเหตุ';
      }

      final next = x.level == 'green' ? 'เฝ้าระวัง' : 'วิกฤต';
      final now = x.level == 'green' ? 'ปกติ' : 'เฝ้าระวัง';
      return '$name ยัง$now ($value) แต่เสื่อมลง ${mvDay(x.rate)} '
          '→ คาดว่าจะถึงระดับ$next ใน${daysText(x.days!)}';
    }

    final top = items.take(3).toList();

    // one line of the list
    Widget row(int n) => Padding(
      padding: EdgeInsets.only(bottom: fill ? 0 : 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 30,
            height: 30,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: top[n].level == 'red'
                  ? const Color(0xFFE5484D)
                  : const Color(0xFFE0A100),
              shape: BoxShape.circle,
            ),
            child: Text(
              '${n + 1}',
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              describe(top[n]),
              style: TextStyle(
                fontSize: fill ? 16.5 : 16,
                color: Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );

    const emptyText = Text(
      'ไม่พบ CH ที่ต้องรีบแก้ไขในช่วงเวลานี้',
      style: TextStyle(fontSize: 16, color: valueGreen),
    );

    return Container(
      width: double.infinity,
      margin: EdgeInsets.only(bottom: fill ? 0 : 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: redDark.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'จุดที่ควรแก้ไขก่อน',
            style: TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w800,
              color: redDark,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            alertRange == 'latest'
                ? 'ดูจากค่าแรงดันล่าสุด เรียงค่าต่ำสุดก่อน'
                : 'อัตราความเสื่อม = ค่าที่เปลี่ยนไปต่อวัน (mV/วัน) '
                      'ติดลบ = ค่าลดลง/เสื่อมลง เรียงตามความเร่งด่วน',
            style: TextStyle(
              fontSize: 14,
              color: redDark.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: 10),
          if (fill)
            // the lines are spread evenly over the rest of the card
            Expanded(
              child: LayoutBuilder(
                builder: (context, bc) => SingleChildScrollView(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minHeight: bc.maxHeight),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: top.isEmpty
                          ? [emptyText]
                          : [for (var n = 0; n < top.length; n++) row(n)],
                    ),
                  ),
                ),
              ),
            )
          else if (top.isEmpty)
            emptyText
          else
            for (var n = 0; n < top.length; n++) row(n),
        ],
      ),
    );
  }

  // ---------- connection status (Online / Offline) ----------
  // a station is Online when its newest reading is at most 2 minutes old
  bool deviceOnline(Device d) {
    final r = rowsFor(d);
    if (r.isEmpty) return false;

    final t = DateTime.tryParse(r.first['created_at']?.toString() ?? '');
    if (t == null) return false;

    return DateTime.now().toUtc().difference(t.toUtc()).inSeconds <= 120;
  }

  // a measuring point is Online when its station is Online and it sends a
  // real value (empty or exactly 0 = nothing connected)
  bool chOnline(Device d, int i) {
    if (!deviceOnline(d)) return false;

    final v = rowsFor(d).first['ch$i'];
    return v != null && getValue(v) != 0;
  }

  Widget onlineBadge(bool online) {
    final color = online ? valueGreen : mutedText;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.circle, size: 8, color: color),
          const SizedBox(width: 5),
          Text(
            online ? 'Online' : 'Offline',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  // every station + its measuring points, easy to scan:
  // totals on top, then one line per station
  Widget connectionCard() {
    final all = devices;

    var stationsOn = 0, pointsOn = 0, pointsAll = 0;
    final lines = <Widget>[];

    for (final d in all) {
      final rows = rowsFor(d);
      final chs = channelsOf(d, rows);
      final on = deviceOnline(d);
      final onList = [
        for (final i in chs)
          if (chOnline(d, i)) i,
      ];
      final offList = [
        for (final i in chs)
          if (!onList.contains(i)) i,
      ];

      if (on) stationsOn++;
      pointsOn += onList.length;
      pointsAll += chs.length;

      final offText = !on
          ? 'ไม่มีข้อมูลเข้ามา — ทั้งสถานีไม่ตอบสนอง'
          : (offList.isEmpty
                ? 'ทุกจุดวัดทำงานปกติ'
                : 'Offline: ${offList.take(8).map((i) => chLabel(d.id, i)).join(', ')}'
                      '${offList.length > 8 ? ' และอีก ${offList.length - 8} จุด' : ''}');

      final hovered = hoverStation == d.id;
      final statusColor = on ? valueGreen : mutedText;

      lines.add(
        MouseRegion(
          cursor: SystemMouseCursors.click,
          onEnter: (_) => setState(() => hoverStation = d.id),
          onExit: (_) => setState(() {
            if (hoverStation == d.id) hoverStation = null;
          }),
          child: Tooltip(
            message: 'คลิกเพื่อดูข้อมูลของ ${d.name}',
            // shows at once, so it is clear this row can be clicked
            waitDuration: Duration.zero,
            textStyle: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            decoration: BoxDecoration(
              color: primaryBlue,
              borderRadius: BorderRadius.circular(10),
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              // click a location: open its data
              onTap: () {
                setState(() {
                  selectedDevice = d.id;
                  selectedMenu = 0;
                });
                loadTrend();
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                width: double.infinity,
                margin: const EdgeInsets.only(top: 10),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                // pointed at: the row floats up with an outline and a soft
                // shadow; the fill color stays the same (nothing flashes)
                transformAlignment: Alignment.center,
                transform: hovered
                    ? (Matrix4.identity()
                        ..translateByDouble(0.0, -3.0, 0.0, 1.0)
                        ..scaleByDouble(1.02, 1.02, 1.0, 1.0))
                    : Matrix4.identity(),
                decoration: BoxDecoration(
                  color: tileColor,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: hovered
                        ? primaryBlue.withValues(alpha: 0.6)
                        : Colors.transparent,
                    width: 1.4,
                  ),
                  boxShadow: hovered
                      ? [
                          BoxShadow(
                            color: navyDark.withValues(alpha: 0.16),
                            blurRadius: 16,
                            offset: const Offset(0, 7),
                          ),
                        ]
                      : null,
                ),
                child: Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 20,
                  runSpacing: 8,
                  children: [
                    // status bar on the left
                    Container(
                      width: 5,
                      height: 38,
                      decoration: BoxDecoration(
                        color: statusColor,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                    SizedBox(
                      width: 230,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            d.mock ? '${d.name} (จำลอง)' : d.name,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: navyDark,
                            ),
                          ),
                          Text(
                            rows.isEmpty
                                ? 'ยังไม่มีข้อมูล'
                                : 'ข้อมูลล่าสุด ${formatThaiTime(rows.first['created_at']?.toString())}',
                            style: const TextStyle(
                              fontSize: 11,
                              color: mutedText,
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(width: 84, child: onlineBadge(on)),
                    SizedBox(
                      width: 190,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'จุดวัด Online ${onList.length}/${chs.length}',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: navyDark,
                            ),
                          ),
                          const SizedBox(height: 5),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: chs.isEmpty
                                  ? 0
                                  : onList.length / chs.length,
                              minHeight: 8,
                              color: valueGreen,
                              backgroundColor: const Color(0xFFD9DEE8),
                            ),
                          ),
                        ],
                      ),
                    ),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 420),
                      child: Text(
                        offText,
                        style: TextStyle(
                          fontSize: 12,
                          color: offList.isEmpty && on ? valueGreen : mutedText,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    Widget total(String label, int n, Color color) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$n',
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          Text(label, style: const TextStyle(fontSize: 12, color: navyDark)),
        ],
      ),
    );

    return homeCard(
      title: 'สถานะการเชื่อมต่อ',
      trailing: const Text(
        'Online = มีข้อมูลใหม่ใน 2 นาที',
        style: TextStyle(fontSize: 12, color: mutedText),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              total('สถานี Online', stationsOn, valueGreen),
              total(
                'สถานี Offline',
                all.length - stationsOn,
                all.length - stationsOn == 0
                    ? mutedText
                    : const Color(0xFFE5484D),
              ),
              total('จุดวัด Online', pointsOn, valueGreen),
              total('จุดวัด Offline', pointsAll - pointsOn, mutedText),
            ],
          ),
          ...lines,
        ],
      ),
    );
  }

  // appears before the "latest data" card only when a red value exists:
  // degradation rate of every CH as horizontal bars
  Widget alertCard(List<Map<String, dynamic>> rows, {bool fill = false}) {
    const red = Color(0xFFE5484D);
    const redDark = Color(0xFFB42318);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 16, 16, 20),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF4F4),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: red.withValues(alpha: 0.45)),
        boxShadow: [
          BoxShadow(
            color: red.withValues(alpha: 0.10),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // title on the left, the period filter in the top-right corner
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.only(top: 2),
                child: Icon(Icons.warning_amber_rounded, color: red, size: 38),
              ),
              const SizedBox(width: 12),
              const Text(
                'แจ้งเตือน',
                maxLines: 1,
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: redDark,
                  height: 1.2,
                ),
              ),
              // the filter keeps the top-right corner and only shrinks when
              // the card is too narrow for it
              Expanded(
                child: Align(
                  alignment: Alignment.topRight,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.topRight,
                    child: alertFilter(),
                  ),
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(left: 50),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'อัตราความเสื่อมของทุก CH',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: redDark,
                  ),
                ),
                if (trendLoading) ...[
                  const SizedBox(width: 10),
                  const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: red,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (fill) Expanded(child: priorityBox(fill: true)) else priorityBox(),
        ],
      ),
    );
  }
}
