import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'n_data.dart';

Future<void> main() async {
WidgetsFlutterBinding.ensureInitialized();

const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
const supabasePublishableKey =
String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');

if (supabaseUrl.isEmpty || supabasePublishableKey.isEmpty) {
runApp(const NConfigurationErrorApp());
return;
}

await Supabase.initialize(
url: supabaseUrl,
publishableKey: supabasePublishableKey,
);

runApp(const NApp());
}

class NConfigurationErrorApp extends StatelessWidget {
const NConfigurationErrorApp({super.key});

@override
Widget build(BuildContext context) {
return MaterialApp(
debugShowCheckedModeBanner: false,
home: Scaffold(
body: Center(
child: Padding(
padding: const EdgeInsets.all(24),
child: Text(
'إعدادات Supabase غير موجودة. أعد بناء التطبيق من Codemagic.',
textAlign: TextAlign.center,
),
),
),
),
);
}
}

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
scaffoldBackgroundColor: const Color(0xFF07080D),
colorScheme: ColorScheme.fromSeed(
seedColor: const Color(0xFF00C8FF),
brightness: Brightness.dark,
),
inputDecorationTheme: InputDecorationTheme(
filled: true,
fillColor: const Color(0xFF11141C),
border: OutlineInputBorder(
borderRadius: BorderRadius.circular(16),
borderSide: BorderSide.none,
),
),
),
home: const Directionality(
textDirection: TextDirection.rtl,
child: LoginPage(),
),
);
}
}

class LoginPage extends StatefulWidget {
const LoginPage({super.key});

@override
State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
bool register = true;
bool hidden = true;

final name = TextEditingController();
final username = TextEditingController();
final email = TextEditingController();
final password = TextEditingController();

DateTime? birthDate;

@override
void dispose() {
name.dispose();
username.dispose();
email.dispose();
password.dispose();
super.dispose();
}

int ageFromBirth(DateTime date) {
final now = DateTime.now();
var age = now.year - date.year;

if (DateTime(now.year, date.month, date.day).isAfter(now)) {
  age--;
}

return age;

}

Future<void> chooseBirthDate() async {
final result = await showDatePicker(
context: context,
initialDate: DateTime(2000),
firstDate: DateTime(1900),
lastDate: DateTime.now(),
helpText: 'اختر تاريخ الميلاد',
);

if (result != null) {
  setState(() => birthDate = result);
}

}

void message(String text) {
ScaffoldMessenger.of(context).showSnackBar(
SnackBar(content: Text(text)),
);
}

Future<void> submit() async {
final cleanUsername = username.text
.trim()
.replaceFirst('@', '')
.replaceAll(' ', '')
.toLowerCase();

final cleanEmail = email.text.trim();
final cleanName = name.text.trim();
final cleanPassword = password.text;

if (register && cleanName.isEmpty) {
  message('اكتب اسمك');
  return;
}

if (cleanUsername.length < 4) {
  message('اسم المستخدم يجب أن يحتوي على 4 أحرف على الأقل');
  return;
}

if (!RegExp(r'^[a-zA-Z0-9_.]+$').hasMatch(cleanUsername)) {
  message('استخدم الأحرف الإنجليزية والأرقام و _ و . فقط');
  return;
}

if (!cleanEmail.contains('@')) {
  message('أدخل بريدًا إلكترونيًا صحيحًا');
  return;
}

if (cleanPassword.length < 6) {
  message('كلمة المرور يجب أن تكون 6 أحرف على الأقل');
  return;
}

if (register && birthDate == null) {
  message('اختر تاريخ الميلاد');
  return;
}

final age = register ? ageFromBirth(birthDate!) : 25;

if (register && age < 13) {
  message('يجب أن يكون العمر 13 سنة أو أكثر');
  return;
}

try {
  final client = Supabase.instance.client;

  if (register) {
    final existing = await client
        .from('profiles')
        .select('id')
        .eq('username', cleanUsername)
        .maybeSingle();

    if (existing != null) {
      message('اسم المستخدم مستخدم بالفعل');
      return;
    }

    final response = await client.auth.signUp(
      email: cleanEmail,
      password: cleanPassword,
      data: {
        'name': cleanName,
        'username': cleanUsername,
        'age': age,
      },
    );

    final user = response.user;

    if (user == null) {
      message('تعذر إنشاء الحساب');
      return;
    }

    if (response.session == null) {
      message(
        'تم إنشاء الحساب. تحقق من بريدك الإلكتروني ثم سجّل الدخول.',
      );
      setState(() => register = false);
      return;
    }

    await data.loadCurrentUser();

    if (!mounted) return;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const NHome()),
    );

    return;
  }

  await client.auth.signInWithPassword(
    email: cleanEmail,
    password: cleanPassword,
  );

  await data.loadCurrentUser();

  if (!data.loggedIn) {
    message(data.errorMessage ?? 'تعذر تحميل الحساب');
    return;
  }

  if (!mounted) return;

  Navigator.pushReplacement(
    context,
    MaterialPageRoute(builder: (_) => const NHome()),
  );
} on AuthException catch (e) {
  message(e.message);
} on PostgrestException catch (e) {
  message('خطأ في قاعدة البيانات: ${e.message}');
} catch (e) {
  message('حدث خطأ أثناء العملية');
}

}

@override
Widget build(BuildContext context) {
return Scaffold(
body: SafeArea(
child: Center(
child: SingleChildScrollView(
padding: const EdgeInsets.all(24),
child: ConstrainedBox(
constraints: const BoxConstraints(maxWidth: 500),
child: Column(
crossAxisAlignment: CrossAxisAlignment.stretch,
children: [
const SizedBox(height: 35),
const CircleAvatar(
radius: 42,
child: Text(
'N',
style: TextStyle(
fontSize: 38,
fontWeight: FontWeight.w900,
),
),
),
const SizedBox(height: 18),
const Text(
'N',
textAlign: TextAlign.center,
style: TextStyle(
fontSize: 42,
fontWeight: FontWeight.w900,
),
),
const SizedBox(height: 6),
Text(
register
? 'أنشئ حسابك في N'
: 'مرحباً بعودتك إلى N',
textAlign: TextAlign.center,
style: const TextStyle(
fontSize: 18,
color: Colors.white70,
),
),
const SizedBox(height: 32),
if (register) ...[
TextField(
controller: name,
textInputAction: TextInputAction.next,
decoration: const InputDecoration(
labelText: 'الاسم',
prefixIcon: Icon(Icons.person_outline),
),
),
const SizedBox(height: 14),
],
TextField(
controller: username,
textInputAction: TextInputAction.next,
decoration: const InputDecoration(
labelText: 'اسم المستخدم',
hintText: 'username',
prefixIcon: Icon(Icons.alternate_email),
),
),
const SizedBox(height: 14),
TextField(
controller: email,
keyboardType: TextInputType.emailAddress,
textInputAction: TextInputAction.next,
decoration: const InputDecoration(
labelText: 'البريد الإلكتروني',
prefixIcon: Icon(Icons.email_outlined),
),
),
const SizedBox(height: 14),
TextField(
controller: password,
obscureText: hidden,
onSubmitted: (_) => submit(),
decoration: InputDecoration(
labelText: 'كلمة المرور',
prefixIcon: const Icon(Icons.lock_outline),
suffixIcon: IconButton(
onPressed: () {
setState(() => hidden = !hidden);
},
icon: Icon(
hidden
? Icons.visibility_outlined
: Icons.visibility_off_outlined,
),
),
),
),
if (register) ...[
const SizedBox(height: 14),
OutlinedButton.icon(
onPressed: chooseBirthDate,
icon: const Icon(Icons.cake_outlined),
label: Text(
birthDate == null
? 'اختيار تاريخ الميلاد'
: 'تاريخ الميلاد: '
'${birthDate!.day}/'
'${birthDate!.month}/'
'${birthDate!.year}',
),
),
],
const SizedBox(height: 22),
FilledButton(
onPressed: data.loading ? null : submit,
child: Padding(
padding: const EdgeInsets.symmetric(vertical: 14),
child: Text(
register ? 'إنشاء الحساب' : 'تسجيل الدخول',
style: const TextStyle(
fontSize: 17,
fontWeight: FontWeight.bold,
),
),
),
),
const SizedBox(height: 12),
TextButton(
onPressed: () {
setState(() => register = !register);
},
child: Text(
register
? 'لديك حساب بالفعل؟ تسجيل الدخول'
: 'ليس لديك حساب؟ إنشاء حساب',
),
),
],
),
),
),
),
),
);
}
}

class NHome extends StatefulWidget {
const NHome({super.key});

@override
State<NHome> createState() => _NHomeState();
}

class _NHomeState extends State<NHome> {
int index = 0;

final pages = const [
NVideoFeedPage(),
ExplorePage(),
CreatePage(),
MessagesPage(),
ProfilePage(),
];

@override
Widget build(BuildContext context) {
return AnimatedBuilder(
animation: data,
builder: (_, __) {
return Scaffold(
body: IndexedStack(
index: index,
children: pages,
),
bottomNavigationBar: NavigationBar(
selectedIndex: index,
onDestinationSelected: (value) {
setState(() => index = value);
},
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
label: 'الملف',
),
],
),
);
},
);
}
}

class NVideoFeedPage extends StatelessWidget {
const NVideoFeedPage({super.key});

@override
Widget build(BuildContext context) {
final posts = data.visiblePosts();

if (posts.isEmpty) {
  return const Center(
    child: Text(
      'لا توجد منشورات حالياً',
      style: TextStyle(fontSize: 18),
    ),
  );
}

return PageView.builder(
  scrollDirection: Axis.vertical,
  itemCount: posts.length,
  itemBuilder: (_, index) {
    return PostCard(
      post: posts[index],
      fullScreen: true,
    );
  },
);

}
}

class PostCard extends StatelessWidget {
const PostCard({
super.key,
required this.post,
this.fullScreen = false,
});

final NPost post;
final bool fullScreen;

@override
Widget build(BuildContext context) {
return Card(
margin: fullScreen
? EdgeInsets.zero
: const EdgeInsets.only(bottom: 12),
clipBehavior: Clip.antiAlias,
child: Container(
constraints: fullScreen
? const BoxConstraints.expand()
: const BoxConstraints(minHeight: 230),
padding: const EdgeInsets.all(18),
child: Stack(
children: [
if (fullScreen)
const Positioned.fill(
child: ColoredBox(
color: Color(0xFF0C0E14),
child: Center(
child: Icon(
Icons.play_circle_outline,
size: 80,
color: Colors.white38,
),
),
),
),
Positioned(
right: 16,
left: 16,
bottom: fullScreen ? 30 : 16,
child: Column(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
Row(
children: [
const CircleAvatar(
radius: 23,
child: Icon(Icons.person),
),
const SizedBox(width: 10),
Text(
post.author,
style: const TextStyle(
fontSize: 17,
fontWeight: FontWeight.bold,
),
),
if (post.verified) ...[
const SizedBox(width: 5),
const Icon(Icons.verified, size: 19),
],
],
),
const SizedBox(height: 12),
Text(
post.text,
style: const TextStyle(
fontSize: 17,
height: 1.4,
),
),
const SizedBox(height: 14),
Row(
children: [
IconButton(
onPressed: () => data.like(post),
icon: Icon(
post.liked
? Icons.favorite
: Icons.favorite_border,
color: post.liked ? Colors.red : null,
),
),
Text('${post.likes}'),
const SizedBox(width: 12),
IconButton(
onPressed: () => data.comment(post),
icon: const Icon(Icons.mode_comment_outlined),
),
Text('${post.comments}'),
const SizedBox(width: 12),
IconButton(
onPressed: () => data.save(post),
icon: Icon(
post.saved
? Icons.bookmark
: Icons.bookmark_border,
),
),
],
),
],
),
),
],
),
),
);
}
}

class ExplorePage extends StatelessWidget {
const ExplorePage({super.key});

@override
Widget build(BuildContext context) {
return Scaffold(
appBar: AppBar(
title: const Text(
'استكشاف',
style: TextStyle(fontWeight: FontWeight.w900),
),
),
body: ListView(
padding: const EdgeInsets.all(12),
children: [
const TextField(
decoration: InputDecoration(
hintText: 'بحث في N',
prefixIcon: Icon(Icons.search),
),
),
const SizedBox(height: 22),
const Text(
'حسابات مقترحة',
style: TextStyle(
fontSize: 21,
fontWeight: FontWeight.bold,
),
),
const SizedBox(height: 10),
...[
['Ahmed', 'ahmed'],
['Sara', 'sara'],
['N Official', 'n'],
['N News', 'nnews'],
].map(
(user) => Card(
margin: const EdgeInsets.only(bottom: 9),
child: ListTile(
leading: const CircleAvatar(
child: Icon(Icons.person),
),
title: Text(user[0]),
subtitle: Text('@${user[1]}'),
onTap: () => Navigator.push(
context,
MaterialPageRoute(
builder: (_) => UserProfilePage(
name: user[0],
username: user[1],
),
),
),
trailing: FilledButton(
onPressed: () => data.follow(user[1]),
child: Text(
data.following.contains(user[1])
? 'متابَع'
: 'متابعة',
),
),
),
),
),
],
),
);
}
}

class CreatePage extends StatefulWidget {
const CreatePage({super.key});

@override
State<CreatePage> createState() => _CreatePageState();
}

class _CreatePageState extends State<CreatePage> {
final controller = TextEditingController();

bool adult = false;
String visibility = 'عام';

@override
void dispose() {
controller.dispose();
super.dispose();
}

Future<void> publish() async {
final text = controller.text.trim();

if (text.isEmpty) {
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text('اكتب شيئًا قبل النشر')),
  );
  return;
}

final success = await data.createPost(
  text,
  adult: adult,
  visibility: visibility,
);

if (!mounted) return;

if (!success) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(
        data.errorMessage ?? 'تعذر نشر المنشور',
      ),
    ),
  );
  return;
}

controller.clear();

setState(() {
  adult = false;
  visibility = 'عام';
});

ScaffoldMessenger.of(context).showSnackBar(
  const SnackBar(content: Text('تم نشر المنشور بنجاح')),
);

}

@override
Widget build(BuildContext context) {
return Padding(
padding: const EdgeInsets.all(16),
child: Column(
crossAxisAlignment: CrossAxisAlignment.stretch,
children: [
const Text(
'إنشاء منشور',
style: TextStyle(
fontSize: 29,
fontWeight: FontWeight.w900,
),
),
const SizedBox(height: 16),
Row(
children: [
const CircleAvatar(
radius: 24,
child: Icon(Icons.person),
),
const SizedBox(width: 10),
Text(
data.name,
style: const TextStyle(
fontWeight: FontWeight.bold,
),
),
],
),
const SizedBox(height: 14),
Expanded(
child: TextField(
controller: controller,
maxLines: null,
expands: true,
maxLength: 2000,
textAlignVertical: TextAlignVertical.top,
decoration: const InputDecoration(
hintText: 'ماذا تريد أن تشارك؟',
contentPadding: EdgeInsets.all(17),
),
),
),
SwitchListTile(
contentPadding: EdgeInsets.zero,
title: const Text('+21'),
subtitle: const Text(
'محتوى للبالغين بعمر 21 سنة فأكثر',
),
value: adult,
onChanged: (value) {
if (value && !data.adultAllowed) {
ScaffoldMessenger.of(context).showSnackBar(
const SnackBar(
content: Text(
'هذا الخيار متاح للحسابات بعمر 21 سنة فأكثر',
),
),
);
return;
}

          setState(() => adult = value);
        },
      ),
      DropdownButtonFormField<String>(
        initialValue: visibility,
        decoration: const InputDecoration(
          labelText: 'الخصوصية',
        ),
        items: const [
          DropdownMenuItem(
            value: 'عام',
            child: Text('عام'),
          ),
          DropdownMenuItem(
            value: 'المتابعون',
            child: Text('المتابعون'),
          ),
          DropdownMenuItem(
            value: 'خاص',
            child: Text('خاص'),
          ),
        ],
        onChanged: (value) {
          if (value != null) {
            setState(() => visibility = value);
          }
        },
      ),
      const SizedBox(height: 10),
      FilledButton.icon(
        onPressed: data.loading ? null : publish,
        icon: const Icon(Icons.send),
        label: const Padding(
          padding: EdgeInsets.all(13),
          child: Text('نشر'),
        ),
      ),
    ],
  ),
);

}
}

class MessagesPage extends StatelessWidget {
const MessagesPage({super.key});

@override
Widget build(BuildContext context) {
return Scaffold(
appBar: AppBar(
title: const Text(
'الرسائل',
style: TextStyle(fontWeight: FontWeight.w900),
),
),
body: AnimatedBuilder(
animation: data,
builder: (_, __) {
final conversations = data.sortedConversations();

      if (conversations.isEmpty) {
        return const Center(
          child: Text('لا توجد محادثات'),
        );
      }

      return ListView(
        padding: const EdgeInsets.all(12),
        children: conversations.map((entry) {
          final last = entry.value.isEmpty
              ? null
              : entry.value.last;

          return Card(
            margin: const EdgeInsets.only(bottom: 10),
            child: ListTile(
              leading: const CircleAvatar(
                child: Icon(Icons.person),
              ),
              title: Text('@${entry.key}'),
              subtitle: Text(
                last?.text ?? 'لا توجد رسائل',
              ),
              trailing: const Icon(Icons.chevron_left),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ChatPage(
                    name: entry.key,
                    username: entry.key,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      );
    },
  ),
);

}
}

class ChatPage extends StatefulWidget {
const ChatPage({
super.key,
required this.name,
required this.username,
});

final String name;
final String username;

@override
State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
final controller = TextEditingController();

@override
void dispose() {
controller.dispose();
super.dispose();
}

Future<void> send() async {
final text = controller.text.trim();

if (text.isEmpty) return;

await data.sendMessage(widget.username, text);

if (!mounted) return;

controller.clear();

}

@override
Widget build(BuildContext context) {
return Scaffold(
appBar: AppBar(
title: Text(widget.name),
),
body: Column(
children: [
Expanded(
child: AnimatedBuilder(
animation: data,
builder: (_, __) {
final current =
data.messages[widget.username] ?? [];

            return ListView.builder(
              padding: const EdgeInsets.all(15),
              itemCount: current.length,
              itemBuilder: (_, i) {
                final message = current[i];
                final mine =
                    message.sender == data.username;

                return Align(
                  alignment: mine
                      ? Alignment.centerRight
                      : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: mine
                          ? const Color(0xFF006D91)
                          : const Color(0xFF1B1E27),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        Text(message.text),
                        const SizedBox(height: 3),
                        Text(
                          message.time,
                          style: const TextStyle(
                            fontSize: 10,
                            color: Colors.white54,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
      SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => send(),
                  decoration: const InputDecoration(
                    hintText: 'اكتب رسالة...',
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                onPressed: send,
                icon: const Icon(Icons.send),
              ),
            ],
          ),
        ),
      ),
    ],
  ),
);

}
}

class ProfilePage extends StatelessWidget {
const ProfilePage({super.key});

@override
Widget build(BuildContext context) {
return AnimatedBuilder(
animation: data,
builder: (_, __) {
final myPosts = data.postsOf(data.username);

    return Scaffold(
      appBar: AppBar(
        title: Text('@${data.username}'),
        actions: [
          IconButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const NotificationsPage(),
              ),
            ),
            icon: const Icon(Icons.notifications_outlined),
          ),
          IconButton(
            onPressed: () async {
              await data.logout();

              if (!context.mounted) return;

              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(
                  builder: (_) => const LoginPage(),
                ),
                (_) => false,
              );
            },
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const SizedBox(height: 10),
          const Center(
            child: CircleAvatar(
              radius: 48,
              child: Icon(Icons.person, size: 50),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            data.name,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '@${data.username}',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white60,
            ),
          ),
          const SizedBox(height: 18),
          Row(
            mainAxisAlignment:
                MainAxisAlignment.spaceEvenly,
            children: [
              _ProfileStat(
                value: '${myPosts.length}',
                label: 'منشورات',
              ),
              const _ProfileStat(
                value: '0',
                label: 'المتابعون',
              ),
              _ProfileStat(
                value: '${data.following.length}',
                label: 'يتابع',
              ),
            ],
          ),
          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 12),
          const Text(
            'منشوراتي',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 12),
          if (myPosts.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(40),
                child: Text('لم تنشر أي منشورات بعد'),
              ),
            )
          else
            ...myPosts.map(
              (post) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: PostCard(post: post),
              ),
            ),
        ],
      ),
    );
  },
);

}
}

class _ProfileStat extends StatelessWidget {
const _ProfileStat({
required this.value,
required this.label,
});

final String value;
final String label;

@override
Widget build(BuildContext context) {
return Column(
children: [
Text(
value,
style: const TextStyle(
fontSize: 20,
fontWeight: FontWeight.w900,
),
),
const SizedBox(height: 3),
Text(
label,
style: const TextStyle(color: Colors.white60),
),
],
);
}
}

class UserProfilePage extends StatelessWidget {
const UserProfilePage({
super.key,
required this.name,
required this.username,
});

final String name;
final String username;

@override
Widget build(BuildContext context) {
return AnimatedBuilder(
animation: data,
builder: (_, __) {
final userPosts = data.postsOf(username);
final isFollowing =
data.following.contains(username);

    return Scaffold(
      appBar: AppBar(
        title: Text('@$username'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const SizedBox(height: 10),
          const Center(
            child: CircleAvatar(
              radius: 48,
              child: Icon(Icons.person, size: 50),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            name,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w900,
            ),
          ),
          Text(
            '@$username',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white60,
            ),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () => data.follow(username),
            child: Text(
              isFollowing ? 'إلغاء المتابعة' : 'متابعة',
            ),
          ),
          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 12),
          const Text(
            'المنشورات',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 12),
          if (userPosts.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(40),
                child: Text('لا توجد منشورات'),
              ),
            )
          else
            ...userPosts.map(
              (post) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: PostCard(post: post),
              ),
            ),
        ],
      ),
    );
  },
);

}
}

class NotificationsPage extends StatelessWidget {
const NotificationsPage({super.key});

@override
Widget build(BuildContext context) {
return Scaffold(
appBar: AppBar(
title: const Text('الإشعارات'),
),
body: const ListView(
padding: EdgeInsets.all(12),
children: [
ListTile(
leading: CircleAvatar(
child: Icon(Icons.favorite),
),
title: Text('إعجاب جديد'),
subtitle: Text('أعجب شخص بمنشورك'),
),
ListTile(
leading: CircleAvatar(
child: Icon(Icons.person_add),
),
title: Text('متابع جديد'),
subtitle: Text('بدأ شخص بمتابعتك'),
),
ListTile(
leading: CircleAvatar(
child: Icon(Icons.comment),
),
title: Text('تعليق جديد'),
subtitle: Text('تمت إضافة تعليق على منشورك'),
),
],
),
);
}
}
