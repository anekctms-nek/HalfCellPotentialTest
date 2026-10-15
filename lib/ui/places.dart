// Add / edit / delete a location, Google Maps link reader
part of '../main.dart';

// ignore_for_file: invalid_use_of_protected_member, unused_element

extension _Places on _Ads1115PageState {
  Future<void> loadPlaces() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('places');
      if (raw == null) return;

      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      final loaded = <String, Place>{
        for (final e in decoded.entries)
          e.key: (
            name: (e.value as Map)['name'].toString(),
            lat: ((e.value as Map)['lat'] as num).toDouble(),
            lng: ((e.value as Map)['lng'] as num).toDouble(),
          ),
      };

      if (mounted) setState(() => placeOverrides = loaded);
    } catch (e) {
      debugPrint('LOAD PLACES ERROR = $e');
    }
  }

  Future<void> persistPlaces() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        'places',
        jsonEncode({
          for (final e in placeOverrides.entries)
            e.key: {
              'name': e.value.name,
              'lat': e.value.lat,
              'lng': e.value.lng,
            },
        }),
      );
    } catch (e) {
      debugPrint('SAVE PLACES ERROR = $e');
    }
  }

  // latitude / longitude out of a Google Maps link or typed coordinates;
  // null when nothing usable is found
  (double, double)? parseMapText(String text) {
    final t = Uri.decodeFull(text.trim());

    (double, double)? pick(RegExpMatch? m) {
      if (m == null) return null;
      final lat = double.tryParse(m.group(1)!);
      final lng = double.tryParse(m.group(2)!);
      if (lat == null || lng == null) return null;
      if (lat.abs() > 90 || lng.abs() > 180) return null;
      return (lat, lng);
    }

    const n = r'(-?\d+(?:\.\d+)?)';

    // the pin itself (!3d..!4d..), then the map centre (@lat,lng),
    // then ?q=lat,lng, then plain "lat, lng"
    return pick(RegExp('!3d$n!4d$n').firstMatch(t)) ??
        pick(RegExp('@$n,$n').firstMatch(t)) ??
        pick(RegExp('[?&](?:q|query|ll|center)=$n,\\s*$n').firstMatch(t)) ??
        pick(RegExp('^\\s*$n\\s*[, ]\\s*$n\\s*\$').firstMatch(t));
  }

  // short links (maps.app.goo.gl / goo.gl) are followed to the real address
  Future<(double, double)?> resolveMapPosition(String text) async {
    final direct = parseMapText(text);
    if (direct != null) return direct;

    final url = Uri.tryParse(text.trim());
    if (url == null || !url.hasScheme) return null;

    final client = HttpClient()..connectionTimeout = const Duration(seconds: 8);
    try {
      var current = url;
      for (var i = 0; i < 6; i++) {
        final req = await client.getUrl(current);
        req.followRedirects = false;
        final res = await req.close();
        await res.drain<void>();

        final loc = res.headers.value('location');
        if (loc == null) break;

        current = current.resolve(loc);
        final p = parseMapText(current.toString());
        if (p != null) return p;
      }
    } catch (e) {
      debugPrint('MAP LINK ERROR = $e');
    } finally {
      client.close();
    }

    return null;
  }

  Future<void> loadHiddenPlaces() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getStringList('hidden_places');
      if (saved != null && mounted) {
        setState(() => hiddenPlaces = saved.toSet());
      }
    } catch (e) {
      debugPrint('LOAD HIDDEN ERROR = $e');
    }
  }

  Future<void> persistHiddenPlaces() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('hidden_places', hiddenPlaces.toList());
    } catch (e) {
      debugPrint('SAVE HIDDEN ERROR = $e');
    }
  }

  // number of rows the sensor has in the database (null = could not count)
  Future<int?> countSensorRows(String sensor) async {
    try {
      final res = await supabase
          .from('ads1115_data')
          .select('id')
          .eq('sensor', sensor)
          .limit(1)
          .count(CountOption.exact);
      return res.count;
    } catch (e) {
      debugPrint('COUNT ERROR = $e');
      return null;
    }
  }

  Future<void> deletePlace(Device d) async {
    if (devices.length <= 1) {
      showSaved('ลบไม่ได้ ต้องเหลืออย่างน้อย 1 สถานที่');
      return;
    }

    final rowsInDb = d.mock ? 0 : await countSensorRows(d.id);
    if (!mounted) return;

    var understood = false;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: const Text('ลบสถานที่'),
          content: SizedBox(
            width: 440,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('ลบ "${d.name}" ?', style: const TextStyle(fontSize: 16)),
                const SizedBox(height: 10),
                if (d.mock)
                  const Text(
                    'เป็นสถานที่จำลอง ไม่มีข้อมูลในฐานข้อมูล '
                    '(กู้คืนได้จากหน้าต่าง "เพิ่มสถานที่")',
                    style: TextStyle(fontSize: 13, color: mutedText),
                  )
                else ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF4F4),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: Colors.red.withValues(alpha: 0.4),
                      ),
                    ),
                    child: Text(
                      rowsInDb == null
                          ? 'จะลบข้อมูลทั้งหมดของเซนเซอร์ ${d.id} ในฐานข้อมูล '
                                'อย่างถาวร และกู้คืนไม่ได้'
                          : 'จะลบข้อมูลของเซนเซอร์ ${d.id} ในฐานข้อมูล '
                                '$rowsInDb แถว อย่างถาวร และกู้คืนไม่ได้',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFFB42318),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    value: understood,
                    onChanged: (v) => setLocal(() => understood = v == true),
                    title: const Text(
                      'ฉันเข้าใจว่าข้อมูลจะถูกลบถาวร',
                      style: TextStyle(fontSize: 14),
                    ),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('ยกเลิก'),
            ),
            FilledButton(
              onPressed: (d.mock || understood)
                  ? () => Navigator.of(ctx).pop(true)
                  : null,
              style: FilledButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('ลบสถานที่'),
            ),
          ],
        ),
      ),
    );

    if (ok != true || !mounted) return;

    if (!d.mock) {
      try {
        await supabase.from('ads1115_data').delete().eq('sensor', d.id);
      } catch (e) {
        debugPrint('DELETE ERROR = $e');
        showSaved('ลบข้อมูลในฐานข้อมูลไม่สำเร็จ');
        return;
      }

      // the database may refuse silently (no permission): check
      final left = await countSensorRows(d.id);
      if (left != null && left > 0) {
        showSaved('ฐานข้อมูลไม่อนุญาตให้ลบ (ยังเหลือ $left แถว)');
        return;
      }
    }

    if (!mounted) return;

    setState(() {
      mapPin = null;

      if (d.mock) {
        hiddenPlaces.add(d.id);
      } else {
        // its rows are gone: forget them, the name / position and the cache
        history = [
          for (final r in history)
            if (r['sensor']?.toString() != d.id) r,
        ];
        placeOverrides.remove(d.id);
        hiddenPlaces.remove(d.id);
        seriesCache.removeWhere((k, _) => k.startsWith('${d.id}|'));
        histCache.removeWhere((k, _) => k.startsWith('${d.id}|'));
        // keep at least one place on screen if that was the only real one
        if (devices.where((x) => x.id == d.id).isNotEmpty) {
          hiddenPlaces.add(d.id);
        }
      }

      // the deleted place was the open one: move to the first that is left
      if (selectedDevice == d.id) selectedDevice = devices.first.id;
    });

    await persistPlaces();
    await persistHiddenPlaces();
    loadTrend();
    showSaved('ลบสถานที่ "${d.name}" แล้ว');
  }

  // dialog to add a location, or to change the name / position of one
  Future<void> showPlaceDialog({Device? editing}) async {
    final nameC = TextEditingController(text: editing?.name ?? '');
    final sensorC = TextEditingController(text: editing?.id ?? '');
    final linkC = TextEditingController(
      text: editing == null ? '' : coordText(editing),
    );
    String? error;
    var busy = false;

    final removable = editing != null && placeOverrides.containsKey(editing.id);

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: Text(editing == null ? 'เพิ่มสถานที่' : 'แก้ไขสถานที่'),
          content: SizedBox(
            width: 480,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: nameC,
                  decoration: const InputDecoration(labelText: 'ชื่อสถานที่'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: sensorC,
                  enabled: editing == null,
                  decoration: const InputDecoration(
                    labelText: 'รหัสเซนเซอร์ (Sensor ID) เช่น 0x49',
                    helperText: 'ตรงกับค่า sensor ของข้อมูลในฐานข้อมูล',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: linkC,
                  minLines: 1,
                  maxLines: 3,
                  decoration: InputDecoration(
                    labelText: 'ลิงก์ Google Maps หรือพิกัด',
                    hintText:
                        'https://maps.app.goo.gl/… หรือ 13.7563, 100.5018',
                    errorText: error,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'วิธีใช้: เปิด Google Maps แล้วกดแชร์ (หรือคลิกขวาที่ตำแหน่ง) '
                  'คัดลอกลิงก์หรือพิกัด แล้ววางในช่องด้านบน',
                  style: TextStyle(fontSize: 12, color: mutedText),
                ),
                // places that were deleted can be brought back from here
                if (editing == null && hiddenPlaces.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  const Text(
                    'กู้คืนสถานที่ที่ลบไว้',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: navyDark,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final d in allDevices)
                        if (hiddenPlaces.contains(d.id))
                          ActionChip(
                            avatar: const Icon(Icons.restore_rounded, size: 16),
                            label: Text(d.name),
                            onPressed: () async {
                              setState(() => hiddenPlaces.remove(d.id));
                              await persistHiddenPlaces();
                              setLocal(() {});
                              showSaved('กู้คืน "${d.name}" แล้ว');
                            },
                          ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          actions: [
            if (removable)
              TextButton(
                onPressed: () async {
                  setState(() => placeOverrides.remove(editing.id));
                  await persistPlaces();
                  if (ctx.mounted) Navigator.of(ctx).pop();
                  showSaved('คืนค่าสถานที่เป็นค่าเดิมแล้ว');
                },
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                child: const Text('คืนค่าเดิม'),
              ),
            if (editing != null)
              TextButton.icon(
                onPressed: () {
                  Navigator.of(ctx).pop();
                  deletePlace(editing);
                },
                icon: const Icon(Icons.delete_outline_rounded, size: 18),
                label: const Text('ลบสถานที่'),
                style: TextButton.styleFrom(foregroundColor: Colors.red),
              ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('ยกเลิก'),
            ),
            FilledButton(
              onPressed: busy
                  ? null
                  : () async {
                      final name = nameC.text.trim();
                      final sensor = sensorC.text.trim();

                      if (name.isEmpty || sensor.isEmpty) {
                        setLocal(
                          () => error = 'กรอกชื่อสถานที่และรหัสเซนเซอร์',
                        );
                        return;
                      }

                      setLocal(() {
                        busy = true;
                        error = null;
                      });

                      final pos = await resolveMapPosition(linkC.text);

                      if (pos == null) {
                        setLocal(() {
                          busy = false;
                          error =
                              'อ่านพิกัดจากลิงก์นี้ไม่ได้ ลองวางพิกัด เช่น 13.7563, 100.5018';
                        });
                        return;
                      }

                      setState(() {
                        placeOverrides[sensor] = (
                          name: name,
                          lat: pos.$1,
                          lng: pos.$2,
                        );
                        mapPin = sensor;
                        hiddenPlaces.remove(
                          sensor,
                        ); // adding it again brings it back
                      });
                      await persistPlaces();
                      await persistHiddenPlaces();

                      if (ctx.mounted) Navigator.of(ctx).pop();
                      showSaved('บันทึกสถานที่ "$name" แล้ว');
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        try {
                          mapController.move(LatLng(pos.$1, pos.$2), 12);
                        } catch (_) {}
                      });
                    },
              child: Text(busy ? 'กำลังอ่านลิงก์…' : 'บันทึก'),
            ),
          ],
        ),
      ),
    );

    nameC.dispose();
    sensorC.dispose();
    linkC.dispose();
  }
}
