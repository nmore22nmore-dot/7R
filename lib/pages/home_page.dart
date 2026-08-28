import 'package:flutter/material.dart';

class NHomePage extends StatelessWidget {
const NHomePage({super.key});

@override
Widget build(BuildContext context) {
return Scaffold(
backgroundColor: Colors.black,
appBar: AppBar(
backgroundColor: Colors.black,
elevation: 0,
title: const Text(
'N',
style: TextStyle(
fontSize: 30,
fontWeight: FontWeight.w900,
),
),
actions: [
IconButton(
onPressed: () {},
icon: const Icon(Icons.search),
),
IconButton(
onPressed: () {},
icon: const Icon(Icons.notifications_none),
),
],
),
body: PageView.builder(
scrollDirection: Axis.vertical,
itemCount: 10,
itemBuilder: (context, index) {
return Stack(
fit: StackFit.expand,
children: [
Container(
decoration: const BoxDecoration(
gradient: LinearGradient(
begin: Alignment.topCenter,
end: Alignment.bottomCenter,
colors: [
Color(0xFF161823),
Color(0xFF050509),
],
),
),
child: const Center(
child: Icon(
Icons.play_circle_outline,
size: 82,
color: Colors.white70,
),
),
),
Positioned(
right: 16,
left: 90,
bottom: 30,
child: Column(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
const Text(
'@n_user',
style: TextStyle(
fontSize: 18,
fontWeight: FontWeight.bold,
),
),
const SizedBox(height: 8),
const Text(
'هذا مثال لمنشور فيديو في N. '
'سنربطه لاحقًا بالمحتوى الحقيقي.',
style: TextStyle(
fontSize: 15,
height: 1.4,
),
),
const SizedBox(height: 12),
Row(
children: [
OutlinedButton.icon(
onPressed: () {},
icon: const Icon(Icons.music_note),
label: const Text('الصوت الأصلي'),
),
],
),
],
),
),
Positioned(
left: 12,
bottom: 30,
child: Column(
children: [
_ActionButton(
icon: Icons.favorite_border,
label: '0',
onPressed: () {},
),
_ActionButton(
icon: Icons.comment_outlined,
label: '0',
onPressed: () {},
),
_ActionButton(
icon: Icons.bookmark_border,
label: 'حفظ',
onPressed: () {},
),
_ActionButton(
icon: Icons.share_outlined,
label: 'مشاركة',
onPressed: () {},
),
],
),
),
],
);
},
),
bottomNavigationBar: NavigationBar(
backgroundColor: Colors.black,
destinations: const [
NavigationDestination(
icon: Icon(Icons.home_outlined),
selectedIcon: Icon(Icons.home),
label: 'الرئيسية',
),
NavigationDestination(
icon: Icon(Icons.explore_outlined),
selectedIcon: Icon(Icons.explore),
label: 'استكشاف',
),
NavigationDestination(
icon: Icon(Icons.add_circle_outline),
selectedIcon: Icon(Icons.add_circle),
label: 'نشر',
),
NavigationDestination(
icon: Icon(Icons.chat_bubble_outline),
selectedIcon: Icon(Icons.chat_bubble),
label: 'الرسائل',
),
NavigationDestination(
icon: Icon(Icons.person_outline),
selectedIcon: Icon(Icons.person),
label: 'حسابي',
),
],
),
);
}
}

class _ActionButton extends StatelessWidget {
const _ActionButton({
required this.icon,
required this.label,
required this.onPressed,
});

final IconData icon;
final String label;
final VoidCallback onPressed;

@override
Widget build(BuildContext context) {
return Padding(
padding: const EdgeInsets.only(bottom: 18),
child: Column(
children: [
IconButton(
onPressed: onPressed,
icon: Icon(icon),
iconSize: 32,
color: Colors.white,
),
Text(
label,
style: const TextStyle(
fontSize: 12,
color: Colors.white70,
),
),
],
),
);
}
}
