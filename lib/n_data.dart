import 'package:flutter/material.dart';

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
  });

  final String id;
  final String author;
  final String username;
  final String text;

  int likes;
  int comments;

  bool liked = false;
  bool saved = false;
  bool adult;
  String visibility;
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

  final List<NPost> posts = [
    NPost(
      id: 'official-1',
      author: 'N Official',
      username: 'n',
      text: 'مرحباً بك في N 👋',
      likes: 1240,
      comments: 86,
    ),
    NPost(
      id: 'official-2',
      author: 'N Official',
      username: 'n',
      text: 'شارك أفكارك وصورك وفيديوهاتك ولحظاتك مع مجتمع N.',
      likes: 842,
      comments: 41,
    ),
  ];

  final Set<String> following = {};

  final Map<String, List<NMessage>> messages = {
    'ahmed': [
      NMessage(
        sender: 'Ahmed',
        text: 'مرحباً 👋',
        time: '10:20',
      ),
    ],
    'sara': [
      NMessage(
        sender: 'Sara',
        text: 'أهلاً بك في N',
        time: '11:05',
      ),
    ],
  };

  bool get adultAllowed => age >= 21;

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

  void createPost(
    String text, {
    bool adult = false,
    String visibility = 'عام',
  }) {
    final cleanText = text.trim();

    if (cleanText.isEmpty) return;

    posts.insert(
      0,
      NPost(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        author: name,
        username: username,
        text: cleanText,
        adult: adult,
        visibility: visibility,
      ),
    );

    notifyListeners();
  }

  void deletePost(NPost post) {
    posts.removeWhere((item) => item.id == post.id);
    notifyListeners();
  }

  void like(NPost post) {
    post.liked = !post.liked;

    if (post.liked) {
      post.likes++;
    } else if (post.likes > 0) {
      post.likes--;
    }

    notifyListeners();
  }

  void comment(NPost post) {
    post.comments++;
    notifyListeners();
  }

  void save(NPost post) {
    post.saved = !post.saved;
    notifyListeners();
  }

  void follow(String user) {
    if (following.contains(user)) {
      following.remove(user);
    } else {
      following.add(user);
    }

    notifyListeners();
  }

  List<NPost> postsOf(String user) {
    return posts
        .where((post) => post.username == user)
        .toList();
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

  void sendMessage(String user, String text) {
    final clean = text.trim();

    if (clean.isEmpty) return;

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
            '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}',
      ),
    );

    notifyListeners();
  }

  List<MapEntry<String, List<NMessage>>> sortedConversations() {
    final items = messages.entries.toList();

    items.sort((a, b) {
      final aTime =
          a.value.isEmpty ? 0 : a.value.last.hashCode;

      final bTime =
          b.value.isEmpty ? 0 : b.value.last.hashCode;

      return bTime.compareTo(aTime);
    });

    return items;
  }

  void setPrivateAccount(bool value) {
    privateAccount = value;
    notifyListeners();
  }

  void setActivityStatus(bool value) {
    activityStatus = value;
    notifyListeners();
  }

  void setAllowMessages(bool value) {
    allowMessages = value;
    notifyListeners();
  }

  void setNotifications(bool value) {
    notifications = value;
    notifyListeners();
  }

  void setSounds(bool value) {
    sounds = value;
    notifyListeners();
  }

  void logout() {
    loggedIn = false;
    notifyListeners();
  }
}

final NData data = NData();
