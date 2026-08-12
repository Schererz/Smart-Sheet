import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/aposta.dart';
import '../theme/app_theme.dart';
import '../widgets/aposta_card.dart';
import '../widgets/filtro_apostas.dart';
import '../widgets/filtro_apostas_sheet.dart';

class ApostasScreen extends StatefulWidget {
  final List<Aposta> apostas;
  final bool carregando;
  final String? erro;
  final void Function(Aposta) onTocarStatus;
  final void Function(Aposta) onExcluir;
  final void Function(Aposta) onEditar;
  final Future<void> Function() onRefresh;

  const ApostasScreen({
    super.key,
    required this.apostas,
    required this.carregando,
    required this.erro,
    required this.onTocarStatus,
    required this.onExcluir,
    required this.onEditar,
    required this.onRefresh,
  });

  @override
  State<ApostasScreen> createState() => _ApostasScreenState();
}

class _ApostasScreenState extends State<ApostasScreen> {
  FiltroApostas _filtro = const FiltroApostas();

  List<String> get _casasDisponiveis {
    final nomes = widget.apostas.map((a) => a.casaDeApostas).toSet().toList();
    nomes.sort();
    return nomes;
  }

  /// Agrupa as apostas (já ordenadas por data, mais recente primeiro) em
  /// blocos por dia, preservando a ordem — pra desenhar os divisores tipo
  /// "Hoje", "Ontem", "11/08" etc.
  List<MapEntry<DateTime, List<Aposta>>> _agruparPorDia(List<Aposta> apostas) {
    final grupos = <DateTime, List<Aposta>>{};
    for (final aposta in apostas) {
      final dia = DateTime(aposta.data.year, aposta.data.month, aposta.data.day);
      grupos.putIfAbsent(dia, () => []).add(aposta);
    }
    return grupos.entries.toList();
  }

  String _rotuloDia(DateTime dia) {
    final agora = DateTime.now();
    final hoje = DateTime(agora.year, agora.month, agora.day);
    final ontem = hoje.subtract(const Duration(days: 1));

    if (dia == hoje) return 'HOJE';
    if (dia == ontem) return 'ONTEM';
    return DateFormat('dd/MM').format(dia);
  }

  Future<void> _abrirFiltro() async {
    final novoFiltro = await abrirFiltroApostas(
      context,
      filtroAtual: _filtro,
      casasDisponiveis: _casasDisponiveis,
    );
    if (novoFiltro != null) setState(() => _filtro = novoFiltro);
  }

  @override
  Widget build(BuildContext context) {
    final apostasFiltradas = _filtro.aplicar(widget.apostas);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Minhas apostas'),
        backgroundColor: AppColors.fundo,
        actions: [
          IconButton(
            tooltip: 'Filtrar',
            onPressed: _abrirFiltro,
            icon: Badge(
              isLabelVisible: _filtro.temFiltroAtivo,
              label: Text('${_filtro.quantidadeAtiva}'),
              child: const Icon(Icons.filter_list_rounded),
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: widget.onRefresh,
        child: widget.carregando
            ? const Center(child: CircularProgressIndicator())
            : widget.erro != null
                ? _EstadoErro(mensagem: widget.erro!, onTentarDeNovo: widget.onRefresh)
                : apostasFiltradas.isEmpty
                    ? _EstadoVazio(temFiltro: _filtro.temFiltroAtivo)
                    : Column(
                        children: [
                          if (_filtro.temFiltroAtivo)
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      '${apostasFiltradas.length} de ${widget.apostas.length} apostas',
                                      style: const TextStyle(color: AppColors.textoSecundario, fontSize: 12.5),
                                    ),
                                  ),
                                  TextButton(
                                    onPressed: () => setState(() => _filtro = const FiltroApostas()),
                                    child: const Text('Limpar filtro', style: TextStyle(fontSize: 12.5)),
                                  ),
                                ],
                              ),
                            ),
                          Expanded(
                            child: Builder(
                              builder: (context) {
                                final grupos = _agruparPorDia(apostasFiltradas);
                                return ListView.builder(
                                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
                                  itemCount: grupos.length,
                                  itemBuilder: (context, indiceGrupo) {
                                    final grupo = grupos[indiceGrupo];
                                    return Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        _DivisorDia(rotulo: _rotuloDia(grupo.key)),
                                        ...grupo.value.map(
                                          (aposta) => Padding(
                                            padding: const EdgeInsets.only(bottom: 10),
                                            child: ApostaCard(
                                              aposta: aposta,
                                              onTocarStatus: () => widget.onTocarStatus(aposta),
                                              onExcluir: () => widget.onExcluir(aposta),
                                              onEditar: () => widget.onEditar(aposta),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                      ],
                                    );
                                  },
                                );
                              },
                            ),
                          ),
                        ],
                      ),
      ),
    );
  }
}

class _DivisorDia extends StatelessWidget {
  final String rotulo;
  const _DivisorDia({required this.rotulo});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 10),
      child: Row(
        children: [
          Text(
            rotulo,
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: AppColors.textoSecundario,
              letterSpacing: 0.4,
            ),
          ),
          const SizedBox(width: 10),
          const Expanded(child: Divider(color: AppColors.borda, height: 1)),
        ],
      ),
    );
  }
}

class _EstadoVazio extends StatelessWidget {
  final bool temFiltro;
  const _EstadoVazio({required this.temFiltro});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                temFiltro
                    ? 'Nenhuma aposta encontrada com esse filtro.'
                    : 'Nenhuma aposta ainda.\nToque no + pra registrar a primeira.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.textoSecundario, fontSize: 15),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _EstadoErro extends StatelessWidget {
  final String mensagem;
  final Future<void> Function() onTentarDeNovo;
  const _EstadoErro({required this.mensagem, required this.onTentarDeNovo});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.cloud_off, color: AppColors.textoSecundario, size: 36),
                  const SizedBox(height: 12),
                  Text(mensagem, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.textoSecundario)),
                  const SizedBox(height: 16),
                  OutlinedButton(onPressed: onTentarDeNovo, child: const Text('Tentar de novo')),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
