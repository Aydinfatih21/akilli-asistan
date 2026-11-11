import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../api/api_client.dart';
import '../api/asistan_api.dart';
import '../api/models.dart';
import '../widgets/state_views.dart';

/// Not ekleme: metni yapıştır veya TXT / PDF dosyası seç.
class AddNoteScreen extends StatefulWidget {
  const AddNoteScreen({super.key, required this.course});

  final Course course;

  @override
  State<AddNoteScreen> createState() => _AddNoteScreenState();
}

class _AddNoteScreenState extends State<AddNoteScreen> {
  static const int maxLength = 15000;

  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _content = _LimitController(maxLength);
  String _source = 'text';
  String? _fileName;
  bool _saving = false;
  bool _extracting = false; // PDF metni sunucuda çıkarılıyor
  String? _error;

  @override
  void dispose() {
    _title.dispose();
    _content.dispose();
    super.dispose();
  }

  /// PDF'ler için üst sınır (n8n'in istek boyutu sınırının altında kalır).
  static const int maxPdfBytes = 10 * 1024 * 1024;

  Future<void> _pickFile() async {
    setState(() => _error = null);
    try {
      // file_picker 13.x API'si: tek dosya için statik pickFile, içerik için readAsBytes
      final file = await FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: const ['txt', 'pdf'],
      );
      if (file == null) return; // kullanıcı vazgeçti
      final bytes = await file.readAsBytes();
      if (!mounted) return;
      final isPdf = file.name.toLowerCase().endsWith('.pdf');

      var text = '';
      String? warning;
      if (isPdf) {
        if (bytes.length > maxPdfBytes) {
          setState(() => _error = 'PDF en fazla 10 MB olabilir (seçilen: ${(bytes.length / 1048576).toStringAsFixed(1)} MB).');
          return;
        }
        setState(() => _extracting = true);
        try {
          final pdf = await context.read<AsistanApi>().extractPdf(bytes, file.name);
          text = pdf.text;
        } on ApiException catch (e) {
          if (mounted) setState(() => _error = e.message);
          return;
        } finally {
          if (mounted) setState(() => _extracting = false);
        }
        if (!mounted) return;
      } else {
        text = utf8.decode(bytes, allowMalformed: true).replaceAll('\r\n', '\n').trim();
        if (text.contains('\uFFFD')) {
          warning = 'Dosyadaki bazı karakterler okunamadı. Dosyayı UTF-8 olarak kaydedip tekrar deneyin.';
        }
      }
      if (text.length > maxLength) {
        warning = 'Dosya ${text.length} karakter; $maxLength karakteri aşan kısım kırmızı gösteriliyor. '
            'Kaydetmeden önce kısalt veya "Fazlasını kırp" düğmesini kullan.';
      }
      setState(() {
        _content.text = text;
        _source = isPdf ? 'pdf' : 'txt';
        _fileName = file.name;
        if (_title.text.trim().isEmpty) {
          _title.text = file.name.replaceAll(RegExp(r'\.(txt|pdf)$', caseSensitive: false), '');
        }
        _error = warning;
      });
    } catch (e) {
      if (mounted) setState(() => _error = 'Dosya seçilemedi: $e');
    }
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    final api = context.read<AsistanApi>();
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final title = _title.text.trim();
      final id = await api.createNote(
        courseId: widget.course.id,
        title: title,
        content: _content.text.trim(),
        source: _source,
      );
      if (!mounted) return;
      Navigator.pop(
        context,
        NoteItem(id: id, title: title, preview: _content.text.trim(), source: _source, createdAt: DateTime.now()),
      );
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    _content.overColor = cs.error;
    return Scaffold(
      appBar: AppBar(title: const Text('Not ekle')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text('Ders: ${widget.course.name}', style: TextStyle(color: cs.onSurfaceVariant)),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _saving || _extracting ? null : _pickFile,
                icon: _extracting
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.upload_file_rounded),
                label: Text(_extracting
                    ? 'PDF okunuyor…'
                    : (_fileName == null ? 'TXT veya PDF dosyası seç' : 'Seçilen: $_fileName')),
                style: OutlinedButton.styleFrom(padding: const EdgeInsets.all(16)),
              ),
              const SizedBox(height: 8),
              Center(child: Text('veya metni aşağıya yapıştır', style: TextStyle(color: cs.onSurfaceVariant))),
              const SizedBox(height: 12),
              TextFormField(
                controller: _title,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(labelText: 'Başlık', hintText: 'ör. Flutter Giriş'),
                validator: (v) {
                  final s = (v ?? '').trim();
                  if (s.isEmpty) return 'Bir başlık girin.';
                  if (s.length > 200) return 'En fazla 200 karakter olabilir.';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _content,
                minLines: 10,
                maxLines: 18,
                maxLength: maxLength,
                // Yazmayı engelleme; sınırı aşan kısım kırmızı gösterilir, kayıt doğrulamada durdurulur
                maxLengthEnforcement: MaxLengthEnforcement.none,
                onChanged: (_) => setState(() {}),
                keyboardType: TextInputType.multiline,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Not metni',
                  alignLabelWithHint: true,
                  hintText: 'Ders notunu buraya yapıştır…',
                ),
                validator: (v) {
                  final s = (v ?? '').trim();
                  if (s.length < 20) return 'Not en az 20 karakter olmalıdır.';
                  if (s.length > maxLength) return 'Not en fazla $maxLength karakter olabilir.';
                  return null;
                },
              ),
              if (_content.text.length > maxLength)
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: () => setState(() {
                      _content.text = _content.text.substring(0, maxLength);
                      _content.selection = TextSelection.collapsed(offset: maxLength);
                    }),
                    icon: const Icon(Icons.content_cut_rounded, size: 18),
                    label: Text('Fazlasını kırp (${_content.text.length - maxLength} karakter)'),
                  ),
                ),
              if (_error != null) ...[const SizedBox(height: 4), ErrorBanner(_error!)],
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _saving || _extracting ? null : _save,
                icon: _saving
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.save_rounded),
                label: const Text('Kaydet'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Sınırı aşan metni kırmızı (arka planı hafif renkli) gösteren metin denetleyicisi.
class _LimitController extends TextEditingController {
  _LimitController(this.limit);

  final int limit;
  Color overColor = Colors.red;

  @override
  TextSpan buildTextSpan({required BuildContext context, TextStyle? style, required bool withComposing}) {
    // Sınır aşılmadıysa veya klavye kelime oluşturuyorsa (IME) varsayılan görünüm
    if (text.length <= limit || (withComposing && value.isComposingRangeValid)) {
      return super.buildTextSpan(context: context, style: style, withComposing: withComposing);
    }
    return TextSpan(style: style, children: [
      TextSpan(text: text.substring(0, limit)),
      TextSpan(
        text: text.substring(limit),
        style: TextStyle(color: overColor, backgroundColor: overColor.withAlpha(36)),
      ),
    ]);
  }
}
