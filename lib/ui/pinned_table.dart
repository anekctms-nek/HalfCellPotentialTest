// Table with pinned ID/time columns and wheel scrolling
part of '../main.dart';

// ignore_for_file: invalid_use_of_protected_member, unused_element

extension _PinnedTable on _Ads1115PageState {
  // ============================================================
  // HISTORY TABLE
  // ============================================================
  // Mouse wheel over a table, no click needed:
  //  - on the strip along the bottom edge (the sideways scrollbar): sideways
  //  - elsewhere: up/down; sideways with Shift + wheel, a tilt wheel / touchpad
  //    swipe, or when there is nothing to scroll up/down
  // When the table cannot move that way the wheel is left to the page.
  void wheelScroll(
    PointerSignalEvent event,
    ScrollController h,
    ScrollController? v, {
    bool sideways = false,
  }) {
    if (event is! PointerScrollEvent) return;

    final dx = event.scrollDelta.dx;
    final dy = event.scrollDelta.dy;
    final shift = HardwareKeyboard.instance.isShiftPressed;

    bool room(ScrollController? c, double delta) {
      if (c == null || !c.hasClients) return false;

      final p = c.position;

      return delta < 0
          ? p.pixels > p.minScrollExtent
          : p.pixels < p.maxScrollExtent;
    }

    final canUpDown =
        v != null && v.hasClients && v.position.maxScrollExtent > 0;
    final goSideways = sideways || dx != 0 || shift || !canUpDown;
    final delta = goSideways ? (dx != 0 ? dx : dy) : dy;
    final target = goSideways ? h : v;

    // nothing to move: let the page scroll instead
    if (!room(target, delta)) return;

    GestureBinding.instance.pointerSignalResolver.register(event, (_) {
      final c = target; // never null here: up/down needs a controller

      c.jumpTo(
        (c.offset + delta).clamp(
          c.position.minScrollExtent,
          c.position.maxScrollExtent,
        ),
      );
    });
  }

  // ID + time stay pinned on the left, the CH columns scroll sideways.
  // Values sit on a soft colored cell (green / yellow / red) instead of
  // colored text. [v] adds up/down scrolling (history page).

  Widget pinnedTable(
    List<Map<String, dynamic>> rows,
    List<int> channels, {
    required ScrollController h,
    ScrollController? v,
    Set<String> onlyColors = const {}, // not empty = show only these colors
    // row id -> CH whose value changed; null = every cell is shown
    Map<dynamic, Set<int>>? changedCells,
  }) {
    Color stripe(int n) =>
        n.isOdd ? tileColor.withValues(alpha: 0.5) : Colors.transparent;

    Widget textCell(
      String t,
      double w, {
      Color color = navyDark,
      FontWeight weight = FontWeight.w500,
    }) => SizedBox(
      width: w,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Text(
            t,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 13, color: color, fontWeight: weight),
          ),
        ),
      ),
    );

    // with a color filter only the cells of that color are shown,
    // the other cells of the row stay empty
    // changed value: soft colored cell; unchanged value: plain text, no color
    Widget valueCell(dynamic value, bool changed) =>
        (onlyColors.isNotEmpty && !onlyColors.contains(voltLevel(value)))
        ? const SizedBox(width: colW)
        : SizedBox(
            width: colW,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 7),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: (!changed || value == null)
                      ? Colors.transparent
                      : voltColor(value).withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Text(
                    value == null ? '-' : getValue(value).toStringAsFixed(3),
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: changed ? FontWeight.w600 : FontWeight.w400,
                      color: changed ? Colors.black87 : Colors.black45,
                    ),
                  ),
                ),
              ),
            ),
          );

    const head = FontWeight.w700;

    final left = SizedBox(
      width: pinIdW + pinTimeW,
      child: Column(
        children: [
          Container(
            height: headH,
            color: tileColor,
            child: Row(
              children: [
                textCell('ID', pinIdW, weight: head),
                textCell('เวลา', pinTimeW, weight: head),
              ],
            ),
          ),
          for (var n = 0; n < rows.length; n++)
            Container(
              height: rowH,
              color: stripe(n),
              child: Row(
                children: [
                  textCell('${rows[n]['id'] ?? '-'}', pinIdW, color: mutedText),
                  textCell(
                    formatThaiTime(rows[n]['created_at']?.toString()),
                    pinTimeW,
                    color: mutedText,
                  ),
                ],
              ),
            ),
        ],
      ),
    );

    final right = SizedBox(
      width: channels.length * colW,
      child: Column(
        children: [
          Container(
            height: headH,
            color: tileColor,
            child: Row(
              children: [
                for (final i in channels)
                  SizedBox(
                    width: colW,
                    child: Center(
                      child: Text(
                        chLabel(currentDevice.id, i),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: head,
                          color: navyDark,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          for (var n = 0; n < rows.length; n++)
            Container(
              height: rowH,
              color: stripe(n),
              child: Row(
                children: [
                  for (final i in channels)
                    valueCell(
                      rows[n]['ch$i'],
                      changedCells == null ||
                          (changedCells[rows[n]['id']]?.contains(i) ?? false),
                    ),
                ],
              ),
            ),
        ],
      ),
    );

    final behavior = ScrollConfiguration.of(context).copyWith(
      dragDevices: {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
        PointerDeviceKind.trackpad,
      },
      scrollbars: false,
    );

    // room for the horizontal scrollbar under the CH columns
    final horizontal = SingleChildScrollView(
      controller: h,
      scrollDirection: Axis.horizontal,
      child: Padding(padding: const EdgeInsets.only(bottom: 14), child: right),
    );

    // wheel over the table: up/down, or sideways when there is nothing to
    // scroll up/down (see wheelScroll)
    final body = Listener(
      onPointerSignal: (e) => wheelScroll(e, h, v),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          left,
          Expanded(child: horizontal),
        ],
      ),
    );

    final Widget table;

    if (v == null) {
      table = ScrollConfiguration(
        behavior: behavior,
        child: Listener(
          onPointerSignal: (e) => wheelScroll(e, h, v),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              left,
              Expanded(
                child: Scrollbar(
                  controller: h,
                  thumbVisibility: true,
                  child: horizontal,
                ),
              ),
            ],
          ),
        ),
      );
    } else {
      table = ScrollConfiguration(
        behavior: behavior,
        child: Scrollbar(
          controller: v,
          thumbVisibility: true,
          child: Scrollbar(
            controller: h,
            thumbVisibility: true,
            notificationPredicate: (n) => n.depth == 1,
            child: SingleChildScrollView(controller: v, child: body),
          ),
        ),
      );
    }

    // The strip along the bottom edge is the sideways scrollbar: just point
    // at it and turn the mouse wheel, no click needed. (It lets mouse clicks
    // and drags through to the scrollbar underneath.)
    return Stack(
      children: [
        table,
        Positioned(
          left: pinIdW + pinTimeW,
          right: 0,
          bottom: 0,
          height: 24,
          child: Listener(
            behavior: HitTestBehavior.translucent,
            onPointerSignal: (e) => wheelScroll(e, h, v, sideways: true),
            child: const SizedBox.expand(),
          ),
        ),
      ],
    );
  }
}
