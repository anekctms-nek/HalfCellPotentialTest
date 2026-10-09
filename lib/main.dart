import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://lgdinpmyfgqgslbdysok.supabase.co',
    publishableKey: 'sb_publishable_YzJiR_foA-pKIPtSaYU-hg_v4yUZSDD',
  );

  runApp(const MyApp());
}

// ============================================================
// COLORS - NAVY PREMIUM
// ============================================================
const Color navyDark = Color(0xFF0A1F44);
const Color primaryNavy = Color(0xFF0B3D91);
const Color navyLight = Color(0xFF1E5AA8);
const Color backgroundColor = Color(0xFFF5F7FB);
const Color cardColor = Colors.white;

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
          seedColor: primaryNavy,
          brightness: Brightness.light,
        ),

        appBarTheme: const AppBarTheme(
          backgroundColor: navyDark,
          foregroundColor: Colors.white,
          elevation: 0,
          centerTitle: false,
        ),

        cardTheme: CardThemeData(
          color: cardColor,
          elevation: 5,
          shadowColor: navyDark.withValues(alpha: 0.15),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),

        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: primaryNavy,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
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

  Map<String, dynamic>? latestData;

  bool loading = true;
  String? error;

  RealtimeChannel? realtimeChannel;

  // ============================================================
  // INIT
  // ============================================================
  @override
  void initState() {
    super.initState();

    loadLatestData();
    startRealtime();
  }

  // ============================================================
  // LOAD LATEST DATA
  // ============================================================
  Future<void> loadLatestData() async {
    try {
      if (latestData == null) {
        setState(() {
          loading = true;
          error = null;
        });
      } else {
        setState(() {
          error = null;
        });
      }

      final result = await supabase
          .from('ads1115_data')
          .select('id, sensor, ch1, ch2, ch3, ch4, created_at')
          .order('id', ascending: false)
          .limit(1);

      debugPrint('LATEST RESULT = $result');

      if (!mounted) return;

      setState(() {
        if (result.isNotEmpty) {
          latestData = Map<String, dynamic>.from(result.first);
        } else {
          latestData = null;
        }

        loading = false;
      });
    } catch (e) {
      debugPrint('SUPABASE ERROR = $e');

      if (!mounted) return;

      setState(() {
        error = e.toString();
        loading = false;
      });
    }
  }

  // ============================================================
  // SUPABASE REALTIME
  // ============================================================
  void startRealtime() {
    realtimeChannel = supabase
        .channel('ads1115_monitor')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'ads1115_data',
          callback: (payload) {
            debugPrint('REALTIME NEW DATA = ${payload.newRecord}');

            final newData = Map<String, dynamic>.from(payload.newRecord);

            if (!mounted) return;

            setState(() {
              latestData = newData;
              error = null;
              loading = false;
            });
          },
        )
        .subscribe();
  }

  // ============================================================
  // DISPOSE
  // ============================================================
  @override
  void dispose() {
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
  // GET VALUE
  // ============================================================
  double getValue(dynamic value) {
    if (value == null) {
      return 0.0;
    }

    return double.tryParse(value.toString()) ?? 0.0;
  }

  // ============================================================
  // CHANNEL CARD
  // ============================================================
  Widget channelCard(String channel, dynamic value) {
    final number = getValue(value);

    return Expanded(
      child: Card(
        elevation: 5,
        margin: const EdgeInsets.all(6),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: primaryNavy.withValues(alpha: 0.08)),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 10),
            child: Column(
              children: [
                // ==========================================
                // CHANNEL ICON
                // ==========================================
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: primaryNavy.withValues(alpha: 0.10),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.electric_bolt,
                    color: Color.fromARGB(255, 235, 223, 60),
                    size: 25,
                  ),
                ),

                const SizedBox(height: 10),

                // ==========================================
                // CHANNEL NAME
                // ==========================================
                Text(
                  channel,
                  style: const TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.bold,
                    color: navyDark,
                  ),
                ),

                const SizedBox(height: 8),

                // ==========================================
                // VALUE
                // ==========================================
                Text(
                  '${number.toStringAsFixed(3)} V',
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: primaryNavy,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ============================================================
  // BUILD
  // ============================================================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: const Text(
          'Half Cell Potential Test Monitor',
          style: TextStyle(
            fontWeight: FontWeight.normal,
            fontStyle: FontStyle.italic,
            fontSize: 22,
          ),
        ),
        actions: [
          // LIVE STATUS
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.circle,
                      size: 9,
                      color: realtimeChannel != null
                          ? Colors.greenAccent
                          : Colors.grey,
                    ),
                    const SizedBox(width: 6),
                    const Text(
                      'LIVE',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),

      // ========================================================
      // BODY
      // ========================================================
      body: loading
          ? const Center(child: CircularProgressIndicator(color: primaryNavy))
          : error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      size: 60,
                      color: Colors.red,
                    ),

                    const SizedBox(height: 15),

                    const Text(
                      'เกิดข้อผิดพลาด',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: navyDark,
                      ),
                    ),

                    const SizedBox(height: 10),

                    Text(
                      error!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.red),
                    ),

                    const SizedBox(height: 20),

                    ElevatedButton.icon(
                      onPressed: loadLatestData,
                      icon: const Icon(Icons.refresh),
                      label: const Text('โหลดข้อมูลใหม่'),
                    ),
                  ],
                ),
              ),
            )
          : latestData == null
          ? const Center(
              child: Text(
                'ไม่มีข้อมูล',
                style: TextStyle(
                  fontSize: 20,
                  color: navyDark,
                  fontWeight: FontWeight.bold,
                ),
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // ==================================================
                // HEADER
                // ==================================================
                Row(
                  children: [
                    Container(
                      width: 5,
                      height: 32,
                      decoration: BoxDecoration(
                        color: primaryNavy,
                        borderRadius: BorderRadius.circular(5),
                      ),
                    ),

                    const SizedBox(width: 10),

                    const Text(
                      'ค่าล่าสุด',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        color: navyDark,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                // ==================================================
                // SENSOR INFO
                // ==================================================
                Card(
                  elevation: 3,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(9),
                              decoration: BoxDecoration(
                                color: primaryNavy.withValues(alpha: 0.10),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(
                                Icons.sensors,
                                color: primaryNavy,
                              ),
                            ),

                            const SizedBox(width: 12),

                            Expanded(
                              child: Text(
                                'Sensor: ${latestData!['sensor'] ?? '-'}',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: navyDark,
                                ),
                              ),
                            ),
                          ],
                        ),

                        const Divider(height: 25),

                        Row(
                          children: [
                            const Icon(Icons.tag, size: 18, color: Colors.grey),
                            const SizedBox(width: 8),
                            Text(
                              'ID: ${latestData!['id'] ?? '-'}',
                              style: const TextStyle(color: Colors.grey),
                            ),
                          ],
                        ),

                        const SizedBox(height: 8),

                        Row(
                          children: [
                            const Icon(
                              Icons.access_time,
                              size: 18,
                              color: Colors.grey,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                formatThaiTime(
                                  latestData!['created_at']?.toString(),
                                ),
                                style: const TextStyle(color: Colors.grey),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                // ==================================================
                // CH1 CH2
                // ==================================================
                Row(
                  children: [
                    channelCard('CH1', latestData!['ch1']),
                    channelCard('CH2', latestData!['ch2']),
                  ],
                ),

                // ==================================================
                // CH3 CH4
                // ==================================================
                Row(
                  children: [
                    channelCard('CH3', latestData!['ch3']),
                    channelCard('CH4', latestData!['ch4']),
                  ],
                ),

                const SizedBox(height: 10),

                // ==================================================
                // REALTIME FOOTER
                // ==================================================
                Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.cloud_done,
                        size: 16,
                        color: primaryNavy,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'ข้อมูลจาก Supabase Realtime',
                        style: TextStyle(
                          color: navyDark.withValues(alpha: 0.65),
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 10),
              ],
            ),
    );
  }
}
