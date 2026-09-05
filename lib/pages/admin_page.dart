import 'package:flutter/material.dart';
import '../core/constants/app_colors.dart';
import '../core/widgets/n_logo.dart';
import '../n_data.dart';

class NAdminPage extends StatefulWidget {
  const NAdminPage({super.key, required this.data});
  final NData data;

  @override
  State<NAdminPage> createState() => _NAdminPageState();
}

class _NAdminPageState extends State<NAdminPage> {
  bool loading = true;
  Map<String, dynamic> stats = {};
  List<Map<String, dynamic>> reports = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => loading = true);
    try {
      final result = await widget.data.adminOverview();
      final rows = await widget.data.adminReports();
      if (!mounted) return;
      setState(() {
        stats = result;
        reports = rows;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تعذر تحميل لوحة الإدارة: $e')),
      );
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _status(String id, String status) async {
    final ok = await widget.data.adminSetReportStatus(id, status);
    if (!mounted) return;
    if (ok) await _load();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(ok ? 'تم تحديث البلاغ' : 'تعذر تحديث البلاغ')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: NColors.background,
      appBar: AppBar(
        backgroundColor: NColors.background,
        title: const NLogo(size: 34),
        centerTitle: true,
        actions: [IconButton(onPressed: _load, icon: const Icon(Icons.refresh_rounded))],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text('لوحة الإدارة', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900)),
            const SizedBox(height: 6),
            const Text('مراقبة المنصة وإدارة البلاغات والمحتوى.', style: TextStyle(color: NColors.muted)),
            const SizedBox(height: 18),
            if (loading)
              const Padding(padding: EdgeInsets.all(32), child: Center(child: CircularProgressIndicator()))
            else ...[
              _statsGrid(),
              const SizedBox(height: 18),
              const Text('آخر البلاغات', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900)),
              const SizedBox(height: 10),
              if (reports.isEmpty)
                _empty()
              else
                ...reports.map(_reportCard),
            ],
          ],
        ),
      ),
    );
  }

  Widget _statsGrid() {
    final items = [
      ('المستخدمون', stats['users'] ?? 0, Icons.people_alt_outlined),
      ('الفيديوهات', stats['posts'] ?? 0, Icons.video_library_outlined),
      ('بلاغات مفتوحة', stats['reports_open'] ?? 0, Icons.flag_outlined),
      ('مراجعة', stats['reports_reviewing'] ?? 0, Icons.manage_search_rounded),
      ('البث الآن', stats['live_now'] ?? 0, Icons.podcasts_rounded),
      ('كل البلاغات', stats['reports_total'] ?? 0, Icons.assessment_outlined),
    ];
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: items.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, crossAxisSpacing: 10, mainAxisSpacing: 10, childAspectRatio: 1.55),
      itemBuilder: (_, i) {
        final item = items[i];
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: NColors.surface, borderRadius: BorderRadius.circular(18), border: Border.all(color: NColors.divider)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(item.$3, color: NColors.cyan),
            const SizedBox(height: 8),
            Text('${item.$2}', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
            Text(item.$1, style: const TextStyle(color: NColors.muted, fontSize: 12)),
          ]),
        );
      },
    );
  }

  Widget _reportCard(Map<String, dynamic> report) {
    final status = report['status']?.toString() ?? 'open';
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: NColors.surface, borderRadius: BorderRadius.circular(18), border: Border.all(color: NColors.divider)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.flag_rounded, color: NColors.pink),
          const SizedBox(width: 8),
          Expanded(child: Text(report['reason']?.toString() ?? 'بلاغ', style: const TextStyle(fontWeight: FontWeight.w800))),
          _statusChip(status),
        ]),
        if ((report['details'] ?? '').toString().isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(report['details'].toString(), style: const TextStyle(color: NColors.muted)),
        ],
        const SizedBox(height: 8),
        Text('المستخدم المبلّغ: ${report['reporter_id'] ?? '-'}', style: const TextStyle(fontSize: 11, color: NColors.muted)),
        if (report['reported_user_id'] != null) Text('الحساب المبلّغ عنه: ${report['reported_user_id']}', style: const TextStyle(fontSize: 11, color: NColors.muted)),
        const SizedBox(height: 10),
        Wrap(spacing: 6, children: [
          _action(report['id']?.toString() ?? '', 'مراجعة', 'reviewing'),
          _action(report['id']?.toString() ?? '', 'حل', 'resolved'),
          _action(report['id']?.toString() ?? '', 'رفض', 'dismissed'),
          _action(report['id']?.toString() ?? '', 'فتح', 'open'),
        ]),
      ]),
    );
  }

  Widget _action(String id, String label, String status) => OutlinedButton(onPressed: id.isEmpty ? null : () => _status(id, status), child: Text(label));

  Widget _statusChip(String status) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
    decoration: BoxDecoration(color: NColors.card, borderRadius: BorderRadius.circular(99)),
    child: Text(status == 'resolved' ? 'محلول' : status == 'dismissed' ? 'مرفوض' : status == 'reviewing' ? 'مراجعة' : 'مفتوح', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800)),
  );

  Widget _empty() => Container(padding: const EdgeInsets.all(28), decoration: BoxDecoration(color: NColors.surface, borderRadius: BorderRadius.circular(18)), child: const Center(child: Text('لا توجد بلاغات حاليًا', style: TextStyle(color: NColors.muted))));
}
