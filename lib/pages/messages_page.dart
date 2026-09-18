import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
class MessagesPage extends StatefulWidget{const MessagesPage({super.key});@override State<MessagesPage>createState()=>_MessagesPageState();}
class _MessagesPageState extends State<MessagesPage>{
  List<Map<String,dynamic>> rows=[];bool loading=true;
  @override void initState(){super.initState();load();}
  Future<void>load()async{try{final r=await Supabase.instance.client.from('conversations').select('*').order('updated_at',ascending:false);rows=List<Map<String,dynamic>>.from(r);}catch(_){}if(mounted)setState(()=>loading=false);}
  @override Widget build(BuildContext context)=>Column(children:[
    const SizedBox(height:55),const Text('الرسائل',style:TextStyle(fontSize:28,fontWeight:FontWeight.bold)),
    Expanded(child:loading?const Center(child:CircularProgressIndicator()):ListView.builder(itemCount:rows.length,itemBuilder:(_,i)=>ListTile(leading:const CircleAvatar(child:Icon(Icons.person)),title:Text(rows[i]['title']??'محادثة'),subtitle:Text(rows[i]['last_message']??''))))
  ]);
}
