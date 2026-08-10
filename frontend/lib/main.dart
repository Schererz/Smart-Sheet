import 'package:flutter/material.dart';

import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'services/auth_service.dart';
import 'theme/app_theme.dart';

void main() {
  runApp(const ApostasApp());
}

class ApostasApp extends StatelessWidget {
  const ApostasApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Planilha de Apostas',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.tema,
      home: const _TelaInicial(),
    );
  }
}

/// Decide entre Login e Home checando se já existe uma sessão salva no
/// aparelho — assim o usuário não precisa logar de novo toda vez que abre.
class _TelaInicial extends StatefulWidget {
  const _TelaInicial();

  @override
  State<_TelaInicial> createState() => _TelaInicialState();
}

class _TelaInicialState extends State<_TelaInicial> {
  final _auth = AuthService();
  bool _carregando = true;
  bool _logado = false;

  @override
  void initState() {
    super.initState();
    _verificar();
  }

  Future<void> _verificar() async {
    final logado = await _auth.restaurarSessaoSalva();
    if (mounted) {
      setState(() {
        _logado = logado;
        _carregando = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_carregando) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return _logado ? const HomeScreen() : const LoginScreen();
  }
}
