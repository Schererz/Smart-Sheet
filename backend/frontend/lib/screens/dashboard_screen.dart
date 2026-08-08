import 'package:flutter/material.dart';

import '../models/aposta.dart';
import '../theme/app_theme.dart';
import '../widgets/resumo_header.dart';
import 'importar_planilha_screen.dart';

class DashboardScreen extends StatelessWidget {
  final ResumoStats resumo;
  final List<PontoEvolucaoBanca> evolucao;
  final List<Aposta> apostas;
  final VoidCallback onEditarBanca;
  final Future<void> Function() onRefresh;

  const DashboardScreen({
    super.key,
    required this.resumo,
    required this.evolucao,
    required this.apostas,
    required this.onEditarBanca,
    required this.onRefresh,
  });

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
              onEditarBanca: onEditarBanca,
            ),
          ],
        ),
      ),
    );
  }
}
