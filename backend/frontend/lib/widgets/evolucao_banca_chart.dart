import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

import '../models/aposta.dart';
import '../theme/app_theme.dart';

class EvolucaoBancaChart extends StatelessWidget {
  final List<PontoEvolucaoBanca> pontos;

  const EvolucaoBancaChart({super.key, required this.pontos});

  @override
  Widget build(BuildContext context) {
    if (pontos.length < 2) {
      return const SizedBox(
        height: 120,
        child: Center(
          child: Text(
            'A evolução da banca aparece aqui assim que você tiver apostas resolvidas.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textoSecundario, fontSize: 12.5),
          ),
        ),
      );
    }

    final valores = pontos.map((p) => p.banca).toList();
    final minY = valores.reduce((a, b) => a < b ? a : b);
    final maxY = valores.reduce((a, b) => a > b ? a : b);
    final margem = ((maxY - minY).abs() * 0.15).clamp(5, double.infinity);

    final subiu = pontos.last.banca >= pontos.first.banca;
    final corLinha = subiu ? AppColors.green : AppColors.red;

    return SizedBox(
      height: 140,
      child: LineChart(
        LineChartData(
          minY: minY - margem,
          maxY: maxY + margem,
          gridData: const FlGridData(show: false),
          titlesData: const FlTitlesData(show: false),
          borderData: FlBorderData(show: false),
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipColor: (_) => AppColors.superficieAlta,
              getTooltipItems: (spots) => spots.map((s) {
                final ponto = pontos[s.x.toInt()];
                return LineTooltipItem(
                  'R\$ ${ponto.banca.toStringAsFixed(2)}',
                  const TextStyle(color: AppColors.textoPrimario, fontWeight: FontWeight.w600, fontSize: 12),
                );
              }).toList(),
            ),
          ),
          lineBarsData: [
            LineChartBarData(
              spots: [for (int i = 0; i < pontos.length; i++) FlSpot(i.toDouble(), pontos[i].banca)],
              isCurved: true,
              curveSmoothness: 0.2,
              color: corLinha,
              barWidth: 2.5,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(show: true, color: corLinha.withValues(alpha: 0.12)),
            ),
          ],
        ),
      ),
    );
  }
}
