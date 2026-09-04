import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/constants/app_colors.dart';
import '../core/widgets/n_logo.dart';
import '../n_data.dart';

class NInboxPage extends StatefulWidget {
  const NInboxPage({super.key, this.initialTab = 0});

  final int initialTab;

  @override
  State<NInboxPage> createState() => _NInboxPageState();
}

class _NInboxPageState extends State<NInboxPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  bool loadingNotifications = true;
  List<Map<String, dynamic>> notifications = [];
  String? notificationError;
  RealtimeChannel? _notificationChannel;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this, initialIndex: widget.initialTab.clamp(0, 1));
    unawaited(_loadNotifications());
    unawaited(data.loadConversations());
    _subscribeNotifications();
  }

  void _subscribeNotifications() {
    final uid = data.userId;
    if (uid == null) return;
    _notificationChannel = data.supabase
        .channel('n-notifications-$uid')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'notifications',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: uid,
          ),
          callback: (_) => _loadNotifications(),
        )
        .subscribe();
  }

  @override
  void dispose() {
    if (_notificationChannel != null) {
      data.supabase.removeChannel(_notificationChannel!);
    }
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _loadNotifications() async {
    if (mounted) setState(() => loadingNotifications = true);
    try {
      final rows = await data.supabase
          .from('notifications')
          .select()
          .eq('user_id', data.userId!)
          .order('created_at', ascending: false)
          .limit(100);
      if (!mounted) return;
      setState(() {
        notifications = rows.map((e) => Map<String, dynamic>.from(e)).toList();
        notificationError = null;
        loadingNotifications = false;
      });
    } on PostgrestException catch (e) {
      if (!mounted) return;
      setState(() {
        notificationError = e.message;
        loadingNotifications = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        notificationError = 'تعذر تحميل الإشعارات';
        loadingNotifications = false;
      });
    }
  }

  Future<void> _markRead(String id) async {
    try {
      await data.supabase.rpc('n_mark_notification_read', params: {'notification_id': id});
      await _loadNotifications();
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: NColors.background,
      appBar: AppBar(
        backgroundColor: NColors.background,
        titleSpacing: 16,
        title: Row(
          children: const [
            NLogo(size: 32),
            SizedBox(width: 10),
            Text('التواصل', style: TextStyle(fontWeight: FontWeight.w900)),
          ],
        ),
        bottom: TabBar(
          controller: _tabs,
          indicatorColor: NColors.pink,
          indicatorWeight: 3,
          tabs: const [
            Tab(text: 'الرسائل'),
            Tab(text: 'الإشعارات'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          _MessagesTab(onRefresh: () => data.loadConversations()),
          _NotificationsTab(
            notifications: notifications,
            loading: loadingNotifications,
            error: notificationError,
            onRefresh: _loadNotifications,
            onRead: _markRead,
          ),
        ],
      ),
    );
  }
}

class _MessagesTab extends StatelessWidget {
  const _MessagesTab({required this.onRefresh});

  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: data,
      builder: (context, _) {
        final conversations = data.sortedConversations();
        return RefreshIndicator(
          onRefresh: onRefresh,
          child: conversations.isEmpty
              ? ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: const [
                    SizedBox(height: 150),
                    Icon(Icons.chat_bubble_outline_rounded, size: 52, color: NColors.muted),
                    SizedBox(height: 14),
                    Center(child: Text('لا توجد محادثات بعد', style: TextStyle(color: NColors.muted))),
                  ],
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(12, 14, 12, 30),
                  physics: const AlwaysScrollableScrollPhysics(),
                  itemCount: conversations.length,
                  separatorBuilder: (_, __) => const Divider(height: 1, color: NColors.divider),
                  itemBuilder: (context, index) {
                    final entry = conversations[index];
                    final last = entry.value.isEmpty ? null : entry.value.last;
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
                      leading: const CircleAvatar(
                        radius: 27,
                        backgroundColor: NColors.surface,
                        child: Icon(Icons.person_rounded, color: Colors.white70),
                      ),
                      title: Text('@${entry.key}', style: const TextStyle(fontWeight: FontWeight.w800)),
                      subtitle: Text(last?.text ?? 'ابدأ المحادثة', maxLines: 1, overflow: TextOverflow.ellipsis),
                      trailing: last == null ? null : Text(last.time, style: const TextStyle(fontSize: 11, color: NColors.muted)),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => NChatPage(username: entry.key)),
                      ),
                    );
                  },
                ),
        );
      },
    );
  }
}

class NChatPage extends StatefulWidget {
  const NChatPage({super.key, required this.username});
  final String username;

  @override
  State<NChatPage> createState() => _NChatPageState();
}

class _NChatPageState extends State<NChatPage> {
  final controller = TextEditingController();
  bool sending = false;

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = controller.text.trim();
    if (text.isEmpty || sending) return;
    setState(() => sending = true);
    controller.clear();
    await data.sendMessage(widget.username, text);
    if (mounted) setState(() => sending = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: NColors.background,
      appBar: AppBar(title: Text('@${widget.username}', style: const TextStyle(fontWeight: FontWeight.w800))),
      body: Column(
        children: [
          Expanded(
            child: AnimatedBuilder(
              animation: data,
              builder: (context, _) {
                final messages = data.messages[widget.username] ?? const <NMessage>[];
                if (messages.isEmpty) {
                  return const Center(child: Text('ابدأ أول رسالة', style: TextStyle(color: NColors.muted)));
                }
                return ListView.builder(
                  reverse: false,
                  padding: const EdgeInsets.all(14),
                  itemCount: messages.length,
                  itemBuilder: (_, i) {
                    final message = messages[i];
                    final mine = message.sender == data.username;
                    return Align(
                      alignment: mine ? Alignment.centerLeft : Alignment.centerRight,
                      child: Container(
                        constraints: const BoxConstraints(maxWidth: 320),
                        margin: const EdgeInsets.only(bottom: 9),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: mine ? NColors.cyan.withValues(alpha: .18) : NColors.surface,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: mine ? NColors.cyan.withValues(alpha: .28) : NColors.divider),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(message.text),
                            const SizedBox(height: 4),
                            Text(message.time, style: const TextStyle(fontSize: 10, color: NColors.muted)),
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
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 6, 12, 10),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: controller,
                      minLines: 1,
                      maxLines: 4,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _send(),
                      decoration: const InputDecoration(hintText: 'اكتب رسالة...'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: sending ? null : _send,
                    icon: sending
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.send_rounded),
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

class _NotificationsTab extends StatelessWidget {
  const _NotificationsTab({
    required this.notifications,
    required this.loading,
    required this.error,
    required this.onRefresh,
    required this.onRead,
  });

  final List<Map<String, dynamic>> notifications;
  final bool loading;
  final String? error;
  final Future<void> Function() onRefresh;
  final Future<void> Function(String id) onRead;

  IconData _icon(String type) {
    switch (type) {
      case 'like': return Icons.favorite_rounded;
      case 'comment': return Icons.chat_bubble_rounded;
      case 'follow': return Icons.person_add_alt_1_rounded;
      case 'message': return Icons.mail_rounded;
      case 'gift': return Icons.card_giftcard_rounded;
      case 'live': return Icons.podcasts_rounded;
      default: return Icons.notifications_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (loading) return const Center(child: CircularProgressIndicator());
    if (error != null) {
      return RefreshIndicator(
        onRefresh: onRefresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [const SizedBox(height: 160), Center(child: Icon(Icons.cloud_off_rounded, size: 52, color: NColors.muted)), const SizedBox(height: 12), Center(child: Text(error ?? 'تعذر تحميل الإشعارات', textAlign: TextAlign.center, style: TextStyle(color: NColors.muted))), const SizedBox(height: 12), Center(child: TextButton(onPressed: onRefresh, child: Text('إعادة المحاولة')))],
        ),
      );
    }
    if (notifications.isEmpty) {
      return RefreshIndicator(
        onRefresh: onRefresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: const [SizedBox(height: 160), Center(child: Icon(Icons.notifications_none_rounded, size: 56, color: NColors.muted)), SizedBox(height: 12), Center(child: Text('لا توجد إشعارات جديدة', style: TextStyle(color: NColors.muted)))],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 30),
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: notifications.length,
        separatorBuilder: (_, __) => const Divider(height: 1, color: NColors.divider),
        itemBuilder: (context, index) {
          final n = notifications[index];
          final read = n['read'] == true;
          final type = (n['type'] ?? '').toString();
          final actor = (n['actor_username'] ?? n['actor_id'] ?? '').toString();
          final title = (n['title'] ?? 'إشعار جديد').toString();
          final body = (n['body'] ?? '').toString();
          final created = DateTime.tryParse((n['created_at'] ?? '').toString());
          return ListTile(
            tileColor: read ? Colors.transparent : NColors.cyan.withValues(alpha: .06),
            leading: CircleAvatar(
              backgroundColor: read ? NColors.surface : NColors.pink.withValues(alpha: .18),
              child: Icon(_icon(type), color: read ? Colors.white70 : NColors.pink),
            ),
            title: Text(title, style: TextStyle(fontWeight: read ? FontWeight.w600 : FontWeight.w900)),
            subtitle: Text(body.isNotEmpty ? body : (actor.isNotEmpty ? '@$actor' : '')),
            trailing: created == null ? null : Text(_time(created), style: const TextStyle(fontSize: 10, color: NColors.muted)),
            onTap: read ? null : () => onRead((n['id'] ?? '').toString()),
          );
        },
      ),
    );
  }

  String _time(DateTime time) {
    final local = time.toLocal();
    return '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }
}
