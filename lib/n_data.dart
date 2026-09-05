import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

int _toIntValue(
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
    this.isPinned = false,
    this.shareCount = 0,
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
  bool isPinned;
  int shareCount;

  factory NPost.fromMap(
    Map<String, dynamic> map, {
    int likes = 0,
    int comments = 0,
    bool liked = false,
    bool saved = false,
    bool isPinned = false,
    int shareCount = 0,
  }) {
    final profile = _extractProfile(map);

    return NPost(
      id: (map['id'] ?? '').toString(),
      author: _stringValue(
        profile['name'],
        fallback: 'مستخدم N',
      ),
      username: _stringValue(
        profile['username'],
        fallback: '',
      ),
      text: (map['text'] ?? '').toString(),
      likes: likes,
      comments: comments,
      adult: map['adult'] == true,
      visibility: _stringValue(
        map['visibility'],
        fallback: 'عام',
      ),
      verified: profile['verified'] == true,
      video: map['video'] == true,
      videoUrl: _nullableString(map['video_url']),
      imageUrl: _nullableString(map['image_url']),
      liked: liked,
      saved: saved,
      isPinned: map['is_pinned'] == true || isPinned,
      shareCount: _toIntValue(map['share_count'], fallback: shareCount),
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

    final profile = _extractProfile(map);

    return NMessage(
      sender: _stringValue(
        profile['username'] ?? map['sender_username'],
        fallback: 'مستخدم',
      ),
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

  NMessage? get lastMessage {
    if (messages.isEmpty) {
      return null;
    }

    return messages.last;
  }
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
  bool isAdmin = false;
  bool isSuspended = false;
  DateTime? suspendedUntil;

  String? avatarUrl;
  String? _currentBio;

  final List<String> badges = [];
  final List<NPost> posts = [];
  final Set<String> following = <String>{};
  final Map<String, List<NMessage>> messages =
      <String, List<NMessage>>{};

  bool loading = false;
  StreamSubscription<AuthState>? _authSubscription;
  String? errorMessage;

  bool get adultAllowed => age >= 21;

  String? get userId => supabase.auth.currentUser?.id;

  String? get currentBio => _currentBio;

  // =========================================================
  // INITIALIZE
  // =========================================================

  Future<void> initialize() async {
    loading = true;
    errorMessage = null;
    notifyListeners();

    try {
      final session = supabase.auth.currentSession;

      if (session == null) {
        loggedIn = false;
        return;
      }

      try {
        await loadCurrentUser();
      } catch (e) {
        // A valid Supabase session must not be discarded because an optional
        // feed/conversation/admin query failed during startup.
        loggedIn = true;
        if (kDebugMode) debugPrint('N profile bootstrap warning: $e');
      }

      _authSubscription ??= supabase.auth.onAuthStateChange.listen((state) async {
        if (state.event == AuthChangeEvent.signedOut) {
          await _clearLocalSession();
          return;
        }
        if (state.event == AuthChangeEvent.signedIn ||
            state.event == AuthChangeEvent.tokenRefreshed ||
            state.event == AuthChangeEvent.userUpdated) {
          try {
            await loadCurrentUser();
          } catch (e) {
            if (kDebugMode) debugPrint('N auth refresh error: $e');
          }
        }
      });
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

  // =========================================================
  // SET AUTHENTICATED USER
  // =========================================================

  void setAuthenticatedUser({
    required String newName,
    required String newUsername,
    required String newEmail,
    required int newAge,
  }) {
    name = newName.trim().isEmpty
        ? 'مستخدم N'
        : newName.trim();

    username = newUsername.trim().isEmpty
        ? 'n_user'
        : newUsername.trim();

    email = newEmail.trim();
    age = newAge;
    loggedIn = true;

    notifyListeners();
  }

  // =========================================================
  // SIGN UP
  // =========================================================

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

    if (cleanUsername.length < 1) {
      errorMessage = 'اسم المستخدم مطلوب';
      notifyListeners();
      return false;
    }

    if (!RegExp(r'^[a-zA-Z0-9_.]+$').hasMatch(cleanUsername)) {
      errorMessage =
          'استخدم الأحرف الإنجليزية والأرقام و _ و . فقط';
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
      // فحص اسم المستخدم قبل التسجيل.
      // إذا كانت سياسة RLS تمنع الفحص، التسجيل نفسه
      // سيحسم الأمر من خلال قاعدة البيانات.
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
      } catch (e) {
        if (kDebugMode) {
          debugPrint(
            'N username precheck skipped: $e',
          );
        }
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

      name = cleanName;
      username = cleanUsername;
      email = cleanEmail;
      age = newAge;

      // إذا كان تأكيد البريد الإلكتروني مفعلاً،
      // لن تكون هناك جلسة مباشرة.
      if (response.session == null) {
        loggedIn = false;
        return true;
      }

      await loadCurrentUser();

      return loggedIn;
    } on AuthException catch (e) {
      errorMessage = e.message;

      if (kDebugMode) {
        debugPrint(
          'N signUp AuthException: ${e.message}',
        );
      }

      return false;
    } on PostgrestException catch (e) {
      errorMessage =
          'حدث خطأ في قاعدة البيانات: ${e.message}';

      if (kDebugMode) {
        debugPrint(
          'N signUp PostgrestException: ${e.message}',
        );
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

  // =========================================================
  // LOGIN
  // =========================================================

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

      if (kDebugMode) {
        debugPrint(
          'N login AuthException: ${e.message}',
        );
      }

      return false;
    } on PostgrestException catch (e) {
      errorMessage =
          'حدث خطأ في قاعدة البيانات: ${e.message}';
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

  // =========================================================
  // LOAD CURRENT USER
  // =========================================================

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
      errorMessage =
          'الحساب موجود ولكن الملف الشخصي غير موجود';
      return;
    }

    name = _stringValue(
      profile['name'],
      fallback: 'مستخدم N',
    );

    username = _stringValue(
      profile['username'],
      fallback: 'n_user',
    );

    email = _stringValue(
      profile['email'] ?? user.email,
      fallback: '',
    );

    age = _toInt(
      profile['age'],
      fallback: 25,
    );

    avatarUrl = _nullableString(
      profile['avatar_url'],
    );

    _currentBio = _nullableString(profile['bio']);

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

    try {
      isAdmin = (await supabase.rpc('n_is_admin')) == true;
    } catch (_) {
      isAdmin = false;
    }

    try {
      final suspension = await supabase.rpc('n_my_suspension');
      if (suspension is Map && suspension.isNotEmpty) {
        isSuspended = true;
        suspendedUntil = DateTime.tryParse((suspension['suspended_until'] ?? '').toString());
      } else {
        isSuspended = false;
        suspendedUntil = null;
      }
    } catch (_) {
      isSuspended = false;
      suspendedUntil = null;
    }

    loggedIn = true;

    // These are secondary data loads. A failure here must never turn a valid
    // authenticated session into a logged-out state.
    await Future.wait([
      loadPosts().catchError((e) { if (kDebugMode) debugPrint('N posts bootstrap warning: $e'); }),
      loadFollowing().catchError((e) { if (kDebugMode) debugPrint('N following bootstrap warning: $e'); }),
      loadConversations().catchError((e) { if (kDebugMode) debugPrint('N conversations bootstrap warning: $e'); }),
    ]);
  }

  // =========================================================
  // HELPERS
  // =========================================================

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

  // =========================================================
  // LOCAL LOGIN
  // =========================================================

  void login({
    required String newName,
    required String newUsername,
    required String newEmail,
    required int newAge,
  }) {
    setAuthenticatedUser(
      newName: newName,
      newUsername: newUsername,
      newEmail: newEmail,
      newAge: newAge,
    );
  }

  // =========================================================
  // SESSION CLEAR
  // =========================================================

  Future<void> _clearLocalSession() async {
    name = 'مستخدم N';
    username = 'n_user';
    email = '';
    age = 25;
    loggedIn = false;
    isAdmin = false;
    isSuspended = false;
    suspendedUntil = null;
    supporterLevel = 0;
    coins = 0;
    avatarUrl = null;
    _currentBio = null;
    badges.clear();
    posts.clear();
    following.clear();
    messages.clear();
    notifyListeners();
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    _authSubscription = null;
    super.dispose();
  }

  // =========================================================
  // LOGOUT
  // =========================================================

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

    privateAccount = false;
    activityStatus = true;
    allowMessages = true;
    notifications = true;
    sounds = true;
    isAdmin = false;

    supporterLevel = 0;
    coins = 0;
    avatarUrl = null;

    badges.clear();
    posts.clear();
    following.clear();
    messages.clear();

    errorMessage = null;

    notifyListeners();
  }

  // =========================================================
  // WALLET / GIFTS
  // =========================================================

  Future<Map<String, dynamic>> adminOverview() async {
    final result = await supabase.rpc('n_admin_overview');
    return Map<String, dynamic>.from(result as Map);
  }

  Future<List<Map<String, dynamic>>> adminReports() async {
    final result = await supabase.rpc('n_admin_reports', params: {'limit_count': 50});
    if (result is! List) return <Map<String, dynamic>>[];
    return result.map((row) => Map<String, dynamic>.from(row as Map)).toList();
  }

  Future<bool> adminSetReportStatus(String reportId, String status) async {
    try {
      await supabase.rpc('n_admin_set_report_status', params: {
        'report_id': reportId,
        'new_status': status,
      });
      return true;
    } catch (e) {
      if (kDebugMode) debugPrint('N admin status error: $e');
      return false;
    }
  }

  Future<void> refreshWallet() async {
    if (userId == null) return;
    try {
      final row = await supabase
          .from('profiles')
          .select('coins, supporter_level')
          .eq('id', userId!)
          .single();
      coins = _toInt(row['coins'], fallback: coins);
      supporterLevel = _toInt(row['supporter_level'], fallback: supporterLevel);
      notifyListeners();
    } catch (e) {
      if (kDebugMode) debugPrint('N wallet refresh error: $e');
    }
  }

  Future<bool> sendGift({required String recipientUsername, required String giftId}) async {
    if (userId == null || recipientUsername.trim().isEmpty) return false;
    try {
      final result = await supabase.rpc('n_send_gift', params: {
        'recipient_username': recipientUsername.trim().replaceFirst('@', '').toLowerCase(),
        'gift_id': giftId,
      });
      coins = _toInt(result, fallback: coins);
      notifyListeners();
      return true;
    } catch (e) {
      errorMessage = e.toString().replaceFirst('PostgrestException(message: ', '').split(', code:').first;
      if (kDebugMode) debugPrint('N send gift error: $e');
      notifyListeners();
      return false;
    }
  }

  // =========================================================
  // POSTS
  // =========================================================

  Future<void> loadPosts() async {
    if (userId == null) {
      return;
    }

    try {
      List<dynamic> rows;

      // Do not join through public_profiles using posts_user_id_fkey: the FK
      // belongs to profiles and a view cannot be the FK relationship target.
      rows = await supabase
          .from('posts')
          .select()
          .order('created_at', ascending: false);

      final loaded = <NPost>[];

      for (final row in rows) {
        final map = Map<String, dynamic>.from(row);

        // دعم public_profiles إذا كانت العلاقة موجودة.
        final publicProfile =
            _mapFromDynamic(map['public_profiles']);

        if (publicProfile.isNotEmpty) {
          map['profiles'] = publicProfile;
        }

        final postId =
            (map['id'] ?? '').toString();

        if (postId.isEmpty) {
          continue;
        }

        // إذا لم يتم تحميل الملف الشخصي من العلاقة،
        // نحاول تحميله باستخدام user_id.
        if (publicProfile.isEmpty) {
          final authorId =
              (map['user_id'] ?? '').toString();

          if (authorId.isNotEmpty) {
            try {
              final profile = await supabase
                  .from('public_profiles')
                  .select()
                  .eq('id', authorId)
                  .maybeSingle();

              if (profile != null) {
                map['profiles'] =
                    Map<String, dynamic>.from(profile);
              }
            } catch (e) {
              if (kDebugMode) {
                debugPrint(
                  'N post profile error: $e',
                );
              }
            }
          }
        }

        int likeCount = 0;
        int commentCount = 0;
        bool liked = false;
        bool saved = false;

        try {
          final likeRows = await supabase
              .from('post_likes')
              .select('user_id')
              .eq('post_id', postId);

          likeCount = likeRows.length;

          final currentId = userId;

          if (currentId != null) {
            liked = likeRows.any(
              (like) =>
                  like['user_id']?.toString() ==
                  currentId,
            );
          }
        } catch (e) {
          if (kDebugMode) {
            debugPrint(
              'N post likes error: $e',
            );
          }
        }

        try {
          final commentRows = await supabase
              .from('comments')
              .select('id')
              .eq('post_id', postId);

          commentCount = commentRows.length;
        } catch (e) {
          if (kDebugMode) {
            debugPrint(
              'N post comments error: $e',
            );
          }
        }

        if (userId != null) {
          try {
            saved = await _isSaved(postId);
          } catch (e) {
            if (kDebugMode) {
              debugPrint(
                'N post saved error: $e',
              );
            }
          }
        }

        loaded.add(
          NPost.fromMap(
            map,
            likes: likeCount,
            comments: commentCount,
            liked: liked,
            saved: saved,
          ),
        );
      }

      posts
        ..clear()
        ..addAll(loaded);

      errorMessage = null;
      notifyListeners();
    } catch (e) {
      errorMessage = 'تعذر تحميل المنشورات';

      if (kDebugMode) {
        debugPrint(
          'N loadPosts error: $e',
        );
      }

      notifyListeners();
    }
  }

  // =========================================================
  // VIDEO UPLOAD
  // =========================================================

  Future<void> registerView(NPost post) async {
    if (userId == null || post.id.isEmpty) return;
    try {
      await supabase.rpc('register_post_view', params: {'target_post_id': post.id});
    } catch (e) {
      if (kDebugMode) debugPrint('N registerView error: $e');
    }
  }


  Future<String?> uploadImage(File file) async {
    final currentUserId = userId;
    if (currentUserId == null) {
      errorMessage = 'يجب تسجيل الدخول أولاً';
      notifyListeners();
      return null;
    }

    final path = '$currentUserId/covers/${DateTime.now().millisecondsSinceEpoch}.jpg';

    try {
      await supabase.storage.from('images').upload(
        path,
        file,
        fileOptions: const FileOptions(
          contentType: 'image/jpeg',
          upsert: false,
        ),
      );
      errorMessage = null;
      return supabase.storage.from('images').getPublicUrl(path);
    } on StorageException catch (e) {
      errorMessage = 'تعذر رفع الغلاف: ${e.message}';
      if (kDebugMode) debugPrint('N uploadImage StorageException: ${e.message}');
      notifyListeners();
      return null;
    } catch (e) {
      errorMessage = 'تعذر رفع الغلاف';
      if (kDebugMode) debugPrint('N uploadImage error: $e');
      notifyListeners();
      return null;
    }
  }

  Future<String?> uploadVideo(File file) async {
    final currentUserId = userId;
    if (currentUserId == null) {
      errorMessage = 'يجب تسجيل الدخول أولاً';
      notifyListeners();
      return null;
    }

    final extension = _videoExtension(file.path);
    final path = '$currentUserId/${DateTime.now().millisecondsSinceEpoch}.$extension';

    try {
      await supabase.storage.from('videos').upload(
        path,
        file,
        fileOptions: FileOptions(
          contentType: _videoContentType(extension),
          upsert: false,
        ),
      );

      errorMessage = null;
      return supabase.storage.from('videos').getPublicUrl(path);
    } on StorageException catch (e) {
      errorMessage = 'تعذر رفع الفيديو: ${e.message}';
      if (kDebugMode) debugPrint('N uploadVideo StorageException: ${e.message}');
      notifyListeners();
      return null;
    } catch (e) {
      errorMessage = 'تعذر رفع الفيديو';
      if (kDebugMode) debugPrint('N uploadVideo error: $e');
      notifyListeners();
      return null;
    }
  }

  String _videoExtension(String path) {
    final value = path.split('.').last.toLowerCase();
    const allowed = {'mp4', 'mov', 'm4v', 'webm'};
    return allowed.contains(value) ? value : 'mp4';
  }

  String _videoContentType(String extension) {
    switch (extension) {
      case 'mov':
        return 'video/quicktime';
      case 'webm':
        return 'video/webm';
      default:
        return 'video/mp4';
    }
  }

  // =========================================================
  // CREATE POST
  // =========================================================

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

    final currentUserId = userId;

    if (currentUserId == null) {
      errorMessage = 'يجب تسجيل الدخول أولاً';
      notifyListeners();
      return false;
    }

    final cleanVideoUrl = _nullableString(videoUrl);
    final cleanImageUrl = _nullableString(imageUrl);

    if (cleanText.isEmpty &&
        cleanVideoUrl == null &&
        cleanImageUrl == null) {
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

    const allowedVisibility = <String>{
      'عام',
      'المتابعون',
      'خاص',
    };

    if (!allowedVisibility.contains(visibility)) {
      errorMessage =
          'نوع ظهور المنشور غير صحيح';
      notifyListeners();
      return false;
    }

    try {
      await supabase.from('posts').insert({
        'user_id': currentUserId,
        'text': cleanText,
        'adult': adult,
        'visibility': visibility,
        'video': video,
        'video_url': cleanVideoUrl,
        'image_url': cleanImageUrl,
      });

      await loadPosts();

      return true;
    } on PostgrestException catch (e) {
      errorMessage =
          'تعذر نشر المنشور: ${e.message}';

      if (kDebugMode) {
        debugPrint(
          'N createPost PostgrestException: ${e.message}',
        );
      }

      notifyListeners();
      return false;
    } catch (e) {
      errorMessage = 'تعذر نشر المنشور';

      if (kDebugMode) {
        debugPrint(
          'N createPost error: $e',
        );
      }

      notifyListeners();
      return false;
    }
  }

  // =========================================================
  // LIVE STREAMS
  // =========================================================

  Future<List<Map<String, dynamic>>> loadLiveStreams() async {
    try {
      final rows = await supabase
          .from('live_streams')
          .select('id,user_id,title,room_name,created_at,profiles!live_streams_user_id_fkey(username,name,avatar_url,verified)')
          .eq('status', 'live')
          .order('created_at', ascending: false)
          .limit(50);
      return List<Map<String, dynamic>>.from(rows);
    } catch (e) {
      if (kDebugMode) debugPrint('N loadLiveStreams error: $e');
      return <Map<String, dynamic>>[];
    }
  }

  Future<Map<String, dynamic>?> startLive({required String title}) async {
    final currentUserId = userId;
    if (currentUserId == null) {
      errorMessage = 'يجب تسجيل الدخول أولاً';
      notifyListeners();
      return null;
    }
    final cleanTitle = title.trim().isEmpty ? 'بث N مباشر' : title.trim();
    try {
      final room = 'n_${currentUserId}_${DateTime.now().millisecondsSinceEpoch}';
      final row = await supabase.from('live_streams').insert({
        'user_id': currentUserId,
        'title': cleanTitle,
        'room_name': room,
        'status': 'live',
      }).select('id,user_id,title,room_name,created_at').single();
      return Map<String, dynamic>.from(row);
    } catch (e) {
      errorMessage = 'تعذر بدء البث المباشر';
      if (kDebugMode) debugPrint('N startLive error: $e');
      notifyListeners();
      return null;
    }
  }

  Future<bool> endLive(String liveId) async {
    final currentUserId = userId;
    if (currentUserId == null || liveId.isEmpty) return false;
    try {
      await supabase.from('live_streams').update({
        'status': 'ended',
        'ended_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', liveId).eq('user_id', currentUserId);
      return true;
    } catch (e) {
      if (kDebugMode) debugPrint('N endLive error: $e');
      return false;
    }
  }

  // =========================================================
  // BLOCK / REPORT
  // =========================================================

  Future<bool> blockUser(String targetUserId) async {
    final me = userId;
    if (me == null || targetUserId.isEmpty || me == targetUserId) return false;
    try {
      await supabase.from('user_blocks').upsert({
        'blocker_id': me,
        'blocked_id': targetUserId,
      });
      return true;
    } catch (e) {
      errorMessage = 'تعذر حظر المستخدم';
      notifyListeners();
      return false;
    }
  }

  Future<bool> unblockUser(String targetUserId) async {
    final me = userId;
    if (me == null || targetUserId.isEmpty) return false;
    try {
      await supabase.from('user_blocks')
          .delete()
          .eq('blocker_id', me)
          .eq('blocked_id', targetUserId);
      return true;
    } catch (e) {
      errorMessage = 'تعذر إلغاء الحظر';
      notifyListeners();
      return false;
    }
  }

  Future<bool> reportContent({
    String? targetUserId,
    String? postId,
    required String reason,
    String? details,
  }) async {
    final me = userId;
    if (me == null) return false;
    try {
      await supabase.from('content_reports').insert({
        'reporter_id': me,
        'reported_user_id': targetUserId,
        'post_id': postId,
        'reason': reason,
        'details': details?.trim().isEmpty == true ? null : details?.trim(),
      });
      return true;
    } catch (e) {
      errorMessage = 'تعذر إرسال البلاغ';
      notifyListeners();
      return false;
    }
  }

  Future<bool> pinPost(NPost post) async {
    if (userId == null) return false;
    try {
      final result = await supabase.rpc('n_pin_post', params: {'post_id': post.id});
      final pinned = result == true || (result is Map && result['is_pinned'] == true);
      for (final item in posts.where((p) => p.username == username)) { item.isPinned = item.id == post.id && pinned; }
      post.isPinned = pinned;
      notifyListeners();
      return true;
    } catch (e) {
      if (kDebugMode) debugPrint('N pinPost error: $e');
      return false;
    }
  }

  Future<void> registerShare(NPost post) async {
    try {
      await supabase.rpc('n_register_share', params: {'post_id': post.id});
      post.shareCount++;
      notifyListeners();
    } catch (e) {
      if (kDebugMode) debugPrint('N registerShare error: $e');
    }
  }

  Future<bool> registerProfileVisit(String targetUserId) async {
    if (userId == null || targetUserId.isEmpty || userId == targetUserId) return false;
    try {
      await supabase.rpc('register_profile_visit', params: {'target_profile_id': targetUserId});
      return true;
    } catch (e) {
      if (kDebugMode) debugPrint('N profile visit error: $e');
      return false;
    }
  }

  // =========================================================
  // DELETE POST
  // =========================================================

  Future<void> deletePost(NPost post) async {
    final currentUserId = userId;

    if (currentUserId == null) {
      return;
    }

    try {
      await supabase
          .from('posts')
          .delete()
          .eq('id', post.id)
          .eq('user_id', currentUserId);

      posts.removeWhere(
        (item) => item.id == post.id,
      );

      notifyListeners();
    } on PostgrestException catch (e) {
      errorMessage =
          'تعذر حذف المنشور: ${e.message}';

      if (kDebugMode) {
        debugPrint(
          'N deletePost PostgrestException: ${e.message}',
        );
      }

      notifyListeners();
    } catch (e) {
      errorMessage = 'تعذر حذف المنشور';

      if (kDebugMode) {
        debugPrint(
          'N deletePost error: $e',
        );
      }

      notifyListeners();
    }
  }

  // =========================================================
  // VISIBLE POSTS
  // =========================================================

  List<NPost> visiblePosts() {
    return posts.where((post) {
      // حماية +21
      if (post.adult && !adultAllowed) {
        return false;
      }

      // المنشور الخاص يظهر لصاحبه فقط.
      if (post.visibility == 'خاص' &&
          post.username != username) {
        return false;
      }

      // منشورات المتابعين.
      if (post.visibility == 'المتابعون' &&
          post.username != username &&
          !following.contains(post.username)) {
        return false;
      }

      return true;
    }).toList();
  }

  // =========================================================
  // FOLLOWER COUNT
  // =========================================================

  Future<int> followerCount(String user) async {
    final cleanUser = user.trim();
    if (cleanUser.isEmpty) return 0;
    try {
      final target = await supabase
          .from('public_profiles')
          .select('id')
          .eq('username', cleanUser)
          .maybeSingle();
      final id = target?['id']?.toString();
      if (id == null || id.isEmpty) return 0;
      final rows = await supabase
          .from('follows')
          .select('follower_id')
          .eq('following_id', id);
      return rows.length;
    } catch (e) {
      if (kDebugMode) debugPrint('N followerCount error: $e');
      return 0;
    }
  }

  // =========================================================
  // USER POSTS
  // =========================================================

  List<NPost> postsOf(String user) {
    final cleanUser = user.trim();

    if (cleanUser.isEmpty) {
      return <NPost>[];
    }

    return posts
        .where(
          (post) => post.username == cleanUser,
        )
        .toList();
  }

  // =========================================================
  // LIKE
  // =========================================================

  Future<void> like(NPost post) async {
    final currentUserId = userId;

    if (currentUserId == null) {
      return;
    }

    final wasLiked = post.liked;

    try {
      if (wasLiked) {
        await supabase
            .from('post_likes')
            .delete()
            .eq('post_id', post.id)
            .eq('user_id', currentUserId);

        post.liked = false;

        if (post.likes > 0) {
          post.likes--;
        }
      } else {
        await supabase.from('post_likes').insert({
          'post_id': post.id,
          'user_id': currentUserId,
        });

        post.liked = true;
        post.likes++;
      }

      errorMessage = null;
      notifyListeners();
    } on PostgrestException catch (e) {
      errorMessage =
          'تعذر تحديث الإعجاب: ${e.message}';

      if (kDebugMode) {
        debugPrint(
          'N like PostgrestException: ${e.message}',
        );
      }

      notifyListeners();
    } catch (e) {
      errorMessage = 'تعذر تحديث الإعجاب';

      if (kDebugMode) {
        debugPrint(
          'N like error: $e',
        );
      }

      notifyListeners();
    }
  }

  // =========================================================
  // COMMENTS
  // =========================================================

  Future<bool> addComment(
    NPost post,
    String text,
  ) async {
    final currentUserId = userId;

    if (currentUserId == null) {
      errorMessage = 'يجب تسجيل الدخول أولاً';
      notifyListeners();
      return false;
    }

    final clean = text.trim();

    if (clean.isEmpty) {
      errorMessage =
          'لا يمكن إرسال تعليق فارغ';
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
        'user_id': currentUserId,
        'text': clean,
      });

      post.comments++;
      errorMessage = null;

      notifyListeners();

      return true;
    } on PostgrestException catch (e) {
      errorMessage =
          'تعذر إرسال التعليق: ${e.message}';

      if (kDebugMode) {
        debugPrint(
          'N addComment PostgrestException: '
          '${e.message}',
        );
      }

      notifyListeners();

      return false;
    } catch (e) {
      errorMessage = 'تعذر إرسال التعليق';

      if (kDebugMode) {
        debugPrint(
          'N addComment error: $e',
        );
      }

      notifyListeners();

      return false;
    }
  }

  Future<List<Map<String, dynamic>>> loadComments(String postId) async {
    if (postId.trim().isEmpty) return <Map<String, dynamic>>[];
    try {
      final rows = await supabase
          .from('comments')
          .select('id, post_id, user_id, parent_id, text, created_at')
          .eq('post_id', postId)
          .order('created_at', ascending: true);
      final result = <Map<String, dynamic>>[];
      for (final row in rows) {
        final item = Map<String, dynamic>.from(row);
        final uid = item['user_id']?.toString();
        if (uid != null && uid.isNotEmpty) {
          try {
            final profile = await supabase.from('public_profiles').select('id,name,username,avatar_url,verified').eq('id', uid).maybeSingle();
            if (profile != null) item['profile'] = Map<String, dynamic>.from(profile);
          } catch (_) {}
        }
        result.add(item);
      }
      return result;
    } catch (e) {
      if (kDebugMode) debugPrint('N loadComments error: $e');
      return <Map<String, dynamic>>[];
    }
  }

  Future<bool> deleteComment(String commentId) async {
    if (userId == null || commentId.trim().isEmpty) return false;
    try {
      await supabase.rpc('n_delete_comment', params: {'comment_id': commentId});
      return true;
    } catch (e) {
      if (kDebugMode) debugPrint('N deleteComment error: $e');
      return false;
    }
  }

  // =========================================================
  // COMMENT COMPATIBILITY
  // =========================================================

  Future<bool> comment(
    NPost post, [
    String text = '',
  ]) {
    return addComment(post, text);
  }

  // =========================================================
  // SAVED POSTS
  // =========================================================

  Future<bool> _isSaved(
    String postId,
  ) async {
    final currentUserId = userId;

    if (currentUserId == null) {
      return false;
    }

    final row = await supabase
        .from('saved_posts')
        .select('post_id')
        .eq('post_id', postId)
        .eq('user_id', currentUserId)
        .maybeSingle();

    return row != null;
  }

  Future<void> save(
    NPost post,
  ) async {
    final currentUserId = userId;

    if (currentUserId == null) {
      return;
    }

    try {
      if (post.saved) {
        await supabase
            .from('saved_posts')
            .delete()
            .eq('post_id', post.id)
            .eq('user_id', currentUserId);

        post.saved = false;
      } else {
        await supabase.from('saved_posts').insert({
          'post_id': post.id,
          'user_id': currentUserId,
        });

        post.saved = true;
      }

      errorMessage = null;
      notifyListeners();
    } on PostgrestException catch (e) {
      errorMessage =
          'تعذر تحديث المحفوظات: ${e.message}';

      if (kDebugMode) {
        debugPrint(
          'N save PostgrestException: ${e.message}',
        );
      }

      notifyListeners();
    } catch (e) {
      errorMessage = 'تعذر تحديث المحفوظات';

      if (kDebugMode) {
        debugPrint(
          'N save error: $e',
        );
      }

      notifyListeners();
    }
  }

  // =========================================================
  // FOLLOWING
  // =========================================================

  Future<void> loadFollowing() async {
    final currentUserId = userId;

    if (currentUserId == null) {
      return;
    }

    try {
      final rows = await supabase
          .from('follows')
          .select(
            'following_id, public_profiles(username)',
          )
          .eq(
            'follower_id',
            currentUserId,
          );

      following.clear();

      for (final row in rows) {
        final profile =
            _mapFromDynamic(row['public_profiles']);

        final value = profile['username'];

        if (value != null) {
          final clean = value.toString().trim();

          if (clean.isNotEmpty) {
            following.add(clean);
          }
        }
      }

      notifyListeners();
    } catch (e) {
      if (kDebugMode) {
        debugPrint(
          'N loadFollowing relation error: $e',
        );
      }

      try {
        final rows = await supabase
            .from('follows')
            .select('following_id')
            .eq(
              'follower_id',
              currentUserId,
            );

        following.clear();

        for (final row in rows) {
          final id =
              row['following_id']?.toString();

          if (id == null || id.isEmpty) {
            continue;
          }

          try {
            final profile = await supabase
                .from('public_profiles')
                .select('username')
                .eq('id', id)
                .maybeSingle();

            final value =
                profile?['username'];

            if (value != null) {
              final clean = value.toString().trim();

              if (clean.isNotEmpty) {
                following.add(clean);
              }
            }
          } catch (profileError) {
            if (kDebugMode) {
              debugPrint(
                'N following profile error: '
                '$profileError',
              );
            }
          }
        }

        notifyListeners();
      } catch (fallbackError) {
        if (kDebugMode) {
          debugPrint(
            'N loadFollowing fallback error: '
            '$fallbackError',
          );
        }
      }
    }
  }

  // =========================================================
  // FOLLOW / UNFOLLOW
  // =========================================================

  Future<void> follow(
    String user,
  ) async {
    final currentUserId = userId;
    final cleanUser = user.trim();

    if (currentUserId == null ||
        cleanUser.isEmpty ||
        cleanUser == username) {
      return;
    }

    try {
      final target = await supabase
          .from('public_profiles')
          .select('id, username')
          .eq('username', cleanUser)
          .maybeSingle();

      if (target == null) {
        errorMessage = 'المستخدم غير موجود';
        notifyListeners();
        return;
      }

      final targetId =
          target['id']?.toString();

      if (targetId == null || targetId.isEmpty) {
        errorMessage = 'معرف المستخدم غير صالح';
        notifyListeners();
        return;
      }

      if (following.contains(cleanUser)) {
        await supabase
            .from('follows')
            .delete()
            .eq(
              'follower_id',
              currentUserId,
            )
            .eq(
              'following_id',
              targetId,
            );

        following.remove(cleanUser);
      } else {
        await supabase.from('follows').insert({
          'follower_id': currentUserId,
          'following_id': targetId,
        });

        following.add(cleanUser);
      }

      errorMessage = null;
      notifyListeners();
    } on PostgrestException catch (e) {
      errorMessage =
          'تعذر تحديث المتابعة: ${e.message}';

      if (kDebugMode) {
        debugPrint(
          'N follow PostgrestException: ${e.message}',
        );
      }

      notifyListeners();
    } catch (e) {
      errorMessage =
          'تعذر تحديث المتابعة';

      if (kDebugMode) {
        debugPrint(
          'N follow error: $e',
        );
      }

      notifyListeners();
    }
  }

  // =========================================================
  // CONVERSATIONS
  // =========================================================

  Future<void> loadConversations() async {
    final currentUserId = userId;

    if (currentUserId == null) {
      return;
    }

    try {
      final memberships = await supabase
          .from('conversation_members')
          .select('conversation_id')
          .eq(
            'user_id',
            currentUserId,
          );

      messages.clear();

      for (final membership in memberships) {
        final conversationId =
            membership['conversation_id']?.toString();

        if (conversationId == null ||
            conversationId.isEmpty) {
          continue;
        }

        List<dynamic> rows;

        try {
          rows = await supabase
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
        } catch (e) {
          if (kDebugMode) {
            debugPrint(
              'N messages relation error: $e',
            );
          }

          rows = await supabase
              .from('messages')
              .select()
              .eq(
                'conversation_id',
                conversationId,
              )
              .order(
                'created_at',
                ascending: true,
              );
        }

        for (final row in rows) {
          final map =
              Map<String, dynamic>.from(row);

          final profile =
              _mapFromDynamic(map['profiles']);

          String? sender =
              profile['username']?.toString();

          // fallback إلى sender_id
          if (sender == null || sender.trim().isEmpty) {
            final senderId =
                map['sender_id']?.toString();

            if (senderId != null &&
                senderId.isNotEmpty) {
              try {
                final senderProfile =
                    await supabase
                        .from('public_profiles')
                        .select('username')
                        .eq('id', senderId)
                        .maybeSingle();

                sender =
                    senderProfile?['username']
                        ?.toString();
              } catch (e) {
                if (kDebugMode) {
                  debugPrint(
                    'N sender profile error: $e',
                  );
                }
              }
            }
          }

          if (sender == null ||
              sender.trim().isEmpty) {
            continue;
          }

          map['profiles'] = {
            'username': sender,
          };

          final message =
              NMessage.fromMap(map);

          messages
              .putIfAbsent(
                sender,
                () => <NMessage>[],
              )
              .add(message);
        }
      }

      errorMessage = null;
      notifyListeners();
    } catch (e) {
      errorMessage =
          'تعذر تحميل المحادثات';

      if (kDebugMode) {
        debugPrint(
          'N loadConversations error: $e',
        );
      }

      notifyListeners();
    }
  }

  // =========================================================
  // GET CONVERSATION ID
  // =========================================================

  Future<String?> _getConversationId(
    String otherUserId,
  ) async {
    final currentUserId = userId;

    if (currentUserId == null ||
        otherUserId.isEmpty) {
      return null;
    }

    try {
      final myRows = await supabase
          .from('conversation_members')
          .select('conversation_id')
          .eq(
            'user_id',
            currentUserId,
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
                row['conversation_id']?.toString(),
          )
          .whereType<String>()
          .toSet();

      for (final row in otherRows) {
        final id =
            row['conversation_id']?.toString();

        if (id != null && mine.contains(id)) {
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

  // =========================================================
  // CREATE CONVERSATION
  // =========================================================

  Future<String?> _createConversation(
    String otherUserId,
  ) async {
    final currentUserId = userId;

    if (currentUserId == null) {
      return null;
    }

    if (otherUserId.isEmpty) {
      errorMessage = 'معرف المستخدم غير صالح';
      notifyListeners();
      return null;
    }

    if (otherUserId == currentUserId) {
      errorMessage =
          'لا يمكنك إنشاء محادثة مع نفسك';
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

      final parsedId =
          _extractConversationId(result);

      if (parsedId != null) {
        return parsedId;
      }

      // إذا كانت الدالة أعادت null أو قيمة غير متوقعة،
      // نبحث عن المحادثة الموجودة.
      final existing =
          await _getConversationId(
        otherUserId,
      );

      if (existing != null) {
        return existing;
      }

      errorMessage =
          'تم إنشاء المحادثة ولكن تعذر الحصول على معرفها';

      notifyListeners();

      return null;
    } on PostgrestException catch (e) {
      // قد تكون المحادثة موجودة أصلًا.
      final existing =
          await _getConversationId(
        otherUserId,
      );

      if (existing != null) {
        return existing;
      }

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
      final existing =
          await _getConversationId(
        otherUserId,
      );

      if (existing != null) {
        return existing;
      }

      errorMessage =
          'تعذر إنشاء المحادثة';

      if (kDebugMode) {
        debugPrint(
          'N _createConversation error: $e',
        );
      }

      notifyListeners();

      return null;
    }
  }

  // =========================================================
  // SEND MESSAGE
  // =========================================================

  Future<void> sendMessage(
    String user,
    String text,
  ) async {
    final currentUserId = userId;
    final cleanUser = user.trim();
    final clean = text.trim();

    if (currentUserId == null) {
      errorMessage =
          'يجب تسجيل الدخول أولاً';
      notifyListeners();
      return;
    }

    if (!allowMessages) {
      errorMessage =
          'الرسائل الخاصة غير مفعلة';
      notifyListeners();
      return;
    }

    if (cleanUser.isEmpty) {
      errorMessage =
          'اسم المستخدم غير صالح';
      notifyListeners();
      return;
    }

    if (clean.isEmpty) {
      errorMessage =
          'لا يمكن إرسال رسالة فارغة';
      notifyListeners();
      return;
    }

    if (clean.length > 5000) {
      errorMessage =
          'الرسالة طويلة جدًا';
      notifyListeners();
      return;
    }

    try {
      final target = await supabase
          .from('public_profiles')
          .select('id, username, name')
          .eq(
            'username',
            cleanUser,
          )
          .maybeSingle();

      if (target == null) {
        errorMessage =
            'المستخدم غير موجود';
        notifyListeners();
        return;
      }

      final otherUserId =
          target['id']?.toString();

      if (otherUserId == null ||
          otherUserId.isEmpty) {
        errorMessage =
            'معرف المستخدم غير صالح';
        notifyListeners();
        return;
      }

      if (otherUserId == currentUserId) {
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
        'sender_id': currentUserId,
        'text': clean,
      });

      final list =
          messages.putIfAbsent(
        cleanUser,
        () => <NMessage>[],
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
      errorMessage =
          'تعذر إرسال الرسالة';

      if (kDebugMode) {
        debugPrint(
          'N sendMessage error: $e',
        );
      }

      notifyListeners();
    }
  }

  // =========================================================
  // SORT CONVERSATIONS
  // =========================================================

  List<MapEntry<String, List<NMessage>>>
      sortedConversations() {
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

  // =========================================================
  // UPDATE PROFILE
  // =========================================================

  Future<void> _updateProfile(
    Map<String, dynamic> values,
  ) async {
    final currentUserId = userId;

    if (currentUserId == null) {
      throw StateError(
        'User is not authenticated',
      );
    }

    await supabase
        .from('profiles')
        .update(values)
        .eq(
          'id',
          currentUserId,
        );
  }

  // =========================================================
  // PRIVATE ACCOUNT
  // =========================================================

  Future<void> updateProfile({String? name, String? username, String? bio, String? avatarUrl}) async {
    final values = <String, dynamic>{};
    if (name != null) {
      final clean = name.trim();
      if (clean.isNotEmpty) values['name'] = clean;
    }
    if (username != null) {
      final clean = username.trim().replaceFirst('@', '').toLowerCase();
      if (!RegExp(r'^[a-zA-Z0-9_.]+$').hasMatch(clean)) {
        throw StateError('اسم المستخدم غير صالح');
      }
      if (clean.isEmpty) throw StateError('اسم المستخدم مطلوب');
      values['username'] = clean;
    }
    if (bio != null) values['bio'] = bio.trim();
    if (avatarUrl != null) values['avatar_url'] = avatarUrl;
    if (values.isEmpty) return;
    await _updateProfile(values);
    if (values.containsKey('name')) this.name = values['name'].toString();
    if (values.containsKey('username')) this.username = values['username'].toString();
    if (values.containsKey('bio')) _currentBio = values['bio']?.toString();
    if (values.containsKey('avatar_url')) avatarUrl = values['avatar_url']?.toString();
    notifyListeners();
  }

  Future<void> setPrivateAccount(
    bool value,
  ) async {
    final oldValue = privateAccount;

    privateAccount = value;
    notifyListeners();

    try {
      await _updateProfile({
        'private_account': value,
      });
    } catch (e) {
      privateAccount = oldValue;

      if (kDebugMode) {
        debugPrint(
          'N privateAccount error: $e',
        );
      }

      notifyListeners();
    }
  }

  // =========================================================
  // ACTIVITY STATUS
  // =========================================================

  Future<void> setActivityStatus(
    bool value,
  ) async {
    final oldValue = activityStatus;

    activityStatus = value;
    notifyListeners();

    try {
      await _updateProfile({
        'activity_status': value,
      });
    } catch (e) {
      activityStatus = oldValue;

      if (kDebugMode) {
        debugPrint(
          'N activityStatus error: $e',
        );
      }

      notifyListeners();
    }
  }

  // =========================================================
  // ALLOW MESSAGES
  // =========================================================

  Future<void> setAllowMessages(
    bool value,
  ) async {
    final oldValue = allowMessages;

    allowMessages = value;
    notifyListeners();

    try {
      await _updateProfile({
        'allow_messages': value,
      });
    } catch (e) {
      allowMessages = oldValue;

      if (kDebugMode) {
        debugPrint(
          'N allowMessages error: $e',
        );
      }

      notifyListeners();
    }
  }

  // =========================================================
  // NOTIFICATIONS
  // =========================================================

  Future<void> setNotifications(
    bool value,
  ) async {
    final oldValue = notifications;

    notifications = value;
    notifyListeners();

    try {
      await _updateProfile({
        'notifications': value,
      });
    } catch (e) {
      notifications = oldValue;

      if (kDebugMode) {
        debugPrint(
          'N notifications error: $e',
        );
      }

      notifyListeners();
    }
  }

  // =========================================================
  // SOUNDS
  // =========================================================

  Future<void> setSounds(
    bool value,
  ) async {
    final oldValue = sounds;

    sounds = value;
    notifyListeners();

    try {
      await _updateProfile({
        'sounds': value,
      });
    } catch (e) {
      sounds = oldValue;

      if (kDebugMode) {
        debugPrint(
          'N sounds error: $e',
        );
      }

      notifyListeners();
    }
  }
}

// =========================================================
// MAP HELPERS
// =========================================================

Map<String, dynamic> _mapFromDynamic(
  dynamic value,
) {
  if (value is Map<String, dynamic>) {
    return value;
  }

  if (value is Map) {
    try {
      return Map<String, dynamic>.from(value);
    } catch (_) {
      return <String, dynamic>{};
    }
  }

  return <String, dynamic>{};
}

// =========================================================
// EXTRACT PROFILE
// =========================================================

Map<String, dynamic> _extractProfile(
  Map<String, dynamic> map,
) {
  final publicProfile =
      _mapFromDynamic(map['public_profiles']);

  if (publicProfile.isNotEmpty) {
    return publicProfile;
  }

  final profile =
      _mapFromDynamic(map['profiles']);

  if (profile.isNotEmpty) {
    return profile;
  }

  return <String, dynamic>{};
}

// =========================================================
// STRING HELPER
// =========================================================

String _stringValue(
  dynamic value, {
  required String fallback,
}) {
  if (value == null) {
    return fallback;
  }

  final text = value.toString().trim();

  if (text.isEmpty) {
    return fallback;
  }

  return text;
}

// =========================================================
// NULLABLE STRING
// =========================================================

String? _nullableString(
  dynamic value,
) {
  if (value == null) {
    return null;
  }

  final text = value.toString().trim();

  if (text.isEmpty) {
    return null;
  }

  return text;
}

// =========================================================
// CONVERSATION ID HELPER
// =========================================================

String? _extractConversationId(
  dynamic result,
) {
  if (result == null) {
    return null;
  }

  if (result is String) {
    final value = result.trim();

    return value.isEmpty ? null : value;
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

    return null;
  }

  if (result is List &&
      result.isNotEmpty) {
    final first = result.first;

    if (first is Map) {
      final id =
          first['id'] ??
          first['conversation_id'];

      if (id != null) {
        final value = id.toString().trim();

        if (value.isNotEmpty) {
          return value;
        }
      }
    }

    if (first != null) {
      final value = first.toString().trim();

      if (value.isNotEmpty &&
          value != 'null') {
        return value;
      }
    }
  }

  return null;
}

// =========================================================
// GLOBAL DATA
// =========================================================

final NData data = NData();
