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
    final profile = _mapFromDynamic(map['profiles']);

    return NPost(
      id: (map['id'] ?? '').toString(),
      author: (profile['name'] ?? 'مستخدم N').toString(),
      username: (profile['username'] ?? '').toString(),
      text: (map['text'] ?? '').toString(),
      likes: likes,
      comments: comments,
      adult: map['adult'] == true,
      visibility: (map['visibility'] ?? 'عام').toString(),
      verified: profile['verified'] == true,
      video: map['video'] == true,
      videoUrl: _nullableString(map['video_url']),
      imageUrl: _nullableString(map['image_url']),
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

  factory NMessage.fromMap(Map<String, dynamic> map) {
    final created = DateTime.tryParse(
      (map['created_at'] ?? '').toString(),
    );

    final time = created == null
        ? ''
        : '${created.hour.toString().padLeft(2, '0')}:'
          '${created.minute.toString().padLeft(2, '0')}';

    final profile = _mapFromDynamic(map['profiles']);

    return NMessage(
      sender: (
        profile['username'] ??
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

  final SupabaseClient supabase = Supabase.instance.client;

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

  String? get userId => supabase.auth.currentUser?.id;

  Future<void> initialize() async {
    loading = true;
    errorMessage = null;
    notifyListeners();

    try {
      if (supabase.auth.currentSession == null) {
        loggedIn = false;
      } else {
        await loadCurrentUser();
      }
    } catch (e) {
      loggedIn = false;
      errorMessage = 'تعذر تهيئة التطبيق';

      if (kDebugMode) {
        debugPrint('N initialize error: $e');
      }
    } finally {
      loading = false;
      notifyListeners();
    }
  }

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
      errorMessage = 'يرجى إدخال البيانات بشكل صحيح';
      notifyListeners();
      return false;
    }

    if (cleanUsername.contains('@')) {
      errorMessage = 'لا تكتب @ داخل اسم المستخدم';
      notifyListeners();
      return false;
    }

    if (cleanUsername.contains(' ')) {
      errorMessage = 'لا يمكن أن يحتوي اسم المستخدم على مسافات';
      notifyListeners();
      return false;
    }

    if (cleanUsername.length < 4) {
      errorMessage = 'اسم المستخدم يجب أن يكون 4 أحرف على الأقل';
      notifyListeners();
      return false;
    }

    if (!RegExp(r'^[a-zA-Z0-9_.]+$').hasMatch(cleanUsername)) {
      errorMessage = 'استخدم الأحرف الإنجليزية والأرقام و _ و . فقط';
      notifyListeners();
      return false;
    }

    if (newAge < 13 || newAge > 120) {
      errorMessage = 'العمر يجب أن يكون بين 13 و120 سنة';
      notifyListeners();
      return false;
    }

    loading = true;
    notifyListeners();

    try {
      final existing = await supabase
          .from('profiles')
          .select('id')
          .eq('username', cleanUsername)
          .maybeSingle();

      if (existing != null) {
        errorMessage = 'اسم المستخدم مستخدم بالفعل';
        return false;
      }

      final response = await supabase.auth.signUp(
        email: cleanEmail,
        password: password,
        data: {
          'name': cleanName,
          'username': cleanUsername,
          'age': newAge,
        },
      );

      final user = response.user;

      if (user == null) {
        errorMessage = 'تعذر إنشاء الحساب';
        return false;
      }

      if (response.session == null) {
        name = cleanName;
        username = cleanUsername;
        email = cleanEmail;
        age = newAge;
        loggedIn = false;

        return true;
      }

      await loadCurrentUser();

      return loggedIn;
    } on AuthException catch (e) {
      errorMessage = e.message;

      if (kDebugMode) {
        debugPrint('N signUp AuthException: ${e.message}');
      }

      return false;
    } on PostgrestException catch (e) {
      errorMessage = 'حدث خطأ في قاعدة البيانات: ${e.message}';

      if (kDebugMode) {
        debugPrint('N signUp PostgrestException: ${e.message}');
      }

      return false;
    } catch (e) {
      errorMessage = 'حدث خطأ أثناء إنشاء الحساب';

      if (kDebugMode) {
        debugPrint('N signUp error: $e');
      }

      return false;
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<bool> loginWithPassword({
    required String emailAddress,
    required String password,
  }) async {
    errorMessage = null;

    final cleanEmail = emailAddress.trim();

    if (cleanEmail.isEmpty || password.isEmpty) {
      errorMessage = 'أدخل البريد الإلكتروني وكلمة المرور';
      notifyListeners();
      return false;
    }

    loading = true;
    notifyListeners();

    try {
      await supabase.auth.signInWithPassword(
        email: cleanEmail,
        password: password,
      );

      await loadCurrentUser();

      return loggedIn;
    } on AuthException catch (e) {
      errorMessage = e.message;
      return false;
    } on PostgrestException catch (e) {
      errorMessage = 'حدث خطأ في قاعدة البيانات: ${e.message}';
      return false;
    } catch (e) {
      errorMessage = 'تعذر تسجيل الدخول';

      if (kDebugMode) {
        debugPrint('N login error: $e');
      }

      return false;
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> loadCurrentUser() async {
    final user = supabase.auth.currentUser;

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
      errorMessage = 'الحساب موجود ولكن الملف الشخصي غير موجود';
      return;
    }

    name = (profile['name'] ?? 'مستخدم N').toString();
    username = (profile['username'] ?? 'n_user').toString();
    email = (profile['email'] ?? user.email ?? '').toString();

    age = _toInt(
      profile['age'],
      fallback: 25,
    );

    avatarUrl = _nullableString(
      profile['avatar_url'],
    );

    privateAccount = profile['private_account'] == true;
    activityStatus = profile['activity_status'] != false;
    allowMessages = profile['allow_messages'] != false;
    notifications = profile['notifications'] != false;
    sounds = profile['sounds'] != false;

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
      loadConversations(),
    ]);

    notifyListeners();
  }

  int _toInt(
    dynamic value, {
    required int fallback,
  }) {
    if (value is int) return value;
    if (value is num) return value.toInt();

    return int.tryParse(
          value?.toString() ?? '',
        ) ??
        fallback;
  }

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
    } catch (e) {
      if (kDebugMode) {
        debugPrint('N logout error: $e');
      }
    }

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

  Future<void> loadPosts() async {
    if (!loggedIn) return;

    try {
      final rows = await supabase
          .from('posts')
          .select('*, profiles!posts_user_id_fkey(*)')
          .order(
            'created_at',
            ascending: false,
          );

      final loaded = <NPost>[];

      for (final row in rows) {
        final map = Map<String, dynamic>.from(row);
        final postId = (map['id'] ?? '').toString();

        final likeRows = await supabase
            .from('post_likes')
            .select('user_id')
            .eq('post_id', postId);

        final commentRows = await supabase
            .from('comments')
            .select('id')
            .eq('post_id', postId);

        final currentUserId = userId;

        final liked = currentUserId != null &&
            likeRows.any(
              (like) =>
                  like['user_id'].toString() ==
                  currentUserId,
            );

        final saved = currentUserId != null
            ? await _isSaved(postId)
            : false;

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
    } catch (e) {
      errorMessage = 'تعذر تحميل المنشورات';

      if (kDebugMode) {
        debugPrint('N loadPosts error: $e');
      }

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
    errorMessage = null;

    final cleanText = text.trim();

    if (userId == null) {
      errorMessage = 'يجب تسجيل الدخول أولاً';
      notifyListeners();
      return false;
    }

    if (cleanText.isEmpty &&
        videoUrl == null &&
        imageUrl == null) {
      errorMessage = 'اكتب منشورًا أو اختر صورة أو فيديو';
      notifyListeners();
      return false;
    }

    if (adult && !adultAllowed) {
      errorMessage = 'محتوى +21 غير متاح لمن هم دون 21 عاماً';
      notifyListeners();
      return false;
    }

    const allowedVisibility = {
      'عام',
      'المتابعون',
      'خاص',
    };

    if (!allowedVisibility.contains(visibility)) {
      errorMessage = 'نوع ظهور المنشور غير صحيح';
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
    } catch (e) {
      errorMessage = 'تعذر نشر المنشور';

      if (kDebugMode) {
        debugPrint('N createPost error: $e');
      }

      notifyListeners();
      return false;
    }
  }

  Future<void> deletePost(NPost post) async {
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
    } catch (e) {
      errorMessage = 'تعذر حذف المنشور';

      if (kDebugMode) {
        debugPrint('N deletePost error: $e');
      }

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
          !following.contains(post.username)) {
        return false;
      }

      return true;
    }).toList();
  }

  List<NPost> postsOf(String user) {
    return posts
        .where(
          (post) => post.username == user,
        )
        .toList();
  }

  Future<void> like(NPost post) async {
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
        await supabase.from('post_likes').insert({
          'post_id': post.id,
          'user_id': userId,
        });

        post.liked = true;
        post.likes++;
      }

      notifyListeners();
    } catch (e) {
      errorMessage = 'تعذر تحديث الإعجاب';

      if (kDebugMode) {
        debugPrint('N like error: $e');
      }

      notifyListeners();
    }
  }

  Future<bool> addComment(
    NPost post,
    String text,
  ) async {
    if (userId == null) {
      errorMessage = 'يجب تسجيل الدخول أولاً';
      notifyListeners();
      return false;
    }

    final clean = text.trim();

    if (clean.isEmpty) {
      errorMessage = 'لا يمكن إرسال تعليق فارغ';
      notifyListeners();
      return false;
    }

    if (clean.length > 1000) {
      errorMessage = 'التعليق طويل جدًا';
      notifyListeners();
      return false;
    }

    try {
      await supabase.from('comments').insert({
        'post_id': post.id,
        'user_id': userId,
        'text': clean,
      });

      post.comments++;

      errorMessage = null;
      notifyListeners();

      return true;
    } on PostgrestException catch (e) {
      errorMessage = 'تعذر إرسال التعليق: ${e.message}';

      if (kDebugMode) {
        debugPrint(
          'N addComment PostgrestException: ${e.message}',
        );
      }

      notifyListeners();
      return false;
    } catch (e) {
      errorMessage = 'تعذر إرسال التعليق';

      if (kDebugMode) {
        debugPrint('N addComment error: $e');
      }

      notifyListeners();
      return false;
    }
  }

  Future<bool> comment(
    NPost post,
    String text,
  ) {
    return addComment(post, text);
  }

  Future<bool> _isSaved(String postId) async {
    if (userId == null) return false;

    final row = await supabase
        .from('saved_posts')
        .select('post_id')
        .eq('post_id', postId)
        .eq('user_id', userId!)
        .maybeSingle();

    return row != null;
  }

  Future<void> save(NPost post) async {
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
        await supabase.from('saved_posts').insert({
          'post_id': post.id,
          'user_id': userId,
        });

        post.saved = true;
      }

      notifyListeners();
    } catch (e) {
      errorMessage = 'تعذر تحديث المحفوظات';

      if (kDebugMode) {
        debugPrint('N save error: $e');
      }

      notifyListeners();
    }
  }

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
          final value = profile['username'];

          if (value != null) {
            following.add(
              value.toString(),
            );
          }
        }
      }

      notifyListeners();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('N loadFollowing error: $e');
      }
    }
  }

  Future<void> follow(String user) async {
    if (userId == null || user == username) {
      return;
    }

    try {
      final target = await supabase
          .from('profiles')
          .select('id')
          .eq('username', user)
          .maybeSingle();

      if (target == null) {
        errorMessage = 'المستخدم غير موجود';
        notifyListeners();
        return;
      }

      final targetId = target['id'].toString();

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
        await supabase.from('follows').insert({
          'follower_id': userId,
          'following_id': targetId,
        });

        following.add(user);
      }

      notifyListeners();
    } catch (e) {
      errorMessage = 'تعذر تحديث المتابعة';

      if (kDebugMode) {
        debugPrint('N follow error: $e');
      }

      notifyListeners();
    }
  }

  Future<void> loadConversations() async {
    if (userId == null) return;

    try {
      final memberships = await supabase
          .from('conversation_members')
          .select('conversation_id')
          .eq(
            'user_id',
            userId!,
          );

      messages.clear();

      for (final membership in memberships) {
        final conversationId =
            membership['conversation_id'].toString();

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

          final profile = map['profiles'];

          if (profile is! Map) continue;

          final sender =
              profile['username']?.toString();

          if (sender == null || sender.isEmpty) {
            continue;
          }

          messages
              .putIfAbsent(
                sender,
                () => [],
              )
              .add(message);
        }
      }

      notifyListeners();
    } catch (e) {
      errorMessage = 'تعذر تحميل المحادثات';

      if (kDebugMode) {
        debugPrint(
          'N loadConversations error: $e',
        );
      }

      notifyListeners();
    }
  }

  Future<String?> _getConversationId(
    String otherUserId,
  ) async {
    if (userId == null) return null;

    try {
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
                row['conversation_id'].toString(),
          )
          .toSet();

      for (final row in otherRows) {
        final id =
            row['conversation_id'].toString();

        if (mine.contains(id)) {
          return id;
        }
      }

      return null;
    } catch (e) {
      if (kDebugMode) {
        debugPrint(
          'N _getConversationId error: $e',
        );
      }

      return null;
    }
  }

  Future<String?> _createConversation(
    String otherUserId,
  ) async {
    if (userId == null) return null;

    if (otherUserId == userId) {
      errorMessage = 'لا يمكنك إنشاء محادثة مع نفسك';
      notifyListeners();
      return null;
    }

    try {
      final result = await supabase.rpc(
        'create_conversation',
        params: {
          'other_user_id': otherUserId,
        },
      );

      if (result == null) {
        errorMessage = 'تعذر إنشاء المحادثة';
        notifyListeners();
        return null;
      }

      if (result is String) {
        final id = result.trim();

        if (id.isNotEmpty) {
          return id;
        }
      }

      if (result is Map) {
        final id =
            result['id'] ??
            result['conversation_id'];

        if (id != null) {
          final value = id.toString().trim();

          if (value.isNotEmpty) {
            return value;
          }
        }
      }

      if (result is List && result.isNotEmpty) {
        final first = result.first;

        if (first is Map) {
          final id =
              first['id'] ??
              first['conversation_id'];

          if (id != null) {
            final value =
                id.toString().trim();

            if (value.isNotEmpty) {
              return value;
            }
          }
        }

        if (first != null) {
          final value =
              first.toString().trim();

          if (value.isNotEmpty) {
            return value;
          }
        }
      }

      final conversation =
          await _getConversationId(
        otherUserId,
      );

      if (conversation != null) {
        return conversation;
      }

      errorMessage =
          'تم إنشاء المحادثة ولكن تعذر الحصول على معرفها';

      notifyListeners();

      return null;
    } on PostgrestException catch (e) {
      errorMessage =
          'تعذر إنشاء المحادثة: ${e.message}';

      if (kDebugMode) {
        debugPrint(
          'N _createConversation PostgrestException: '
          '${e.message}',
        );
      }

      notifyListeners();

      return null;
    } catch (e) {
      errorMessage = 'تعذر إنشاء المحادثة';

      if (kDebugMode) {
        debugPrint(
          'N _createConversation error: $e',
        );
      }

      notifyListeners();

      return null;
    }
  }

  Future<void> sendMessage(
    String user,
    String text,
  ) async {
    if (userId == null) {
      errorMessage = 'يجب تسجيل الدخول أولاً';
      notifyListeners();
      return;
    }

    if (!allowMessages) {
      errorMessage = 'الرسائل الخاصة غير مفعلة';
      notifyListeners();
      return;
    }

    final clean = text.trim();

    if (clean.isEmpty) {
      errorMessage = 'لا يمكن إرسال رسالة فارغة';
      notifyListeners();
      return;
    }

    if (clean.length > 5000) {
      errorMessage = 'الرسالة طويلة جدًا';
      notifyListeners();
      return;
    }

    try {
      final target = await supabase
          .from('profiles')
          .select('id, username, name')
          .eq(
            'username',
            user,
          )
          .maybeSingle();

      if (target == null) {
        errorMessage = 'المستخدم غير موجود';
        notifyListeners();
        return;
      }

      final otherUserId =
          target['id'].toString();

      if (otherUserId == userId) {
        errorMessage =
            'لا يمكنك إرسال رسالة إلى نفسك';
        notifyListeners();
        return;
      }

      final conversationId =
          await _createConversation(
        otherUserId,
      );

      if (conversationId == null) {
        return;
      }

      await supabase.from('messages').insert({
        'conversation_id': conversationId,
        'sender_id': userId,
        'text': clean,
      });

      final list =
          messages.putIfAbsent(
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

      errorMessage = null;
      notifyListeners();
    } on PostgrestException catch (e) {
      errorMessage =
          'تعذر إرسال الرسالة: ${e.message}';

      if (kDebugMode) {
        debugPrint(
          'N sendMessage PostgrestException: '
          '${e.message}',
        );
      }

      notifyListeners();
    } catch (e) {
      errorMessage = 'تعذر إرسال الرسالة';

      if (kDebugMode) {
        debugPrint(
          'N sendMessage error: $e',
        );
      }

      notifyListeners();
    }
  }

  List<MapEntry<String, List<NMessage>>>
      sortedConversations() {
    final items =
        messages.entries.toList();

    items.sort((a, b) {
      final aTime =
          a.value.isEmpty
              ? ''
              : a.value.last.time;

      final bTime =
          b.value.isEmpty
              ? ''
              : b.value.last.time;

      return bTime.compareTo(aTime);
    });

    return items;
  }

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
    } catch (e) {
      if (kDebugMode) {
        debugPrint(
          'N privateAccount error: $e',
        );
      }
    }

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
    } catch (e) {
      if (kDebugMode) {
        debugPrint(
          'N activityStatus error: $e',
        );
      }
    }

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
    } catch (e) {
      if (kDebugMode) {
        debugPrint(
          'N allowMessages error: $e',
        );
      }
    }

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
    } catch (e) {
      if (kDebugMode) {
        debugPrint(
          'N notifications error: $e',
        );
      }
    }

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
    } catch (e) {
      if (kDebugMode) {
        debugPrint(
          'N sounds error: $e',
        );
      }
    }

    notifyListeners();
  }
}

Map<String, dynamic> _mapFromDynamic(
  dynamic value,
) {
  if (value is Map<String, dynamic>) {
    return value;
  }

  if (value is Map) {
    return Map<String, dynamic>.from(value);
  }

  return <String, dynamic>{};
}

String? _nullableString(dynamic value) {
  if (value == null) return null;

  final text = value.toString().trim();

  if (text.isEmpty) return null;

  return text;
}

final NData data = NData();
