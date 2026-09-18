import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

class PublishPage extends StatefulWidget{const PublishPage({super.key});@override State<PublishPage>createState()=>_PublishPageState();}
class _PublishPageState extends State<PublishPage>{
  final picker=ImagePicker(),caption=TextEditingController();XFile? file;bool busy=false;
  Future<void> pick(ImageSource s)async{file=await picker.pickVideo(source:s);if(mounted)setState((){});}
  Future<void> upload()async{
    if(file==null)return;setState(()=>busy=true);
    try{
      final sb=Supabase.instance.client,uid=sb.auth.currentUser!.id,ext=file!.path.split('.').last;
      final path='$uid/${const Uuid().v4()}.$ext';
      await sb.storage.from('post-media').upload(path,File(file!.path));
      final url=sb.storage.from('post-media').getPublicUrl(path);
      await sb.from('posts').insert({'user_id':uid,'video_url':url,'caption':caption.text.trim(),'visibility':'public'});
      if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('تم نشر الفيديو بنجاح')));
      file=null;caption.clear();
    }catch(e){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(e.toString())));}
    finally{if(mounted)setState(()=>busy=false);}
  }
  @override Widget build(BuildContext context)=>Padding(padding:const EdgeInsets.all(20),child:Column(children:[
    const SizedBox(height:50),const Text('إنشاء منشور',style:TextStyle(fontSize:28,fontWeight:FontWeight.bold)),
    const SizedBox(height:20),Text(file?.name??'اختر فيديو'),const SizedBox(height:20),
    TextField(controller:caption,maxLines:3,decoration:const InputDecoration(labelText:'الوصف')),
    const Spacer(),Row(mainAxisAlignment:MainAxisAlignment.spaceEvenly,children:[
      FilledButton.icon(onPressed:busy?null:()=>pick(ImageSource.camera),icon:const Icon(Icons.camera_alt),label:const Text('تصوير')),
      FilledButton.icon(onPressed:busy?null:()=>pick(ImageSource.gallery),icon:const Icon(Icons.video_library),label:const Text('المعرض')),
    ]),
    const SizedBox(height:12),SizedBox(width:double.infinity,child:FilledButton(onPressed:busy?null:upload,child:Text(busy?'جاري الرفع...':'نشر'))),
  ]));
}
