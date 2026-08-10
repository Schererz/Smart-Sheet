import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/aposta.dart';
import '../models/casa.dart';
import '../theme/app_theme.dart';
import 'evolucao_banca_chart.dart';
import 'lucro_chart.dart';
import 'lucro_por_dia_list.dart';
import 'resumo_casas_list.dart';
import 'seletor_periodo.dart';

class ResumoHeader extends StatefulWidget {
  final ResumoStats resumo;
  final List<PontoEvolucaoBanca> evolucao;
  final List<Aposta> apostas;
  final List<PontoLucroDia> lucroPorDia;
  final List<ResumoPorCasa> resumoPorCasa;
  final VoidCallback onEditarBanca;

  const ResumoHeader({
    super.key,
    required this.resumo,
    required this.evolucao,
    required this.apostas,
    required this.lucroPorDia,
    required this.resumoPorCasa,
    required this.onEditarBanca,
  });

  @override
  State<ResumoHeader> createState() => _ResumoHeaderState();
}

class _ResumoHeaderState extends State<ResumoHeader> {
  PeriodoFiltro _periodo = PeriodoFiltro.tudo;

  List<PontoEvolucaoBanca> get _evolucaoFiltrada {
    final corte = _periodo.dataDeCorte();
    if (corte == null) return widget.evolucao;
    final filtrado = widget.evolucao.where((p) => !p.data.isBefore(corte)).toList();
    // mantém pelo menos 1 ponto antes do corte como referência de partida, se existir
    if (filtrado.length < widget.evolucao.length) {
      final indiceAnterior = widget.evolucao.length - filtrado.length - 1;
      if (indiceAnterior >= 0) return [widget.evolucao[indiceAnterior], ...filtrado];
    }
    return filtrado;
  }

  List<Aposta> get _apostasFiltradas {
    final corte = _periodo.dataDeCorte();
    if (corte == null) return widget.apostas;
    return widget.apostas.where((a) => !a.data.isBefore(corte)).toList();
  }

  @override
  Widget build(BuildContext context) {
    final formatoMoeda = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
    final corLucro = widget.resumo.lucroTotal >= 0 ? AppColors.green : AppColors.red;

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
                      formatoMoeda.format(widget.resumo.bancaAtual),
                      style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w800, letterSpacing: -0.5),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: widget.onEditarBanca,
                icon: const Icon(Icons.settings_outlined, size: 20),
                color: AppColors.textoSecundario,
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '${widget.resumo.lucroTotal >= 0 ? '+' : ''}${formatoMoeda.format(widget.resumo.lucroTotal)} desde o início',
            style: TextStyle(color: corLucro, fontSize: 13, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 16),
          SeletorPeriodo(selecionado: _periodo, onSelecionar: (p) => setState(() => _periodo = p)),
          const SizedBox(height: 14),
          EvolucaoBancaChart(pontos: _evolucaoFiltrada),
          const SizedBox(height: 18),
          const Text('Lucro por aposta', style: TextStyle(color: AppColors.textoSecundario, fontSize: 13)),
          const SizedBox(height: 8),
          LucroBarChart(apostas: _apostasFiltradas),
          const SizedBox(height: 14),
          Row(
            children: [
              _Estatistica(rotulo: 'Apostas', valor: '${widget.resumo.totalApostas}'),
              _Estatistica(rotulo: 'ROI', valor: widget.resumo.roi != null ? '${widget.resumo.roi!.toStringAsFixed(1)}%' : '—'),
              _Estatistica(
                rotulo: 'Acerto',
                valor: widget.resumo.taxaAcerto != null ? '${widget.resumo.taxaAcerto!.toStringAsFixed(0)}%' : '—',
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _Estatistica(
                rotulo: 'Odd média',
                valor: widget.resumo.oddMedia != null ? widget.resumo.oddMedia!.toStringAsFixed(2) : '—',
              ),
              _Estatistica(
                rotulo: 'Ticket médio',
                valor: widget.resumo.valorMedioApostado != null
                    ? formatoMoeda.format(widget.resumo.valorMedioApostado)
                    : '—',
              ),
              _Estatistica(rotulo: 'Em aberto', valor: '${widget.resumo.apostasEmAberto}'),
            ],
          ),
          const SizedBox(height: 22),
          const Text('Lucro por dia', style: TextStyle(color: AppColors.textoSecundario, fontSize: 13, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          LucroPorDiaList(pontos: widget.lucroPorDia),
          const SizedBox(height: 18),
          const Text('Resumo por casa', style: TextStyle(color: AppColors.textoSecundario, fontSize: 13, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          ResumoCasasList(casas: widget.resumoPorCasa),
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
