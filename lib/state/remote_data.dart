// Loading from Supabase, realtime inserts, refresh
part of '../main.dart';

// ignore_for_file: invalid_use_of_protected_member, unused_element

extension _RemoteData on _Ads1115PageState {
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
              history = [newData, ...history].take(historyLimit).toList();
              error = null;
              loading = false;
            });
          },
        )
        .subscribe();
  }

  // ============================================================
  // REFRESH
  // ============================================================
  Future<void> refresh() async {
    if (isMock) {
      setState(() => addMockRow(currentDevice, DateTime.now().toUtc()));
    } else {
      await loadLatestData();
    }
  }
}
