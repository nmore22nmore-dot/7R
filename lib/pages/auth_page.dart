import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'home_page.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});
  @override
  Widget build(BuildContext context) => StreamBuilder<AuthState>(
    stream: Supabase.instance.client.auth.onAuthStateChange,
    builder: (_, __) => Supabase.instance.client.auth.currentSession == null
      ? const AuthPage() : const HomePage(),
  );
}

class AuthPage extends StatefulWidget {
  const AuthPage({super.key});
  @override State<AuthPage> createState() => _AuthPageState();
}
class _AuthPageState extends State<AuthPage> {
  final email=TextEditingController(), password=TextEditingController(), username=TextEditingController();
  bool login=true, busy=false;
  Future<void> submit() async {
    setState(()=>busy=true);
    try {
      final sb=Supabase.instance.client;
      if(login) {
        await sb.auth.signInWithPassword(email:email.text.trim(),password:password.text);
      } else {
        final u=username.text.trim();
        if(u.length<4) throw Exception('اسم المستخدم يجب أن يكون 4 أحرف على الأقل.');
        await sb.auth.signUp(email:email.text.trim(),password:password.text,data:{'username':u});
      }
    } catch(e) {
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(e.toString())));
    } finally { if(mounted)setState(()=>busy=false); }
  }
  @override Widget build(BuildContext context)=>Directionality(
    textDirection:TextDirection.rtl,
    child:Scaffold(body:Center(child:SingleChildScrollView(
      padding:const EdgeInsets.all(24),
      child:ConstrainedBox(constraints:const BoxConstraints(maxWidth:420),child:Column(children:[
        const Text('N',style:TextStyle(fontSize:76,fontWeight:FontWeight.w900,color:Color(0xFF00C8FF))),
        Text(login?'تسجيل الدخول':'إنشاء حساب',style:const TextStyle(fontSize:26,fontWeight:FontWeight.bold)),
        const SizedBox(height:24),
        if(!login) TextField(controller:username,decoration:const InputDecoration(labelText:'اسم المستخدم')),
        const SizedBox(height:12),
        TextField(controller:email,decoration:const InputDecoration(labelText:'البريد الإلكتروني')),
        const SizedBox(height:12),
        TextField(controller:password,obscureText:true,decoration:const InputDecoration(labelText:'كلمة المرور')),
        const SizedBox(height:20),
        SizedBox(width:double.infinity,child:FilledButton(onPressed:busy?null:submit,child:Text(busy?'...':(login?'دخول':'تسجيل')))),
        TextButton(onPressed:()=>setState(()=>login=!login),child:Text(login?'إنشاء حساب جديد':'لدي حساب بالفعل')),
      ])),
    ))),
  );
}
