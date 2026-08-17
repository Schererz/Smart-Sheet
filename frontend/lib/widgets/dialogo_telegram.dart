import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../theme/app_theme.dart';

Future<void> abrirDialogoTelegram(BuildContext context) async {
  await showDialog(
    context: context,
    builder: (_) => const _DialogoTelegram(),
  );
}

class _DialogoTelegram extends StatefulWidget {
  const _DialogoTelegram();

  @override
  State<_DialogoTelegram> createState() => _DialogoTelegramState();
}

class _DialogoTelegramState extends State<_DialogoTelegram> {
  final _api = ApiService();
  bool _carregando = true;
  bool _conectado = false;
  String? _codigo;
  String? _erro;

  @override
  void initState() {
    super.initState();
    _verificarStatus();
  }

  Future<void> _verificarStatus() async {
    setState(() => _carregando = true);
    try {
      final conectado = await _api.statusTelegram();
      setState(() {
        _conectado = conectado;
        _carregando = false;
      });
    } catch (e) {
      setState(() {
        _erro = '$e';
        _carregando = false;
      });
    }
  }

  Future<void> _gerarCodigo() async {
    setState(() {
      _carregando = true;
      _erro = null;
    });
    try {
      final resposta = await _api.gerarCodigoTelegram();
      setState(() {
        _codigo = resposta['codigo'] as String;
        _carregando = false;
      });
    } catch (e) {
      setState(() {
        _erro = '$e';
        _carregando = false;
      });
    }
  }

  Future<void> _desconectar() async {
    setState(() => _carregando = true);
    try {
      await _api.desconectarTelegram();
      setState(() {
        _conectado = false;
        _codigo = null;
        _carregando = false;
      });
    } catch (e) {
      setState(() {
        _erro = '$e';
        _carregando = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.superficieAlta,
      title: const Text('Telegram'),
      content: SizedBox(
        width: 320,
        child: _carregando
            ? const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: CircularProgressIndicator()),
              )
            : _conectado
                ? _ConteudoConectado(onDesconectar: _desconectar)
                : _ConteudoDesconectado(codigo: _codigo, erro: _erro, onGerarCodigo: _gerarCodigo),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Fechar')),
      ],
    );
  }
}

class _ConteudoConectado extends StatelessWidget {
  final VoidCallback onDesconectar;
  const _ConteudoConectado({required this.onDesconectar});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(Icons.check_circle, color: AppColors.green, size: 20),
            SizedBox(width: 8),
            Text('Conta conectada', style: TextStyle(fontWeight: FontWeight.w700)),
          ],
        ),
        const SizedBox(height: 10),
        const Text(
          'As apostas que você encaminhar pro bot já entram sozinhas, com status "Aberto".',
          style: TextStyle(color: AppColors.textoSecundario, fontSize: 13),
        ),
        const SizedBox(height: 16),
        OutlinedButton(
          onPressed: onDesconectar,
          style: OutlinedButton.styleFrom(foregroundColor: AppColors.red),
          child: const Text('Desconectar'),
        ),
      ],
    );
  }
}

class _ConteudoDesconectado extends StatelessWidget {
  final String? codigo;
  final String? erro;
  final VoidCallback onGerarCodigo;

  const _ConteudoDesconectado({required this.codigo, required this.erro, required this.onGerarCodigo});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (codigo == null) ...[
          const Text(
            'Conecte sua conta pra registrar apostas direto de um grupo do Telegram, sem abrir o app.',
            style: TextStyle(color: AppColors.textoSecundario, fontSize: 13),
          ),
          const SizedBox(height: 16),
          ElevatedButton(onPressed: onGerarCodigo, child: const Text('Gerar código')),
        ] else ...[
          const Text('Manda esse código pro bot no Telegram:', style: TextStyle(fontSize: 13, color: AppColors.textoSecundario)),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(color: AppColors.superficie, borderRadius: BorderRadius.circular(10)),
            child: Text(
              codigo!,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800, letterSpacing: 4),
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'Válido por 10 minutos. Depois de conectar, feche e abra esse diálogo de novo pra confirmar.',
            style: TextStyle(fontSize: 12, color: AppColors.textoSecundario),
          ),
        ],
        if (erro != null) ...[
          const SizedBox(height: 12),
          Text(erro!, style: const TextStyle(color: AppColors.red, fontSize: 12.5)),
        ],
      ],
    );
  }
}
