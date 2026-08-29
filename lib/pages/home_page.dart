import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';

import '../n_data.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
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
          backgroundColor: Colors.black,
          body: IndexedStack(
            index: index,
            children: pages,
          ),
          bottomNavigationBar: NBottomNavigationBar(
            selectedIndex: index,
            onChanged: (value) {
              setState(() {
                index = value;
              });
            },
          ),
        );
      },
    );
  }
}

/* =========================================================
N VIDEO FEED
========================================================= */

class NVideoFeedPage extends StatefulWidget {
  const NVideoFeedPage({super.key});

  @override
  State<NVideoFeedPage> createState() => _NVideoFeedPageState();
}

class _NVideoFeedPageState extends State<NVideoFeedPage> {
  late PageController pageController;
  int currentPage = 0;

  @override
  void initState() {
    super.initState();
    pageController = PageController();
  }

  @override
  void dispose() {
    pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final posts = data.visiblePosts();

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          if (posts.isEmpty)
            const Center(
              child: Text(
                'لا توجد منشورات متاحة',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                ),
              ),
            )
          else
            PageView.builder(
              controller: pageController,
              scrollDirection: Axis.vertical,
              itemCount: posts.length,
              onPageChanged: (value) {
                setState(() {
                  currentPage = value;
                });
              },
              itemBuilder: (_, index) {
                return NVideoPostPage(
                  key: ValueKey(posts[index].id),
                  post: posts[index],
                  active: index == currentPage,
                );
              },
            ),

          Positioned(
            top: MediaQuery.of(context).padding.top + 12,
            left: 16,
            right: 16,
            child: Row(
              children: [
                const Text(
                  'N',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 30,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const Spacer(),
                _TopFeedButton(
                  icon: Icons.live_tv_outlined,
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const LivePage(),
                      ),
                    );
                  },
                ),
                const SizedBox(width: 8),
                _TopFeedButton(
                  icon: Icons.notifications_none,
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const NotificationsPage(),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/* =========================================================
VIDEO POST
========================================================= */

class NVideoPostPage extends StatefulWidget {
  const NVideoPostPage({
    super.key,
    required this.post,
    required this.active,
  });

  final NPost post;
  final bool active;

  @override
  State<NVideoPostPage> createState() => _NVideoPostPageState();
}

class _NVideoPostPageState extends State<NVideoPostPage> {
  VideoPlayerController? controller;
  bool initialized = false;
  bool loading = false;
  bool muted = false;

  @override
  void initState() {
    super.initState();
    _prepareVideo();
  }

  @override
  void didUpdateWidget(covariant NVideoPostPage oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.active != widget.active) {
      if (widget.active) {
        controller?.play();
      } else {
        controller?.pause();
      }
    }
  }

  Future<void> _prepareVideo() async {
    final url = widget.post.videoUrl;

    if (!widget.post.video || url == null || url.isEmpty) {
      return;
    }

    setState(() {
      loading = true;
    });

    try {
      final parsed = Uri.tryParse(url);

      if (parsed != null &&
          (parsed.scheme == 'http' || parsed.scheme == 'https')) {
        controller = VideoPlayerController.networkUrl(parsed);
      } else {
        controller = VideoPlayerController.file(
          File(url),
        );
      }

      await controller!.initialize();
      await controller!.setLooping(true);

      if (widget.active) {
        await controller!.play();
      }

      if (mounted) {
        setState(() {
          initialized = true;
          loading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          loading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    controller?.dispose();
    super.dispose();
  }

  void togglePlay() {
    if (controller == null || !initialized) return;

    if (controller!.value.isPlaying) {
      controller!.pause();
    } else {
      controller!.play();
    }

    setState(() {});
  }

  void toggleMute() {
    if (controller == null || !initialized) return;

    muted = !muted;
    controller!.setVolume(muted ? 0 : 1);

    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: togglePlay,
      child: Stack(
        fit: StackFit.expand,
        children: [
          _background(),

          if (widget.post.adult) _AdultOverlay(),

          _gradient(),

          Positioned(
            right: 10,
            bottom: 115,
            child: _Actions(
              post: widget.post,
            ),
          ),

          Positioned(
            left: 16,
            right: 85,
            bottom: 28,
            child: _PostInformation(
              post: widget.post,
            ),
          ),

          if (widget.post.video && initialized)
            Positioned(
              top: MediaQuery.of(context).padding.top + 70,
              right: 18,
              child: GestureDetector(
                onTap: toggleMute,
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: .35),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    muted
                        ? Icons.volume_off
                        : Icons.volume_up,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ),
            ),

          if (loading)
            const Center(
              child: CircularProgressIndicator(),
            ),
        ],
      ),
    );
  }

  Widget _background() {
    if (widget.post.video &&
        controller != null &&
        initialized) {
      return FittedBox(
        fit: BoxFit.cover,
        child: SizedBox(
          width: controller!.value.size.width,
          height: controller!.value.size.height,
          child: VideoPlayer(controller!),
        ),
      );
    }

    if (widget.post.imageUrl != null &&
        widget.post.imageUrl!.isNotEmpty) {
      return Image.file(
        File(widget.post.imageUrl!),
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) {
          return _textBackground();
        },
      );
    }

    return _textBackground();
  }

  Widget _textBackground() {
    return Container(
      color: const Color(0xFF080A10),
      padding: const EdgeInsets.symmetric(
        horizontal: 45,
      ),
      child: Center(
        child: Text(
          widget.post.text,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 25,
            height: 1.5,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  Widget _gradient() {
    return IgnorePointer(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.black.withValues(alpha: .28),
              Colors.transparent,
              Colors.black.withValues(alpha: .82),
            ],
            stops: const [
              0,
              .42,
              1,
            ],
          ),
        ),
      ),
    );
  }
}

/* =========================================================
POST INFORMATION
========================================================= */

class _PostInformation extends StatelessWidget {
  const _PostInformation({
    required this.post,
  });

  final NPost post;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            GestureDetector(
              onTap: () {},
              child: const CircleAvatar(
                radius: 21,
                backgroundColor: Color(0xFF252935),
                child: Icon(
                  Icons.person,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Flexible(
              child: Text(
                '@${post.username}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            if (post.verified) ...[
              const SizedBox(width: 5),
              const Icon(
                Icons.verified,
                color: Color(0xFF00C8FF),
                size: 18,
              ),
            ],
            if (post.username != data.username) ...[
              const SizedBox(width: 10),
              GestureDetector(
                onTap: () {
                  data.follow(post.username);
                },
                child: Text(
                  data.following.contains(post.username)
                      ? 'متابَع'
                      : 'متابعة',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 12),
        if (post.text.isNotEmpty)
          Text(
            post.text,
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              height: 1.45,
            ),
          ),
        const SizedBox(height: 7),
        const Row(
          children: [
            Icon(
              Icons.music_note,
              size: 15,
              color: Colors.white,
            ),
            SizedBox(width: 5),
            Text(
              'N original sound',
              style: TextStyle(
                color: Colors.white,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/* =========================================================
ACTIONS
========================================================= */

class _Actions extends StatelessWidget {
  const _Actions({
    required this.post,
  });

  final NPost post;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _ActionItem(
          icon: post.liked
              ? Icons.favorite
              : Icons.favorite_border,
          value: '${post.likes}',
          color: post.liked
              ? Colors.redAccent
              : Colors.white,
          onTap: () {
            data.like(post);
          },
        ),
        const SizedBox(height: 18),
        _ActionItem(
          icon: Icons.comment,
          value: '${post.comments}',
          onTap: () {
            _comments(context);
          },
        ),
        const SizedBox(height: 18),
        _ActionItem(
          icon: post.saved
              ? Icons.bookmark
              : Icons.bookmark_border,
          value: 'حفظ',
          onTap: () {
            data.save(post);
          },
        ),
        const SizedBox(height: 18),
        _ActionItem(
          icon: Icons.share,
          value: 'مشاركة',
          onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('تم تجهيز المشاركة'),
              ),
            );
          },
        ),
        const SizedBox(height: 18),
        GestureDetector(
          onTap: () {},
          child: const CircleAvatar(
            radius: 25,
            backgroundColor: Color(0xFF1E212B),
            child: Icon(
              Icons.person,
              color: Colors.white,
            ),
          ),
        ),
      ],
    );
  }

  void _comments(BuildContext context) {
    final controller = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF11131A),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.fromLTRB(
            16,
            20,
            16,
            MediaQuery.of(ctx).viewInsets.bottom + 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'التعليقات',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 15),
              TextField(
                controller: controller,
                maxLines: 3,
                decoration: const InputDecoration(
                  hintText: 'اكتب تعليقك...',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () {
                    if (controller.text.trim().isNotEmpty) {
                      data.comment(post);
                    }

                    Navigator.pop(ctx);
                    controller.dispose();
                  },
                  child: const Text('إرسال'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ActionItem extends StatelessWidget {
  const _ActionItem({
    required this.icon,
    required this.value,
    required this.onTap,
    this.color = Colors.white,
  });

  final IconData icon;
  final String value;
  final VoidCallback onTap;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Icon(
            icon,
            color: color,
            size: 31,
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/* =========================================================
ADULT OVERLAY
========================================================= */

class _AdultOverlay extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    if (data.adultAllowed) {
      return const SizedBox.shrink();
    }

    return Container(
      color: Colors.black.withValues(alpha: .92),
      alignment: Alignment.center,
      child: const Padding(
        padding: EdgeInsets.all(35),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.lock,
              color: Colors.white,
              size: 55,
            ),
            SizedBox(height: 16),
            Text(
              'هذا المحتوى متاح لمن هم بعمر 21 سنة فأكثر',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/* =========================================================
TOP BUTTON
========================================================= */

class _TopFeedButton extends StatelessWidget {
  const _TopFeedButton({
    required this.icon,
    required this.onPressed,
  });

  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: .35),
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          color: Colors.white,
          size: 21,
        ),
      ),
    );
  }
}

/* =========================================================
BOTTOM NAVIGATION
========================================================= */

class NBottomNavigationBar extends StatelessWidget {
  const NBottomNavigationBar({
    super.key,
    required this.selectedIndex,
    required this.onChanged,
  });

  final int selectedIndex;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 68,
      decoration: const BoxDecoration(
        color: Color(0xFF07080D),
        border: Border(
          top: BorderSide(
            color: Color(0xFF1A1C24),
            width: .6,
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _item(
            0,
            Icons.home_outlined,
            Icons.home,
            'الرئيسية',
          ),
          _item(
            1,
            Icons.search_outlined,
            Icons.search,
            'استكشاف',
          ),
          GestureDetector(
            onTap: () => onChanged(2),
            child: Container(
              width: 44,
              height: 32,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(9),
                gradient: const LinearGradient(
                  colors: [
                    Color(0xFF00C8FF),
                    Color(0xFFFF287A),
                  ],
                ),
              ),
              child: const Icon(
                Icons.add,
                color: Colors.white,
                size: 25,
              ),
            ),
          ),
          _item(
            3,
            Icons.chat_bubble_outline,
            Icons.chat_bubble,
            'الرسائل',
          ),
          _item(
            4,
            Icons.person_outline,
            Icons.person,
            'حسابي',
          ),
        ],
      ),
    );
  }

  Widget _item(
    int value,
    IconData icon,
    IconData selectedIcon,
    String label,
  ) {
    final selected = selectedIndex == value;

    return GestureDetector(
      onTap: () => onChanged(value),
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 65,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              selected ? selectedIcon : icon,
              color: selected
                  ? Colors.white
                  : Colors.white54,
              size: 23,
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                color: selected
                    ? Colors.white
                    : Colors.white54,
                fontSize: 9,
                fontWeight: selected
                    ? FontWeight.bold
                    : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/* =========================================================
LIVE
========================================================= */

class LivePage extends StatelessWidget {
  const LivePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF07080D),
      appBar: AppBar(
        title: const Text('البث المباشر'),
      ),
      body: const Center(
        child: Text(
          'البث المباشر',
          style: TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}

/* =========================================================
NOTIFICATIONS
========================================================= */

class NotificationsPage extends StatelessWidget {
  const NotificationsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF07080D),
      appBar: AppBar(
        title: const Text('الإشعارات'),
      ),
      body: const Center(
        child: Text(
          'الإشعارات',
          style: TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}

/* =========================================================
EXPLORE
========================================================= */

class ExplorePage extends StatefulWidget {
  const ExplorePage({super.key});

  @override
  State<ExplorePage> createState() => _ExplorePageState();
}

class _ExplorePageState extends State<ExplorePage> {
  final controller = TextEditingController();
  String query = '';

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final posts = data.visiblePosts().where((p) {
      final q = query.toLowerCase();

      return p.text.toLowerCase().contains(q) ||
          p.author.toLowerCase().contains(q) ||
          p.username.toLowerCase().contains(q);
    }).toList();

    return Scaffold(
      backgroundColor: const Color(0xFF07080D),
      appBar: AppBar(
        backgroundColor: const Color(0xFF07080D),
        title: const Text(
          'استكشاف',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(15),
            child: TextField(
              controller: controller,
              onChanged: (value) {
                setState(() {
                  query = value;
                });
              },
              decoration: InputDecoration(
                hintText: 'ابحث عن أشخاص أو منشورات...',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: const Color(0xFF151720),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: posts.length,
              itemBuilder: (_, index) {
                final post = posts[index];

                return ListTile(
                  leading: const CircleAvatar(
                    child: Icon(Icons.person),
                  ),
                  title: Row(
                    children: [
                      Text(post.author),
                      if (post.verified) ...[
                        const SizedBox(width: 4),
                        const Icon(
                          Icons.verified,
                          size: 16,
                          color: Color(0xFF00C8FF),
                        ),
                      ],
                    ],
                  ),
                  subtitle: Text(
                    '@${post.username}\n${post.text}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/* =========================================================
CREATE
========================================================= */

class CreatePage extends StatefulWidget {
  const CreatePage({super.key});

  @override
  State<CreatePage> createState() => _CreatePageState();
}

class _CreatePageState extends State<CreatePage> {
  final controller = TextEditingController();
  final ImagePicker picker = ImagePicker();

  XFile? selectedImage;
  XFile? selectedVideo;

  VideoPlayerController? videoController;

  bool adult = false;
  String visibility = 'عام';
  bool loadingVideo = false;

  @override
  void dispose() {
    controller.dispose();
    videoController?.dispose();
    super.dispose();
  }

  Future<void> pickImage() async {
    try {
      final image = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 90,
      );

      if (image == null) return;

      videoController?.dispose();
      videoController = null;

      if (!mounted) return;

      setState(() {
        selectedImage = image;
        selectedVideo = null;
        loadingVideo = false;
      });
    } catch (_) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تعذر اختيار الصورة'),
        ),
      );
    }
  }

  Future<void> pickVideo() async {
    try {
      final video = await picker.pickVideo(
        source: ImageSource.gallery,
      );

      if (video == null) return;

      videoController?.dispose();
      videoController = null;

      if (!mounted) return;

      setState(() {
        selectedVideo = video;
        selectedImage = null;
        loadingVideo = true;
      });

      final newController = VideoPlayerController.file(
        File(video.path),
      );

      await newController.initialize();
      await newController.setLooping(true);

      if (!mounted) {
        newController.dispose();
        return;
      }

      setState(() {
        videoController = newController;
        loadingVideo = false;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        loadingVideo = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تعذر اختيار الفيديو'),
        ),
      );
    }
  }

  void removeMedia() {
    videoController?.dispose();
    videoController = null;

    setState(() {
      selectedImage = null;
      selectedVideo = null;
      loadingVideo = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF07080D),
      appBar: AppBar(
        title: const Text('إنشاء'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          TextField(
            controller: controller,
            minLines: 6,
            maxLines: 10,
            decoration: InputDecoration(
              hintText: 'ماذا تريد أن تنشر؟',
              filled: true,
              fillColor: const Color(0xFF151720),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: pickImage,
                  icon: const Icon(
                    Icons.image_outlined,
                  ),
                  label: const Text('صورة'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: pickVideo,
                  icon: const Icon(
                    Icons.videocam_outlined,
                  ),
                  label: const Text('فيديو'),
                ),
              ),
            ],
          ),
          if (selectedImage != null ||
              selectedVideo != null ||
              loadingVideo) ...[
            const SizedBox(height: 15),
            _mediaPreview(),
          ],
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('محتوى +21'),
            subtitle: const Text(
              'يظهر للمستخدمين بعمر 21 سنة فأكثر',
            ),
            value: adult,
            onChanged: (value) {
              setState(() {
                adult = value;
              });
            },
          ),
          DropdownButtonFormField<String>(
            initialValue: visibility,
            decoration: const InputDecoration(
              labelText: 'الخصوصية',
              border: OutlineInputBorder(),
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
                setState(() {
                  visibility = value;
                });
              }
            },
          ),
          const SizedBox(height: 18),
          FilledButton(
            onPressed: publish,
            child: const Padding(
              padding: EdgeInsets.all(14),
              child: Text(
                'نشر الآن',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _mediaPreview() {
    if (loadingVideo) {
      return Container(
        height: 260,
        decoration: BoxDecoration(
          color: const Color(0xFF151720),
          borderRadius: BorderRadius.circular(18),
        ),
        alignment: Alignment.center,
        child: const CircularProgressIndicator(),
      );
    }

    if (selectedImage != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Stack(
          children: [
            Image.file(
              File(selectedImage!.path),
              width: double.infinity,
              height: 260,
              fit: BoxFit.cover,
            ),
            Positioned(
              top: 10,
              right: 10,
              child: _removeMediaButton(),
            ),
          ],
        ),
      );
    }

    if (selectedVideo != null &&
        videoController != null &&
        videoController!.value.isInitialized) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Stack(
          alignment: Alignment.center,
          children: [
            AspectRatio(
              aspectRatio:
                  videoController!.value.aspectRatio,
              child: VideoPlayer(videoController!),
            ),
            GestureDetector(
              onTap: () {
                if (videoController!.value.isPlaying) {
                  videoController!.pause();
                } else {
                  videoController!.play();
                }

                setState(() {});
              },
              child: Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: .55),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  videoController!.value.isPlaying
                      ? Icons.pause
                      : Icons.play_arrow,
                  color: Colors.white,
                  size: 34,
                ),
              ),
            ),
            Positioned(
              top: 10,
              right: 10,
              child: _removeMediaButton(),
            ),
          ],
        ),
      );
    }

    return const SizedBox.shrink();
  }

  Widget _removeMediaButton() {
    return GestureDetector(
      onTap: removeMedia,
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: .65),
          shape: BoxShape.circle,
        ),
        child: const Icon(
          Icons.close,
          color: Colors.white,
        ),
      ),
    );
  }

  void publish() {
    final text = controller.text.trim();

    if (text.isEmpty &&
        selectedImage == null &&
        selectedVideo == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'اكتب منشورًا أو اختر صورة أو فيديو',
          ),
        ),
      );
      return;
    }

    if (adult && !data.adultAllowed) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'محتوى +21 غير متاح لمن هم دون 21 عاماً',
          ),
        ),
      );
      return;
    }

    data.createPost(
      text,
      adult: adult,
      visibility: visibility,
      video: selectedVideo != null,
      videoUrl: selectedVideo?.path,
      imageUrl: selectedImage?.path,
    );

    controller.clear();

    videoController?.dispose();
    videoController = null;

    setState(() {
      selectedImage = null;
      selectedVideo = null;
      loadingVideo = false;
      adult = false;
      visibility = 'عام';
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('تم نشر المنشور'),
      ),
    );
  }
}

/* =========================================================
MESSAGES
========================================================= */

class MessagesPage extends StatelessWidget {
  const MessagesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final entries = data.messages.entries.toList();

    return Scaffold(
      backgroundColor: const Color(0xFF07080D),
      appBar: AppBar(
        title: const Text('الرسائل'),
      ),
      body: entries.isEmpty
          ? const Center(
              child: Text('لا توجد محادثات'),
            )
          : ListView.builder(
              itemCount: entries.length,
              itemBuilder: (_, index) {
                final entry = entries[index];
                final last = entry.value.isEmpty
                    ? null
                    : entry.value.last;

                return ListTile(
                  leading: const CircleAvatar(
                    child: Icon(Icons.person),
                  ),
                  title: Text(entry.key),
                  subtitle: Text(
                    last?.text ?? 'ابدأ المحادثة',
                  ),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ChatPage(
                          username: entry.key,
                        ),
                      ),
                    );
                  },
                );
              },
            ),
    );
  }
}

class ChatPage extends StatefulWidget {
  const ChatPage({
    super.key,
    required this.username,
  });

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

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: data,
      builder: (_, __) {
        final list = data.messages[widget.username] ?? [];

        return Scaffold(
          appBar: AppBar(
            title: Text(widget.username),
          ),
          body: Column(
            children: [
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: list.length,
                  itemBuilder: (_, index) {
                    final message = list[index];
                    final mine =
                        message.sender == data.username;

                    return Align(
                      alignment: mine
                          ? Alignment.centerRight
                          : Alignment.centerLeft,
                      child: Container(
                        margin:
                            const EdgeInsets.only(bottom: 8),
                        padding:
                            const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: mine
                              ? const Color(0xFF006D8D)
                              : const Color(0xFF1A1D27),
                          borderRadius:
                              BorderRadius.circular(16),
                        ),
                        child: Text(message.text),
                      ),
                    );
                  },
                ),
              ),
              SafeArea(
                top: false,
                child: Row(
                  children: [
                    Expanded(
                      child: Padding(
                        padding:
                            const EdgeInsets.all(8),
                        child: TextField(
                          controller: controller,
                          decoration:
                              const InputDecoration(
                            hintText: 'اكتب رسالة...',
                            border:
                                OutlineInputBorder(),
                          ),
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () {
                        final text =
                            controller.text.trim();

                        if (text.isEmpty) return;

                        data.sendMessage(
                          widget.username,
                          text,
                        );

                        controller.clear();
                      },
                      icon: const Icon(Icons.send),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/* =========================================================
PROFILE
========================================================= */

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    final posts = data.postsOf(data.username);

    return Scaffold(
      backgroundColor: const Color(0xFF07080D),
      appBar: AppBar(
        title: const Text('حسابي'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const SettingsPage(),
                ),
              );
            },
          ),
        ],
      ),
      body: ListView(
        children: [
          const SizedBox(height: 20),
          const Center(
            child: CircleAvatar(
              radius: 50,
              child: Icon(
                Icons.person,
                size: 55,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Center(
            child: Text(
              data.name,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          Center(
            child: Text(
              '@${data.username}',
              style: const TextStyle(
                color: Colors.white54,
              ),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment:
                MainAxisAlignment.spaceEvenly,
            children: [
              Stat('${posts.length}', 'منشورات'),
              Stat(
                '${data.following.length}',
                'متابَعون',
              ),
              const Stat('0', 'متابعون'),
            ],
          ),
          const SizedBox(height: 20),
          Center(
            child: OutlinedButton(
              onPressed: () {},
              child: const Text(
                'تعديل الملف الشخصي',
              ),
            ),
          ),
          const SizedBox(height: 20),
          const Padding(
            padding: EdgeInsets.symmetric(
              horizontal: 18,
            ),
            child: Text(
              'منشوراتي',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 10),
          ...posts.map(
            (post) => ListTile(
              title: Text(
                post.text.isEmpty
                    ? 'منشور بصورة أو فيديو'
                    : post.text,
              ),
              subtitle: Text(
                '${post.likes} إعجاب • ${post.comments} تعليق',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class Stat extends StatelessWidget {
  const Stat(
    this.value,
    this.label, {
    super.key,
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
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white54,
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}

/* =========================================================
SETTINGS
========================================================= */

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: data,
      builder: (_, __) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('الإعدادات'),
          ),
          body: ListView(
            children: [
              SwitchListTile(
                title: const Text('حساب خاص'),
                value: data.privateAccount,
                onChanged: data.setPrivateAccount,
              ),
              SwitchListTile(
                title: const Text('حالة النشاط'),
                value: data.activityStatus,
                onChanged: data.setActivityStatus,
              ),
              SwitchListTile(
                title: const Text('السماح بالرسائل'),
                value: data.allowMessages,
                onChanged: data.setAllowMessages,
              ),
              SwitchListTile(
                title: const Text('الإشعارات'),
                value: data.notifications,
                onChanged: data.setNotifications,
              ),
              const Divider(),
              ListTile(
                leading: const Icon(
                  Icons.military_tech,
                ),
                title: const Text(
                  'مستوى الداعم',
                ),
                trailing: Text(
                  '${data.supporterLevel}',
                ),
              ),
              ListTile(
                leading: const Icon(
                  Icons.stars,
                ),
                title: const Text(
                  'الشارات والجوائز',
                ),
                subtitle: Text(
                  data.badges.join(' • '),
                ),
              ),
              ListTile(
                leading: const Icon(
                  Icons.monetization_on,
                ),
                title: const Text('الرصيد'),
                trailing: Text(
                  '${data.coins}',
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
