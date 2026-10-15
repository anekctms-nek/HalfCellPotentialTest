// Top bar and the location dropdown
part of '../main.dart';

// ignore_for_file: invalid_use_of_protected_member, unused_element

extension _TopBarUi on _Ads1115PageState {
  // ============================================================
  // TOP BAR
  // ============================================================
  Widget deviceDropdown(bool wide) {
    final list = devices;
    final value = list.any((d) => d.id == selectedDevice)
        ? selectedDevice
        : list.first.id;

    return Container(
      width: wide ? 300 : 180,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          dropdownColor: Colors.white,
          iconEnabledColor: Colors.white,
          borderRadius: BorderRadius.circular(12),
          // what is shown on the blue bar: white
          selectedItemBuilder: (context) => [
            for (final d in list)
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  d.name,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
          ],
          items: [
            for (final d in list)
              DropdownMenuItem<String>(
                value: d.id,
                child: Row(
                  children: [
                    Icon(
                      d.mock ? Icons.science_outlined : Icons.sensors,
                      size: 18,
                      color: primaryBlue,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        d.mock ? '${d.name} (จำลอง)' : d.name,
                        style: const TextStyle(fontSize: 14, color: navyDark),
                      ),
                    ),
                  ],
                ),
              ),
          ],
          onChanged: (v) {
            if (v != null) {
              setState(() => selectedDevice = v);
              loadTrend();
            }
          },
        ),
      ),
    );
  }

  // title + subtitle of the page that is open
  (String, String) pageHeading() => switch (selectedMenu) {
    4 => ('ภาพรวมทุกสถานที่', 'Half Cell Potential Test Monitor'),
    0 => ('ข้อมูล', currentDevice.name),
    1 => ('ประวัติข้อมูล', currentDevice.name),
    3 => ('แก้ไขชื่อ CH', currentDevice.name),
    5 => ('เพิ่ม CH', 'เพิ่มช่องวัดให้สถานที่'),
    _ => ('ตั้งค่า', 'บัญชีผู้ใช้'),
  };

  // floating rounded top bar, blue gradient with glass-like controls
  Widget topBar(bool wide) {
    final (title, subtitle) = pageHeading();

    return Padding(
      padding: EdgeInsets.fromLTRB(wide ? 14 : 12, 12, 12, 0),
      child: Container(
        height: 72,
        padding: const EdgeInsets.symmetric(horizontal: 18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF4C78F5), primaryBlueDark, Color(0xFF2547B8)],
          ),
          boxShadow: [
            BoxShadow(
              color: primaryBlue.withValues(alpha: 0.32),
              blurRadius: 24,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Row(
          children: [
            if (!wide)
              IconButton(
                onPressed: () => scaffoldKey.currentState?.openDrawer(),
                icon: const Icon(Icons.menu_rounded, color: Colors.white),
              ),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      height: 1.15,
                    ),
                  ),
                  Text(
                    subtitle,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white.withValues(alpha: 0.78),
                    ),
                  ),
                ],
              ),
            ),
            // the home page shows every location, so no location picker there
            if (selectedMenu != 4) deviceDropdown(wide),
          ],
        ),
      ),
    );
  }
}
