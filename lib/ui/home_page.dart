// Home page layout
part of '../main.dart';

// ignore_for_file: invalid_use_of_protected_member, unused_element

extension _HomePage on _Ads1115PageState {
  Widget cachedMap(String sig, Widget Function() build) {
    if (mapCache == null || sig != mapCacheSig) {
      mapCacheSig = sig;
      mapCache = RepaintBoundary(child: build());
    }
    return mapCache!;
  }

  Widget homePage(List<Map<String, dynamic>> rows) {
    const gap = 16.0;
    const mapH = 280.0;

    // measure the connection card after the frame, rebuild only on a change
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final h = connKey.currentContext?.size?.height;
      if (!mounted || h == null) return;
      if (connHeight == null || (connHeight! - h).abs() > 1) {
        setState(() => connHeight = h);
      }
    });

    return LayoutBuilder(
      builder: (context, c) {
        final wide = c.maxWidth >= 1100;
        final panel = KeyedSubtree(key: mapKey, child: mapPanel());

        // the map is one more card; while it is big the card keeps its place
        Widget mapSlot(bool fill) {
          final inner = mapExpanded ? const SizedBox.shrink() : panel;
          return fill
              ? Expanded(child: inner)
              : SizedBox(height: mapH, child: inner);
        }

        final connection = KeyedSubtree(key: connKey, child: connectionCard());

        return Stack(
          children: [
            ListView(
              padding: const EdgeInsets.all(20),
              children: [
                performanceCard(),
                const SizedBox(height: gap),
                if (wide)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 7, child: connection),
                      const SizedBox(width: gap),
                      // report summary + map card: together exactly as tall
                      // as the connection-status card
                      Expanded(
                        flex: 3,
                        child: connHeight == null
                            ? Column(
                                children: [
                                  reportSummary(),
                                  const SizedBox(height: gap),
                                  mapSlot(false),
                                ],
                              )
                            : SizedBox(
                                height: max(connHeight!, 420),
                                child: Column(
                                  children: [
                                    reportSummary(),
                                    const SizedBox(height: gap),
                                    mapSlot(true),
                                  ],
                                ),
                              ),
                      ),
                    ],
                  )
                else ...[
                  connection,
                  const SizedBox(height: gap),
                  reportSummary(),
                  const SizedBox(height: gap),
                  mapSlot(false),
                ],
              ],
            ),
            // big map: covers the page, the button on it brings it back
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
