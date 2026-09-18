import 'package:flutter/material.dart';
import 'feed_page.dart';
import 'publish_page.dart';
import 'messages_page.dart';
import 'profile_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override State<HomePage> createState()=>_HomePageState();
}
class _HomePageState extends State<HomePage> {
  int index=0;
  final pages=const[FeedPage(),FeedPage(following:true),PublishPage(),MessagesPage(),ProfilePage()];
  @override Widget build(BuildContext context)=>Directionality(
    textDirection:TextDirection.rtl,
    child:Scaffold(
      body:pages[index],
      bottomNavigationBar:NavigationBar(
        selectedIndex:index,
        onDestinationSelected:(i)=>setState(()=>index=i),
        destinations:const[
          NavigationDestination(icon:Icon(Icons.home_outlined),selectedIcon:Icon(Icons.home),label:'الرئيسية'),
          NavigationDestination(icon:Icon(Icons.people_outline),selectedIcon:Icon(Icons.people),label:'المتابعة'),
          NavigationDestination(icon:Icon(Icons.add_circle),selectedIcon:Icon(Icons.add_circle),label:'نشر'),
          NavigationDestination(icon:Icon(Icons.chat_bubble_outline),selectedIcon:Icon(Icons.chat_bubble),label:'الرسائل'),
          NavigationDestination(icon:Icon(Icons.person_outline),selectedIcon:Icon(Icons.person),label:'الملف الشخصي'),
        ],
      ),
    ),
  );
}
