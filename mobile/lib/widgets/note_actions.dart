import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api/api_client.dart';
import '../api/asistan_api.dart';
import '../api/models.dart';

/// Onay alıp notu siler (ders kalır). Silindiyse true döner.
Future<bool> confirmAndDeleteNote(BuildContext context, NoteItem note) async {
  final cs = Theme.of(context).colorScheme;
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      icon: Icon(Icons.delete_outline_rounded, color: cs.error),
      title: const Text('Notu sil'),
      content: Text(
        '"${note.title}" notu, özeti ve bu nottan oluşturulan testler ile sonuçları kalıcı olarak silinecek. '
        'Ders ve diğer notlar etkilenmez. Bu işlem geri alınamaz.',
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
    final quizzes = await api.deleteNote(note.id);
    messenger.showSnackBar(SnackBar(
      content: Text(quizzes > 0 ? '"${note.title}" notu ve $quizzes testi silindi.' : '"${note.title}" notu silindi.'),
    ));
    return true;
  } on ApiException catch (e) {
    messenger.showSnackBar(SnackBar(content: Text(e.message)));
    return false;
  }
}
