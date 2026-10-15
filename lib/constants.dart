import 'package:flutter/material.dart';

// ============================================================
// COLORS - DASHBOARD
// ============================================================
const Color navyDark = Color(0xFF1B2559);
const Color primaryBlue = Color(0xFF3F6BF0);
const Color primaryBlueDark = Color(0xFF2F55D4);
const Color backgroundColor = Color(0xFFEEF2FB);
const Color tileColor = Color(0xFFF3F6FD);
const Color mutedText = Color(0xFF8F9BB3);
const Color valueGreen = Color(0xFF16C784);
const Color cardColor = Colors.white;

// ============================================================
// CONFIG
// ============================================================
const int historyLimit = 50;
const int channelCount = 30; // max sensors (CH) per device

// real device used until Supabase answers
const String defaultRealSensor = '0x48';

// display names of real devices (sensor id -> name, e.g. a location)
const Map<String, String> deviceNames = {
  defaultRealSensor: 'เครื่องทดสอบ 0x48',
};

// simulated devices (not stored anywhere, only for testing the UI)
const List<String> mockDeviceNames = [
  'โรงงานระยอง',
  'สะพานพระราม 9',
  'ท่าเรือแหลมฉบัง',
  'อาคารสำนักงานใหญ่',
];

// a place the user named / moved: name + position
typedef Place = ({String name, double lat, double lng});

class Device {
  const Device({
    required this.id,
    required this.name,
    this.mock = false,
    this.lat = 13.7563,
    this.lng = 100.5018,
  });

  final String id;
  final String name;
  final bool mock;
  final double lat; // position on the map
  final double lng;
}

// map positions of real devices (sensor id -> latitude, longitude);
// a device that is not listed here is placed in Bangkok - replace these
// with the real locations
const Map<String, (double, double)> deviceCoords = {
  defaultRealSensor: (13.7563, 100.5018),
};

// positions of the simulated devices (same order as mockDeviceNames)
const List<(double, double)> mockCoords = [
  (12.6814, 101.2816), // โรงงานระยอง
  (13.6890, 100.5440), // สะพานพระราม 9
  (13.0827, 100.8830), // ท่าเรือแหลมฉบัง
  (13.7367, 100.5231), // อาคารสำนักงานใหญ่
];

// ============================================================
// SIZES AND PERIOD LISTS (used by several pages)
// ============================================================
const int infoCount = 5;

// pinned-table sizes
const double pinIdW = 80;
const double pinTimeW = 160;
const double colW = 96;
const double headH = 44;
const double rowH = 46;

// comparison periods: 1 day .. 6 months
const trendRanges = <String, String>{
  'day': '1 วัน',
  'week': '1 สัปดาห์',
  'month': '1 เดือน',
  '3m': '3 เดือน',
  '6m': '6 เดือน',
};

const trendDays = <String, int>{
  'day': 1,
  'week': 7,
  'month': 30,
  '3m': 90,
  '6m': 180,
};

// the alert card also has "latest" (the default)
const alertRanges = <String, String>{'latest': 'ล่าสุด', ...trendRanges};

// newest rows kept for one period of the history page
const histMax = 1000;
