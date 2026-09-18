import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
class ProfilePage extends StatefulWidget{const ProfilePage({super.key});@override State<ProfilePage>createState()=>_ProfilePageState();}
class _ProfilePageState extends State<ProfilePage>{
  Map<String,dynamic>? p;int posts=0,followers=0,following=0;
  @override void initState(){super.initState();load();}
  Future<void>load()async{
    final sb=Supabase.instance.client,uid=sb.auth.currentUser!.id;
    try{
      p=await sb.from('profiles').select().eq('id',uid).single();
      posts=(await sb.from('posts').select('id').eq('user_id',uid).count()).count;
      followers=(await sb.from('follows').select('follower_id').eq('following_id',uid).count()).count;
      following=(await sb.from('follows').select('following_id').eq('follower_id',uid).count()).count;
    }catch(_){}
    if(mounted)setState((){});
  }
  @override Widget build(BuildContext context)=>SingleChildScrollView(padding:const EdgeInsets.fromLTRB(18,55,18,30),child:Column(children:[
    Row(mainAxisAlignment:MainAxisAlignment.end,children:[IconButton(onPressed:()=>Supabase.instance.client.auth.signOut(),icon:const Icon(Icons.logout))]),
    const CircleAvatar(radius:48,child:Icon(Icons.person,size:48)),const SizedBox(height:10),
    Text(p?['display_name']??'مستخدم N',style:const TextStyle(fontSize:22,fontWeight:FontWeight.bold)),Text('@${p?['username']??''}'),
    const SizedBox(height:18),Row(mainAxisAlignment:MainAxisAlignment.spaceEvenly,children:[stat('منشورات',posts),stat('المتابعون',followers),stat('المتابَعون',following)]),
    const SizedBox(height:28),const Align(alignment:Alignment.centerRight,child:Text('منشوراتي',style:TextStyle(fontSize:22,fontWeight:FontWeight.bold))),
    const SizedBox(height:180,child:Center(child:Text('ستظهر منشوراتك هنا'))),
  ]));
  Widget stat(String t,int n)=>Column(children:[Text('$n',style:const TextStyle(fontSize:20,fontWeight:FontWeight.bold)),Text(t)]);
}
