import 'package:flutter/material.dart';

import '../core/app_controller.dart';
import '../core/theme.dart';
import '../services/models.dart';
import '../widgets/ludo_art.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _email = TextEditingController();
  final _pass = TextEditingController();
  final _name = TextEditingController();
  bool _register = true;
  bool _busy = false;
  bool _showPass = false;

  @override
  void dispose() {
    _email.dispose();
    _pass.dispose();
    _name.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() body) async {
    setState(() => _busy = true);
    try {
      await body();
      await app.afterAuth();
    } on BackendException catch (e) {
      if (mounted) toast(context, e.message, error: true);
    } catch (e) {
      if (mounted) toast(context, '$e', error: true);
    }
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final local = app.backend.isLocal;
    return GxScaffold(
      body: Container(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: Column(children: [
                  const LudoLogoHero(),
                  const SizedBox(height: 26),
                  AppCard(
                    padding: const EdgeInsets.all(20),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                      Row(children: [
                        Expanded(child: _tab('Register', _register, () => setState(() => _register = true))),
                        const SizedBox(width: 8),
                        Expanded(child: _tab('Sign in', !_register, () => setState(() => _register = false))),
                      ]),
                      const SizedBox(height: 18),
                      if (_register) ...[
                        TextField(controller: _name, maxLength: 16, decoration: const InputDecoration(labelText: 'Username', counterText: '', prefixIcon: Icon(Icons.person_outline))),
                        const SizedBox(height: 12),
                      ],
                      TextField(
                        controller: _email,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(labelText: 'Email', prefixIcon: Icon(Icons.mail_outline)),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _pass,
                        obscureText: !_showPass,
                        decoration: InputDecoration(
                          labelText: 'Password',
                          prefixIcon: const Icon(Icons.lock_outline),
                          suffixIcon: IconButton(icon: Icon(_showPass ? Icons.visibility_off : Icons.visibility), onPressed: () => setState(() => _showPass = !_showPass)),
                        ),
                      ),
                      const SizedBox(height: 18),
                      GoldButton(
                        label: _register ? 'CREATE ACCOUNT' : 'SIGN IN',
                        loading: _busy,
                        onPressed: () => _run(() => _register ? app.backend.register(_email.text, _pass.text, _name.text) : app.backend.signIn(_email.text, _pass.text)),
                      ),
                      const SizedBox(height: 10),
                      GoldButton(
                        label: 'CONTINUE AS GUEST',
                        outlined: true,
                        onPressed: _busy ? null : () => _run(() => app.backend.signInGuest(_name.text.trim().length >= 3 ? _name.text : 'Guest${DateTime.now().millisecond}')),
                      ),
                    ]),
                  ),
                  const SizedBox(height: 16),
                  const SimBanner(),
                  const SizedBox(height: 10),
                  Text(
                    local ? 'Backend: local simulation (Firebase not configured)' : 'Backend: Firebase Auth + Firestore + Cloud Functions',
                    style: Gx.label(size: 11),
                    textAlign: TextAlign.center,
                  ),
                  if (local)
                    TextButton(
                      onPressed: _busy
                          ? null
                          : () async {
                              await app.backend.resetLocalData();
                              if (mounted) toast(context, 'Local data cleared');
                            },
                      child: const Text('Reset local data', style: TextStyle(color: Gx.muted, fontSize: 12)),
                    ),
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _tab(String t, bool on, VoidCallback f) => GestureDetector(
        onTap: f,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 11),
          decoration: BoxDecoration(
            color: on ? Gx.gold.withOpacity(0.22) : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: on ? Gx.gold : Gx.line),
          ),
          child: Center(child: Text(t.toUpperCase(), style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: 0.8, color: on ? Gx.goldLight : Gx.muted, fontSize: 13))),
        ),
      );
}
