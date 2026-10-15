// Rename CH page
part of '../main.dart';

// ignore_for_file: invalid_use_of_protected_member, unused_element

extension _ChNamesPage on _Ads1115PageState {
  // rename the CH shown on the "latest voltage" card (per device)
  Widget chNamesPage(List<Map<String, dynamic>> rows) {
    final device = currentDevice;
    final channels = channelsOf(device, [rows.first]);

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        pageTitle('แก้ไขชื่อ CH • ${device.name}'),
        const SizedBox(height: 6),
        Text(
          'ตั้งชื่อให้แต่ละ CH ของอุปกรณ์นี้ เช่น ชื่อจุดที่ติดตั้งเซนเซอร์ '
          'เว้นว่างไว้เพื่อใช้ชื่อเดิม (CH1, CH2, ...)',
          style: TextStyle(
            fontSize: 13,
            color: navyDark.withValues(alpha: 0.6),
          ),
        ),
        const SizedBox(height: 16),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: panelDecoration(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // each CH has its own save button
              Wrap(
                spacing: 16,
                runSpacing: 16,
                children: [
                  for (final i in channels)
                    SizedBox(
                      width: 360,
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: chController(device.id, i),
                              maxLength: 20,
                              // refresh so the save button reacts to typing
                              onChanged: (_) => setState(() {}),
                              onSubmitted: (_) => saveChName(device.id, i),
                              decoration: InputDecoration(
                                labelText: 'CH$i',
                                hintText: 'CH$i',
                                counterText: '',
                                filled: true,
                                fillColor: tileColor,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: BorderSide.none,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton.filled(
                            tooltip: chNameChanged(device.id, i)
                                ? 'บันทึก CH$i'
                                : 'บันทึกแล้ว',
                            // enabled only when this CH has unsaved changes
                            onPressed: chNameChanged(device.id, i)
                                ? () => saveChName(device.id, i)
                                : null,
                            style: IconButton.styleFrom(
                              backgroundColor: valueGreen,
                              disabledBackgroundColor: tileColor,
                              minimumSize: const Size(48, 48),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            icon: const Icon(Icons.save_rounded, size: 22),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              // bottom of the card: reset (red) on the left, save all on the right
              Row(
                children: [
                  TextButton(
                    onPressed: () => resetChNames(device.id, channels),
                    style: TextButton.styleFrom(foregroundColor: Colors.red),
                    child: const Text('ยกเลิก'),
                  ),
                  const Spacer(),
                  FilledButton(
                    onPressed: anyChNameChanged(device.id, channels)
                        ? () => saveAllChNames(device.id, channels)
                        : null,
                    style: FilledButton.styleFrom(
                      backgroundColor: valueGreen,
                      disabledBackgroundColor: tileColor,
                      minimumSize: const Size(0, 44),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Text('บันทึกทั้งหมด'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}
