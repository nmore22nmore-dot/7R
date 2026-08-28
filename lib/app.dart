import 'package:flutter/material.dart';

class NApp extends StatelessWidget {
const NApp({super.key});

@override
Widget build(BuildContext context) {
return MaterialApp(
title: 'N',
debugShowCheckedModeBanner: false,
theme: ThemeData(
useMaterial3: true,
brightness: Brightness.dark,
scaffoldBackgroundColor: const Color(0xFF050509),
colorScheme: ColorScheme.fromSeed(
seedColor: const Color(0xFF00C8FF),
brightness: Brightness.dark,
),
fontFamily: 'sans',
),
builder: (context, child) {
return Directionality(
textDirection: TextDirection.rtl,
child: child ?? const SizedBox.shrink(),
);
},
home: const NWelcomePage(),
);
}
}

class NWelcomePage extends StatelessWidget {
const NWelcomePage({super.key});

@override
Widget build(BuildContext context) {
return Scaffold(
body: SafeArea(
child: Center(
child: Padding(
padding: const EdgeInsets.all(24),
child: Column(
mainAxisAlignment: MainAxisAlignment.center,
children: [
Container(
width: 110,
height: 110,
decoration: BoxDecoration(
borderRadius: BorderRadius.circular(32),
gradient: const LinearGradient(
colors: [
Color(0xFF00C8FF),
Color(0xFFFF287A),
],
),
),
child: const Center(
child: Text(
'N',
style: TextStyle(
fontSize: 72,
fontWeight: FontWeight.w900,
),
),
),
),
const SizedBox(height: 28),
const Text(
'N',
style: TextStyle(
fontSize: 42,
fontWeight: FontWeight.w900,
),
),
const SizedBox(height: 8),
const Text(
'شبكتك الاجتماعية الجديدة',
style: TextStyle(
color: Colors.white60,
fontSize: 16,
),
),
const SizedBox(height: 36),
SizedBox(
width: double.infinity,
child: FilledButton(
onPressed: () {},
child: const Padding(
padding: EdgeInsets.all(15),
child: Text(
'ابدأ الآن',
style: TextStyle(
fontSize: 17,
fontWeight: FontWeight.bold,
),
),
),
),
),
],
),
),
),
),
);
}
}
