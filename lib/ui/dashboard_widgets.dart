// CH tile, main readings panel, info panel
part of '../main.dart';

// ignore_for_file: invalid_use_of_protected_member, unused_element

extension _DashboardWidgets on _Ads1115PageState {
  // ============================================================
  // CHANNEL TILE
  // ============================================================
  Widget channelTile(String channel, dynamic value, {int? ch}) {
    final has =
        ch != null && sensorImages.containsKey('${currentDevice.id}|$ch');

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
      decoration: BoxDecoration(
        color: tileColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Stack(
        clipBehavior: Clip.none,
        fit: StackFit.passthrough,
        children: [
          Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                channel,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: Colors.black,
                ),
              ),
              const SizedBox(height: 6),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  volt(value),
                  style: TextStyle(
                    color: voltColor(value),
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          // (i) in the top-right corner: picture of where this sensor is
          if (ch != null)
            Positioned(
              top: -8,
              right: -6,
              child: Tooltip(
                message: has
                    ? 'ดู / เปลี่ยนรูปตำแหน่งเซนเซอร์'
                    : 'อัปโหลดรูปตำแหน่งเซนเซอร์',
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: () => showSensorImageDialog(currentDevice, ch),
                  child: Padding(
                    padding: const EdgeInsets.all(5),
                    child: Icon(
                      has ? Icons.info_rounded : Icons.info_outline_rounded,
                      size: 18,
                      color: has ? primaryBlue : mutedText,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ============================================================
  // MAIN READINGS PANEL
  // ============================================================
  // balance the grid so every row is filled and tiles use the full width
  ({int cols, int rows, double width}) channelGrid(
    double innerWidth,
    int count,
  ) {
    const gap = 12.0;
    const minTile = 128.0;

    final n = count < 1 ? 1 : count;
    final maxCols = ((innerWidth + gap) / (minTile + gap)).floor().clamp(1, n);
    final rows = (n / maxCols).ceil();
    final cols = (n / rows).ceil();

    return (
      cols: cols,
      rows: rows,
      width: (innerWidth - gap * (cols - 1)) / cols,
    );
  }

  Widget readingsPanel(
    Map<String, dynamic> d,
    ({int cols, int rows, double width}) grid,
  ) {
    final channels = channelsOf(currentDevice, [d]);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: panelDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'ค่าแรงดันล่าสุด',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: navyDark,
                  ),
                ),
              ),
              Text(
                '${channels.length} CH',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: mutedText,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              for (final i in channels)
                SizedBox(
                  width: grid.width,
                  child: channelTile(
                    chLabel(currentDevice.id, i),
                    d['ch$i'],
                    ch: i,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  // ============================================================
  // INFO PANEL
  // ============================================================

  // info chips laid out in as few full-width rows as possible
  ({int cols, int rows, double width}) infoLayout(double innerWidth) {
    const gap = 10.0;
    const minChip = 210.0; // wide enough for the date + time chip

    // chips are as wide as their content, so only the number of rows
    // they need is estimated (all five take about 780px on one line)
    final rows = innerWidth >= 800 ? 1 : (innerWidth >= 420 ? 2 : 3);

    return (cols: (infoCount / rows).ceil(), rows: rows, width: minChip + gap);
  }

  // "Sensor :  0x48": heading + colon, then the bold value, on ONE line.
  // The chip is exactly as wide as its content, nothing is cut with "...".
  Widget infoChip(String label, String value) {
    const style = TextStyle(
      fontSize: 13,
      fontWeight: FontWeight.w700,
      color: Colors.black87,
    );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: tileColor,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('$label :', softWrap: false, style: style),
          const SizedBox(width: 22),
          Text(value, softWrap: false, style: style),
        ],
      ),
    );
  }

  // device name + sensor info in one card, above the readings
  Widget sensorCard(
    Map<String, dynamic> d,
    List<Map<String, dynamic>> rows,
    ({int cols, int rows, double width}) info,
    bool oneLine,
  ) {
    final device = currentDevice;

    final chips = <(String, String)>[
      ('Sensor', device.mock ? 'จำลอง' : device.id),
      ('ID', '${d['id'] ?? '-'}'),
      ('จำนวน CH', '${channelsOf(currentDevice, [d]).length}'),
      ('เวลา', formatThaiTime(d['created_at']?.toString())),
      ('ข้อมูล', '${rows.length} แถว'),
    ];

    // small refresh button pinned to the top-right corner of the card
    final refreshButton = Positioned(
      top: 4,
      right: 4,
      child: IconButton(
        tooltip: 'รีเฟรชข้อมูล',
        onPressed: refresh,
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints.tightFor(width: 28, height: 28),
        style: IconButton.styleFrom(
          backgroundColor: primaryBlue.withValues(alpha: 0.10),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        icon: const Icon(Icons.refresh_rounded, color: primaryBlue, size: 17),
      ),
    );

    // keep content clear of the corner button
    const cornerGap = 22.0;

    return Stack(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: panelDecoration(),
          child: Padding(
            padding: EdgeInsets.only(right: oneLine ? cornerGap : 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(9),
                      decoration: BoxDecoration(
                        color: primaryBlue.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.sensors, color: primaryBlue),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            device.name,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: navyDark,
                            ),
                          ),
                          Text(
                            device.mock
                                ? 'ข้อมูลสุ่มสำหรับทดสอบหน้าจอ ไม่ได้บันทึกลงฐานข้อมูล'
                                : 'อัปเดตอัตโนมัติเมื่อมีข้อมูลใหม่',
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              color: navyDark.withValues(alpha: 0.55),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // chips stay close together (small gaps) right after the name,
                    // with some room kept before the right edge
                    if (oneLine) ...[
                      const SizedBox(width: 20),
                      for (var n = 0; n < chips.length; n++) ...[
                        if (n > 0) const SizedBox(width: 14),
                        infoChip(chips[n].$1, chips[n].$2),
                      ],
                      const SizedBox(width: 36),
                    ],
                  ],
                ),
                if (!oneLine) ...[
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      spacing: 10,
                      runSpacing: 10,
                      children: [for (final c in chips) infoChip(c.$1, c.$2)],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        refreshButton,
      ],
    );
  }
}
