// Values, levels, colors, shared panel decoration
part of '../main.dart';

// ignore_for_file: invalid_use_of_protected_member, unused_element

extension _Helpers on _Ads1115PageState {
  // ============================================================
  // GET VALUE
  // ============================================================
  double getValue(dynamic value) {
    if (value == null) {
      return 0.0;
    }

    return double.tryParse(value.toString()) ?? 0.0;
  }

  // channel numbers (1..channelCount) that have a value = sensors in use
  List<int> channelsIn(Iterable<Map<String, dynamic>> rows) {
    return [
      for (var i = 1; i <= channelCount; i++)
        if (rows.any((r) => r['ch$i'] != null)) i,
    ];
  }

  List<int> channelsOf(Device d, Iterable<Map<String, dynamic>> rows) {
    final all = {...channelsIn(rows), ...?addedChannels[d.id]}.toList()..sort();
    return all;
  }

  Future<void> loadAddedChannels() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('added_channels');
      if (raw == null) return;

      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      final loaded = <String, Set<int>>{
        for (final e in decoded.entries)
          e.key: {for (final v in e.value as List) (v as num).toInt()},
      };

      if (mounted) setState(() => addedChannels = loaded);
    } catch (e) {
      debugPrint('LOAD ADDED CH ERROR = $e');
    }
  }

  Future<void> persistAddedChannels() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        'added_channels',
        jsonEncode({
          for (final e in addedChannels.entries)
            e.key: e.value.toList()..sort(),
        }),
      );
    } catch (e) {
      debugPrint('SAVE ADDED CH ERROR = $e');
    }
  }

  // value color on the CH cards:
  // > -0.20 green, -0.20 .. -0.35 yellow, < -0.35 red
  // 'green' / 'yellow' / 'red' (null when there is no value)
  String? voltLevel(dynamic value) {
    if (value == null) return null;

    final v = getValue(value);

    if (v > -0.20) return 'green';
    if (v >= -0.35) return 'yellow';
    return 'red';
  }

  Color voltColor(dynamic value) => switch (voltLevel(value)) {
    'green' => valueGreen,
    'yellow' => const Color(0xFFE0A100),
    'red' => const Color(0xFFE5484D),
    _ => mutedText,
  };

  String volt(dynamic value) =>
      value == null ? '-' : '${getValue(value).toStringAsFixed(3)} V';

  // ============================================================
  // SHARED DECORATION
  // ============================================================
  BoxDecoration panelDecoration() => BoxDecoration(
    color: cardColor,
    borderRadius: BorderRadius.circular(16),
    boxShadow: [
      BoxShadow(
        color: navyDark.withValues(alpha: 0.06),
        blurRadius: 24,
        offset: const Offset(0, 8),
      ),
    ],
  );
}
