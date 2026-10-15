import 'dart:async';
import 'dart:convert';
import 'dart:io' show Directory, File, HttpClient;
import 'dart:math';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'
    show Clipboard, ClipboardData, HardwareKeyboard;
import 'package:file_picker/file_picker.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' show LatLng;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'constants.dart';
import 'painters.dart';
import 'zoomable_image.dart';

part 'state/devices_mock.dart';
part 'state/remote_data.dart';
part 'state/user_names.dart';
part 'ui/add_ch_page.dart';
part 'ui/alert_connection.dart';
part 'ui/body.dart';
part 'ui/ch_names_page.dart';
part 'ui/dashboard_page.dart';
part 'ui/dashboard_widgets.dart';
part 'ui/filters.dart';
part 'ui/helpers.dart';
part 'ui/history_page.dart';
part 'ui/history_tables.dart';
part 'ui/home_cards.dart';
part 'ui/home_page.dart';
part 'ui/map.dart';
part 'ui/page_helpers.dart';
part 'ui/pinned_table.dart';
part 'ui/places.dart';
part 'ui/sensor_images.dart';
part 'ui/series_chart.dart';
part 'ui/settings_page.dart';
part 'ui/sidebar.dart';
part 'ui/top_bar.dart';
part 'ui/trend_alert.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://lgdinpmyfgqgslbdysok.supabase.co',
    publishableKey: 'sb_publishable_YzJiR_foA-pKIPtSaYU-hg_v4yUZSDD',
  );

  runApp(const MyApp());
}

// ============================================================
// APP
// ============================================================
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Half Cell Potential Test Monitor',
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: backgroundColor,
        colorScheme: ColorScheme.fromSeed(
          seedColor: primaryBlue,
          brightness: Brightness.light,
        ),
      ),
      home: const Ads1115Page(),
    );
  }
}

// ============================================================
// ADS1115 PAGE
// ============================================================
class Ads1115Page extends StatefulWidget {
  const Ads1115Page({super.key});

  @override
  State<Ads1115Page> createState() => _Ads1115PageState();
}

class _Ads1115PageState extends State<Ads1115Page> {
  final supabase = Supabase.instance.client;

  final scaffoldKey = GlobalKey<ScaffoldState>();
  final nameController = TextEditingController();

  // dashboard: search by ID + sideways scroll of the data table
  final dashHScroll = ScrollController();
  final dashVScroll = ScrollController();

  // history page: scroll sideways and up/down
  final histHScroll = ScrollController();
  final histVScroll = ScrollController();

  // rows from Supabase (all real devices, newest first)
  List<Map<String, dynamic>> history = [];

  // simulated devices
  final random = Random();
  late final List<Device> mockDevices;
  final Map<String, List<Map<String, dynamic>>> mockRows = {};
  final Map<String, List<double>> mockLevels = {};
  Timer? mockTimer;

  // custom CH names: device id -> (channel number -> name)
  Map<String, Map<int, String>> chNames = {};
  final Map<String, TextEditingController> chControllers = {};
  int mockRowId = 1;

  String selectedDevice = defaultRealSensor;

  bool loading = true;
  String? error;

  int selectedMenu =
      4; // 0 = dashboard, 1 = history, 2 = settings, 3 = CH names, 4 = home

  String userName = 'ผู้ใช้งาน';

  RealtimeChannel? realtimeChannel;

  // ============================================================
  // INIT
  // ============================================================
  @override
  void initState() {
    super.initState();

    setupMockDevices();
    loadUserName();
    loadChNames();
    loadPlaces();
    loadAddedChannels();
    loadHiddenPlaces();
    loadSensorImages();
    loadLatestData();
    loadTrend();
    startRealtime();
  }

  // ============================================================
  // DISPOSE
  // ============================================================
  @override
  void dispose() {
    mockTimer?.cancel();
    mapController.dispose();
    addChNameC.dispose();
    nameController.dispose();
    filterIdCtrl.dispose();
    alertHScroll.dispose();
    alertVScroll.dispose();
    dashHScroll.dispose();
    dashVScroll.dispose();
    histHScroll.dispose();
    histVScroll.dispose();
    for (final c in chControllers.values) {
      c.dispose();
    }

    if (realtimeChannel != null) {
      supabase.removeChannel(realtimeChannel!);
    }

    super.dispose();
  }

  // ============================================================
  // THAI TIME +07:00
  // ============================================================
  String formatThaiTime(String? value) {
    if (value == null) {
      return '-';
    }

    try {
      final utc = DateTime.parse(value).toUtc();
      final thai = utc.add(const Duration(hours: 7));

      String two(int n) => n.toString().padLeft(2, '0');

      return '${two(thai.day)}/${two(thai.month)}/${thai.year} '
          '${two(thai.hour)}:${two(thai.minute)}:${two(thai.second)}';
    } catch (_) {
      return value;
    }
  }

  // ============================================================
  // BUILD
  // ============================================================
  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 900;

        return Scaffold(
          key: scaffoldKey,
          drawer: wide ? null : Drawer(child: sidebar(inDrawer: true)),
          body: Row(
            children: [
              if (wide) sidebar(),
              Expanded(
                child: Column(
                  children: [
                    topBar(wide),
                    Expanded(child: body()),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ============================================================
  // MORE STATE (used by the pages in ui/ and state/)
  // ============================================================

  // CH numbers a location has: the ones that have values + the ones added by
  // hand on the "เพิ่ม CH" page (they show "-" until data arrives)
  Map<String, Set<int>> addedChannels = {};

  // the side panel can be folded to icons only (never inside the drawer)
  bool sidebarCollapsed = false;

  bool logoHover = false; // mouse on the logo: it shows the fold arrow

  // ---------- photo of where a sensor is (one per CH of a location) ----------
  // "deviceId|ch" -> path of the picture (a copy kept in the app's folder)
  Map<String, String> sensorImages = {};

  // ---------- choose which CH to show ----------
  // empty = show every CH
  Set<int> chFilter = {};

  // ---------- filter of the "latest data" card ----------
  // a dropdown panel under the "ตัวกรอง" button, every change applies at once
  final filterIdCtrl = TextEditingController();

  final filterLink = LayerLink();

  final filterPortal = OverlayPortalController();

  String filterId = '';

  String filterRange = 'all'; // all / hour / today / week / custom

  DateTimeRange? customDates; // whole days, Thai time

  TimeOfDay customFrom = const TimeOfDay(hour: 0, minute: 0);

  TimeOfDay customTo = const TimeOfDay(hour: 23, minute: 59);

  final Set<String> filterColors = {}; // green / yellow / red, empty = any

  bool latestOpen = true; // the "latest data" chart can be hidden

  final alertHScroll = ScrollController();

  final alertVScroll = ScrollController();

  // ---------- comparison with the past (1 day .. 6 months) ----------
  // each card has its own period: alert (default = latest data), latest-data
  // chart, history page
  String alertRange = 'latest';

  String seriesRange = 'day';

  String histRange = 'day';

  // period key -> the reading that was current that long ago (null = none)
  Map<String, Map<String, dynamic>?> pastRows = {};

  bool trendLoading = false;

  int trendToken = 0;

  // "latest data" card: line chart of ONE chosen CH over 1 day / 1 week /
  // 1 month / 3 months / 6 months
  int? compareCh;

  // period key -> (spacing between points, number of points)
  ({Duration span, int points}) seriesSpec(String key) => switch (key) {
    'day' => (span: const Duration(hours: 1), points: 24),
    'week' => (span: const Duration(hours: 6), points: 28),
    'month' => (span: const Duration(days: 1), points: 30),
    '3m' => (span: const Duration(days: 3), points: 30),
    _ => (span: const Duration(days: 6), points: 30),
  };

  // "device|period" -> one reading per time slot (null = no data then)
  final Map<String, List<({DateTime t, Map<String, dynamic>? row})>>
  seriesCache = {};

  bool seriesLoading = false;

  // CH hidden from the chart (all the others are drawn)
  final Set<int> hiddenCh = {};

  int? hoverCh; // CH whose line is highlighted (kept until another click)

  final seriesScroll = ScrollController();

  String? hoverStation; // station row the mouse is on

  // ---------- map of every location (home page) ----------
  final mapController = MapController();

  String? mapPin; // id of the location whose info box is open

  // colour of a station on the map: grey = offline, otherwise the worst
  // level among its CH (green normal / yellow warning / red critical)
  (Color, String) stationLook(Device d) {
    if (!deviceOnline(d)) return (mutedText, 'Offline');

    final r = rowsFor(d);
    final c = levelCounts(r.first);
    if (c.red > 0) return (const Color(0xFFE5484D), 'วิกฤต');
    if (c.yellow > 0) return (const Color(0xFFE0A100), 'เฝ้าระวัง');
    return (valueGreen, 'ปกติ');
  }

  // The map is a card that can grow to the whole page (and back).
  // pan with the mouse, zoom with the wheel (+ / − buttons when it is big).
  // [only] = show just these locations (the data page shows one location).
  bool mapExpanded = false;

  bool mapActive = false; // data page map: clicked, so the wheel zooms it

  // ---------- places added / moved by the user ----------
  // sensor id -> name + position. A place whose sensor has no data yet shows
  // as a location that is Offline until data arrives.
  Map<String, Place> placeOverrides = {};

  // ---------- delete a location ----------
  // A real location is deleted from the database too (every row of its
  // sensor, for good). A simulated one only exists in the app, so it is just
  // hidden.
  Set<String> hiddenPlaces = {};

  // keeps the same FlutterMap widget until [sig] changes
  Widget? mapCache;

  String mapCacheSig = '';

  // keeps the map's view when it moves between the card and the big overlay
  // one tile layer for every rebuild of the map (a new one reloads the tiles
  // and makes the map flicker)
  final mapTiles = TileLayer(
    urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
    // a clear app name: the free OSM servers refuse generic ones
    userAgentPackageName: 'th.halfcell.potential_monitor',
    // if a tile fails (rate limit, high zoom) another free map
    // source fills it in, and failed tiles are retried
    fallbackUrl:
        'https://a.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}.png',
    evictErrorTileStrategy: EvictErrorTileStrategy.notVisibleRespectMargin,
    errorTileCallback: (tile, error, stack) =>
        debugPrint('TILE ERROR = $error'),
    maxNativeZoom: 19,
    // tiles appear at once, no fade-in flicker
    tileDisplay: const TileDisplay.instantaneous(),
  );

  Widget? mapPanelCache;
  String mapPanelKey = '';
  // one key per location for the data-page map (a GlobalObjectKey built from
  // a new string every build is a new key each time: the map was recreated)
  final dataMapKeys = <String, GlobalKey>{};
  final mapKey = GlobalKey();

  // height of the connection-status card, measured so that the map card
  // (under the report summary) ends exactly where that card ends
  final connKey = GlobalKey();

  double? connHeight;

  // ---------- history page: rows of the chosen period ----------
  final Map<String, List<Map<String, dynamic>>> histCache = {};

  bool histLoading = false;

  // CH drawn on the history chart (tick more to compare them)
  final Set<int> historyChs = {};

  // history page: the ticked CH are drawn (tick several to compare them)
  bool historyTouched = false; // false: start with the first CH

  // form state of the "เพิ่ม CH" page
  String? addChDevice; // location id (null = the open location)

  int? addChNumber;

  String? addChPhoto; // picture chosen but not saved yet

  final addChNameC = TextEditingController();

  int lastMenu = 4; // page that was open at the last build
}
