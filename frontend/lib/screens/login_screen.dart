import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import 'home_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _auth = AuthService();
  final _formKey = GlobalKey<FormState>();
  final _nomeUsuario = TextEditingController();
  final _senha = TextEditingController();

  bool _modoCadastro = false;
  bool _carregando = false;
  String? _erro;

  @override
  void dispose() {
    _nomeUsuario.dispose();
    _senha.dispose();
    super.dispose();
  }

  Future<void> _enviar() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _carregando = true;
      _erro = null;
    });

    try {
      if (_modoCadastro) {
        await _auth.registrar(_nomeUsuario.text.trim(), _senha.text);
      } else {
        await _auth.login(_nomeUsuario.text.trim(), _senha.text);
      }
      if (mounted) {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const HomeScreen()));
      }
    } catch (e) {
      setState(() => _erro = '$e');
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 380),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Icon(Icons.bar_chart_rounded, size: 56, color: AppColors.destaque),
                    const SizedBox(height: 16),
                    Text(
                      _modoCadastro ? 'Criar conta' : 'Entrar',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _modoCadastro
                          ? 'Sua planilha de apostas, salva na nuvem'
                          : 'Entra com sua conta pra ver suas apostas',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: AppColors.textoSecundario, fontSize: 13.5),
                    ),
                    const SizedBox(height: 32),
                    TextFormField(
                      controller: _nomeUsuario,
                      decoration: const InputDecoration(hintText: 'Nome de usuário'),
                      validator: (v) => (v == null || v.trim().length < 3) ? 'Pelo menos 3 caracteres' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _senha,
                      obscureText: true,
                      decoration: const InputDecoration(hintText: 'Senha'),
                      validator: (v) => (v == null || v.length < 4) ? 'Pelo menos 4 caracteres' : null,
                      onFieldSubmitted: (_) => _enviar(),
                    ),
                    if (_erro != null) ...[
                      const SizedBox(height: 14),
                      Text(_erro!, style: const TextStyle(color: AppColors.red, fontSize: 13), textAlign: TextAlign.center),
                    ],
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: _carregando ? null : _enviar,
                      child: _carregando
                          ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                          : Text(_modoCadastro ? 'Criar conta' : 'Entrar'),
                    ),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: _carregando
                          ? null
                          : () => setState(() {
                                _modoCadastro = !_modoCadastro;
                                _erro = null;
                              }),
                      child: Text(
                        _modoCadastro ? 'Já tenho conta — entrar' : 'Não tenho conta — criar uma',
                      ),
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
