import 'package:flutter/material.dart';

/// Model yanıtlarındaki temel Markdown'ı gösterir (ek paket gerektirmez):
/// başlık (#), madde (-, *, •), numaralı liste, kod bloğu (```), **kalın**, *italik*, `kod`.
class SimpleMarkdown extends StatelessWidget {
  const SimpleMarkdown(this.text, {super.key, this.color});

  final String text;
  final Color? color;

  static final _header = RegExp(r'^(#{1,6})\s+(.*)$');
  static final _bullet = RegExp(r'^\s*[-*•]\s+(.*)$');
  static final _numbered = RegExp(r'^\s*(\d+)[.)]\s+(.*)$');
  static final _inline = RegExp(r'(\*\*[^*]+\*\*|`[^`]+`|\*[^*\s][^*]*\*)');

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final base = theme.textTheme.bodyLarge!.copyWith(color: color, height: 1.4);
    final children = <Widget>[];
    final code = <String>[];
    var inCode = false;

    void flushCode() {
      children.add(Container(
        width: double.infinity,
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(8),
        ),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Text(code.join('\n'), style: base.copyWith(fontFamily: 'monospace', fontSize: 13)),
        ),
      ));
      code.clear();
    }

    for (final raw in text.replaceAll('\r\n', '\n').split('\n')) {
      if (raw.trimLeft().startsWith('```')) {
        if (inCode) flushCode();
        inCode = !inCode;
        continue;
      }
      if (inCode) {
        code.add(raw);
        continue;
      }
      final line = raw.trimRight();
      if (line.trim().isEmpty) {
        children.add(const SizedBox(height: 6));
        continue;
      }
      final h = _header.firstMatch(line);
      if (h != null) {
        children.add(Padding(
          padding: const EdgeInsets.only(top: 4, bottom: 2),
          child: Text.rich(_spans(h.group(2)!, base.copyWith(fontWeight: FontWeight.w700, fontSize: 17))),
        ));
        continue;
      }
      final b = _bullet.firstMatch(line);
      final n = b == null ? _numbered.firstMatch(line) : null;
      if (b != null || n != null) {
        final marker = b != null ? '•' : '${n!.group(1)}.';
        final body = b != null ? b.group(1)! : n!.group(2)!;
        children.add(Padding(
          padding: const EdgeInsets.only(left: 4, top: 2, bottom: 2),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(width: 22, child: Text(marker, style: base.copyWith(fontWeight: FontWeight.w700))),
              Expanded(child: Text.rich(_spans(body, base))),
            ],
          ),
        ));
        continue;
      }
      children.add(Text.rich(_spans(line, base)));
    }
    if (inCode && code.isNotEmpty) flushCode();

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: children);
  }

  TextSpan _spans(String s, TextStyle style) {
    final spans = <InlineSpan>[];
    var last = 0;
    for (final m in _inline.allMatches(s)) {
      if (m.start > last) spans.add(TextSpan(text: s.substring(last, m.start)));
      final t = m.group(0)!;
      if (t.startsWith('**')) {
        spans.add(TextSpan(text: t.substring(2, t.length - 2), style: const TextStyle(fontWeight: FontWeight.w700)));
      } else if (t.startsWith('`')) {
        spans.add(TextSpan(text: t.substring(1, t.length - 1), style: const TextStyle(fontFamily: 'monospace')));
      } else {
        spans.add(TextSpan(text: t.substring(1, t.length - 1), style: const TextStyle(fontStyle: FontStyle.italic)));
      }
      last = m.end;
    }
    if (last < s.length) spans.add(TextSpan(text: s.substring(last)));
    return TextSpan(style: style, children: spans);
  }
}
