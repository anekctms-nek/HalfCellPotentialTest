// Page title, red channels, 2D scroll, simulated history
part of '../main.dart';

// ignore_for_file: invalid_use_of_protected_member, unused_element

extension _PageHelpers on _Ads1115PageState {
  // ============================================================
  // PAGES
  // ============================================================
  Widget pageTitle(String text) => Text(
    text,
    style: const TextStyle(
      fontSize: 24,
      fontWeight: FontWeight.w800,
      color: navyDark,
    ),
  );

  // ---------- alert: red values found ----------
  // channel numbers of a row whose value is red
  List<int> redChannels(Map<String, dynamic> r) => [
    for (var i = 1; i <= channelCount; i++)
      if (voltLevel(r['ch$i']) == 'red') i,
  ];

  // scrolls up/down and sideways (scrollbars, mouse drag, wheel,
  // Shift + wheel, or the wheel over the strip at the bottom edge)
  Widget scroll2D({
    required Widget child,
    required ScrollController h,
    required ScrollController v,
  }) {
    final behavior = ScrollConfiguration.of(context).copyWith(
      dragDevices: {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
        PointerDeviceKind.trackpad,
      },
      scrollbars: false,
    );

    return Stack(
      children: [
        ScrollConfiguration(
          behavior: behavior,
          child: Scrollbar(
            controller: v,
            thumbVisibility: true,
            child: Scrollbar(
              controller: h,
              thumbVisibility: true,
              notificationPredicate: (n) => n.depth == 1,
              child: SingleChildScrollView(
                controller: v,
                child: Listener(
                  onPointerSignal: (e) => wheelScroll(e, h, v),
                  child: SingleChildScrollView(
                    controller: h,
                    scrollDirection: Axis.horizontal,
                    // room for the scrollbars
                    child: Padding(
                      padding: const EdgeInsets.only(right: 14, bottom: 14),
                      child: child,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        Positioned(
          left: 0,
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

  // ---------- simulated history ----------
  // The value of a simulated CH drops in steps at irregular times: sometimes
  // every 1-7 days, sometimes only after a few weeks, mixed, not every day.
  // Same device + CH always give the same steps.
  List<({double age, double drop})> mockDrops(Device d, int ch) {
    final rnd = Random(d.id.hashCode * 31 + ch * 7919);
    final out = <({double age, double drop})>[];

    var age = rnd.nextDouble() * 5; // days ago of the newest drop
    while (age < 200) {
      out.add((age: age, drop: 0.003 + rnd.nextDouble() * 0.012));

      final kind = rnd.nextDouble();
      age += kind < 0.55
          ? 1 +
                rnd.nextDouble() *
                    6 // every 1-7 days
          : (kind < 0.8
                ? 8 +
                      rnd.nextDouble() *
                          14 // every 1-3 weeks
                : 22 + rnd.nextDouble() * 14); // about a month
    }

    return out;
  }

  // value [daysAgo] days ago: the drops that happened since then are put back
  double mockPastValue(Device d, int ch, double nowValue, double daysAgo) {
    var v = nowValue;
    for (final e in mockDrops(d, ch)) {
      if (e.age < daysAgo) v += e.drop;
    }
    return v;
  }
}
