// Chooses which page is shown
part of '../main.dart';

// ignore_for_file: invalid_use_of_protected_member, unused_element

extension _BodyUi on _Ads1115PageState {
  Widget message(Widget child) => Center(
    child: Padding(padding: const EdgeInsets.all(20), child: child),
  );

  Widget body() {
    // changing page folds the map back to its small card
    if (selectedMenu != lastMenu) {
      lastMenu = selectedMenu;
      mapExpanded = false;
      mapActive = false;
      mapPin = null;
    }

    if (selectedMenu == 2) return settingsPage();
    if (selectedMenu == 5) return addChPage();

    // real devices depend on Supabase, simulated ones do not
    if (!isMock) {
      if (loading) {
        return const Center(
          child: CircularProgressIndicator(color: primaryBlue),
        );
      }

      if (error != null) {
        return message(
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 60, color: Colors.red),
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
        );
      }
    }

    final rows = currentRows;

    if (rows.isEmpty) {
      return message(
        const Text(
          'ไม่มีข้อมูล',
          style: TextStyle(
            fontSize: 20,
            color: navyDark,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
    }

    // a key per page keeps the old page's state from overlapping the new one
    final page = switch (selectedMenu) {
      4 => homePage(rows),
      0 => dashboardPage(rows),
      1 => historyPage(rows),
      _ => chNamesPage(rows),
    };

    return KeyedSubtree(key: ValueKey(selectedMenu), child: page);
  }
}
