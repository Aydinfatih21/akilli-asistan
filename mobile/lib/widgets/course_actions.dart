import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api/api_client.dart';
import '../api/asistan_api.dart';
import '../api/models.dart';
import 'state_views.dart';

/// Ders için işlem menüsü (adını değiştir / sil). Bir değişiklik olursa true döner.
Future<bool> showCourseActions(BuildContext context, Course course) async {
  final action = await showModalBottomSheet<String>(
    context: context,
    showDragHandle: true,
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
            child: Text(course.name, style: Theme.of(ctx).textTheme.titleMedium, maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
          ListTile(
            leading: const Icon(Icons.edit_outlined),
            title: const Text('Adını değiştir'),
            onTap: () => Navigator.pop(ctx, 'rename'),
          ),
          ListTile(
            leading: Icon(Icons.delete_outline, color: Theme.of(ctx).colorScheme.error),
            title: Text('Dersi sil', style: TextStyle(color: Theme.of(ctx).colorScheme.error)),
            onTap: () => Navigator.pop(ctx, 'delete'),
          ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
  if (!context.mounted) return false;
  if (action == 'rename') return (await showRenameCourseDialog(context, course)) != null;
  if (action == 'delete') return confirmAndDeleteCourse(context, course);
  return false;
}

Future<Course?> showRenameCourseDialog(BuildContext context, Course course) =>
    showDialog<Course>(context: context, builder: (_) => _RenameCourseDialog(course: course));

/// Onay alıp dersi siler. Silindiyse true döner.
Future<bool> confirmAndDeleteCourse(BuildContext context, Course course) async {
  final cs = Theme.of(context).colorScheme;
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      icon: Icon(Icons.warning_amber_rounded, color: cs.error),
      title: const Text('Dersi sil'),
      content: Text(
        '"${course.name}" dersi; ${course.noteCount} not, ${course.attemptCount} test sonucu ve bu derse ait '
        'sohbetlerle birlikte kalıcı olarak silinecek. Bu işlem geri alınamaz.',
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Vazgeç')),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: cs.error, foregroundColor: cs.onError),
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Sil'),
        ),
      ],
    ),
  );
  if (ok != true || !context.mounted) return false;
  final api = context.read<AsistanApi>();
  final messenger = ScaffoldMessenger.of(context);
  try {
    await api.deleteCourse(course.id);
    messenger.showSnackBar(SnackBar(content: Text('"${course.name}" dersi silindi.')));
    return true;
  } on ApiException catch (e) {
    messenger.showSnackBar(SnackBar(content: Text(e.message)));
    return false;
  }
}

class _RenameCourseDialog extends StatefulWidget {
  const _RenameCourseDialog({required this.course});

  final Course course;

  @override
  State<_RenameCourseDialog> createState() => _RenameCourseDialogState();
}

class _RenameCourseDialogState extends State<_RenameCourseDialog> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.course.name);
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final api = context.read<AsistanApi>();
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final c = await api.renameCourse(widget.course.id, _name.text.trim());
      if (mounted) Navigator.pop(context, c);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Ders adını değiştir'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _name,
              autofocus: true,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(labelText: 'Ders adı'),
              onFieldSubmitted: (_) => _saving ? null : _save(),
              validator: (v) {
                final s = (v ?? '').trim();
                if (s.isEmpty) return 'Ders adını girin.';
                if (s.length > 100) return 'En fazla 100 karakter olabilir.';
                return null;
              },
            ),
            if (_error != null) ...[const SizedBox(height: 12), ErrorBanner(_error!)],
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: _saving ? null : () => Navigator.pop(context), child: const Text('Vazgeç')),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Kaydet'),
        ),
      ],
    );
  }
}
