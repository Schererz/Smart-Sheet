import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

import '../models/aposta.dart';
import '../theme/app_theme.dart';

class EvolucaoBancaMultiChart extends StatefulWidget {
  final List<PontoEvolucaoBanca> total;
  final List<PontoEvolucaoBanca> girino;
  final List<PontoEvolucaoBanca> props;

  const EvolucaoBancaMultiChart({
    super.key,
    required this.total,
    required this.girino,
    required this.props,
  });

  @override
  State<EvolucaoBancaMultiChart> createState() => _EvolucaoBancaMultiChartState();
}

class _EvolucaoBancaMultiChartState extends State<EvolucaoBancaMultiChart> {
  static const _corGirino = Color(0xFF4B9EE0);
  static const _corProps = Color(0xFFE0B84B);

  bool _mostrarTotal = true;
  bool _mostrarGirino = true;
  bool _mostrarProps = true;

  @override
  Widget build(BuildContext context) {
    if (widget.total.length < 2) {
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

    // alinha as 3 linhas pelo mesmo eixo de tempo real (dias desde a
    // data mais antiga entre todas), não por índice — senão ficariam
    // desalinhadas quando uma tiver menos pontos que a outra
    final todasAsDatas = [
      ...widget.total.map((p) => p.data),
      ...widget.girino.map((p) => p.data),
      ...widget.props.map((p) => p.data),
    ];
    final dataMinima = todasAsDatas.reduce((a, b) => a.isBefore(b) ? a : b);

    List<FlSpot> paraSpots(List<PontoEvolucaoBanca> pontos) {
      return pontos.map((p) => FlSpot(p.data.difference(dataMinima).inDays.toDouble(), p.banca)).toList();
    }

    final linhas = <LineChartBarData>[];
    final valoresY = <double>[];

    if (_mostrarTotal) {
      final subiu = widget.total.last.banca >= widget.total.first.banca;
      final cor = subiu ? AppColors.green : AppColors.red;
      final spots = paraSpots(widget.total);
      valoresY.addAll(spots.map((s) => s.y));
      linhas.add(_linha(spots, cor, comArea: true));
    }
    if (_mostrarGirino && widget.girino.length >= 2) {
      final spots = paraSpots(widget.girino);
      valoresY.addAll(spots.map((s) => s.y));
      linhas.add(_linha(spots, _corGirino));
    }
    if (_mostrarProps && widget.props.length >= 2) {
      final spots = paraSpots(widget.props);
      valoresY.addAll(spots.map((s) => s.y));
      linhas.add(_linha(spots, _corProps));
    }

    double minY = 0, maxY = 0;
    if (valoresY.isNotEmpty) {
      minY = valoresY.reduce((a, b) => a < b ? a : b);
      maxY = valoresY.reduce((a, b) => a > b ? a : b);
    }
    final margem = ((maxY - minY).abs() * 0.15).clamp(5, double.infinity);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 140,
          child: linhas.isEmpty
              ? const Center(
                  child: Text('Nenhuma linha selecionada', style: TextStyle(color: AppColors.textoSecundario, fontSize: 12)),
                )
              : LineChart(
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
                          return LineTooltipItem(
                            'R\$ ${s.y.toStringAsFixed(2)}',
                            const TextStyle(color: AppColors.textoPrimario, fontWeight: FontWeight.w600, fontSize: 12),
                          );
                        }).toList(),
                      ),
                    ),
                    lineBarsData: linhas,
                  ),
                ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _botao('Total', AppColors.green, _mostrarTotal, () => setState(() => _mostrarTotal = !_mostrarTotal)),
            _botao('Girino', _corGirino, _mostrarGirino, () => setState(() => _mostrarGirino = !_mostrarGirino)),
            _botao('Props', _corProps, _mostrarProps, () => setState(() => _mostrarProps = !_mostrarProps)),
          ],
        ),
      ],
    );
  }

  LineChartBarData _linha(List<FlSpot> spots, Color cor, {bool comArea = false}) {
    return LineChartBarData(
      spots: spots,
      isCurved: true,
      curveSmoothness: 0.2,
      color: cor,
      barWidth: 2.5,
      dotData: const FlDotData(show: false),
      belowBarData: BarAreaData(show: comArea, color: cor.withValues(alpha: 0.10)),
    );
  }

  Widget _botao(String rotulo, Color cor, bool ativo, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: ativo ? cor.withValues(alpha: 0.18) : AppColors.superficie,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: ativo ? cor.withValues(alpha: 0.6) : AppColors.borda),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 8, height: 8, decoration: BoxDecoration(color: cor, shape: BoxShape.circle)),
            const SizedBox(width: 6),
            Text(
              rotulo,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: ativo ? AppColors.textoPrimario : AppColors.textoSecundario,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
