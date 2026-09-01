import 'package:flutter/material.dart';

import '../constants/app_colors.dart';

class NBottomNav extends StatelessWidget {
  const NBottomNav({super.key, required this.index, required this.onChanged});

  final int index;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    const items = [
      (Icons.home_outlined, Icons.home_rounded, 'الرئيسية'),
      (Icons.explore_outlined, Icons.explore_rounded, 'استكشف'),
      (Icons.add, Icons.add, 'نشر'),
      (Icons.podcasts_outlined, Icons.podcasts, 'البث المباشر'),
      (Icons.person_outline, Icons.person_rounded, 'الملف الشخصي'),
    ];

    return SafeArea(
      top: false,
      child: Container(
        height: 70,
        decoration: const BoxDecoration(
          color: NColors.background,
          border: Border(top: BorderSide(color: NColors.divider, width: .6)),
        ),
        child: Row(
          children: List.generate(items.length, (i) {
            final selected = i == index;
            if (i == 2) {
              return Expanded(
                child: Center(
                  child: GestureDetector(
                    onTap: () => onChanged(i),
                    child: Container(
                      width: 48,
                      height: 36,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: const [
                          BoxShadow(color: NColors.cyan, blurRadius: 0, spreadRadius: 2),
                          BoxShadow(color: NColors.pink, blurRadius: 0, spreadRadius: -2),
                        ],
                      ),
                      child: const Icon(Icons.add, color: Colors.black, size: 28),
                    ),
                  ),
                ),
              );
            }
            final item = items[i];
            return Expanded(
              child: InkWell(
                onTap: () => onChanged(i),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(selected ? item.$2 : item.$1,
                        color: selected ? (i == 3 ? NColors.pink : NColors.cyan) : NColors.white),
                    const SizedBox(height: 3),
                    Text(
                      item.$3,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 9.5,
                        fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
                        color: selected ? NColors.white : NColors.muted,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}
