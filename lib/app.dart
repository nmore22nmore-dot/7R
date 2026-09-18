import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:video_player/video_player.dart';

final sb = Supabase.instance.client;

const bg = Color(0xFF07080D);
const panel = Color(0xFF11131B);
const cyan = Color(0xFF00C8FF);
const pink = Color(0xFFFF287A);

class NApp extends StatelessWidget {
  final bool configError;
  const NApp({super.key, this.configError = false});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'N',
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: bg,
        colorScheme: ColorScheme.fromSeed(seedColor: cyan, brightness: Brightness.dark),
        useMaterial3: true,
      ),
      home: configError ? const ConfigPage() : const AuthGate(),
    );
  }
}

class ConfigPage extends StatelessWidget {
  const ConfigPage({super.key});
  @override
  Widget build(BuildContext context) => const Scaffold(
    body: Center(child: Padding(
      padding: EdgeInsets.all(24),
      child: Text('إعداد Supabase غير مكتمل.\nأضف SUPABASE_URL و SUPABASE_PUBLISHABLE_KEY في إعدادات البناء.',
        textAlign: TextAlign.center, style: TextStyle(fontSize: 18)),
    )),
  );
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: sb.auth.onAuthStateChange,
      builder: (_, snap) => sb.auth.currentSession == null ? const AuthPage() : const Shell(),
    );
  }
}

class AuthPage extends StatefulWidget {
  const AuthPage({super.key});
  @override State<AuthPage> createState() => _AuthPageState();
}
class _AuthPageState extends State<AuthPage> {
  final email = TextEditingController(), pass = TextEditingController(), username = TextEditingController();
  bool signup = false, busy = false;
  String? error;
  Future<void> submit() async {
    setState(() {busy=true; error=null;});
    try {
      if (signup) {
        final u = username.text.trim();
        if (u.length < 4) throw Exception('اسم المستخدم يجب أن يكون 4 أحرف أو أكثر.');
        final r = await sb.auth.signUp(email: email.text.trim(), password: pass.text,
          data: {'username': u});
        if (r.session == null) {
          error = 'تم إنشاء الحساب. تحقق من بريدك الإلكتروني ثم سجّل الدخول.';
        }
      } else {
        await sb.auth.signInWithPassword(email: email.text.trim(), password: pass.text);
      }
    } catch(e) { error = e.toString().replaceFirst('Exception: ', ''); }
    if(mounted) setState(()=>busy=false);
  }
  @override Widget build(BuildContext context) => Scaffold(
    body: SafeArea(child: Center(child: SingleChildScrollView(padding: const EdgeInsets.all(24), child: Column(
      children: [
        const Text('N', style: TextStyle(fontSize: 80, fontWeight: FontWeight.w900, color: cyan)),
        Text(signup ? 'إنشاء حساب' : 'تسجيل الدخول', style: const TextStyle(fontSize: 25, fontWeight: FontWeight.bold)),
        const SizedBox(height: 24),
        if(signup) TextField(controller: username, decoration: const InputDecoration(labelText:'اسم المستخدم', prefixIcon:Icon(Icons.alternate_email))),
        if(signup) const SizedBox(height:12),
        TextField(controller: email, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText:'البريد الإلكتروني')),
        const SizedBox(height:12),
        TextField(controller: pass, obscureText:true, decoration: const InputDecoration(labelText:'كلمة المرور')),
        const SizedBox(height:18),
        if(error!=null) Text(error!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.redAccent)),
        const SizedBox(height:12),
        SizedBox(width:double.infinity, child: FilledButton(onPressed:busy?null:submit, child: Text(busy?'...':signup?'إنشاء الحساب':'دخول'))),
        TextButton(onPressed:()=>setState(()=>signup=!signup), child:Text(signup?'لدي حساب بالفعل':'إنشاء حساب جديد')),
      ],
    )))),
  );
}

class Shell extends StatefulWidget {
  const Shell({super.key});
  @override State<Shell> createState()=>_ShellState();
}
class _ShellState extends State<Shell> {
  int index=0;
  final pages = const [HomePage(), FollowingPage(), PublishPage(), MessagesPage(), ProfilePage()];
  @override Widget build(BuildContext context)=>Scaffold(
    body: IndexedStack(index:index, children:pages),
    bottomNavigationBar: NavigationBar(
      backgroundColor: panel, selectedIndex:index,
      onDestinationSelected:(i)=>setState(()=>index=i),
      destinations: const [
        NavigationDestination(icon:Icon(Icons.home_outlined), selectedIcon:Icon(Icons.home), label:'الرئيسية'),
        NavigationDestination(icon:Icon(Icons.people_outline), label:'المتابعة'),
        NavigationDestination(icon:Icon(Icons.add_circle, size:38, color:cyan), label:'نشر'),
        NavigationDestination(icon:Icon(Icons.chat_bubble_outline), label:'الرسائل'),
        NavigationDestination(icon:Icon(Icons.person_outline), label:'الملف الشخصي'),
      ],
    ),
  );
}

class HomePage extends StatelessWidget {
  const HomePage({super.key});
  @override Widget build(BuildContext context)=>FeedPage(following:false);
}
class FollowingPage extends StatelessWidget {
  const FollowingPage({super.key});
  @override Widget build(BuildContext context)=>FeedPage(following:true);
}

class FeedPage extends StatefulWidget {
  final bool following;
  const FeedPage({super.key, required this.following});
  @override State<FeedPage> createState()=>_FeedPageState();
}
class _FeedPageState extends State<FeedPage> {
  List<Map<String,dynamic>> posts=[]; bool loading=true;
  @override void initState(){super.initState(); load();}
  Future<void> load() async {
    try {
      final data = await sb.from('posts').select('*, profiles(username,avatar_url)').eq('visibility','public').order('created_at',ascending:false).limit(50);
      if(mounted) setState(()=>posts=List<Map<String,dynamic>>.from(data));
    } catch(_) {}
    if(mounted) setState(()=>loading=false);
  }
  @override Widget build(BuildContext context){
    return Scaffold(
      backgroundColor:Colors.black,
      body:loading ? const Center(child:CircularProgressIndicator()) :
      posts.isEmpty ? const Center(child:Text('لا توجد فيديوهات بعد.\nابدأ بالنشر من زر +',textAlign:TextAlign.center)) :
      PageView.builder(scrollDirection:Axis.vertical,itemCount:posts.length,itemBuilder:(_,i)=>VideoCard(post:posts[i])),
    );
  }
}

class VideoCard extends StatefulWidget {
  final Map<String,dynamic> post;
  const VideoCard({super.key,required this.post});
  @override State<VideoCard> createState()=>_VideoCardState();
}
class _VideoCardState extends State<VideoCard>{
  VideoPlayerController? c; bool liked=false,saved=false; int likes=0;
  String get url => (widget.post['media_url'] ?? '').toString();
  @override void initState(){super.initState(); likes=(widget.post['likes_count']??0) as int; if(url.isNotEmpty){c=VideoPlayerController.networkUrl(Uri.parse(url))..initialize().then((_){if(mounted){setState((){});c!.setLooping(true);c!.play();}});}}
  @override void dispose(){c?.dispose();super.dispose();}
  Future<void> like() async {
    final uid=sb.auth.currentUser!.id;
    try {
      if(liked){await sb.from('post_likes').delete().eq('post_id',widget.post['id']).eq('user_id',uid); likes--;}
      else {await sb.from('post_likes').insert({'post_id':widget.post['id'],'user_id':uid}); likes++;}
      setState(()=>liked=!liked);
    } catch(_){}
  }
  Future<void> save() async {
    final uid=sb.auth.currentUser!.id;
    try {
      if(saved){await sb.from('saved_posts').delete().eq('post_id',widget.post['id']).eq('user_id',uid);}
      else {await sb.from('saved_posts').insert({'post_id':widget.post['id'],'user_id':uid});}
      setState(()=>saved=!saved);
    } catch(_){}
  }
  @override Widget build(BuildContext context)=>Stack(fit:StackFit.expand,children:[
    if(c?.value.isInitialized==true) FittedBox(fit:BoxFit.cover,child:SizedBox(width:c!.value.size.width,height:c!.value.size.height,child:VideoPlayer(c!))) else const Center(child:CircularProgressIndicator()),
    Positioned(left:16,bottom:110,child:Column(children:[
      IconButton(onPressed:like,icon:Icon(liked?Icons.favorite:Icons.favorite_border,color:liked?pink:Colors.white,size:34)),
      Text('$likes'),
      IconButton(onPressed:()=>showComments(context,widget.post['id']),icon:const Icon(Icons.comment,size:32)),
      IconButton(onPressed:save,icon:Icon(saved?Icons.bookmark:Icons.bookmark_border,size:32)),
      IconButton(onPressed:()=>showShare(context),icon:const Icon(Icons.share,size:32)),
    ])),
    Positioned(right:16,left:80,bottom:30,child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      Text('@${widget.post['profiles']?['username']??'N'}',style:const TextStyle(fontWeight:FontWeight.bold,fontSize:18)),
      const SizedBox(height:6),
      Text(widget.post['caption']??'',maxLines:3,overflow:TextOverflow.ellipsis),
      const SizedBox(height:8), const Text('N original sound'),
    ])),
  ]);
}

void showShare(BuildContext context)=>showModalBottomSheet(context:context,builder:(_)=>const SafeArea(child:Padding(padding:EdgeInsets.all(24),child:Text('شارك رابط المنشور من خلال مشاركة النظام.'))));

Future<void> showComments(BuildContext context,dynamic postId) async {
  final ctrl=TextEditingController();
  await showModalBottomSheet(context:context,isScrollControlled:true,builder:(ctx)=>StatefulBuilder(builder:(ctx,set)=>Padding(
    padding:EdgeInsets.only(bottom:MediaQuery.of(ctx).viewInsets.bottom),
    child:Column(mainAxisSize:MainAxisSize.min,children:[
      const Padding(padding:EdgeInsets.all(12),child:Text('التعليقات',style:TextStyle(fontSize:20,fontWeight:FontWeight.bold))),
      SizedBox(height:280,child:FutureBuilder<List<Map<String,dynamic>>>(
        future: sb.from('comments').select('*, profiles(username)').eq('post_id',postId).order('created_at',ascending:false).then((x)=>List<Map<String,dynamic>>.from(x)),
        builder:(_,s)=>s.hasData?ListView(children:s.data!.map((e)=>ListTile(title:Text('@${e['profiles']?['username']??''}'),subtitle:Text(e['body']??''))).toList()):const Center(child:CircularProgressIndicator()),
      )),
      Row(children:[Expanded(child:TextField(controller:ctrl,decoration:const InputDecoration(hintText:'اكتب تعليقًا...'))),IconButton(icon:const Icon(Icons.send),onPressed:()async{if(ctrl.text.trim().isEmpty)return;await sb.from('comments').insert({'post_id':postId,'user_id':sb.auth.currentUser!.id,'body':ctrl.text.trim()});ctrl.clear();set((){});})])
    ])))),
  ));
}

class PublishPage extends StatefulWidget { const PublishPage({super.key}); @override State<PublishPage> createState()=>_PublishPageState(); }
class _PublishPageState extends State<PublishPage>{
  final caption=TextEditingController(); XFile? file; bool busy=false;
  Future<void> pick(ImageSource src) async { final x=await ImagePicker().pickVideo(source:src); if(x!=null)setState(()=>file=x); }
  Future<void> publish() async {
    if(file==null)return;
    setState(()=>busy=true);
    try{
      final uid=sb.auth.currentUser!.id; final ext=file!.path.split('.').last; final path='$uid/${DateTime.now().millisecondsSinceEpoch}.$ext';
      await sb.storage.from('post-media').upload(path,File(file!.path));
      final url=sb.storage.from('post-media').getPublicUrl(path);
      await sb.from('posts').insert({'user_id':uid,'media_url':url,'media_type':'video','caption':caption.text.trim(),'visibility':'public'});
      if(mounted){caption.clear();setState(()=>file=null);ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('تم نشر الفيديو')));}
    }catch(e){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('فشل النشر: $e')));}
    if(mounted)setState(()=>busy=false);
  }
  @override Widget build(BuildContext context)=>Scaffold(appBar:AppBar(title:const Text('نشر على N')),body:Padding(padding:const EdgeInsets.all(20),child:Column(children:[
    Row(children:[Expanded(child:OutlinedButton.icon(onPressed:()=>pick(ImageSource.camera),icon:const Icon(Icons.camera_alt),label:const Text('تصوير'))),const SizedBox(width:8),Expanded(child:OutlinedButton.icon(onPressed:()=>pick(ImageSource.gallery),icon:const Icon(Icons.video_library),label:const Text('رفع فيديو')))]),
    const SizedBox(height:15), if(file!=null)Text('تم اختيار: ${file!.name}'),
    TextField(controller:caption,maxLines:3,decoration:const InputDecoration(labelText:'الوصف')),
    const Spacer(),SizedBox(width:double.infinity,child:FilledButton(onPressed:busy?null:publish,child:Text(busy?'جاري النشر...':'نشر')))
  ])));
}

class MessagesPage extends StatefulWidget { const MessagesPage({super.key}); @override State<MessagesPage> createState()=>_MessagesPageState(); }
class _MessagesPageState extends State<MessagesPage>{
  List<Map<String,dynamic>> rows=[]; @override void initState(){super.initState();load();}
  Future<void> load()async{try{final x=await sb.from('conversations').select().or('user_a.eq.${sb.auth.currentUser!.id},user_b.eq.${sb.auth.currentUser!.id}').order('updated_at',ascending:false);setState(()=>rows=List<Map<String,dynamic>>.from(x));}catch(_){}}
  @override Widget build(BuildContext context)=>Scaffold(appBar:AppBar(title:const Text('الرسائل')),body:rows.isEmpty?const Center(child:Text('لا توجد محادثات بعد')):ListView(children:rows.map((e)=>ListTile(leading:const CircleAvatar(child:Icon(Icons.person)),title:Text(e['title']??'محادثة'),subtitle:Text(e['last_message']??''),onTap:()=>ChatPage.open(context,e['id']))).toList()));
}
class ChatPage extends StatefulWidget{
  final dynamic id; const ChatPage({super.key,required this.id});
  static void open(BuildContext c,dynamic id)=>Navigator.push(c,MaterialPageRoute(builder:(_)=>ChatPage(id:id)));
  @override State<ChatPage> createState()=>_ChatPageState();
}
class _ChatPageState extends State<ChatPage>{
  final ctrl=TextEditingController(); List<Map<String,dynamic>> msgs=[];
  @override void initState(){super.initState();load();}
  Future<void> load()async{try{final x=await sb.from('messages').select().eq('conversation_id',widget.id).order('created_at');setState(()=>msgs=List<Map<String,dynamic>>.from(x));}catch(_){}}
  Future<void> send()async{if(ctrl.text.trim().isEmpty)return;await sb.from('messages').insert({'conversation_id':widget.id,'sender_id':sb.auth.currentUser!.id,'body':ctrl.text.trim()});ctrl.clear();load();}
  @override Widget build(BuildContext context)=>Scaffold(appBar:AppBar(title:const Text('محادثة N')),body:Column(children:[Expanded(child:ListView(children:msgs.map((m)=>Align(alignment:m['sender_id']==sb.auth.currentUser!.id?Alignment.centerRight:Alignment.centerLeft,child:Container(margin:const EdgeInsets.all(6),padding:const EdgeInsets.all(10),decoration:BoxDecoration(color:panel,borderRadius:BorderRadius.circular(14)),child:Text(m['body']??''))).toList())),),Row(children:[Expanded(child:TextField(controller:ctrl)),IconButton(onPressed:send,icon:const Icon(Icons.send))])]));
}

class ProfilePage extends StatefulWidget { const ProfilePage({super.key}); @override State<ProfilePage> createState()=>_ProfilePageState(); }
class _ProfilePageState extends State<ProfilePage>{
  Map<String,dynamic>? p;
  @override void initState(){super.initState();load();}
  Future<void> load()async{try{final x=await sb.from('profiles').select().eq('id',sb.auth.currentUser!.id).maybeSingle();setState(()=>p=x);}catch(_){}}
  @override Widget build(BuildContext context)=>Scaffold(appBar:AppBar(title:const Text('الملف الشخصي'),actions:[IconButton(onPressed:()=>sb.auth.signOut(),icon:const Icon(Icons.logout))]),body:Center(child:Column(children:[
    const SizedBox(height:25),const CircleAvatar(radius:48,child:Icon(Icons.person,size:50)),const SizedBox(height:12),
    Text('@${p?['username']??''}',style:const TextStyle(fontSize:24,fontWeight:FontWeight.bold)),Text(p?['bio']??''),
    const SizedBox(height:20),const Text('منشوراتي',style:TextStyle(fontSize:20,fontWeight:FontWeight.bold)),
  ])));
}
