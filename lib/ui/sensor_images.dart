// Picture of where each sensor is
part of '../main.dart';

// ignore_for_file: invalid_use_of_protected_member, unused_element

extension _SensorImages on _Ads1115PageState {
  Future<void> loadSensorImages() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('sensor_images');
      if (raw == null) return;

      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      final loaded = <String, String>{
        for (final e in decoded.entries)
          if (File(e.value.toString()).existsSync()) e.key: e.value.toString(),
      };

      if (mounted) setState(() => sensorImages = loaded);
    } catch (e) {
      debugPrint('LOAD IMAGES ERROR = $e');
    }
  }

  Future<void> persistSensorImages() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('sensor_images', jsonEncode(sensorImages));
    } catch (e) {
      debugPrint('SAVE IMAGES ERROR = $e');
    }
  }

  // choose a picture and keep a copy of it for this CH
  Future<void> pickSensorImage(Device d, int ch) async {
    try {
      final res = await FilePicker.pickFiles(type: FileType.image);
      final path = res.isEmpty ? null : res.first.path;
      if (path == null) return;

      final base = await getApplicationSupportDirectory();
      final dir = Directory('${base.path}/sensor_images')
        ..createSync(recursive: true);
      final ext = path.contains('.') ? path.split('.').last : 'jpg';
      final key = '${d.id}|$ch';
      final copy = await File(path).copy(
        '${dir.path}/${d.id}_${ch}_${DateTime.now().millisecondsSinceEpoch}'
        '.$ext',
      );

      // the old picture of this CH is no longer needed
      final old = sensorImages[key];
      if (old != null && File(old).existsSync()) File(old).deleteSync();

      setState(() => sensorImages[key] = copy.path);
      await persistSensorImages();
    } catch (e) {
      debugPrint('PICK IMAGE ERROR = $e');
      showSaved('เลือกรูปไม่สำเร็จ');
    }
  }

  Future<void> showSensorImageDialog(Device d, int ch) async {
    final key = '${d.id}|$ch';

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) {
          final path = sensorImages[key];

          return AlertDialog(
            title: Text('ตำแหน่งเซนเซอร์ • ${chLabel(d.id, ch)}'),
            content: SizedBox(
              width: 780,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: path == null
                        ? Container(
                            height: 220,
                            width: double.infinity,
                            color: tileColor,
                            alignment: Alignment.center,
                            child: const Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.add_photo_alternate_outlined,
                                  size: 48,
                                  color: mutedText,
                                ),
                                SizedBox(height: 8),
                                Text(
                                  'ยังไม่มีรูป อัปโหลดรูปเพื่อให้รู้ว่าเซนเซอร์อยู่ตรงไหน',
                                  style: TextStyle(color: mutedText),
                                ),
                              ],
                            ),
                          )
                        : ZoomableImage(key: ValueKey(path), path: path),
                  ),
                ],
              ),
            ),
            actions: [
              if (path != null)
                TextButton(
                  onPressed: () async {
                    final old = sensorImages[key];
                    if (old != null && File(old).existsSync()) {
                      File(old).deleteSync();
                    }
                    setState(() => sensorImages.remove(key));
                    await persistSensorImages();
                    setLocal(() {});
                  },
                  style: TextButton.styleFrom(foregroundColor: Colors.red),
                  child: const Text('ลบรูป'),
                ),
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('ปิด'),
              ),
              FilledButton.icon(
                onPressed: () async {
                  await pickSensorImage(d, ch);
                  setLocal(() {});
                },
                icon: const Icon(Icons.upload_rounded, size: 18),
                label: Text(path == null ? 'อัปโหลดรูป' : 'เปลี่ยนรูป'),
              ),
            ],
          );
        },
      ),
    );
  }
}
