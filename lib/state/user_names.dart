// User name and CH names (saved on this computer)
part of '../main.dart';

// ignore_for_file: invalid_use_of_protected_member, unused_element

extension _UserAndNames on _Ads1115PageState {
  // ============================================================
  // USER NAME
  // ============================================================
  Future<void> loadUserName() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString('user_name');

      if (saved != null && saved.isNotEmpty && mounted) {
        setState(() => userName = saved);
      }
    } catch (e) {
      debugPrint('LOAD NAME ERROR = $e');
    }
  }

  Future<void> saveUserName(String value) async {
    final name = value.trim();
    if (name.isEmpty) return;

    setState(() => userName = name);

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_name', name);
    } catch (e) {
      debugPrint('SAVE NAME ERROR = $e');
    }

    if (!mounted) return;

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('บันทึกชื่อเรียบร้อย')));
  }

  // ============================================================
  // CH NAMES
  // ============================================================
  String chLabel(String deviceId, int i) {
    final name = chNames[deviceId]?[i];

    return (name == null || name.isEmpty) ? 'CH$i' : name;
  }

  Future<void> loadChNames() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('ch_names');
      if (raw == null) return;

      final decoded = jsonDecode(raw) as Map<String, dynamic>;

      final loaded = <String, Map<int, String>>{
        for (final e in decoded.entries)
          e.key: {
            for (final c in (e.value as Map<String, dynamic>).entries)
              int.parse(c.key): c.value.toString(),
          },
      };

      if (mounted) setState(() => chNames = loaded);
    } catch (e) {
      debugPrint('LOAD CH NAMES ERROR = $e');
    }
  }

  // controller for one CH name field, filled with the saved name
  TextEditingController chController(String deviceId, int i) {
    return chControllers.putIfAbsent(
      '$deviceId|$i',
      () => TextEditingController(text: chNames[deviceId]?[i] ?? ''),
    );
  }

  Future<void> persistChNames() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        'ch_names',
        jsonEncode({
          for (final e in chNames.entries)
            e.key: {for (final c in e.value.entries) '${c.key}': c.value},
        }),
      );
    } catch (e) {
      debugPrint('SAVE CH NAMES ERROR = $e');
    }
  }

  void showSaved(String text) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(text), duration: const Duration(seconds: 1)),
      );
  }

  // true when the text in the field differs from the saved name of this CH
  bool chNameChanged(String deviceId, int i) {
    final saved = chNames[deviceId]?[i] ?? '';

    return chController(deviceId, i).text.trim() != saved;
  }

  // save ONE channel, the other channels are left untouched
  Future<void> saveChName(String deviceId, int i) async {
    final text = chController(deviceId, i).text.trim();
    final names = {...?chNames[deviceId]};

    if (text.isEmpty) {
      names.remove(i);
    } else {
      names[i] = text;
    }

    setState(() => chNames = {...chNames, deviceId: names});
    await persistChNames();

    showSaved(text.isEmpty ? 'CH$i ใช้ชื่อเดิม' : 'บันทึกชื่อ CH$i แล้ว');
  }

  bool anyChNameChanged(String deviceId, List<int> channels) =>
      channels.any((i) => chNameChanged(deviceId, i));

  // save every CH of the device at once (handy for the first time)
  Future<void> saveAllChNames(String deviceId, List<int> channels) async {
    final names = <int, String>{
      for (final i in channels)
        if (chController(deviceId, i).text.trim().isNotEmpty)
          i: chController(deviceId, i).text.trim(),
    };

    setState(() => chNames = {...chNames, deviceId: names});
    await persistChNames();

    showSaved('บันทึกชื่อ CH ทั้งหมดแล้ว');
  }

  Future<void> resetChNames(String deviceId, List<int> channels) async {
    for (final i in channels) {
      chController(deviceId, i).clear();
    }

    setState(() => chNames = {...chNames, deviceId: {}});
    await persistChNames();

    showSaved('ใช้ชื่อเดิมทั้งหมดแล้ว');
  }

  // ============================================================
  // LOAD LATEST DATA + HISTORY
  // ============================================================
  Future<void> loadLatestData() async {
    try {
      setState(() {
        if (history.isEmpty) loading = true;
        error = null;
      });

      final result = await supabase
          .from('ads1115_data')
          .select()
          .order('id', ascending: false)
          .limit(historyLimit);

      debugPrint('LATEST RESULT = ${result.isEmpty ? [] : result.first}');

      if (!mounted) return;

      setState(() {
        history = result.map((e) => Map<String, dynamic>.from(e)).toList();
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
}
