import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../n_data.dart';
import '../core/constants/app_colors.dart';
import 'admin_page.dart';

class NSecurityPage extends StatefulWidget {
  const NSecurityPage({super.key, required this.data});

  final NData data;

  @override
  State<NSecurityPage> createState() => _NSecurityPageState();
}

class _NSecurityPageState extends State<NSecurityPage> {
  bool privateAccount = false;
  bool activity = true;
  bool allowMessages = true;
  bool notifications = true;

  Future<void> _report() async {
    const reasons = [
      'محتوى مزعج أو احتيالي',
      'إساءة أو تنمر',
      'محتوى غير مناسب',
      'انتحال شخصية',
      'أخرى',
    ];

    final reason = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: NColors.surface,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(18),
              child: Text(
                'إبلاغ عن مشكلة',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            for (final item in reasons)
              ListTile(
                title: Text(item),
                leading: const Icon(Icons.flag_outlined),
                onTap: () => Navigator.pop(context, item),
              ),
          ],
        ),
      ),
    );

    if (reason == null || !mounted) return;

    final ok = await widget.data.reportContent(
      reason: reason,
      details: 'بلاغ من إعدادات الحساب',
    );

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok ? 'تم إرسال البلاغ للمراجعة' : 'تعذر إرسال البلاغ',
        ),
      ),
    );
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
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          tooltip: 'رجوع',
          onPressed: () => Navigator.pop(context),
          icon: const Icon(
            Icons.arrow_forward_rounded,
            size: 30,
          ),
        ),
        title: const Text(
          'الإعدادات والخصوصية',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w900,
          ),
        ),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
        children: [
          _section('الوقت والرفاهية', [
            _tile(
              Icons.hourglass_empty_rounded,
              'الوقت والرفاهية',
              'إدارة وقت استخدام N',
              () {},
            ),
            _tile(
              Icons.family_restroom_rounded,
              'ربط الحسابات للعائلة',
              'إعدادات العائلة والرقابة',
              () {},
            ),
          ]),
          _section('الحساب', [
            _tile(
              Icons.person_rounded,
              'الحساب',
              'معلومات حساب N وإعداداته',
              () {},
            ),
            _tile(
              Icons.shield_rounded,
              'الأمان والأذونات',
              'حماية الحساب والصلاحيات',
              () {},
            ),
            _tile(
              Icons.share_rounded,
              'مشاركة الملف الشخصي',
              'شارك ملفك على N',
              () {},
            ),
          ]),
          _section('الظهور', [
            _switch(
              'حساب خاص',
              'الموافقة على المتابعين الجدد',
              privateAccount,
              (v) async {
                setState(() => privateAccount = v);
                await widget.data.setPrivateAccount(v);
              },
            ),
            _tile(
              Icons.block_rounded,
              'الحسابات المحظورة',
              'إدارة الحسابات التي حظرتها',
              () {},
            ),
          ]),
          _section('التفاعلات', [
            _tile(
              Icons.chat_bubble_rounded,
              'تعليقات',
              'التحكم في التعليقات على منشوراتك',
              () {},
            ),
            _tile(
              Icons.alternate_email_rounded,
              'الذكر',
              'التحكم في الإشارات إليك',
              () {},
            ),
            _tile(
              Icons.send_rounded,
              'الرسائل الخاصة',
              'من يمكنه مراسلتك',
              () {},
            ),
            _switch(
              'حالة النشاط',
              'إظهار أنك متصل',
              activity,
              (v) async {
                setState(() => activity = v);
                await widget.data.setActivityStatus(v);
              },
            ),
            _switch(
              'السماح بالرسائل',
              'السماح للمستخدمين بمراسلتك',
              allowMessages,
              (v) async {
                setState(() => allowMessages = v);
                await widget.data.setAllowMessages(v);
              },
            ),
          ]),
          _section('الإشعارات والحماية', [
            _switch(
              'الإشعارات',
              'الإعجابات والمتابعات والرسائل والبث',
              notifications,
              (v) async {
                setState(() => notifications = v);
                await widget.data.setNotifications(v);
              },
            ),
            _tile(
              Icons.password_rounded,
              'تغيير كلمة المرور',
              'تحديث كلمة مرور الحساب',
              _changePassword,
            ),
            _tile(
              Icons.devices_rounded,
              'الجلسات والأجهزة',
              'تسجيل الخروج من الأجهزة الأخرى',
              _signOutOtherSessions,
            ),
            _tile(
              Icons.flag_outlined,
              'الإبلاغ عن مشكلة',
              'إرسال بلاغ للمراجعة',
              _report,
            ),
          ]),
          if (widget.data.isAdmin)
            _section('الإدارة', [
              _tile(
                Icons.admin_panel_settings_rounded,
                'لوحة الإدارة',
                'إدارة البلاغات ومراقبة المنصة',
                () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => NAdminPage(
                      data: widget.data,
                    ),
                  ),
                ),
              ),
            ]),
          _section('الحساب', [
            _tile(
              Icons.logout_rounded,
              'تسجيل الخروج',
              'إنهاء جلسة الحساب الحالية',
              () async {
                await widget.data.logout();

                if (mounted) {
                  Navigator.pop(context);
                }
              },
            ),
          ]),
        ],
      ),
    );
  }

  Widget _section(
    String title,
    List<Widget> children,
  ) =>
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              8,
              18,
              8,
              8,
            ),
            child: Text(
              title,
              style: const TextStyle(
                color: Color(0xFF9A9A9F),
                fontSize: 14,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFF1D1D1F),
              borderRadius: BorderRadius.circular(16),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                for (var i = 0; i < children.length; i++) ...[
                  children[i],
                  if (i != children.length - 1)
                    const Divider(
                      height: 1,
                      indent: 18,
                      endIndent: 18,
                      color: Color(0xFF29292B),
                    ),
                ],
              ],
            ),
          ),
        ],
      );

  Widget _switch(
    String title,
    String sub,
    bool value,
    ValueChanged<bool> onChanged,
  ) =>
      SwitchListTile(
        value: value,
        onChanged: onChanged,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 2,
        ),
        title: Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.w700,
          ),
        ),
        subtitle: Text(
          sub,
          style: const TextStyle(
            color: NColors.muted,
            fontSize: 12,
          ),
        ),
        secondary: const Icon(
          Icons.toggle_on_rounded,
          color: Color(0xFF8E8E93),
        ),
        activeThumbColor: NColors.pink,
      );

  Widget _tile(
    IconData icon,
    String title,
    String sub,
    VoidCallback onTap,
  ) =>
      ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 4,
        ),
        leading: Icon(
          icon,
          color: const Color(0xFF8E8E93),
          size: 24,
        ),
        title: Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.w800,
          ),
        ),
        subtitle: sub.isEmpty
            ? null
            : Text(
                sub,
                style: const TextStyle(
                  color: NColors.muted,
                  fontSize: 12,
                ),
              ),
        trailing: const Icon(
          Icons.chevron_left_rounded,
          color: Color(0xFF77777B),
          size: 26,
        ),
      );

  Future<void> _changePassword() async {
    final controller = TextEditingController();
    final confirmController = TextEditingController();

    var obscure = true;
    var saving = false;

    final changed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (
          dialogContext,
          setDialogState,
        ) =>
            AlertDialog(
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
                    onPressed: () => setDialogState(
                      () => obscure = !obscure,
                    ),
                    icon: Icon(
                      obscure
                          ? Icons.visibility
                          : Icons.visibility_off,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: confirmController,
                obscureText: obscure,
                decoration: const InputDecoration(
                  labelText: 'تأكيد كلمة المرور',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: saving
                  ? null
                  : () => Navigator.pop(
                        dialogContext,
                        false,
                      ),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              onPressed: saving
                  ? null
                  : () async {
                      final password =
                          controller.text.trim();
                      final confirm =
                          confirmController.text.trim();

                      if (password.length < 6) {
                        ScaffoldMessenger.of(context)
                            .showSnackBar(
                          const SnackBar(
                            content: Text(
                              'كلمة المرور يجب أن تكون 6 أحرف على الأقل',
                            ),
                          ),
                        );
                        return;
                      }

                      if (password != confirm) {
                        ScaffoldMessenger.of(context)
                            .showSnackBar(
                          const SnackBar(
                            content: Text(
                              'كلمتا المرور غير متطابقتين',
                            ),
                          ),
                        );
                        return;
                      }

                      setDialogState(
                        () => saving = true,
                      );

                      try {
                        await widget.data.supabase.auth
                            .updateUser(
                          UserAttributes(
                            password: password,
                          ),
                        );

                        if (dialogContext.mounted) {
                          Navigator.pop(
                            dialogContext,
                            true,
                          );
                        }
                      } on AuthException catch (e) {
                        if (dialogContext.mounted) {
                          setDialogState(
                            () => saving = false,
                          );

                          ScaffoldMessenger.of(context)
                              .showSnackBar(
                            SnackBar(
                              content: Text(e.message),
                            ),
                          );
                        }
                      } catch (_) {
                        if (dialogContext.mounted) {
                          setDialogState(
                            () => saving = false,
                          );

                          ScaffoldMessenger.of(context)
                              .showSnackBar(
                            const SnackBar(
                              content: Text(
                                'تعذر تغيير كلمة المرور',
                              ),
                            ),
                          );
                        }
                      }
                    },
              child: saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                      ),
                    )
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
      const SnackBar(
        content: Text(
          'تم تغيير كلمة المرور بنجاح',
        ),
      ),
    );
  }

  Future<void> _signOutOtherSessions() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: NColors.surface,
        title: const Text('الجلسات والأجهزة'),
        content: const Text(
          'سيتم تسجيل خروج حسابك من جميع الأجهزة الأخرى، وسيبقى هذا الجهاز متصلًا.',
        ),
        actions: [
          TextButton(
            onPressed: () =>
                Navigator.pop(dialogContext, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(dialogContext, true),
            child: const Text('تسجيل الخروج'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      await widget.data.supabase.auth.signOut(
        scope: SignOutScope.others,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'تم تسجيل الخروج من الأجهزة الأخرى',
          ),
        ),
      );
    } on AuthException catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    } catch (_) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'تعذر إنهاء الجلسات الأخرى',
          ),
        ),
      );
    }
  }
}
