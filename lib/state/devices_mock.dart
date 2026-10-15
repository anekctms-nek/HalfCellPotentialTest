// Locations (real + simulated) and the simulated data
part of '../main.dart';

// ignore_for_file: invalid_use_of_protected_member, unused_element

extension _DevicesAndMock on _Ads1115PageState {
  // ============================================================
  // DEVICES
  // ============================================================
  // locations shown in the app (deleted ones are hidden, never all of them)
  List<Device> get devices {
    final list = [
      for (final d in allDevices)
        if (!hiddenPlaces.contains(d.id)) d,
    ];

    return list.isEmpty ? allDevices : list;
  }

  List<Device> get allDevices {
    final sensors = <String>[];
    for (final r in history) {
      final s = r['sensor']?.toString();
      if (s != null && !sensors.contains(s)) sensors.add(s);
    }
    if (sensors.isEmpty) sensors.add(defaultRealSensor);
    // places added by the user whose sensor has no data yet
    for (final s in placeOverrides.keys) {
      if (!sensors.contains(s)) sensors.add(s);
    }

    return [
      for (final s in sensors)
        Device(
          id: s,
          name: placeOverrides[s]?.name ?? deviceNames[s] ?? 'เครื่อง $s',
          lat:
              placeOverrides[s]?.lat ??
              (deviceCoords[s] ?? const (13.7563, 100.5018)).$1,
          lng:
              placeOverrides[s]?.lng ??
              (deviceCoords[s] ?? const (13.7563, 100.5018)).$2,
        ),
      ...mockDevices,
    ];
  }

  Device get currentDevice => devices.firstWhere(
    (d) => d.id == selectedDevice,
    orElse: () => devices.first,
  );

  bool get isMock => currentDevice.mock;

  List<Map<String, dynamic>> get currentRows {
    final d = currentDevice;

    if (d.mock) return mockRows[d.id] ?? const [];

    return history.where((r) => r['sensor']?.toString() == d.id).toList();
  }

  // ============================================================
  // MOCK DEVICES (random number of CH)
  // ============================================================
  void setupMockDevices() {
    mockDevices = [
      for (var i = 0; i < mockDeviceNames.length; i++)
        Device(
          id: 'MOCK-${i + 1}',
          name: mockDeviceNames[i],
          mock: true,
          lat: mockCoords[i].$1,
          lng: mockCoords[i].$2,
        ),
    ];

    for (final d in mockDevices) {
      // the first simulated device always has the maximum (30 sensors),
      // the others get a random number of CH (2..30)
      final channels = d == mockDevices.first
          ? channelCount
          : 2 + random.nextInt(channelCount - 1);
      mockLevels[d.id] = [
        for (var i = 0; i < channels; i++) -0.25 - random.nextDouble() * 0.2,
      ];
      mockRows[d.id] = [];

      // some past rows, 3 seconds apart
      for (var i = 19; i >= 0; i--) {
        addMockRow(
          d,
          DateTime.now().toUtc().subtract(Duration(seconds: i * 3)),
        );
      }
    }

    mockTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (!mounted) return;

      setState(() {
        for (final d in mockDevices) {
          addMockRow(d, DateTime.now().toUtc());
        }
      });
    });
  }

  void addMockRow(Device d, DateTime time) {
    final levels = mockLevels[d.id]!;

    final row = <String, dynamic>{
      'id': mockRowId++,
      'sensor': d.id,
      'created_at': time.toIso8601String(),
    };

    for (var i = 0; i < levels.length; i++) {
      // simulated corrosion: the value only ever gets more negative, and
      // only now and then (about once a minute per CH), by a visible step
      if (random.nextDouble() < 0.04) {
        levels[i] = (levels[i] - (0.0006 + random.nextDouble() * 0.0025))
            .clamp(-0.6, 0.0)
            .toDouble();
      }
      row['ch${i + 1}'] = double.parse(levels[i].toStringAsFixed(3));
    }

    final rows = mockRows[d.id]!;
    rows.insert(0, row);
    if (rows.length > historyLimit) rows.removeLast();
  }
}
