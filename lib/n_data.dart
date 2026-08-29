import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class NPost {
NPost({
required this.id,
required this.author,
required this.username,
required this.text,
this.likes = 0,
this.comments = 0,
this.adult = false,
this.visibility = 'عام',
this.verified = false,
this.video = false,
this.videoUrl,
this.imageUrl,
this.liked = false,
this.saved = false,
});

final String id;
final String author;
final String username;
final String text;

int likes;
int comments;

bool liked;
bool saved;

bool adult;
String visibility;

bool verified;
bool video;

String? videoUrl;
String? imageUrl;

factory NPost.fromMap(
Map<String, dynamic> map, {
int likes = 0,
int comments = 0,
bool liked = false,
bool saved = false,
}) {
final profile = map['profiles'] is Map
? Map<String, dynamic>.from(
map['profiles'] as Map,
)
: <String, dynamic>{};

return NPost(
  id: map['id'].toString(),
  author: (profile['name'] ?? 'مستخدم N').toString(),
  username: (profile['username'] ?? '').toString(),
  text: (map['text'] ?? '').toString(),
  likes: likes,
  comments: comments,
  adult: map['adult'] == true,
  visibility: (map['visibility'] ?? 'عام').toString(),
  verified: profile['verified'] == true,
  video: map['video'] == true,
  videoUrl: map['video_url']?.toString(),
  imageUrl: map['image_url']?.toString(),
  liked: liked,
  saved: saved,
);

}
}

class NMessage {
NMessage({
required this.sender,
required this.text,
required this.time,
});

final String sender;
final String text;
final String time;

factory NMessage.fromMap(
Map<String, dynamic> map,
) {
final created = DateTime.tryParse(
(map['created_at'] ?? '').toString(),
);

final time = created == null
    ? ''
    : '${created.hour.toString().padLeft(2, '0')}:'
      '${created.minute.toString().padLeft(2, '0')}';

final senderProfile = map['profiles'] is Map
    ? Map<String, dynamic>.from(
        map['profiles'] as Map,
      )
    : <String, dynamic>{};

return NMessage(
  sender: (
    senderProfile['username'] ??
    map['sender_username'] ??
    'مستخدم'
  ).toString(),
  text: (map['text'] ?? '').toString(),
  time: time,
);

}
}

class NConversation {
NConversation({
required this.name,
required this.username,
this.messages = const [],
});

final String name;
final String username;
final List<NMessage> messages;

NMessage? get lastMessage =>
messages.isEmpty ? null : messages.last;
}

class NData extends ChangeNotifier {
NData();

final SupabaseClient supabase =
Supabase.instance.client;

String name = 'مستخدم N';
String username = 'n_user';
String email = '';
int age = 25;

bool loggedIn = false;

bool privateAccount = false;
bool activityStatus = true;
bool allowMessages = true;
bool notifications = true;
bool sounds = true;

int supporterLevel = 0;
int coins = 0;

String? avatarUrl;

final List<String> badges = [];

final List<NPost> posts = [];

final Set<String> following = {};

final Map<String, List<NMessage>> messages = {};

bool loading = false;
String? errorMessage;

bool get adultAllowed => age >= 21;

String? get userId =>
supabase.auth.currentUser?.id;

/* =========================================================
INITIALIZATION
========================================================= */

Future<void> initialize() async {
loading = true;
errorMessage = null;
notifyListeners();

try {
  final session =
      supabase.auth.currentSession;

  if (session != null) {
    await loadCurrentUser();
  } else {
    loggedIn = false;
  }
} catch (e) {
  errorMessage =
      'تعذر تهيئة التطبيق: $e';
  loggedIn = false;
} finally {
  loading = false;
  notifyListeners();
}

}

/* =========================================================
AUTH
========================================================= */

Future<bool> signUp({
required String newName,
required String newUsername,
required String newEmail,
required String password,
required int newAge,
}) async {
errorMessage = null;

final cleanName = newName.trim();
final cleanUsername = newUsername.trim();
final cleanEmail = newEmail.trim();

if (cleanName.isEmpty ||
    cleanUsername.isEmpty ||
    cleanEmail.isEmpty ||
    password.length < 6) {
  errorMessage =
      'يرجى إدخال البيانات بشكل صحيح';
  notifyListeners();
  return false;
}

if (cleanUsername.contains('@')) {
  errorMessage =
      'لا تكتب @ داخل اسم المستخدم';
  notifyListeners();
  return false;
}

if (cleanUsername.contains(' ')) {
  errorMessage =
      'لا يمكن أن يحتوي اسم المستخدم على مسافات';
  notifyListeners();
  return false;
}

if (cleanUsername.length < 4) {
  errorMessage =
      'اسم المستخدم يجب أن يكون 4 أحرف على الأقل';
  notifyListeners();
  return false;
}

if (newAge < 13 || newAge > 120) {
  errorMessage =
      'العمر يجب أن يكون بين 13 و120 سنة';
  notifyListeners();
  return false;
}

try {
  final existing = await supabase
      .from('profiles')
      .select('id')
      .eq('username', cleanUsername)
      .maybeSingle();

  if (existing != null) {
    errorMessage =
        'اسم المستخدم مستخدم بالفعل';
    notifyListeners();
    return false;
  }

  final response =
      await supabase.auth.signUp(
    email: cleanEmail,
    password: password,
    data: {
      'name': cleanName,
      'username': cleanUsername,
    },
  );

  final user = response.user;

  if (user == null) {
    errorMessage =
        'تعذر إنشاء الحساب';
    notifyListeners();
    return false;
  }

  await supabase.from('profiles').upsert({
    'id': user.id,
    'name': cleanName,
    'username': cleanUsername,
    'email': cleanEmail,
    'age': newAge,
  });

  name = cleanName;
  username = cleanUsername;
  email = cleanEmail;
  age = newAge;

  loggedIn = response.session != null;

  if (response.session != null) {
    await loadCurrentUser();
  }

  notifyListeners();
  return true;
} on AuthException catch (e) {
  errorMessage = e.message;
  notifyListeners();
  return false;
} catch (_) {
  errorMessage =
      'حدث خطأ أثناء إنشاء الحساب';
  notifyListeners();
  return false;
}

}

Future<bool> loginWithPassword({
required String emailAddress,
required String password,
}) async {
errorMessage = null;

try {
  await supabase.auth.signInWithPassword(
    email: emailAddress.trim(),
    password: password,
  );

  await loadCurrentUser();

  return loggedIn;
} on AuthException catch (e) {
  errorMessage = e.message;
  notifyListeners();
  return false;
} catch (_) {
  errorMessage =
      'تعذر تسجيل الدخول';
  notifyListeners();
  return false;
}

}

Future<void> loadCurrentUser() async {
final user =
supabase.auth.currentUser;

if (user == null) {
  loggedIn = false;
  return;
}

final profile = await supabase
    .from('profiles')
    .select()
    .eq('id', user.id)
    .maybeSingle();

if (profile == null) {
  loggedIn = false;
  return;
}

name =
    (profile['name'] ?? 'مستخدم N').toString();

username =
    (profile['username'] ?? 'n_user').toString();

email =
    (profile['email'] ??
            user.email ??
            '')
        .toString();

age = _toInt(
  profile['age'],
  fallback: 25,
);

avatarUrl =
    profile['avatar_url']?.toString();

privateAccount =
    profile['private_account'] == true;

activityStatus =
    profile['activity_status'] != false;

allowMessages =
    profile['allow_messages'] != false;

notifications =
    profile['notifications'] != false;

sounds =
    profile['sounds'] != false;

supporterLevel = _toInt(
  profile['supporter_level'],
  fallback: 0,
);

coins = _toInt(
  profile['coins'],
  fallback: 0,
);

loggedIn = true;

await Future.wait([
  loadPosts(),
  loadFollowing(),
]);

notifyListeners();

}

int _toInt(
dynamic value, {
required int fallback,
}) {
if (value is int) {
return value;
}

if (value is num) {
  return value.toInt();
}

return int.tryParse(
      value?.toString() ?? '',
    ) ??
    fallback;

}

/*

* للتوافق مع الملفات القديمة.
  */
  void login({
  required String newName,
  required String newUsername,
  required String newEmail,
  required int newAge,
  }) {
  name = newName;
  username = newUsername;
  email = newEmail;
  age = newAge;
  loggedIn = true;
  notifyListeners();
  }

Future<void> logout() async {
try {
await supabase.auth.signOut();
} catch (_) {}

name = 'مستخدم N';
username = 'n_user';
email = '';
age = 25;
loggedIn = false;

posts.clear();
following.clear();
messages.clear();

notifyListeners();

}

/* =========================================================
POSTS
========================================================= */

Future<void> loadPosts() async {
if (!loggedIn) return;

try {
  final rows = await supabase
      .from('posts')
      .select(
        '*, profiles!posts_user_id_fkey(*)',
      )
      .order(
        'created_at',
        ascending: false,
      );

  final loaded = <NPost>[];

  for (final row in rows) {
    final map =
        Map<String, dynamic>.from(row);

    final postId =
        map['id'].toString();

    final likeRows = await supabase
        .from('post_likes')
        .select('user_id')
        .eq('post_id', postId);

    final commentRows = await supabase
        .from('comments')
        .select('id')
        .eq('post_id', postId);

    final liked = userId == null
        ? false
        : likeRows.any(
            (like) =>
                like['user_id']
                    .toString() ==
                userId,
          );

    final saved =
        userId == null
            ? false
            : await _isSaved(postId);

    loaded.add(
      NPost.fromMap(
        map,
        likes: likeRows.length,
        comments: commentRows.length,
        liked: liked,
        saved: saved,
      ),
    );
  }

  posts
    ..clear()
    ..addAll(loaded);

  notifyListeners();
} catch (_) {
  errorMessage =
      'تعذر تحميل المنشورات';
  notifyListeners();
}

}

Future<bool> createPost(
String text, {
bool adult = false,
String visibility = 'عام',
bool video = false,
String? videoUrl,
String? imageUrl,
}) async {
final cleanText = text.trim();

if (userId == null) {
  errorMessage =
      'يجب تسجيل الدخول أولاً';
  notifyListeners();
  return false;
}

if (cleanText.isEmpty &&
    videoUrl == null &&
    imageUrl == null) {
  errorMessage =
      'اكتب منشورًا أو اختر صورة أو فيديو';
  notifyListeners();
  return false;
}

if (adult && !adultAllowed) {
  errorMessage =
      'محتوى +21 غير متاح لمن هم دون 21 عاماً';
  notifyListeners();
  return false;
}

try {
  await supabase.from('posts').insert({
    'user_id': userId,
    'text': cleanText,
    'adult': adult,
    'visibility': visibility,
    'video': video,
    'video_url': videoUrl,
    'image_url': imageUrl,
  });

  await loadPosts();

  return true;
} catch (_) {
  errorMessage =
      'تعذر نشر المنشور';
  notifyListeners();
  return false;
}

}

Future<void> deletePost(
NPost post,
) async {
if (userId == null) return;

try {
  await supabase
      .from('posts')
      .delete()
      .eq('id', post.id)
      .eq('user_id', userId!);

  posts.removeWhere(
    (item) => item.id == post.id,
  );

  notifyListeners();
} catch (_) {
  errorMessage =
      'تعذر حذف المنشور';
  notifyListeners();
}

}

List<NPost> visiblePosts() {
return posts.where((post) {
if (post.adult && !adultAllowed) {
return false;
}

  if (post.visibility == 'خاص' &&
      post.username != username) {
    return false;
  }

  if (post.visibility == 'المتابعون' &&
      post.username != username &&
      !following.contains(
        post.username,
      )) {
    return false;
  }

  return true;
}).toList();

}

List<NPost> postsOf(
String user,
) {
return posts
.where(
(post) => post.username == user,
)
.toList();
}

/* =========================================================
LIKE
========================================================= */

Future<void> like(
NPost post,
) async {
if (userId == null) return;

try {
  if (post.liked) {
    await supabase
        .from('post_likes')
        .delete()
        .eq('post_id', post.id)
        .eq('user_id', userId!);

    post.liked = false;

    if (post.likes > 0) {
      post.likes--;
    }
  } else {
    await supabase
        .from('post_likes')
        .insert({
      'post_id': post.id,
      'user_id': userId,
    });

    post.liked = true;
    post.likes++;
  }

  notifyListeners();
} catch (_) {
  errorMessage =
      'تعذر تحديث الإعجاب';
  notifyListeners();
}

}

/* =========================================================
COMMENTS
========================================================= */

Future<bool> addComment(
NPost post,
String text,
) async {
if (userId == null) {
return false;
}

final clean = text.trim();

if (clean.isEmpty) {
  return false;
}

try {
  await supabase
      .from('comments')
      .insert({
    'post_id': post.id,
    'user_id': userId,
    'text': clean,
  });

  post.comments++;
  notifyListeners();

  return true;
} catch (_) {
  errorMessage =
      'تعذر إرسال التعليق';
  notifyListeners();
  return false;
}

}

/*

* للتوافق مع HomePage الحالية.
* 
* HomePage الحالية تستدعي:
* data.comment(post)
* 
* لذلك ننشئ تعليقًا افتراضيًا فقط إذا
* لم يتم تمرير نص تعليق.
  */
  Future<void> comment(
  NPost post,
  ) async {
  if (userId == null) return;

try {
  await supabase
      .from('comments')
      .insert({
    'post_id': post.id,
    'user_id': userId,
    'text': '',
  });

  post.comments++;

  notifyListeners();
} catch (_) {
  errorMessage =
      'تعذر إضافة التعليق';
  notifyListeners();
}

}

/* =========================================================
SAVE
========================================================= */

Future<bool> _isSaved(
String postId,
) async {
if (userId == null) {
return false;
}

final row = await supabase
    .from('saved_posts')
    .select('post_id')
    .eq('post_id', postId)
    .eq('user_id', userId!)
    .maybeSingle();

return row != null;

}

Future<void> save(
NPost post,
) async {
if (userId == null) return;

try {
  if (post.saved) {
    await supabase
        .from('saved_posts')
        .delete()
        .eq('post_id', post.id)
        .eq('user_id', userId!);

    post.saved = false;
  } else {
    await supabase
        .from('saved_posts')
        .insert({
      'post_id': post.id,
      'user_id': userId,
    });

    post.saved = true;
  }

  notifyListeners();
} catch (_) {
  errorMessage =
      'تعذر تحديث المحفوظات';
  notifyListeners();
}

}

/* =========================================================
FOLLOW
========================================================= */

Future<void> loadFollowing() async {
if (userId == null) return;

try {
  final rows = await supabase
      .from('follows')
      .select(
        'following_id, '
        'profiles!follows_following_id_fkey(username)',
      )
      .eq(
        'follower_id',
        userId!,
      );

  following.clear();

  for (final row in rows) {
    final profile = row['profiles'];

    if (profile is Map) {
      final usernameValue =
          profile['username'];

      if (usernameValue != null) {
        following.add(
          usernameValue.toString(),
        );
      }
    }
  }

  notifyListeners();
} catch (_) {
  /*
   * لا نوقف تشغيل التطبيق إذا كان
   * جدول المتابعة غير متاح مؤقتًا.
   */
}

}

Future<void> follow(
String user,
) async {
if (userId == null ||
user == username) {
return;
}

try {
  final target = await supabase
      .from('profiles')
      .select('id')
      .eq('username', user)
      .maybeSingle();

  if (target == null) {
    errorMessage =
        'المستخدم غير موجود';
    notifyListeners();
    return;
  }

  final targetId =
      target['id'].toString();

  if (following.contains(user)) {
    await supabase
        .from('follows')
        .delete()
        .eq(
          'follower_id',
          userId!,
        )
        .eq(
          'following_id',
          targetId,
        );

    following.remove(user);
  } else {
    await supabase
        .from('follows')
        .insert({
      'follower_id': userId,
      'following_id': targetId,
    });

    following.add(user);
  }

  notifyListeners();
} catch (_) {
  errorMessage =
      'تعذر تحديث المتابعة';
  notifyListeners();
}

}

/* =========================================================
MESSAGES
========================================================= */

Future<void> loadConversations() async {
if (userId == null) return;

try {
  final memberships =
      await supabase
          .from('conversation_members')
          .select(
            'conversation_id',
          )
          .eq(
            'user_id',
            userId!,
          );

  messages.clear();

  for (final membership
      in memberships) {
    final conversationId =
        membership[
          'conversation_id'
        ].toString();

    final rows = await supabase
        .from('messages')
        .select(
          '*, profiles!messages_sender_id_fkey(username)',
        )
        .eq(
          'conversation_id',
          conversationId,
        )
        .order(
          'created_at',
          ascending: true,
        );

    for (final row in rows) {
      final map =
          Map<String, dynamic>.from(row);

      final message =
          NMessage.fromMap(map);

      String? otherUsername;

      final profile =
          map['profiles'];

      if (profile is Map) {
        otherUsername =
            profile['username']
                ?.toString();
      }

      if (otherUsername == null ||
          otherUsername.isEmpty) {
        continue;
      }

      messages
          .putIfAbsent(
            otherUsername,
            () => [],
          )
          .add(message);
    }
  }

  notifyListeners();
} catch (_) {
  errorMessage =
      'تعذر تحميل المحادثات';
  notifyListeners();
}

}

Future<String?> _getConversationId(
String otherUserId,
) async {
if (userId == null) return null;

final myRows = await supabase
    .from('conversation_members')
    .select('conversation_id')
    .eq(
      'user_id',
      userId!,
    );

final otherRows = await supabase
    .from('conversation_members')
    .select('conversation_id')
    .eq(
      'user_id',
      otherUserId,
    );

final mine = myRows
    .map(
      (row) =>
          row['conversation_id']
              .toString(),
    )
    .toSet();

for (final row in otherRows) {
  final id =
      row['conversation_id']
          .toString();

  if (mine.contains(id)) {
    return id;
  }
}

return null;

}

Future<String?> _createConversation(
String otherUserId,
) async {
if (userId == null) {
return null;
}

final existing =
    await _getConversationId(
  otherUserId,
);

if (existing != null) {
  return existing;
}

final conversation =
    await supabase
        .from('conversations')
        .insert({})
        .select('id')
        .single();

final conversationId =
    conversation['id'].toString();

await supabase
    .from('conversation_members')
    .insert([
  {
    'conversation_id':
        conversationId,
    'user_id': userId,
  },
  {
    'conversation_id':
        conversationId,
    'user_id': otherUserId,
  },
]);

return conversationId;

}

Future<void> sendMessage(
String user,
String text,
) async {
if (userId == null ||
!allowMessages) {
return;
}

final clean = text.trim();

if (clean.isEmpty) {
  return;
}

try {
  final target = await supabase
      .from('profiles')
      .select('id')
      .eq(
        'username',
        user,
      )
      .maybeSingle();

  if (target == null) {
    errorMessage =
        'المستخدم غير موجود';
    notifyListeners();
    return;
  }

  final otherUserId =
      target['id'].toString();

  final conversationId =
      await _createConversation(
    otherUserId,
  );

  if (conversationId == null) {
    return;
  }

  await supabase
      .from('messages')
      .insert({
    'conversation_id':
        conversationId,
    'sender_id': userId,
    'text': clean,
  });

  final list = messages.putIfAbsent(
    user,
    () => [],
  );

  final now = DateTime.now();

  list.add(
    NMessage(
      sender: username,
      text: clean,
      time:
          '${now.hour.toString().padLeft(2, '0')}:'
          '${now.minute.toString().padLeft(2, '0')}',
    ),
  );

  notifyListeners();
} catch (_) {
  errorMessage =
      'تعذر إرسال الرسالة';
  notifyListeners();
}

}

List<
MapEntry<
String,
List<NMessage>
>
> sortedConversations() {
final items =
messages.entries.toList();

items.sort((a, b) {
  final aTime = a.value.isEmpty
      ? ''
      : a.value.last.time;

  final bTime = b.value.isEmpty
      ? ''
      : b.value.last.time;

  return bTime.compareTo(aTime);
});

return items;

}

/* =========================================================
SETTINGS
========================================================= */

Future<void> _updateProfile(
Map<String, dynamic> values,
) async {
if (userId == null) return;

await supabase
    .from('profiles')
    .update(values)
    .eq(
      'id',
      userId!,
    );

}

Future<void> setPrivateAccount(
bool value,
) async {
privateAccount = value;

try {
  await _updateProfile({
    'private_account': value,
  });
} catch (_) {}

notifyListeners();

}

Future<void> setActivityStatus(
bool value,
) async {
activityStatus = value;

try {
  await _updateProfile({
    'activity_status': value,
  });
} catch (_) {}

notifyListeners();

}

Future<void> setAllowMessages(
bool value,
) async {
allowMessages = value;

try {
  await _updateProfile({
    'allow_messages': value,
  });
} catch (_) {}

notifyListeners();

}

Future<void> setNotifications(
bool value,
) async {
notifications = value;

try {
  await _updateProfile({
    'notifications': value,
  });
} catch (_) {}

notifyListeners();

}

Future<void> setSounds(
bool value,
) async {
sounds = value;

try {
  await _updateProfile({
    'sounds': value,
  });
} catch (_) {}

notifyListeners();

}
}

final NData data = NData();
