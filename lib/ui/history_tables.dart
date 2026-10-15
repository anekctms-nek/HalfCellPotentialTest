// Latest-data table card and history card
part of '../main.dart';

// ignore_for_file: invalid_use_of_protected_member, unused_element

extension _HistoryTables on _Ads1115PageState {
  // "latest data" card on the dashboard: ONLY the line chart,
  // every CH drawn at the same time
  Widget historyTable(List<Map<String, dynamic>> all, {required int viewRows}) {
    final chs = all.isEmpty ? <int>[] : channelsOf(currentDevice, [all.first]);
    final count = chs.length;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: panelDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 14,
                  runSpacing: 10,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'ข้อมูลล่าสุด',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: navyDark,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          '$count CH • แสดงเฉพาะช่วงที่ค่าน้อยลง',
                          style: const TextStyle(
                            fontSize: 12,
                            color: mutedText,
                          ),
                        ),
                        if (seriesLoading) ...[
                          const SizedBox(width: 10),
                          const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ],
                      ],
                    ),
                    if (latestOpen) chPicker(chs),
                    if (latestOpen)
                      trendFilter(
                        selected: seriesRange,
                        accent: primaryBlue,
                        onSelect: (k) {
                          setState(() => seriesRange = k);
                          loadSeries();
                        },
                      ),
                  ],
                ),
              ),
              // hide / show the chart: far right of the card
              IconButton(
                tooltip: latestOpen ? 'ซ่อนกราฟ' : 'แสดงกราฟ',
                onPressed: () {
                  setState(() => latestOpen = !latestOpen);
                  if (latestOpen && !seriesCache.containsKey(seriesKey())) {
                    loadSeries();
                  }
                },
                icon: AnimatedRotation(
                  turns: latestOpen ? 0.5 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: const Icon(
                    Icons.expand_more_rounded,
                    color: navyDark,
                    size: 28,
                  ),
                ),
              ),
            ],
          ),
          if (latestOpen && all.isNotEmpty) compareSection(all.first),
        ],
      ),
    );
  }

  // rows (newest first) in which at least one CH is smaller than in the
  // reading just before it; the oldest row has nothing to compare with
  List<Map<String, dynamic>> decreasedRows(List<Map<String, dynamic>> rows) {
    final out = <Map<String, dynamic>>[];

    for (var i = 0; i < rows.length - 1; i++) {
      for (var ch = 1; ch <= channelCount; ch++) {
        final now = rows[i]['ch$ch'];
        final before = rows[i + 1]['ch$ch'];

        if (now != null && before != null && getValue(now) < getValue(before)) {
          out.add(rows[i]);
          break;
        }
      }
    }

    return out;
  }

  // for every row: the CH whose value differs from the reading just before
  // it (rows are newest first); cells that stayed the same are left empty
  Map<dynamic, Set<int>> changedCells(List<Map<String, dynamic>> all) {
    final out = <dynamic, Set<int>>{};

    for (var i = 0; i < all.length; i++) {
      final set = <int>{};
      if (i + 1 < all.length) {
        for (var ch = 1; ch <= channelCount; ch++) {
          final now = all[i]['ch$ch'];
          final before = all[i + 1]['ch$ch'];
          if (now != null &&
              before != null &&
              getValue(now) != getValue(before)) {
            set.add(ch);
          }
        }
      }
      out[all[i]['id']] = set;
    }

    return out;
  }

  // rows in which at least one CH changed (up or down, any color) against
  // the reading just before it
  List<Map<String, dynamic>> changedRows(List<Map<String, dynamic>> all) {
    final changed = changedCells(all);

    return [
      for (final r in all)
        if (changed[r['id']]?.isNotEmpty ?? false) r,
    ];
  }

  // history page card: fills the page and scrolls both ways
  Widget historyCard(List<Map<String, dynamic>> all) {
    final rows = applyFilters(all); // every reading; only changes are marked
    // with a color filter keep only the CH columns that have that color
    final channels = channelsOf(currentDevice, all)
        .where(
          (i) =>
              filterColors.isEmpty ||
              rows.any((r) => filterColors.contains(voltLevel(r['ch$i']))),
        )
        .toList();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: panelDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'ตารางข้อมูล',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: navyDark,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '${rows.length} จาก ${all.length} รายการ • ไฮไลต์เฉพาะค่าที่เปลี่ยน • หน่วย: โวลต์ (V)',
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12, color: mutedText),
                ),
              ),
              // top-right corner: search by ID + filter
              searchField(),
              const SizedBox(width: 10),
              filterButton(),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 12,
              runSpacing: 8,
              children: [
                trendFilter(
                  selected: histRange,
                  accent: primaryBlue,
                  onSelect: (k) {
                    setState(() => histRange = k);
                    loadHistoryRows();
                  },
                ),
                if (histLoading)
                  const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
              ],
            ),
          ),
          activeFilters(),
          Expanded(
            child: rows.isEmpty
                ? const Center(
                    child: Text(
                      'ไม่พบข้อมูลที่ตรงกัน',
                      style: TextStyle(color: mutedText),
                    ),
                  )
                : pinnedTable(
                    rows,
                    channels,
                    h: histHScroll,
                    v: histVScroll,
                    onlyColors: filterColors,
                    changedCells: changedCells(all),
                  ),
          ),
        ],
      ),
    );
  }
}
