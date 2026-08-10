import 'package:flutter/material.dart';

import '../models/aposta.dart';
import '../models/casa.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import '../widgets/resumo_header.dart';
import 'importar_planilha_screen.dart';
import 'login_screen.dart';

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
            },
            itemBuilder: (_) => [
              PopupMenuItem(
                enabled: false,
                child: Text(
                  SessaoAtual.nomeUsuario ?? '',
                  style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.textoSecundario),
                ),
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
