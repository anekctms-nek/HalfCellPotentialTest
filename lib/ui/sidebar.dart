// Left side panel
part of '../main.dart';

// ignore_for_file: invalid_use_of_protected_member, unused_element

extension _SidebarUi on _Ads1115PageState {
  // ============================================================
  // SIDEBAR
  // ============================================================

  Widget menuItem(IconData icon, String label, int index, bool inDrawer) {
    final selected = selectedMenu == index;
    final collapsed = !inDrawer && sidebarCollapsed;

    final tile = AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(11),
        gradient: selected
            ? const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [primaryBlue, primaryBlueDark],
              )
            : null,
        color: selected ? null : tileColor,
        boxShadow: selected
            ? [
                BoxShadow(
                  color: primaryBlue.withValues(alpha: 0.35),
                  blurRadius: 12,
                  offset: const Offset(0, 5),
                ),
              ]
            : null,
      ),
      child: Icon(icon, size: 20, color: selected ? Colors.white : mutedText),
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Tooltip(
        // folded: the name is shown when the mouse is on the icon
        message: collapsed ? label : '',
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () {
            setState(() => selectedMenu = index);
            if (index == 1) loadHistoryRows();
            if (inDrawer) Navigator.of(context).pop();
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: collapsed
                ? const EdgeInsets.symmetric(vertical: 6)
                : const EdgeInsets.fromLTRB(8, 8, 12, 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              color: selected ? primaryBlue.withValues(alpha: 0.10) : null,
            ),
            child: collapsed
                ? Center(child: tile)
                : Row(
                    children: [
                      tile,
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          label,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 14.5,
                            fontWeight: selected
                                ? FontWeight.w700
                                : FontWeight.w500,
                            color: selected
                                ? primaryBlue
                                : navyDark.withValues(alpha: 0.75),
                          ),
                        ),
                      ),
                      if (selected)
                        Container(
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(
                            color: primaryBlue,
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  // settings entry at the bottom-left: avatar + name + gear (avatar only
  // when the panel is folded)
  Widget settingsItem(bool inDrawer) {
    final selected = selectedMenu == 2;
    final collapsed = !inDrawer && sidebarCollapsed;
    final initial = userName.isEmpty ? '?' : userName.characters.first;

    final avatar = CircleAvatar(
      radius: 17,
      backgroundColor: primaryBlue,
      child: Text(
        initial.toUpperCase(),
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
        ),
      ),
    );

    return Tooltip(
      message: collapsed ? '$userName • ตั้งค่าบัญชี' : '',
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () {
          nameController.text = userName;
          setState(() => selectedMenu = 2);
          if (inDrawer) Navigator.of(context).pop();
        },
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: collapsed ? 0 : 10,
            vertical: 10,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            color: selected ? primaryBlue.withValues(alpha: 0.10) : null,
          ),
          child: collapsed
              ? Center(child: avatar)
              : Row(
                  children: [
                    avatar,
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            userName,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: navyDark,
                            ),
                          ),
                          const Text(
                            'ตั้งค่าบัญชี',
                            style: TextStyle(fontSize: 11, color: mutedText),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.settings_rounded,
                      size: 20,
                      color: selected ? primaryBlue : mutedText,
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  // small rounded icon button used under the logo
  Widget panelButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onPressed,
    bool active = false,
  }) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      icon: Icon(icon, size: 21, color: active ? primaryBlue : mutedText),
      style: IconButton.styleFrom(
        backgroundColor: active
            ? primaryBlue.withValues(alpha: 0.12)
            : tileColor,
        minimumSize: const Size(38, 38),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(11)),
      ),
    );
  }

  // floating rounded side panel (inside the drawer it fills the drawer);
  // outside the drawer it can be folded to a narrow icon strip
  Widget sidebar({bool inDrawer = false}) {
    final live = realtimeChannel != null;
    final collapsed = !inDrawer && sidebarCollapsed;

    final logoTile = Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(13),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [primaryBlue, primaryBlueDark],
        ),
        boxShadow: [
          BoxShadow(
            color: primaryBlue.withValues(alpha: 0.4),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Icon(
        logoHover
            ? (collapsed
                  ? Icons.keyboard_double_arrow_right_rounded
                  : Icons.keyboard_double_arrow_left_rounded)
            : Icons.bolt,
        color: Colors.white,
        size: 24,
      ),
    );

    final homeButton = panelButton(
      icon: Icons.home_rounded,
      tooltip: 'หน้าหลัก',
      active: selectedMenu == 4,
      onPressed: () {
        setState(() => selectedMenu = 4);
        if (inDrawer) Navigator.of(context).pop();
      },
    );

    // no width animation: the contents change layout at once, so nothing
    // overflows while the panel is still growing or shrinking
    final panel = Container(
      width: collapsed ? 76 : 244,
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(inDrawer ? 0 : 22),
        boxShadow: inDrawer
            ? null
            : [
                BoxShadow(
                  color: navyDark.withValues(alpha: 0.08),
                  blurRadius: 28,
                  offset: const Offset(0, 10),
                ),
              ],
      ),
      padding: EdgeInsets.fromLTRB(
        collapsed ? 12 : 14,
        20,
        collapsed ? 12 : 14,
        14,
      ),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: collapsed
              ? CrossAxisAlignment.center
              : CrossAxisAlignment.start,
          children: [
            // logo: click it to fold / unfold the panel
            Tooltip(
              message: inDrawer ? '' : (collapsed ? 'ขยายเมนู' : 'ย่อเมนู'),
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onHover: inDrawer ? null : (v) => setState(() => logoHover = v),
                onTap: inDrawer
                    ? null
                    : () =>
                          setState(() => sidebarCollapsed = !sidebarCollapsed),
                child: collapsed
                    ? Stack(
                        clipBehavior: Clip.none,
                        children: [
                          logoTile,
                          // live status: green when the realtime channel is connected
                          Positioned(
                            right: -2,
                            top: -2,
                            child: Container(
                              width: 12,
                              height: 12,
                              decoration: BoxDecoration(
                                color: live ? valueGreen : mutedText,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white,
                                  width: 2,
                                ),
                              ),
                            ),
                          ),
                        ],
                      )
                    : Row(
                        children: [
                          logoTile,
                          const SizedBox(width: 11),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Text(
                                      'HalfCell',
                                      style: TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.w800,
                                        color: navyDark,
                                        height: 1.1,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Icon(
                                      Icons.circle,
                                      size: 9,
                                      color: live ? valueGreen : mutedText,
                                    ),
                                  ],
                                ),
                                const Text(
                                  'Potential Monitor',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: mutedText,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 12),
            // home button under the logo
            homeButton,
            SizedBox(height: collapsed ? 16 : 18),
            if (!collapsed)
              const Padding(
                padding: EdgeInsets.only(left: 8, bottom: 10),
                child: Text(
                  'เมนู',
                  style: TextStyle(
                    fontSize: 11,
                    letterSpacing: 1.4,
                    fontWeight: FontWeight.w700,
                    color: mutedText,
                  ),
                ),
              ),
            menuItem(Icons.location_on_rounded, 'ข้อมูล', 0, inDrawer),
            menuItem(Icons.menu_book_rounded, 'ประวัติข้อมูล', 1, inDrawer),
            menuItem(Icons.edit_note_rounded, 'แก้ไขชื่อ CH', 3, inDrawer),
            menuItem(Icons.add_box_rounded, 'เพิ่ม CH', 5, inDrawer),
            const Spacer(),
            // connection card
            if (collapsed)
              Tooltip(
                message: live
                    ? 'Supabase Realtime • เชื่อมต่อแล้ว'
                    : 'Supabase Realtime • ไม่ได้เชื่อมต่อ',
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    gradient: LinearGradient(
                      colors: live
                          ? const [primaryBlue, primaryBlueDark]
                          : [mutedText, mutedText.withValues(alpha: 0.8)],
                    ),
                  ),
                  child: const Icon(
                    Icons.cloud_done_rounded,
                    size: 20,
                    color: Colors.white,
                  ),
                ),
              )
            else
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: live
                        ? const [primaryBlue, primaryBlueDark]
                        : [mutedText, mutedText.withValues(alpha: 0.8)],
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.cloud_done_rounded,
                        size: 18,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Supabase Realtime',
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                          Text(
                            live ? 'เชื่อมต่อแล้ว' : 'ไม่ได้เชื่อมต่อ',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.white.withValues(alpha: 0.8),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 10),
            settingsItem(inDrawer),
          ],
        ),
      ),
    );

    // floating: a little room around the panel
    return inDrawer
        ? panel
        : Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 0, 12),
            child: panel,
          );
  }
}
