import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api/api_client.dart';
import '../api/asistan_api.dart';
import '../api/models.dart';
import '../utils/format.dart';
import '../widgets/course_actions.dart';
import '../widgets/note_actions.dart';
import '../widgets/state_views.dart';
import 'add_note_screen.dart';
import 'chat_screen.dart';
import 'note_screen.dart';

/// Ders ekranı: notlar, derse soru sorma, dersin sohbetleri.
class CourseScreen extends StatefulWidget {
  const CourseScreen({super.key, required this.course});

  final Course course;

  @override
  State<CourseScreen> createState() => _CourseScreenState();
}

class _CourseScreenState extends State<CourseScreen> {
  late Course _course = widget.course; // ad değişirse güncellenir
  List<NoteItem>? _notes;
  List<Conversation> _conversations = const [];
  String? _error;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final api = context.read<AsistanApi>();
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final notes = await api.notes(widget.course.id);
      final convs = await api.conversations(courseId: widget.course.id);
      if (mounted) {
        setState(() {
          _notes = notes;
          _conversations = convs;
        });
      }
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _onMenu(String action) async {
    final c = Course(
      id: _course.id,
      name: _course.name,
      noteCount: _notes?.length ?? _course.noteCount,
      attemptCount: _course.attemptCount,
    );
    if (action == 'rename') {
      final updated = await showRenameCourseDialog(context, c);
      if (updated != null && mounted) setState(() => _course = updated);
    } else if (action == 'delete') {
      if (await confirmAndDeleteCourse(context, c) && mounted) Navigator.pop(context);
    }
  }

  Future<void> _addNote() async {
    final created = await Navigator.push<NoteItem>(
      context,
      MaterialPageRoute(builder: (_) => AddNoteScreen(course: _course)),
    );
    if (created == null || !mounted) return;
    _load();
    // Demo akışı: yeni notun ekranına geç (özet → test)
    await _openNote(created);
  }

  Future<void> _openNote(NoteItem note) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => NoteScreen(course: _course, note: note)),
    );
    if (mounted) _load();
  }

  Future<void> _openChat({Conversation? conversation}) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatScreen(
          conversationId: conversation?.id,
          title: conversation?.title,
          courseId: widget.course.id,
          courseName: _course.name,
        ),
      ),
    );
    if (mounted) _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_course.name, maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(tooltip: 'Yenile', onPressed: _loading ? null : _load, icon: const Icon(Icons.refresh_rounded)),
          PopupMenuButton<String>(
            tooltip: 'Ders işlemleri',
            onSelected: _onMenu,
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'rename', child: ListTile(leading: Icon(Icons.edit_outlined), title: Text('Adını değiştir'))),
              PopupMenuItem(value: 'delete', child: ListTile(leading: Icon(Icons.delete_outline), title: Text('Dersi sil'))),
            ],
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addNote,
        icon: const Icon(Icons.note_add_rounded),
        label: const Text('Not ekle'),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    final notes = _notes;
    if (notes == null) {
      if (_error != null) return ErrorView(message: _error!, onRetry: _load);
      return const LoadingView(message: 'Notlar yükleniyor…');
    }
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
        children: [
          Card(
            elevation: 0,
            color: cs.secondaryContainer,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              leading: Icon(Icons.auto_awesome_rounded, color: cs.onSecondaryContainer),
              title: Text('Bu derse soru sor',
                  style: tt.titleMedium?.copyWith(color: cs.onSecondaryContainer, fontWeight: FontWeight.w600)),
              subtitle: Text('Asistan, yanıtlarken bu dersin notlarını kullanır.',
                  style: TextStyle(color: cs.onSecondaryContainer)),
              trailing: Icon(Icons.chevron_right_rounded, color: cs.onSecondaryContainer),
              onTap: () => _openChat(),
            ),
          ),
          if (_error != null) ...[const SizedBox(height: 12), ErrorBanner(_error!)],
          const SizedBox(height: 20),
          Text('Notlar (${notes.length})', style: tt.titleMedium),
          const SizedBox(height: 8),
          if (notes.isEmpty)
            EmptyView(
              icon: Icons.description_outlined,
              title: 'Bu derste henüz not yok',
              subtitle: 'Not metnini yapıştır veya bir TXT ya da PDF dosyası seç; ardından özet alıp test oluşturabilirsin.',
              action: FilledButton.icon(
                onPressed: _addNote,
                icon: const Icon(Icons.note_add_rounded),
                label: const Text('Not ekle'),
              ),
            )
          else ...[
            for (final n in notes)
              _NoteCard(
                note: n,
                onTap: () => _openNote(n),
                onLongPress: () async {
                  if (await confirmAndDeleteNote(context, n) && mounted) _load();
                },
              ),
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text('İpucu: Notu silmek için karta basılı tut.',
                  textAlign: TextAlign.center, style: tt.labelSmall?.copyWith(color: cs.onSurfaceVariant)),
            ),
          ],
          if (_conversations.isNotEmpty) ...[
            const SizedBox(height: 20),
            Text('Bu dersteki sohbetler', style: tt.titleMedium),
            const SizedBox(height: 8),
            for (final c in _conversations)
              Card(
                elevation: 0,
                color: cs.surfaceContainerLow,
                margin: const EdgeInsets.only(bottom: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                child: ListTile(
                  leading: const Icon(Icons.chat_bubble_outline_rounded),
                  title: Text(c.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                  subtitle: Text(c.lastMessage ?? '', maxLines: 1, overflow: TextOverflow.ellipsis),
                  trailing: Text(relativeTime(c.updatedAt), style: tt.labelSmall),
                  onTap: () => _openChat(conversation: c),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _NoteCard extends StatelessWidget {
  const _NoteCard({required this.note, required this.onTap, this.onLongPress});

  final NoteItem note;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Card(
      elevation: 0,
      color: cs.surfaceContainerLow,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(note.source == 'pdf' ? Icons.picture_as_pdf_outlined : note.source == 'txt' ? Icons.text_snippet_outlined : Icons.description_outlined,
                      size: 20, color: cs.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(note.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: tt.titleMedium),
                  ),
                  if (note.hasSummary)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(color: cs.tertiaryContainer, borderRadius: BorderRadius.circular(10)),
                      child: Text('Özet hazır', style: tt.labelSmall?.copyWith(color: cs.onTertiaryContainer)),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              Text(note.preview, maxLines: 2, overflow: TextOverflow.ellipsis,
                  style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant)),
              const SizedBox(height: 6),
              Text(relativeTime(note.createdAt), style: tt.labelSmall?.copyWith(color: cs.onSurfaceVariant)),
            ],
          ),
        ),
      ),
    );
  }
}
