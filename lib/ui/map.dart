// Map card, info box, zoom buttons
part of '../main.dart';

// ignore_for_file: invalid_use_of_protected_member, unused_element

extension _MapUi on _Ads1115PageState {
  // bring the given locations into view (one location: centre on it)
  void fitMapTo(List<Device> list) {
    final pts = [for (final d in list) LatLng(d.lat, d.lng)];
    if (pts.length == 1) {
      mapController.move(pts.first, 12);
      return;
    }
    mapController.fitCamera(
      CameraFit.coordinates(
        coordinates: pts,
        padding: const EdgeInsets.all(56),
        maxZoom: 12,
      ),
    );
  }

  void zoomMap(double delta) {
    final cam = mapController.camera;
    mapController.move(cam.center, (cam.zoom + delta).clamp(4.0, 19.0));
  }

  Widget mapRoundButton(IconData icon, String tip, VoidCallback onTap) {
    return Tooltip(
      message: tip,
      child: Material(
        color: Colors.white,
        elevation: 3,
        shadowColor: navyDark.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: SizedBox(
            width: 38,
            height: 38,
            child: Icon(icon, size: 21, color: navyDark),
          ),
        ),
      ),
    );
  }

  String coordText(Device d) =>
      '${d.lat.toStringAsFixed(5)}, ${d.lng.toStringAsFixed(5)}';

  // The whole card is kept as it is until something it shows changes, so the
  // 3-second data refresh does not repaint it (that made it flicker).
  Widget mapPanel({List<Device>? only}) {
    final all = only ?? devices;

    Device? pinned;
    for (final d in all) {
      if (d.id == mapPin) pinned = d;
    }
    final pinnedRows = pinned == null ? null : rowsFor(pinned);

    final key =
        '$selectedMenu|$selectedDevice|$mapPin|$mapExpanded|$mapActive|'
        '${pinnedRows == null || pinnedRows.isEmpty ? '' : pinnedRows.first['created_at']}|'
        '${[for (final d in all) '${d.id}:${d.name}:${d.lat}:${d.lng}:${stationLook(d).$2}'].join(',')}';

    if (mapPanelCache == null || key != mapPanelKey) {
      mapPanelKey = key;
      mapPanelCache = buildMapPanel(only: only);
    }
    return mapPanelCache!;
  }

  Widget buildMapPanel({List<Device>? only}) {
    // default: only the given location; "แสดงทุกสถานที่" adds the others
    final all = only ?? devices;
    final big = mapExpanded;
    final pts = [for (final d in all) LatLng(d.lat, d.lng)];
    final one = all.length == 1;
    final locked = only != null; // data page map
    final zoomOn = !locked || mapActive || big;

    // the map is rebuilt only when something it shows changes, so the
    // 3-second data refresh never makes it flicker
    final sig =
        '$selectedMenu|$selectedDevice|$mapPin|$zoomOn|'
        '${[for (final d in all) '${d.id}:${d.lat}:${d.lng}:${stationLook(d).$2}'].join(',')}';

    // the data-page map is locked: the wheel only zooms after a click on it
    final flags = zoomOn
        ? (InteractiveFlag.drag |
              InteractiveFlag.pinchZoom |
              InteractiveFlag.scrollWheelZoom |
              InteractiveFlag.doubleTapZoom |
              InteractiveFlag.flingAnimation)
        : (InteractiveFlag.drag | InteractiveFlag.flingAnimation);

    Device? pinned;
    for (final d in all) {
      if (d.id == mapPin) pinned = d;
    }

    // title (small map: with the button that makes it big)
    final header = Material(
      color: Colors.white,
      elevation: 3,
      shadowColor: navyDark.withValues(alpha: 0.35),
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: EdgeInsets.fromLTRB(10, 4, big ? 12 : 4, 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.map_rounded, size: 18, color: primaryBlue),
            const SizedBox(width: 6),
            Text(
              one ? 'ตำแหน่งสถานที่' : 'แผนที่สถานที่',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: navyDark,
              ),
            ),
            // add a location (paste a Google Maps link for its position)
            const SizedBox(width: 6),
            Tooltip(
              message: 'เพิ่มสถานที่ (วางลิงก์ Google Maps)',
              child: InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () => showPlaceDialog(),
                child: const Padding(
                  padding: EdgeInsets.all(5),
                  child: Icon(
                    Icons.add_location_alt_rounded,
                    size: 19,
                    color: primaryBlue,
                  ),
                ),
              ),
            ),
            if (!big) ...[
              const SizedBox(width: 6),
              Tooltip(
                message: 'ขยายแผนที่เต็มจอ',
                child: InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: () => setState(() => mapExpanded = true),
                  child: const Padding(
                    padding: EdgeInsets.all(5),
                    child: Icon(
                      Icons.open_in_full_rounded,
                      size: 18,
                      color: navyDark,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );

    return MouseRegion(
      // the pointer leaves the map: it is locked again
      onExit: (_) {
        if (mapActive) setState(() => mapActive = false);
      },
      child: Listener(
        // a click on the map unlocks its wheel zoom
        onPointerDown: (_) {
          if (!mapActive) setState(() => mapActive = true);
        },
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(big ? 20 : 16),
            boxShadow: [
              BoxShadow(
                color: navyDark.withValues(alpha: 0.28),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(big ? 20 : 16),
            child: Stack(
              children: [
                cachedMap(
                  sig,
                  () => FlutterMap(
                    mapController: mapController,
                    options: MapOptions(
                      // one location: centred on it; several: all of them in view
                      initialCenter: one
                          ? pts.first
                          : const LatLng(13.0, 101.0),
                      initialZoom: one ? 12 : 6,
                      initialCameraFit: one
                          ? null
                          : CameraFit.coordinates(
                              coordinates: pts,
                              padding: const EdgeInsets.all(40),
                              maxZoom: 12,
                            ),
                      minZoom: 4,
                      interactionOptions: InteractionOptions(flags: flags),
                      maxZoom: 19,
                      onTap: (_, _) => setState(() => mapPin = null),
                    ),
                    children: [
                      mapTiles,
                      MarkerLayer(
                        markers: [
                          for (final d in all)
                            Marker(
                              point: LatLng(d.lat, d.lng),
                              width: 48,
                              height: 52,
                              alignment: Alignment.topCenter,
                              child: Tooltip(
                                message: '${d.name}\n${coordText(d)}',
                                child: MouseRegion(
                                  cursor: SystemMouseCursors.click,
                                  child: GestureDetector(
                                    // a click on the small map opens the big one
                                    onTap: () => setState(() {
                                      mapPin = d.id;
                                      mapExpanded = true;
                                    }),
                                    child: Icon(
                                      Icons.location_on,
                                      size: mapPin == d.id ? 48 : 40,
                                      color: stationLook(d).$1,
                                      shadows: const [
                                        Shadow(
                                          color: Color(0x55000000),
                                          blurRadius: 6,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                Positioned(top: 10, left: 10, child: header),
                // big map: the red cross in the top-right corner shrinks it again
                if (big)
                  Positioned(
                    top: 12,
                    right: 12,
                    child: Tooltip(
                      message: 'ย่อแผนที่',
                      child: Material(
                        color: Colors.white,
                        elevation: 3,
                        shape: const CircleBorder(),
                        child: InkWell(
                          customBorder: const CircleBorder(),
                          onTap: () => setState(() => mapExpanded = false),
                          child: const SizedBox(
                            width: 40,
                            height: 40,
                            child: Icon(
                              Icons.close_rounded,
                              size: 26,
                              color: Color(0xFFE5484D),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                // zoom buttons: bottom-right corner (big map only)
                if (big)
                  Positioned(
                    right: 12,
                    bottom: 26,
                    child: Column(
                      children: [
                        mapRoundButton(Icons.add, 'ซูมเข้า', () => zoomMap(1)),
                        const SizedBox(height: 8),
                        mapRoundButton(
                          Icons.remove,
                          'ซูมออก',
                          () => zoomMap(-1),
                        ),
                        const SizedBox(height: 8),
                        mapRoundButton(
                          Icons.fit_screen_rounded,
                          one ? 'กลับไปที่สถานที่นี้' : 'ดูทุกสถานที่',
                          () => fitMapTo(all),
                        ),
                      ],
                    ),
                  ),
                // legend
                if (big)
                  Positioned(
                    left: 12,
                    top: 62,
                    child: Material(
                      color: Colors.white,
                      elevation: 3,
                      borderRadius: BorderRadius.circular(10),
                      child: Padding(
                        padding: const EdgeInsets.all(10),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            legendDot(valueGreen, 'ปกติ'),
                            const SizedBox(height: 4),
                            legendDot(const Color(0xFFE0A100), 'เฝ้าระวัง'),
                            const SizedBox(height: 4),
                            legendDot(const Color(0xFFE5484D), 'วิกฤต'),
                            const SizedBox(height: 4),
                            legendDot(mutedText, 'Offline'),
                          ],
                        ),
                      ),
                    ),
                  ),
                // info box of the location that was clicked (bottom-left, large)
                if (big && pinned != null)
                  Positioned(left: 12, bottom: 12, child: mapInfoBox(pinned)),
                // locked map: tell the user how to zoom with the wheel
                if (locked && !zoomOn)
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 30,
                    child: IgnorePointer(
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 7,
                          ),
                          decoration: BoxDecoration(
                            color: navyDark.withValues(alpha: 0.78),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Text(
                            'คลิกที่แผนที่ก่อน จึงซูมด้วยล้อเมาส์ได้',
                            style: TextStyle(
                              fontSize: 12.5,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                const Positioned(
                  right: 6,
                  bottom: 4,
                  child: Text(
                    '© OpenStreetMap contributors',
                    style: TextStyle(fontSize: 10, color: Color(0xFF4B5675)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget mapInfoBox(Device d) {
    final (color, label) = stationLook(d);
    final r = rowsFor(d);
    final c = r.isEmpty ? null : levelCounts(r.first);

    return Material(
      color: Colors.white,
      elevation: 8,
      shadowColor: navyDark.withValues(alpha: 0.4),
      borderRadius: BorderRadius.circular(18),
      child: Container(
        width: 430,
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    d.mock ? '${d.name} (จำลอง)' : d.name,
                    style: const TextStyle(
                      fontSize: 21,
                      fontWeight: FontWeight.w800,
                      color: navyDark,
                    ),
                  ),
                ),
                InkWell(
                  onTap: () => setState(() => mapPin = null),
                  child: const Icon(Icons.close_rounded, size: 22),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'สถานะ: $label',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ),
            const SizedBox(height: 12),
            if (c != null)
              Text(
                'ปกติ ${c.green} • เฝ้าระวัง ${c.yellow} • วิกฤต ${c.red} CH',
                style: const TextStyle(fontSize: 16, color: navyDark),
              ),
            if (r.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                'ข้อมูลล่าสุด ${formatThaiTime(r.first['created_at']?.toString())}',
                style: const TextStyle(fontSize: 14, color: mutedText),
              ),
            ],
            const SizedBox(height: 14),
            // latitude / longitude, ready to paste into Google Maps
            Container(
              padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
              decoration: BoxDecoration(
                color: tileColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'ละติจูด  ${d.lat.toStringAsFixed(5)}',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: Colors.black87,
                          ),
                        ),
                        Text(
                          'ลองจิจูด  ${d.lng.toStringAsFixed(5)}',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: Colors.black87,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Tooltip(
                    message: 'คัดลอกพิกัดไปวางใน Google Maps',
                    child: IconButton(
                      onPressed: () async {
                        await Clipboard.setData(
                          ClipboardData(text: coordText(d)),
                        );
                        showSaved('คัดลอกพิกัด ${coordText(d)} แล้ว');
                      },
                      icon: const Icon(Icons.copy_rounded, size: 20),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () {
                  setState(() {
                    selectedDevice = d.id;
                    selectedMenu = 0;
                    mapPin = null;
                  });
                  loadTrend();
                },
                style: FilledButton.styleFrom(
                  backgroundColor: primaryBlue,
                  minimumSize: const Size(0, 46),
                  textStyle: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('ดูข้อมูลสถานที่นี้'),
              ),
            ),
            if (!d.mock) ...[
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => showPlaceDialog(editing: d),
                  icon: const Icon(Icons.edit_location_alt_rounded, size: 20),
                  label: const Text(
                    'แก้ไขชื่อ / ตำแหน่ง (วางลิงก์ Google Maps)',
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: navyDark,
                    minimumSize: const Size(0, 44),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
            // remove the location from the app (hides it, data is kept)
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: TextButton.icon(
                onPressed: () => deletePlace(d),
                icon: const Icon(Icons.delete_outline_rounded, size: 20),
                label: const Text('ลบสถานที่นี้'),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.red,
                  minimumSize: const Size(0, 42),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
