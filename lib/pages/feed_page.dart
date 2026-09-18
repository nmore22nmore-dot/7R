import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:video_player/video_player.dart';

class FeedPage extends StatefulWidget {
  final bool following;
  const FeedPage({super.key,this.following=false});
  @override State<FeedPage> createState()=>_FeedPageState();
}
class _FeedPageState extends State<FeedPage>{
  List<Map<String,dynamic>> posts=[]; bool loading=true;
  @override void initState(){super.initState();load();}
  Future<void> load()async{
    try{
      final r=await Supabase.instance.client.from('posts').select('*, profiles(username,display_name,avatar_url)').eq('visibility','public').order('created_at',ascending:false).limit(50);
      posts=List<Map<String,dynamic>>.from(r);
    }catch(_){}
    if(mounted)setState(()=>loading=false);
  }
  @override Widget build(BuildContext context)=>Stack(children:[
    if(loading)const Center(child:CircularProgressIndicator()),
    if(!loading&&posts.isEmpty)const Center(child:Text('لا توجد منشورات بعد')),
    if(posts.isNotEmpty)PageView.builder(scrollDirection:Axis.vertical,itemCount:posts.length,itemBuilder:(_,i)=>VideoPost(post:posts[i])),
    Positioned(top:44,right:16,left:16,child:Row(children:[
      const Text('N',style:TextStyle(fontSize:30,fontWeight:FontWeight.w900,color:Color(0xFF00C8FF))),
      const Spacer(),IconButton(onPressed:(){},icon:const Icon(Icons.search)),IconButton(onPressed:(){},icon:const Icon(Icons.notifications_none)),
    ])),
  ]);
}

class VideoPost extends StatefulWidget{
  final Map<String,dynamic> post;
  const VideoPost({super.key,required this.post});
  @override State<VideoPost> createState()=>_VideoPostState();
}
class _VideoPostState extends State<VideoPost>{
  VideoPlayerController? c; bool liked=false,saved=false;
  @override void initState(){
    super.initState();
    final u=widget.post['video_url']?.toString();
    if(u!=null&&u.isNotEmpty){
      c=VideoPlayerController.networkUrl(Uri.parse(u));
      c!.initialize().then((_){c!.setLooping(true);c!.play();if(mounted)setState((){});});
    }
  }
  @override void dispose(){c?.dispose();super.dispose();}
  @override Widget build(BuildContext context){
    final p=widget.post,u=p['video_url']?.toString()??'';
    return Stack(fit:StackFit.expand,children:[
      Container(color:Colors.black),
      if(c?.value.isInitialized??false)FittedBox(fit:BoxFit.cover,child:SizedBox(width:c!.value.size.width,height:c!.value.size.height,child:VideoPlayer(c!))),
      if(u.isEmpty)const Center(child:Icon(Icons.videocam_off_outlined,size:70,color:Colors.white54)),
      Positioned(bottom:90,right:16,left:90,child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        Text('@${p['profiles']?['username']??'user'}',style:const TextStyle(fontWeight:FontWeight.bold,fontSize:18)),
        const SizedBox(height:8),Text(p['caption']??'',maxLines:3),
        const SizedBox(height:8),const Text('N original sound'),
      ])),
      Positioned(bottom:110,left:12,child:Column(children:[
        IconButton(onPressed:()=>setState(()=>liked=!liked),icon:Icon(liked?Icons.favorite:Icons.favorite_border,color:liked?const Color(0xFFFF287A):Colors.white,size:34)),
        IconButton(onPressed:(){},icon:const Icon(Icons.comment_outlined,size:32)),
        IconButton(onPressed:()=>setState(()=>saved=!saved),icon:Icon(saved?Icons.bookmark:Icons.bookmark_border,size:32)),
        IconButton(onPressed:(){},icon:const Icon(Icons.share_outlined,size:32)),
      ])),
    ]);
  }
}
