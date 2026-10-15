// CH picker and the filters of the tables
part of '../main.dart';

// ignore_for_file: invalid_use_of_protected_member, unused_element

extension _Filters on _Ads1115PageState {
  List<int> visibleChannels(List<int> available) {
    if (chFilter.isEmpty) return available;

    final shown = available.where(chFilter.contains).toList();

    return shown.isEmpty ? available : shown;
  }

  Widget filterPill(String label, bool selected, VoidCallback onTap) {
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? primaryBlue : tileColor,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: selected ? Colors.white : navyDark,
          ),
        ),
      ),
    );
  }

  Future<void> pickChannels(List<int> available) async {
    final picked = {...(chFilter.isEmpty ? available : chFilter)};

    await showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          title: const Text('เลือก CH ที่ต้องการดู'),
          content: SizedBox(
            width: 420,
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final i in available)
                  FilterChip(
                    label: Text(chLabel(currentDevice.id, i)),
                    selected: picked.contains(i),
                    onSelected: (on) => setLocal(() {
                      on ? picked.add(i) : picked.remove(i);
                    }),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => setLocal(() => picked.addAll(available)),
              child: const Text('เลือกทั้งหมด'),
            ),
            TextButton(
              onPressed: () => setLocal(picked.clear),
              child: const Text('ล้าง'),
            ),
            FilledButton(
              onPressed: () {
                setState(() {
                  // nothing or everything picked = no filter
                  chFilter = picked.length == available.length
                      ? {}
                      : {...picked};
                });
                Navigator.of(context).pop();
              },
              child: const Text('ตกลง'),
            ),
          ],
        ),
      ),
    );
  }

  // quick filters: all / CH1-10 / CH11-20 / CH21-30 / pick yourself
  Widget chFilterBar(List<int> available) {
    if (available.length <= 5) return const SizedBox.shrink();

    final ranges = <(String, Set<int>)>[
      for (var start = 1; start <= channelCount; start += 10)
        if (available.any((i) => i >= start && i < start + 10))
          (
            'CH$start–${start + 9}',
            {
              for (final i in available)
                if (i >= start && i < start + 10) i,
            },
          ),
    ];

    bool same(Set<int> a) =>
        a.length == chFilter.length && a.containsAll(chFilter);

    final custom = chFilter.isNotEmpty && !ranges.any((r) => same(r.$2));

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          filterPill('ทั้งหมด', chFilter.isEmpty, () {
            setState(() => chFilter = {});
          }),
          for (final r in ranges)
            filterPill(
              r.$1,
              chFilter.isNotEmpty && same(r.$2),
              () => setState(() => chFilter = {...r.$2}),
            ),
          filterPill(
            custom ? 'เลือกเอง (${chFilter.length})' : 'เลือกเอง',
            custom,
            () => pickChannels(available),
          ),
        ],
      ),
    );
  }

  bool get timeFilterOn =>
      filterRange != 'all' && (filterRange != 'custom' || customDates != null);

  // the filter panel only has the date and the colors (ID has its own search)
  bool get hasFilter => timeFilterOn || filterColors.isNotEmpty;

  int get filterCount =>
      (timeFilterOn ? 1 : 0) + (filterColors.isNotEmpty ? 1 : 0);

  // dates are typed as Thai time (UTC+7), rows hold UTC
  DateTime asUtc(DateTime thai) => DateTime.utc(
    thai.year,
    thai.month,
    thai.day,
    thai.hour,
    thai.minute,
  ).subtract(const Duration(hours: 7));

  // start / end of the chosen period, in UTC (null = open ended)
  (DateTime?, DateTime?) timeBounds() {
    final now = DateTime.now().toUtc();
    final thaiNow = now.add(const Duration(hours: 7));

    switch (filterRange) {
      case 'hour':
        return (now.subtract(const Duration(hours: 1)), null);
      case 'today':
        final midnight = DateTime(thaiNow.year, thaiNow.month, thaiNow.day);
        return (asUtc(midnight), null);
      case 'week':
        return (now.subtract(const Duration(days: 7)), null);
      case 'custom':
        final d = customDates;
        if (d == null) return (null, null);

        final from = DateTime(
          d.start.year,
          d.start.month,
          d.start.day,
          customFrom.hour,
          customFrom.minute,
        );
        final to = DateTime(
          d.end.year,
          d.end.month,
          d.end.day,
          customTo.hour,
          customTo.minute,
        );

        // "to" includes the whole minute that was picked
        return (asUtc(from), asUtc(to).add(const Duration(seconds: 59)));
    }

    return (null, null);
  }

  String two(int n) => n.toString().padLeft(2, '0');

  String fmtDay(DateTime d) => '${two(d.day)}/${two(d.month)}';

  String fmtClock(TimeOfDay t) => '${two(t.hour)}:${two(t.minute)}';

  String timeLabel() {
    switch (filterRange) {
      case 'hour':
        return '1 ชั่วโมงล่าสุด';
      case 'today':
        return 'วันนี้';
      case 'week':
        return '7 วันล่าสุด';
      case 'custom':
        final d = customDates;
        if (d == null) return 'กำหนดเอง';

        return '${fmtDay(d.start)}–${fmtDay(d.end)} '
            '${fmtClock(customFrom)}–${fmtClock(customTo)}';
    }

    return 'ทั้งหมด';
  }

  List<Map<String, dynamic>> applyFilters(List<Map<String, dynamic>> all) {
    final (from, to) = timeBounds();

    return all.where((r) {
      if (filterId.isNotEmpty && !'${r['id']}'.contains(filterId)) {
        return false;
      }

      if (from != null || to != null) {
        final t = DateTime.tryParse('${r['created_at']}')?.toUtc();
        if (t == null) return false;
        if (from != null && t.isBefore(from)) return false;
        if (to != null && t.isAfter(to)) return false;
      }

      if (filterColors.isNotEmpty) {
        final hit = [
          for (var i = 1; i <= channelCount; i++) voltLevel(r['ch$i']),
        ].any((level) => level != null && filterColors.contains(level));

        if (!hit) return false;
      }

      return true;
    }).toList();
  }

  // search box for the ID (top-right of the card, outside the filter panel)
  Widget searchField() {
    return SizedBox(
      width: 200,
      height: 40,
      child: TextField(
        controller: filterIdCtrl,
        keyboardType: TextInputType.number,
        onChanged: (v) => setState(() => filterId = v.trim()),
        style: const TextStyle(fontSize: 14, color: navyDark),
        decoration: InputDecoration(
          hintText: 'ค้นหา ID',
          hintStyle: const TextStyle(fontSize: 14, color: mutedText),
          prefixIcon: const Icon(Icons.search_rounded, size: 20),
          suffixIcon: filterIdCtrl.text.isEmpty
              ? null
              : IconButton(
                  tooltip: 'ล้างการค้นหา',
                  iconSize: 18,
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => setState(() {
                    filterIdCtrl.clear();
                    filterId = '';
                  }),
                ),
          filled: true,
          fillColor: tileColor,
          contentPadding: EdgeInsets.zero,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }

  // clears the filter panel (the ID search box is separate)
  void clearFilters() => setState(() {
    filterRange = 'all';
    customDates = null;
    filterColors.clear();
  });

  Future<void> pickCustomDates() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      initialDateRange: customDates,
    );

    if (picked != null && mounted) setState(() => customDates = picked);
  }

  Future<void> pickClock(bool isFrom) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: isFrom ? customFrom : customTo,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      ),
    );

    if (picked == null || !mounted) return;

    setState(() => isFrom ? customFrom = picked : customTo = picked);
  }

  // a tick box for one color
  Widget colorPill(String key, String label, Color color) {
    final on = filterColors.contains(key);

    void toggle() =>
        setState(() => on ? filterColors.remove(key) : filterColors.add(key));

    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: toggle,
      child: Padding(
        padding: const EdgeInsets.only(right: 14),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Checkbox(
              value: on,
              activeColor: color,
              visualDensity: VisualDensity.compact,
              onChanged: (_) => toggle(),
            ),
            Icon(Icons.circle, size: 11, color: color),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: navyDark,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget clockButton(String label, TimeOfDay t, VoidCallback onTap) {
    return Expanded(
      child: OutlinedButton.icon(
        onPressed: onTap,
        icon: const Icon(Icons.schedule_rounded, size: 17),
        label: Text('$label ${fmtClock(t)}'),
        style: OutlinedButton.styleFrom(
          foregroundColor: navyDark,
          side: const BorderSide(color: Color(0xFFD9E0F0)),
          minimumSize: const Size(0, 42),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),
    );
  }

  Widget filterSection(String title, Widget child) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: navyDark,
            ),
          ),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }

  Widget filterPanel() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'ตัวกรอง',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: navyDark,
                  ),
                ),
              ),
              TextButton(
                onPressed: hasFilter ? clearFilters : null,
                child: const Text('ล้างทั้งหมด'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          filterSection(
            'สีของค่าใน CH',
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                colorPill('green', 'ปกติ', valueGreen),
                colorPill('yellow', 'เฝ้าระวัง', const Color(0xFFE0A100)),
                colorPill('red', 'วิกฤต', const Color(0xFFE5484D)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // the "ตัวกรอง" button + the dropdown panel that opens under it
  Widget filterButton() {
    final active = hasFilter;

    return CompositedTransformTarget(
      link: filterLink,
      child: OverlayPortal(
        controller: filterPortal,
        overlayChildBuilder: (overlayContext) => Stack(
          children: [
            // click anywhere outside to close
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: filterPortal.hide,
              ),
            ),
            CompositedTransformFollower(
              link: filterLink,
              targetAnchor: Alignment.bottomRight,
              followerAnchor: Alignment.topRight,
              offset: const Offset(0, 8),
              child: Material(
                elevation: 12,
                shadowColor: navyDark.withValues(alpha: 0.35),
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: 380,
                    maxHeight: 560,
                  ),
                  child: SizedBox(
                    width: 380,
                    child: SingleChildScrollView(child: filterPanel()),
                  ),
                ),
              ),
            ),
          ],
        ),
        child: OutlinedButton.icon(
          onPressed: filterPortal.toggle,
          icon: const Icon(Icons.filter_list_rounded, size: 18),
          label: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(active ? 'ตัวกรอง ($filterCount)' : 'ตัวกรอง'),
              const Icon(Icons.arrow_drop_down_rounded, size: 22),
            ],
          ),
          style: OutlinedButton.styleFrom(
            // grey button (dark grey and filled while a filter is on)
            foregroundColor: active ? Colors.white : const Color(0xFF6B7280),
            backgroundColor: active ? const Color(0xFF6B7280) : null,
            side: BorderSide(
              color: active ? const Color(0xFF6B7280) : const Color(0xFFB8C0CC),
            ),
            minimumSize: const Size(0, 40),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        ),
      ),
    );
  }

  // what is currently filtered, each can be removed by itself
  Widget activeFilters() {
    if (!hasFilter) return const SizedBox.shrink();

    String colorNames() => filterColors
        .map((k) => {'green': 'ปกติ', 'yellow': 'เฝ้าระวัง', 'red': 'วิกฤต'}[k])
        .join(', ');

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          if (timeFilterOn)
            InputChip(
              label: Text('เวลา: ${timeLabel()}'),
              onDeleted: () => setState(() {
                filterRange = 'all';
                customDates = null;
              }),
            ),
          if (filterColors.isNotEmpty)
            InputChip(
              label: Text('สี: ${colorNames()}'),
              onDeleted: () => setState(filterColors.clear),
            ),
          TextButton(onPressed: clearFilters, child: const Text('ล้างทั้งหมด')),
        ],
      ),
    );
  }
}
