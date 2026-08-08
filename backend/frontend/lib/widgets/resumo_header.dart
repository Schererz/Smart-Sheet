import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/aposta.dart';
import '../theme/app_theme.dart';
import 'evolucao_banca_chart.dart';
import 'lucro_chart.dart';

class ResumoHeader extends StatelessWidget {
  final ResumoStats resumo;
  final List<PontoEvolucaoBanca> evolucao;
  final List<Aposta> apostas;
  final VoidCallback onEditarBanca;

  const ResumoHeader({
    super.key,
    required this.resumo,
    required this.evolucao,
    required this.apostas,
    required this.onEditarBanca,
  });

  @override
  Widget build(BuildContext context) {
    final formatoMoeda = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
    final corLucro = resumo.lucroTotal >= 0 ? AppColors.green : AppColors.red;

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
      decoration: const BoxDecoration(
        color: AppColors.superficieAlta,
        borderRadius: BorderRadius.only(bottomLeft: Radius.circular(24), bottomRight: Radius.circular(24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Banca atual', style: TextStyle(color: AppColors.textoSecundario, fontSize: 13)),
                    const SizedBox(height: 4),
                    Text(
                      formatoMoeda.format(resumo.bancaAtual),
                      style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w800, letterSpacing: -0.5),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: onEditarBanca,
                icon: const Icon(Icons.settings_outlined, size: 20),
                color: AppColors.textoSecundario,
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '${resumo.lucroTotal >= 0 ? '+' : ''}${formatoMoeda.format(resumo.lucroTotal)} desde o início',
            style: TextStyle(color: corLucro, fontSize: 13, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 14),
          EvolucaoBancaChart(pontos: evolucao),
          const SizedBox(height: 18),
          const Text('Lucro por aposta', style: TextStyle(color: AppColors.textoSecundario, fontSize: 13)),
          const SizedBox(height: 8),
          LucroBarChart(apostas: apostas),
          const SizedBox(height: 14),
          Row(
            children: [
              _Estatistica(rotulo: 'Apostas', valor: '${resumo.totalApostas}'),
              _Estatistica(rotulo: 'ROI', valor: resumo.roi != null ? '${resumo.roi!.toStringAsFixed(1)}%' : '—'),
              _Estatistica(
                rotulo: 'Acerto',
                valor: resumo.taxaAcerto != null ? '${resumo.taxaAcerto!.toStringAsFixed(0)}%' : '—',
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _Estatistica(
                rotulo: 'Odd média',
                valor: resumo.oddMedia != null ? resumo.oddMedia!.toStringAsFixed(2) : '—',
              ),
              _Estatistica(
                rotulo: 'Ticket médio',
                valor: resumo.valorMedioApostado != null
                    ? formatoMoeda.format(resumo.valorMedioApostado)
                    : '—',
              ),
              _Estatistica(rotulo: 'Em aberto', valor: '${resumo.apostasEmAberto}'),
            ],
          ),
        ],
      ),
    );
  }
}

class _Estatistica extends StatelessWidget {
  final String rotulo;
  final String valor;

  const _Estatistica({required this.rotulo, required this.valor});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(valor, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
          Text(rotulo, style: const TextStyle(fontSize: 12, color: AppColors.textoSecundario)),
        ],
      ),
    );
  }
}
