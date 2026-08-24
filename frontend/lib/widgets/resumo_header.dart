import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/aposta.dart';
import '../models/casa.dart';
import '../theme/app_theme.dart';
import '../utils/resumo_calculado.dart';
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
  PeriodoSelecionado _periodo = PeriodoSelecionado.tudo;

  List<PontoEvolucaoBanca> get _evolucaoFiltrada {
    final inicio = _periodo.inicio;
    final fim = _periodo.fim;
    if (inicio == null && fim == null) return widget.evolucao;

    var lista = widget.evolucao;

    
    if (inicio != null) {
      final indicePrimeiro = lista.indexWhere((p) => !p.data.isBefore(inicio));
      if (indicePrimeiro == -1) {
        lista = const [];
      } else if (indicePrimeiro > 0) {
        lista = lista.sublist(indicePrimeiro - 1);
      } else {
        lista = lista.sublist(indicePrimeiro);
      }
    }

    if (fim != null) {
      lista = lista.where((p) => !p.data.isAfter(fim)).toList();
    }

    return lista;
  }

  List<Aposta> get _apostasFiltradas {
    final inicio = _periodo.inicio;
    final fim = _periodo.fim;
    return widget.apostas.where((a) {
      if (inicio != null && a.data.isBefore(inicio)) return false;
      if (fim != null && a.data.isAfter(fim)) return false;
      return true;
    }).toList();
  }


  ResumoCalculado get _resumoFiltrado => calcularResumoLocal(_apostasFiltradas);

  @override
  Widget build(BuildContext context) {
    final formatoMoeda = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
    final resumoPeriodo = _resumoFiltrado;
    final corLucroPeriodo = resumoPeriodo.lucroTotal >= 0 ? AppColors.green : AppColors.red;
    final eTudo = !_periodo.ehPersonalizado && _periodo.preset == PeriodoFiltro.tudo;

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
          const SizedBox(height: 16),
          SeletorPeriodo(selecionado: _periodo, onSelecionar: (p) => setState(() => _periodo = p)),
          const SizedBox(height: 10),
          Text(
            '${resumoPeriodo.lucroTotal >= 0 ? '+' : ''}${formatoMoeda.format(resumoPeriodo.lucroTotal)}'
            '${eTudo ? ' desde o início' : ' no período selecionado'}',
            style: TextStyle(color: corLucroPeriodo, fontSize: 13, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 14),
          EvolucaoBancaChart(pontos: _evolucaoFiltrada),
          const SizedBox(height: 18),
          const Text('Lucro por aposta', style: TextStyle(color: AppColors.textoSecundario, fontSize: 13)),
          const SizedBox(height: 8),
          LucroBarChart(apostas: _apostasFiltradas),
          const SizedBox(height: 14),
          Row(
            children: [
              _Estatistica(rotulo: 'Apostas', valor: '${resumoPeriodo.totalApostas}'),
              _Estatistica(rotulo: 'ROI', valor: resumoPeriodo.roi != null ? '${resumoPeriodo.roi!.toStringAsFixed(1)}%' : '—'),
              _Estatistica(
                rotulo: 'Acerto',
                valor: resumoPeriodo.taxaAcerto != null ? '${resumoPeriodo.taxaAcerto!.toStringAsFixed(0)}%' : '—',
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _Estatistica(
                rotulo: 'Odd média',
                valor: resumoPeriodo.oddMedia != null ? resumoPeriodo.oddMedia!.toStringAsFixed(2) : '—',
              ),
              _Estatistica(
                rotulo: 'Ticket médio',
                valor: resumoPeriodo.valorMedioApostado != null
                    ? formatoMoeda.format(resumoPeriodo.valorMedioApostado)
                    : '—',
              ),
              _Estatistica(rotulo: 'Em aberto', valor: '${resumoPeriodo.apostasEmAberto}'),
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
