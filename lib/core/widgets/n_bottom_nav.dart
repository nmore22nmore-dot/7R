import 'package:flutter/material.dart';

import '../constants/app_colors.dart';

/// N's bottom navigation follows the familiar short-video layout while
/// keeping N's own cyan/pink visual identity.
class NBottomNav extends StatelessWidget {
  const NBottomNav({super.key, required this.index, required this.onChanged});

  final int index;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    const items = [
      (Icons.home_outlined, Icons.home_rounded, 'الصفحة الرئيسية'),
      (Icons.people_outline_rounded, Icons.people_rounded, 'الأصدقاء'),
      (Icons.add, Icons.add, 'نشر'),
      (Icons.chat_bubble_outline_rounded, Icons.chat_bubble_rounded, 'صندوق الوارد'),
      (Icons.person_outline_rounded, Icons.person_rounded, 'الملف الشخصي'),
    ];

    return SafeArea(
      top: false,
      child: Container(
        height: 76,
        decoration: const BoxDecoration(
          color: Colors.black,
          border: Border(top: BorderSide(color: Color(0xFF202124), width: .7)),
        ),
        child: Row(
          children: List.generate(items.length, (i) {
            final selected = i == index;

            if (i == 2) {
              return Expanded(
                child: Center(
                  child: Semantics(
                    button: true,
                    label: 'نشر',
                    child: GestureDetector(
                      onTap: () => onChanged(i),
                      child: SizedBox(
                        width: 54,
                        height: 42,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            Positioned(
                              left: 2,
                              child: Container(
                                width: 48,
                                height: 38,
                                decoration: BoxDecoration(
                                  color: NColors.cyan,
                                  borderRadius: BorderRadius.circular(11),
                                ),
                              ),
                            ),
                            Positioned(
                              right: 2,
                              child: Container(
                                width: 48,
                                height: 38,
                                decoration: BoxDecoration(
                                  color: NColors.pink,
                                  borderRadius: BorderRadius.circular(11),
                                ),
                              ),
                            ),
                            Container(
                              width: 48,
                              height: 38,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(11),
                              ),
                              child: const Icon(Icons.add, color: Colors.black, size: 29),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }

            final item = items[i];
            return Expanded(
              child: InkWell(
                onTap: () => onChanged(i),
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.only(top: 7, bottom: 5),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        selected ? item.$2 : item.$1,
                        size: selected ? 27 : 25,
                        color: selected ? Colors.white : const Color(0xFF9A9A9F),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        item.$3,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: selected ? FontWeight.w900 : FontWeight.w600,
                          color: selected ? Colors.white : const Color(0xFF9A9A9F),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}
