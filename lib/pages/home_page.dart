import 'package:flutter/material.dart';

import '../n_data.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: data,
      builder: (context, _) {
        final posts = data.visiblePosts();

        if (posts.isEmpty) {
          return const Center(
            child: Text(
              'لا توجد منشورات حاليًا',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 16,
              ),
            ),
          );
        }

        return CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            const SliverToBoxAdapter(
              child: _StoriesSection(),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
              sliver: SliverList.builder(
                itemCount: posts.length,
                itemBuilder: (context, index) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: PostCard(post: posts[index]),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

class _StoriesSection extends StatelessWidget {
  const _StoriesSection();

  @override
  Widget build(BuildContext context) {
    final stories = const [
      ('قصتك', true),
      ('N Official', false),
      ('Ahmed', false),
      ('Sara', false),
      ('Mohamed', false),
      ('Noor', false),
    ];

    return SizedBox(
      height: 128,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: stories.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final story = stories[index];

          return SizedBox(
            width: 76,
            child: Column(
              children: [
                Container(
                  width: 68,
                  height: 68,
                  padding: const EdgeInsets.all(2.5),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      colors: [
                        Color(0xFF00C8FF),
                        Color(0xFFFF287A),
                      ],
                    ),
                  ),
                  child: Container(
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color(0xFF11141C),
                    ),
                    child: story.$2
                        ? const Icon(
                            Icons.add,
                            size: 30,
                            color: Colors.white,
                          )
                        : const Icon(
                            Icons.person,
                            size: 30,
                            color: Colors.white70,
                          ),
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  story.$1,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class PostCard extends StatelessWidget {
  const PostCard({
    super.key,
    required this.post,
  });

  final NPost post;

  @override
  Widget build(BuildContext context) {
    final isOwner = post.username == data.username;

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => _PostAuthorPage(
                          username: post.username,
                          author: post.author,
                        ),
                      ),
                    );
                  },
                  child: const CircleAvatar(
                    radius: 23,
                    child: Icon(Icons.person),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => _PostAuthorPage(
                            username: post.username,
                            author: post.author,
                          ),
                        ),
                      );
                    },
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                post.author,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                ),
                              ),
                            ),
                            if (post.verified) ...[
                              const SizedBox(width: 4),
                              const Icon(
                                Icons.verified,
                                size: 17,
                                color: Color(0xFF00C8FF),
                              ),
                            ],
                          ],
                        ),
                        Text(
                          '@${post.username}',
                          style: const TextStyle(
                            color: Colors.white54,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                PopupMenuButton<String>(
                  onSelected: (value) async {
                    if (value == 'delete' && isOwner) {
                      await data.deletePost(post);
                    }
                  },
                  itemBuilder: (_) => [
                    if (isOwner)
                      const PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(
                              Icons.delete_outline,
                              color: Colors.redAccent,
                            ),
                            SizedBox(width: 10),
                            Text('حذف المنشور'),
                          ],
                        ),
                      ),
                    const PopupMenuItem(
                      value: 'report',
                      child: Row(
                        children: [
                          Icon(Icons.flag_outlined),
                          SizedBox(width: 10),
                          Text('إبلاغ'),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (post.adult)
              Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  color: Colors.red.withValues(alpha: 0.12),
                ),
                child: const Row(
                  children: [
                    Icon(
                      Icons.eighteen_mp,
                      size: 18,
                      color: Colors.redAccent,
                    ),
                    SizedBox(width: 7),
                    Text(
                      'محتوى +21',
                      style: TextStyle(
                        color: Colors.redAccent,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            if (post.text.isNotEmpty)
              Text(
                post.text,
                style: const TextStyle(
                  fontSize: 16,
                  height: 1.55,
                ),
              ),
            if (post.imageUrl != null &&
                post.imageUrl!.trim().isNotEmpty) ...[
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Image.network(
                  post.imageUrl!,
                  width: double.infinity,
                  height: 260,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) {
                    return const SizedBox(
                      height: 180,
                      child: Center(
                        child: Icon(
                          Icons.broken_image_outlined,
                          size: 42,
                          color: Colors.white38,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
            if (post.video &&
                post.videoUrl != null &&
                post.videoUrl!.trim().isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                height: 240,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  color: Colors.black,
                ),
                child: const Center(
                  child: Icon(
                    Icons.play_circle_fill,
                    size: 64,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 10),
            Row(
              children: [
                Text(
                  '${post.likes}',
                  style: const TextStyle(
                    color: Colors.white60,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(width: 4),
                const Text(
                  'إعجاب',
                  style: TextStyle(
                    color: Colors.white60,
                    fontSize: 12,
                  ),
                ),
                const Spacer(),
                Text(
                  '${post.comments} تعليق',
                  style: const TextStyle(
                    color: Colors.white60,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            const Divider(height: 18),
            Row(
              children: [
                Expanded(
                  child: _ActionButton(
                    icon: post.liked
                        ? Icons.favorite
                        : Icons.favorite_border,
                    label: 'إعجاب',
                    active: post.liked,
                    onTap: () => data.like(post),
                  ),
                ),
                Expanded(
                  child: _ActionButton(
                    icon: Icons.chat_bubble_outline,
                    label: 'تعليق',
                    onTap: () => _showCommentDialog(
                      context,
                      post,
                    ),
                  ),
                ),
                Expanded(
                  child: _ActionButton(
                    icon: post.saved
                        ? Icons.bookmark
                        : Icons.bookmark_border,
                    label: 'حفظ',
                    active: post.saved,
                    onTap: () => data.save(post),
                  ),
                ),
                Expanded(
                  child: _ActionButton(
                    icon: Icons.share_outlined,
                    label: 'مشاركة',
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('تم تجهيز المنشور للمشاركة'),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showCommentDialog(
    BuildContext context,
    NPost post,
  ) async {
    final controller = TextEditingController();

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('إضافة تعليق'),
          content: TextField(
            controller: controller,
            autofocus: true,
            maxLines: 4,
            decoration: const InputDecoration(
              hintText: 'اكتب تعليقك...',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              onPressed: () async {
                final success = await data.addComment(
                  post,
                  controller.text,
                );

                if (!dialogContext.mounted) return;

                if (success) {
                  Navigator.pop(dialogContext);
                }
              },
              child: const Text('إرسال'),
            ),
          ],
        );
      },
    );

    controller.dispose();
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.active = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          children: [
            Icon(
              icon,
              size: 22,
              color: active
                  ? const Color(0xFFFF287A)
                  : Colors.white70,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                color: Colors.white60,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PostAuthorPage extends StatelessWidget {
  const _PostAuthorPage({
    required this.username,
    required this.author,
  });

  final String username;
  final String author;

  @override
  Widget build(BuildContext context) {
    final posts = data.postsOf(username);

    return Scaffold(
      appBar: AppBar(
        title: Text(author),
      ),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          Center(
            child: Column(
              children: [
                const CircleAvatar(
                  radius: 45,
                  child: Icon(
                    Icons.person,
                    size: 45,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  author,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  '@$username',
                  style: const TextStyle(
                    color: Colors.white54,
                  ),
                ),
                const SizedBox(height: 12),
                if (username != data.username)
                  FilledButton(
                    onPressed: () => data.follow(username),
                    child: Text(
                      data.following.contains(username)
                          ? 'متابَع'
                          : 'متابعة',
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'منشورات الحساب',
            style: TextStyle(
              fontSize: 21,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 10),
          if (posts.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(
                child: Text('لا توجد منشورات بعد'),
              ),
            ),
          ...posts.map(
            (post) => Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: PostCard(post: post),
            ),
          ),
        ],
      ),
    );
  }
}
