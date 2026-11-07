import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api/api_client.dart';
import '../api/asistan_api.dart';
import '../api/models.dart';
import '../widgets/state_views.dart';

/// Not ekleme: metni yapıştır veya TXT dosyası seç.
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
  final _content = TextEditingController();
  String _source = 'text';
  String? _fileName;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _title.dispose();
    _content.dispose();
    super.dispose();
  }

  Future<void> _pickTxt() async {
    setState(() => _error = null);
    try {
      // file_picker 13.x API'si: tek dosya için statik pickFile, içerik için readAsBytes
      final file = await FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: const ['txt'],
      );
      if (file == null) return; // kullanıcı vazgeçti
      final bytes = await file.readAsBytes();
      if (!mounted) return;
      var text = utf8.decode(bytes, allowMalformed: true).replaceAll('\r\n', '\n').trim();
      var warning = text.contains('�')
          ? 'Dosyadaki bazı karakterler okunamadı. Dosyayı UTF-8 olarak kaydedip tekrar deneyin.'
          : null;
      if (text.length > maxLength) {
        text = text.substring(0, maxLength);
        warning = 'Dosya $maxLength karakterden uzun olduğu için kısaltıldı.';
      }
      setState(() {
        _content.text = text;
        _source = 'txt';
        _fileName = file.name;
        if (_title.text.trim().isEmpty) {
          _title.text = file.name.replaceAll(RegExp(r'\.txt$', caseSensitive: false), '');
        }
        _error = warning;
      });
    } catch (e) {
      setState(() => _error = 'Dosya seçilemedi: $e');
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
                onPressed: _saving ? null : _pickTxt,
                icon: const Icon(Icons.upload_file_rounded),
                label: Text(_fileName == null ? 'TXT dosyası seç' : 'Seçilen: $_fileName'),
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
              if (_error != null) ...[const SizedBox(height: 4), ErrorBanner(_error!)],
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _saving ? null : _save,
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
