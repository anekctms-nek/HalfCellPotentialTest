// Data page
part of '../main.dart';

// ignore_for_file: invalid_use_of_protected_member, unused_element

extension _DashboardPage on _Ads1115PageState {
  Widget dashboardPage(List<Map<String, dynamic>> rows) {
    final d = rows.first;

    return LayoutBuilder(
      builder: (context, c) {
        const pad = 20.0;
        const gap = 16.0;
        const cardPad = 40.0; // 20 on each side of a card
        const rowH = 380.0; // height of the alert + map row

        final inner = c.maxWidth - pad * 2 - cardPad;

        final grid = channelGrid(inner, channelsOf(currentDevice, [d]).length);
        final info = infoLayout(inner);

        // wide enough: name and all info items share one line
        final oneLine = inner >= 1250;

        // the red-value alert card sits above the "latest data" card
        final hasRed = rows.any((r) => redChannels(r).isNotEmpty);
        final wide = c.maxWidth >= 1000;

        // map of THIS location; one key per location keeps its own view
        final dev = currentDevice;
        final panel = KeyedSubtree(
          key: dataMapKeys.putIfAbsent(dev.id, () => GlobalKey()),
          child: mapPanel(only: [dev]),
        );
        final mapSlot = SizedBox(
          height: rowH,
          child: mapExpanded ? const SizedBox.shrink() : panel,
        );
        final alertSlot = SizedBox(
          height: rowH,
          child: alertCard(rows, fill: true),
        );

        return Stack(
          children: [
            ListView(
              padding: const EdgeInsets.all(pad),
              children: [
                sensorCard(d, rows, info, oneLine),
                const SizedBox(height: gap),
                readingsPanel(d, grid),
                const SizedBox(height: gap),
                // alert card (half size) on the left, the map on the right
                if (hasRed && wide)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: alertSlot),
                      const SizedBox(width: gap),
                      Expanded(child: mapSlot),
                    ],
                  )
                else ...[
                  if (hasRed) ...[alertCard(rows), const SizedBox(height: gap)],
                  mapSlot,
                ],
                const SizedBox(height: gap),
                historyTable(rows, viewRows: 3),
              ],
            ),
            // big map: covers the page, the red cross brings it back
            if (mapExpanded)
              Positioned.fill(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  // fades in, so growing the map feels quick and smooth
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: 1),
                    duration: const Duration(milliseconds: 180),
                    builder: (context, v, child) =>
                        Opacity(opacity: v, child: child),
                    child: panel,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
