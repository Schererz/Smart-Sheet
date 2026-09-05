import 'package:flutter/material.dart';

import '../models/aposta.dart';
import '../models/casa.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import '../widgets/dialogo_telegram.dart';
import '../widgets/resumo_header.dart';
import 'importar_planilha_screen.dart';
import 'login_screen.dart';
import 'movimentacoes_screen.dart';
import 'modo_mensal_screen.dart';

class DashboardScreen extends StatelessWidget {
  final ResumoStats resumo;
  final List<PontoEvolucaoBanca> evolucao;
  final List<Aposta> apostas;
  final List<PontoLucroDia> lucroPorDia;
  final List<ResumoPorCasa> resumoPorCasa;
  final VoidCallback onEditarBanca;
  final Future<void> Function() onRefresh;

  const DashboardScreen({
    super.key,
    required this.resumo,
    required this.evolucao,
    required this.apostas,
    required this.lucroPorDia,
    required this.resumoPorCasa,
    required this.onEditarBanca,
    required this.onRefresh,
  });

  Future<void> _sair(BuildContext context) async {
    final confirmou = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.superficieAlta,
        title: const Text('Sair da conta?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Sair')),
        ],
      ),
    );
    if (confirmou != true) return;

    await AuthService().logout();
    if (context.mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (_) => false,
      );
    }
  }

  Future<void> _apagarTudo(BuildContext context) async {
    final controlador = TextEditingController();
    final confirmou = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.superficieAlta,
        title: const Text('Apagar TODAS as apostas?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Isso não pode ser desfeito. Casas e a configuração de banca continuam, só as apostas somem.\n\nPra confirmar, digite APAGAR TUDO abaixo:',
              style: TextStyle(fontSize: 13, color: AppColors.textoSecundario),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controlador,
              autofocus: true,
              decoration: const InputDecoration(hintText: 'APAGAR TUDO'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          TextButton(
            onPressed: () => Navigator.pop(context, controlador.text.trim() == 'APAGAR TUDO'),
            child: const Text('Apagar tudo', style: TextStyle(color: AppColors.red)),
          ),
        ],
      ),
    );

    if (confirmou != true) {
      if (context.mounted && controlador.text.trim().isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Texto não bateu com "APAGAR TUDO" — nada foi apagado.')),
        );
      }
      return;
    }

    try {
      final quantidade = await ApiService().deletarTodasApostas();
      await onRefresh();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$quantidade apostas apagadas.')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Não consegui apagar: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        backgroundColor: AppColors.fundo,
        actions: [
          IconButton(
            tooltip: 'Importar planilha',
            icon: const Icon(Icons.upload_file_outlined),
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ImportarPlanilhaScreen()),
              );
              onRefresh();
            },
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.account_circle_outlined),
            onSelected: (valor) {
              if (valor == 'sair') _sair(context);
              if (valor == 'apagar_tudo') _apagarTudo(context);
              if (valor == 'telegram') abrirDialogoTelegram(context);
              if (valor == 'movimentacoes') {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const MovimentacoesScreen())).then((_) => onRefresh());
                }
              if (valor == 'modo_mensal') {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const ModoMensalScreen())).then((_) => onRefresh());
              }
            },
            itemBuilder: (_) => [
              PopupMenuItem(
                enabled: false,
                child: Text(
                  SessaoAtual.nomeUsuario ?? '',
                  style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.textoSecundario),
                ),
              ),
              const PopupMenuItem(value: 'telegram', child: Text('Conectar Telegram')),
              const PopupMenuItem(value: 'movimentacoes', child: Text('Saques e depósitos')),
              const PopupMenuItem(value: 'modo_mensal', child: Text('Modo mensal')),
              const PopupMenuItem(
                value: 'apagar_tudo',
                child: Text('Apagar todas as apostas', style: TextStyle(color: AppColors.red)),
              ),
              const PopupMenuItem(value: 'sair', child: Text('Sair da conta')),
            ],
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: onRefresh,
        child: ListView(
          padding: const EdgeInsets.only(bottom: 100),
          children: [
            ResumoHeader(
              resumo: resumo,
              evolucao: evolucao,
              apostas: apostas,
              lucroPorDia: lucroPorDia,
              resumoPorCasa: resumoPorCasa,
              onEditarBanca: onEditarBanca,
            ),
          ],
        ),
      ),
    );
  }
}
