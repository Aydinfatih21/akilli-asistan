import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api/api_client.dart';
import '../state/auth_state.dart';
import '../widgets/state_views.dart';

/// Giriş ve kayıt (aynı ekran, iki mod).
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();

  bool _register = false;
  bool _loading = false;
  bool _obscure = true;
  String? _error;

  static final _emailRe = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    final auth = context.read<AuthState>();
    try {
      if (_register) {
        await auth.register(_name.text.trim(), _email.text.trim(), _password.text);
      } else {
        await auth.login(_email.text.trim(), _password.text);
      }
      // Başarılı: kök widget ana sayfaya geçer
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _toggleMode() {
    setState(() {
      _register = !_register;
      _error = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Image.asset(
                        'assets/icon/app_icon.png',
                        width: 92,
                        height: 92,
                        // pubspec'e asset eklenmemişse eski ikon gösterilir
                        errorBuilder: (_, _, _) => Container(
                          width: 84,
                          height: 84,
                          decoration: BoxDecoration(color: cs.primaryContainer, borderRadius: BorderRadius.circular(24)),
                          child: Icon(Icons.school_rounded, size: 46, color: cs.onPrimaryContainer),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text('Akıllı Ders Asistanı',
                        textAlign: TextAlign.center, style: tt.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 6),
                    Text(
                      _register ? 'Yeni hesap oluştur' : 'Notlarını özetle, kendini test et',
                      textAlign: TextAlign.center,
                      style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                    ),
                    const SizedBox(height: 32),
                    if (_register) ...[
                      TextFormField(
                        controller: _name,
                        textCapitalization: TextCapitalization.words,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(labelText: 'Ad Soyad', prefixIcon: Icon(Icons.person_outline)),
                        validator: (v) {
                          final s = (v ?? '').trim();
                          if (s.isEmpty) return 'Adınızı girin.';
                          if (s.length > 100) return 'En fazla 100 karakter olabilir.';
                          return null;
                        },
                      ),
                      const SizedBox(height: 14),
                    ],
                    TextFormField(
                      controller: _email,
                      keyboardType: TextInputType.emailAddress,
                      autocorrect: false,
                      textInputAction: TextInputAction.next,
                      autofillHints: const [AutofillHints.email],
                      decoration: const InputDecoration(labelText: 'E-posta', prefixIcon: Icon(Icons.alternate_email)),
                      validator: (v) {
                        final s = (v ?? '').trim();
                        if (s.isEmpty) return 'E-posta adresinizi girin.';
                        if (!_emailRe.hasMatch(s)) return 'Geçerli bir e-posta adresi girin.';
                        return null;
                      },
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _password,
                      obscureText: _obscure,
                      textInputAction: TextInputAction.done,
                      autofillHints: const [AutofillHints.password],
                      onFieldSubmitted: (_) => _loading ? null : _submit(),
                      decoration: InputDecoration(
                        labelText: 'Şifre',
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          tooltip: _obscure ? 'Şifreyi göster' : 'Şifreyi gizle',
                          icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                          onPressed: () => setState(() => _obscure = !_obscure),
                        ),
                      ),
                      validator: (v) {
                        final s = v ?? '';
                        if (s.isEmpty) return 'Şifrenizi girin.';
                        if (_register && s.length < 6) return 'Şifre en az 6 karakter olmalıdır.';
                        if (s.length > 72) return 'Şifre en fazla 72 karakter olabilir.';
                        return null;
                      },
                    ),
                    if (_error != null) ...[const SizedBox(height: 16), ErrorBanner(_error!)],
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: _loading ? null : _submit,
                      child: _loading
                          ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5))
                          : Text(_register ? 'Kayıt ol' : 'Giriş yap'),
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: _loading ? null : _toggleMode,
                      child: Text(_register ? 'Zaten hesabın var mı? Giriş yap' : 'Hesabın yok mu? Kayıt ol'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
