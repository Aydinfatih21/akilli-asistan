import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api/api_client.dart';
import '../api/asistan_api.dart';
import '../api/models.dart';
import '../state/settings_state.dart';
import '../widgets/simple_markdown.dart';
import '../widgets/state_views.dart';

/// Sohbet ekranı. [conversationId] verilirse geçmiş yüklenir; verilmezse ilk mesajla yeni sohbet açılır.
/// [courseId] verilirse asistan o dersin notlarını bağlam olarak kullanır.
class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key, this.conversationId, this.title, this.courseId, this.courseName});

  final String? conversationId;
  final String? title;
  final String? courseId;
  final String? courseName;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _input = TextEditingController();
  final List<ChatMessage> _messages = [];
  String? _conversationId;
  bool _loadingHistory = false;
  bool _sending = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _conversationId = widget.conversationId;
    if (_conversationId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _loadHistory());
    }
  }

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  Future<void> _loadHistory() async {
    final api = context.read<AsistanApi>();
    setState(() {
      _loadingHistory = true;
      _error = null;
    });
    try {
      final msgs = await api.history(_conversationId!);
      if (mounted) {
        setState(() => _messages
          ..clear()
          ..addAll(msgs));
      }
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loadingHistory = false);
    }
  }

  Future<void> _send([String? preset]) async {
    final text = (preset ?? _input.text).trim();
    if (text.isEmpty || _sending) return;
    final api = context.read<AsistanApi>();
    final model = context.read<SettingsState>().model;
    final pending = ChatMessage(id: 'yerel', role: 'user', content: text, createdAt: DateTime.now());
    _input.clear();
    setState(() {
      _messages.add(pending);
      _sending = true;
      _error = null;
    });
    try {
      final r = await api.sendMessage(
        text,
        conversationId: _conversationId,
        courseId: _conversationId == null ? widget.courseId : null,
        model: model,
      );
      if (!mounted) return;
      setState(() {
        _conversationId = r.conversationId;
        _messages.add(r.reply);
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      // Başarısız istekte sunucu mesajı kaydetmez: mesajı geri al, metni kutuya geri koy
      setState(() {
        _messages.remove(pending);
        _input.text = text;
        _error = e.message;
      });
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final model = context.watch<SettingsState>().model;
    final title = widget.title ?? widget.courseName ?? 'Yapay zekâ asistanı';

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 18)),
            Text(
              [if (widget.courseName != null) 'Ders notlarıyla', model ?? 'varsayılan model'].join(' · '),
              style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(child: _buildMessages()),
          if (_error != null) Padding(padding: const EdgeInsets.fromLTRB(12, 0, 12, 8), child: ErrorBanner(_error!)),
          _buildInput(),
        ],
      ),
    );
  }

  Widget _buildMessages() {
    if (_loadingHistory) return const LoadingView(message: 'Sohbet yükleniyor…');
    if (_messages.isEmpty) return _buildEmpty();
    final items = _messages.reversed.toList();
    return ListView.builder(
      reverse: true, // en yeni mesaj altta, klavye açılınca otomatik görünür
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      itemCount: items.length + (_sending ? 1 : 0),
      itemBuilder: (context, i) {
        if (_sending && i == 0) return const _TypingBubble();
        final m = items[_sending ? i - 1 : i];
        return _Bubble(message: m);
      },
    );
  }

  Widget _buildEmpty() {
    final cs = Theme.of(context).colorScheme;
    final suggestions = widget.courseId != null
        ? const ['Notlarımdaki ana konular neler?', 'En önemli kavramı bir örnekle açıklar mısın?', 'Bana bu dersten 3 kısa soru sor.']
        : const ['Flutter nedir?', 'Etkili ders çalışma yöntemleri nelerdir?', 'Pomodoro tekniğini anlatır mısın?'];
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const SizedBox(height: 24),
        Icon(Icons.auto_awesome_rounded, size: 56, color: cs.primary),
        const SizedBox(height: 12),
        Text('Ne öğrenmek istersin?', textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 6),
        Text(
          widget.courseId != null
              ? 'Asistan, "${widget.courseName}" dersindeki notlarına dayanarak yanıt verir.'
              : 'Ders konularıyla ilgili istediğin soruyu sorabilirsin.',
          textAlign: TextAlign.center,
          style: TextStyle(color: cs.onSurfaceVariant),
        ),
        const SizedBox(height: 20),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 8,
          runSpacing: 8,
          children: [for (final s in suggestions) ActionChip(label: Text(s), onPressed: () => _send(s))],
        ),
      ],
    );
  }

  Widget _buildInput() {
    final cs = Theme.of(context).colorScheme;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 4, 8, 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: TextField(
                controller: _input,
                minLines: 1,
                maxLines: 5,
                maxLength: 4000,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(hintText: 'Sorunu yaz…', counterText: ''),
              ),
            ),
            const SizedBox(width: 6),
            IconButton.filled(
              tooltip: 'Gönder',
              onPressed: _sending ? null : () => _send(),
              icon: _sending
                  ? SizedBox(
                      width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: cs.onPrimary))
                  : const Icon(Icons.send_rounded),
            ),
          ],
        ),
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.message});

  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final user = message.isUser;
    final maxWidth = MediaQuery.of(context).size.width * 0.82;
    return Align(
      alignment: user ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(maxWidth: maxWidth),
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: user ? cs.primary : cs.surfaceContainerHigh,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: Radius.circular(user ? 18 : 4),
            bottomRight: Radius.circular(user ? 4 : 18),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (user)
              Text(message.content, style: TextStyle(color: cs.onPrimary, fontSize: 16, height: 1.35))
            else
              SimpleMarkdown(message.content, color: cs.onSurface),
            if (!user && message.model != null) ...[
              const SizedBox(height: 6),
              Text(message.model!, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: cs.onSurfaceVariant)),
            ],
          ],
        ),
      ),
    );
  }
}

class _TypingBubble extends StatelessWidget {
  const _TypingBubble();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(color: cs.surfaceContainerHigh, borderRadius: BorderRadius.circular(18)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
            const SizedBox(width: 10),
            Text('Asistan yazıyor…', style: TextStyle(color: cs.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }
}
