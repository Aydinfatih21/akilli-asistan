import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api/api_client.dart';
import '../api/asistan_api.dart';
import '../api/models.dart';
import '../utils/format.dart';
import '../widgets/state_views.dart';
import 'chat_screen.dart';

/// Kullanıcının tüm sohbetleri (genel + derse bağlı).
class ConversationsScreen extends StatefulWidget {
  const ConversationsScreen({super.key});

  @override
  State<ConversationsScreen> createState() => _ConversationsScreenState();
}

class _ConversationsScreenState extends State<ConversationsScreen> {
  List<Conversation>? _items;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final api = context.read<AsistanApi>();
    setState(() => _error = null);
    try {
      final items = await api.conversations();
      if (mounted) setState(() => _items = items);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  Future<void> _open({Conversation? c}) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatScreen(
          conversationId: c?.id,
          title: c?.title,
          courseId: c?.courseId,
          courseName: c?.courseName,
        ),
      ),
    );
    if (mounted) _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sohbetler')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _open(),
        icon: const Icon(Icons.add_comment_rounded),
        label: const Text('Yeni sohbet'),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    final items = _items;
    if (items == null) {
      if (_error != null) return ErrorView(message: _error!, onRetry: _load);
      return const LoadingView(message: 'Sohbetler yükleniyor…');
    }
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
        children: [
          if (_error != null) ...[ErrorBanner(_error!), const SizedBox(height: 12)],
          if (items.isEmpty)
            const EmptyView(
              icon: Icons.forum_outlined,
              title: 'Henüz sohbet yok',
              subtitle: 'Yapay zekâ asistanına ilk sorunu sor; sohbetlerin burada saklanır.',
            )
          else
            for (final c in items)
              Card(
                elevation: 0,
                color: cs.surfaceContainerLow,
                margin: const EdgeInsets.only(bottom: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: c.courseId != null ? cs.secondaryContainer : cs.primaryContainer,
                    child: Icon(c.courseId != null ? Icons.menu_book_rounded : Icons.auto_awesome_rounded, size: 20),
                  ),
                  title: Text(c.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                  subtitle: Text(
                    [if (c.courseName != null) c.courseName!, c.lastMessage ?? ''].where((s) => s.isNotEmpty).join(' · '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: Text(relativeTime(c.updatedAt), style: tt.labelSmall),
                  onTap: () => _open(c: c),
                ),
              ),
        ],
      ),
    );
  }
}
