// Add CH page
part of '../main.dart';

// ignore_for_file: invalid_use_of_protected_member, unused_element

extension _AddChPage on _Ads1115PageState {
  // ============================================================
  // ADD CH PAGE
  // ============================================================

  // choose a picture now, it is saved together with the new CH
  Future<void> pickAddChPhoto() async {
    try {
      final res = await FilePicker.pickFiles(type: FileType.image);
      final path = res.isEmpty ? null : res.first.path;
      if (path != null) setState(() => addChPhoto = path);
    } catch (e) {
      debugPrint('PICK IMAGE ERROR = $e');
      showSaved('เลือกรูปไม่สำเร็จ');
    }
  }

  Future<void> addChannelNow(Device d, int ch) async {
    // 1) the CH itself
    setState(
      () => addedChannels = {
        ...addedChannels,
        d.id: {...?addedChannels[d.id], ch},
      },
    );
    await persistAddedChannels();

    // 2) its name
    final name = addChNameC.text.trim();
    if (name.isNotEmpty) {
      final names = {...?chNames[d.id]};
      names[ch] = name;
      setState(() => chNames = {...chNames, d.id: names});
      chControllers['${d.id}|$ch']?.text = name;
      await persistChNames();
    }

    // 3) the picture of where the sensor is
    final photo = addChPhoto;
    if (photo != null) {
      try {
        final base = await getApplicationSupportDirectory();
        final dir = Directory('${base.path}/sensor_images')
          ..createSync(recursive: true);
        final ext = photo.contains('.') ? photo.split('.').last : 'jpg';
        final copy = await File(photo).copy(
          '${dir.path}/${d.id}_${ch}_${DateTime.now().millisecondsSinceEpoch}'
          '.$ext',
        );
        setState(() => sensorImages['${d.id}|$ch'] = copy.path);
        await persistSensorImages();
      } catch (e) {
        debugPrint('SAVE IMAGE ERROR = $e');
      }
    }

    setState(() {
      addChNumber = null;
      addChPhoto = null;
      addChNameC.clear();
    });
    showSaved('เพิ่ม ${chLabel(d.id, ch)} ให้ "${d.name}" แล้ว');
  }

  Future<void> removeAddedChannel(Device d, int ch) async {
    setState(() {
      final left = {...?addedChannels[d.id]}..remove(ch);
      addedChannels = {...addedChannels, d.id: left};
    });
    await persistAddedChannels();
    showSaved('เอา CH$ch ออกจาก "${d.name}" แล้ว');
  }

  Widget addChPage() {
    final all = devices;
    final dev = all.firstWhere(
      (d) => d.id == (addChDevice ?? selectedDevice),
      orElse: () => all.first,
    );

    // CH numbers of this location that are still free
    final used = channelsOf(dev, rowsFor(dev)).toSet();
    final free = [
      for (var i = 1; i <= channelCount; i++)
        if (!used.contains(i)) i,
    ];
    final number = free.contains(addChNumber) ? addChNumber : null;

    Widget field(String label, Widget child, {double width = 300}) => SizedBox(
      width: width,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: navyDark,
            ),
          ),
          const SizedBox(height: 6),
          child,
        ],
      ),
    );

    Widget boxed(Widget child) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      height: 48,
      alignment: Alignment.centerLeft,
      decoration: BoxDecoration(
        color: tileColor,
        borderRadius: BorderRadius.circular(10),
      ),
      child: child,
    );

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        pageTitle('เพิ่ม CH'),
        const SizedBox(height: 6),
        Text(
          'เพิ่มช่องวัดใหม่ให้สถานที่ ตั้งชื่อ และใส่รูปตำแหน่งเซนเซอร์ได้เลย '
          'CH ที่เพิ่มจะขึ้นเป็น "-" จนกว่าจะมีข้อมูลเข้ามา',
          style: TextStyle(
            fontSize: 13,
            color: navyDark.withValues(alpha: 0.6),
          ),
        ),
        const SizedBox(height: 16),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: panelDecoration(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 20,
                runSpacing: 18,
                crossAxisAlignment: WrapCrossAlignment.start,
                children: [
                  field(
                    'สถานที่',
                    boxed(
                      DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: dev.id,
                          isExpanded: true,
                          borderRadius: BorderRadius.circular(12),
                          items: [
                            for (final d in all)
                              DropdownMenuItem(
                                value: d.id,
                                child: Text(
                                  d.mock ? '${d.name} (จำลอง)' : d.name,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                          ],
                          onChanged: (v) => setState(() {
                            addChDevice = v;
                            addChNumber = null;
                          }),
                        ),
                      ),
                    ),
                    width: 340,
                  ),
                  field(
                    'หมายเลข CH',
                    boxed(
                      DropdownButtonHideUnderline(
                        child: DropdownButton<int>(
                          value: number,
                          isExpanded: true,
                          hint: const Text('เลือก'),
                          borderRadius: BorderRadius.circular(12),
                          items: [
                            for (final i in free)
                              DropdownMenuItem(value: i, child: Text('CH$i')),
                          ],
                          onChanged: (v) => setState(() => addChNumber = v),
                        ),
                      ),
                    ),
                    width: 170,
                  ),
                  field(
                    'ชื่อ CH (ไม่ใส่ก็ได้)',
                    TextField(
                      controller: addChNameC,
                      maxLength: 20,
                      decoration: InputDecoration(
                        counterText: '',
                        hintText: 'เช่น เสาต้นที่ 3',
                        filled: true,
                        fillColor: tileColor,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    width: 300,
                  ),
                  field(
                    'รูปตำแหน่งเซนเซอร์ (ไม่ใส่ก็ได้)',
                    Row(
                      children: [
                        OutlinedButton.icon(
                          onPressed: pickAddChPhoto,
                          icon: const Icon(
                            Icons.add_photo_alternate_outlined,
                            size: 20,
                          ),
                          label: Text(
                            addChPhoto == null ? 'เลือกรูป' : 'เปลี่ยนรูป',
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: navyDark,
                            minimumSize: const Size(0, 48),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                        if (addChPhoto != null) ...[
                          const SizedBox(width: 10),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.file(
                              File(addChPhoto!),
                              width: 48,
                              height: 48,
                              fit: BoxFit.cover,
                            ),
                          ),
                          IconButton(
                            tooltip: 'เอารูปออก',
                            onPressed: () => setState(() => addChPhoto = null),
                            icon: const Icon(Icons.close_rounded, size: 18),
                          ),
                        ],
                      ],
                    ),
                    width: 360,
                  ),
                ],
              ),
              const SizedBox(height: 22),
              FilledButton.icon(
                onPressed: number == null
                    ? null
                    : () => addChannelNow(dev, number),
                icon: const Icon(Icons.add_rounded, size: 20),
                label: Text(
                  number == null ? 'เลือกหมายเลข CH ก่อน' : 'เพิ่ม CH$number',
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: primaryBlue,
                  minimumSize: const Size(0, 48),
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // CH that were added by hand, per location (they can be taken off)
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: panelDecoration(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'CH ที่เพิ่มไว้',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: navyDark,
                ),
              ),
              const SizedBox(height: 12),
              if (all.every((d) => (addedChannels[d.id] ?? {}).isEmpty))
                const Text(
                  'ยังไม่มี CH ที่เพิ่มด้วยมือ',
                  style: TextStyle(color: mutedText),
                )
              else
                for (final d in all)
                  if ((addedChannels[d.id] ?? {}).isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          SizedBox(
                            width: 220,
                            child: Text(
                              d.mock ? '${d.name} (จำลอง)' : d.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                color: navyDark,
                              ),
                            ),
                          ),
                          for (final ch in ([...addedChannels[d.id]!]..sort()))
                            InputChip(
                              label: Text(chLabel(d.id, ch)),
                              onDeleted: () => removeAddedChannel(d, ch),
                            ),
                        ],
                      ),
                    ),
            ],
          ),
        ),
      ],
    );
  }
}
