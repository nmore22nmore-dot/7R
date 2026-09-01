import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../n_data.dart';
import '../core/constants/app_colors.dart';
import '../core/widgets/n_logo.dart';
import 'admin_page.dart';

class NSecurityPage extends StatefulWidget {
  const NSecurityPage({super.key, required this.data});
  final NData data;
  @override State<NSecurityPage> createState() => _NSecurityPageState();
}

class _NSecurityPageState extends State<NSecurityPage> {
  bool privateAccount = false;
  bool activity = true;
  bool allowMessages = true;
  bool notifications = true;

  Future<void> _report() async {
    const reasons = ['محتوى مزعج أو احتيالي','إساءة أو تنمر','محتوى غير مناسب','انتحال شخصية','أخرى'];
    final reason = await showModalBottomSheet<String>(
      context: context, backgroundColor: NColors.surface,
      builder: (_) => SafeArea(child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Padding(padding: EdgeInsets.all(18), child: Text('إبلاغ عن مشكلة', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900))),
        for (final item in reasons) ListTile(title: Text(item), leading: const Icon(Icons.flag_outlined), onTap: () => Navigator.pop(context, item)),
      ])),
    );
    if (reason == null || !mounted) return;
    final ok = await widget.data.reportContent(reason: reason, details: 'بلاغ من إعدادات الحساب');
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(ok ? 'تم إرسال البلاغ للمراجعة' : 'تعذر إرسال البلاغ')));
  }

  @override
  void initState() {
    super.initState();
    privateAccount = widget.data.privateAccount;
    activity = widget.data.activityStatus;
    allowMessages = widget.data.allowMessages;
    notifications = widget.data.notifications;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: NColors.background,
      appBar: AppBar(backgroundColor: NColors.background, title: const NLogo(size: 32), centerTitle: true),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        const Text('الأمان والخصوصية', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
        const SizedBox(height: 6),
        const Text('تحكم بظهور حسابك ووسائل التواصل معك.', style: TextStyle(color: NColors.muted)),
        const SizedBox(height: 20),
        _section('الخصوصية', [
          _switch('حساب خاص', 'الموافقة على المتابعين الجدد', privateAccount, (v) async { setState(() => privateAccount = v); await widget.data.setPrivateAccount(v); }),
          _switch('حالة النشاط', 'إظهار أنك متصل', activity, (v) async { setState(() => activity = v); await widget.data.setActivityStatus(v); }),
          _switch('السماح بالرسائل', 'السماح للمستخدمين بمراسلتك', allowMessages, (v) async { setState(() => allowMessages = v); await widget.data.setAllowMessages(v); }),
        ]),
        const SizedBox(height: 12),
        _section('التنبيهات', [
          _switch('الإشعارات', 'الإعجابات والمتابعات والرسائل والبث', notifications, (v) async { setState(() => notifications = v); await widget.data.setNotifications(v); }),
        ]),
        const SizedBox(height: 12),
        _section('الحماية', [
          _tile(Icons.password_rounded, 'تغيير كلمة المرور', 'تحديث كلمة مرور الحساب', _changePassword),
          _tile(Icons.devices_rounded, 'الجلسات والأجهزة', 'تسجيل الخروج من الأجهزة الأخرى', _signOutOtherSessions),
          _tile(Icons.flag_outlined, 'الإبلاغ عن مشكلة', 'إرسال بلاغ للمراجعة', _report),
        ]),
        const SizedBox(height: 12),
        if (widget.data.isAdmin)
          _section('الإدارة', [
            _tile(Icons.admin_panel_settings_rounded, 'لوحة الإدارة', 'إدارة البلاغات ومراقبة المنصة', () => Navigator.push(context, MaterialPageRoute(builder: (_) => NAdminPage(data: widget.data)))),
          ]),
        _section('الحساب', [
          _tile(Icons.logout_rounded, 'تسجيل الخروج', 'إنهاء جلسة الحساب الحالية', () async { await widget.data.logout(); if (mounted) Navigator.pop(context); }),
        ]),
      ]),
    );
  }

  Widget _section(String title, List<Widget> children) => Container(
    margin: const EdgeInsets.only(bottom: 4), padding: const EdgeInsets.symmetric(vertical: 8),
    decoration: BoxDecoration(color: NColors.surface, borderRadius: BorderRadius.circular(18)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Padding(padding: const EdgeInsets.fromLTRB(16, 8, 16, 4), child: Text(title, style: const TextStyle(color: NColors.cyan, fontWeight: FontWeight.w800))), ...children],),
  );

  Widget _switch(String title, String sub, bool value, ValueChanged<bool> onChanged) => SwitchListTile(value: value, onChanged: onChanged, title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)), subtitle: Text(sub, style: const TextStyle(color: NColors.muted, fontSize: 12)), activeColor: NColors.pink);

  Widget _tile(IconData icon, String title, String sub, VoidCallback onTap) => ListTile(onTap: onTap, leading: Icon(icon, color: NColors.cyan), title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)), subtitle: Text(sub, style: const TextStyle(color: NColors.muted, fontSize: 12)), trailing: const Icon(Icons.chevron_left_rounded));


  Future<void> _changePassword() async {
    final controller = TextEditingController();
    final confirmController = TextEditingController();
    var obscure = true;
    var saving = false;

    final changed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          backgroundColor: NColors.surface,
          title: const Text('تغيير كلمة المرور'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: controller,
                obscureText: obscure,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: 'كلمة المرور الجديدة',
                  suffixIcon: IconButton(
                    onPressed: () => setDialogState(() => obscure = !obscure),
                    icon: Icon(obscure ? Icons.visibility : Icons.visibility_off),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: confirmController,
                obscureText: obscure,
                decoration: const InputDecoration(labelText: 'تأكيد كلمة المرور'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: saving ? null : () => Navigator.pop(dialogContext, false),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              onPressed: saving
                  ? null
                  : () async {
                      final password = controller.text.trim();
                      final confirm = confirmController.text.trim();
                      if (password.length < 6) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('كلمة المرور يجب أن تكون 6 أحرف على الأقل')),
                        );
                        return;
                      }
                      if (password != confirm) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('كلمتا المرور غير متطابقتين')),
                        );
                        return;
                      }
                      setDialogState(() => saving = true);
                      try {
                        await widget.data.supabase.auth.updateUser(
                          UserAttributes(password: password),
                        );
                        if (dialogContext.mounted) Navigator.pop(dialogContext, true);
                      } on AuthException catch (e) {
                        if (dialogContext.mounted) {
                          setDialogState(() => saving = false);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(e.message)),
                          );
                        }
                      } catch (_) {
                        if (dialogContext.mounted) {
                          setDialogState(() => saving = false);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('تعذر تغيير كلمة المرور')),
                          );
                        }
                      }
                    },
              child: saving
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('حفظ'),
            ),
          ],
        ),
      ),
    );

    controller.dispose();
    confirmController.dispose();
    if (!mounted || changed != true) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('تم تغيير كلمة المرور بنجاح')),
    );
  }

  Future<void> _signOutOtherSessions() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: NColors.surface,
        title: const Text('الجلسات والأجهزة'),
        content: const Text('سيتم تسجيل خروج حسابك من جميع الأجهزة الأخرى، وسيبقى هذا الجهاز متصلًا.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('إلغاء')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('تسجيل الخروج')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      await widget.data.supabase.auth.signOut(scope: SignOutScope.others);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم تسجيل الخروج من الأجهزة الأخرى')),
      );
    } on AuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تعذر إنهاء الجلسات الأخرى')),
      );
    }
  }

  void _message(String text) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
}
