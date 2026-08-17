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
  int _paginaAtual = 0; // começa em 0 internamente, mostrado como "página 1" pro usuário
  int _itensPorPagina = 25;

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
    if (novoFiltro != null) {
      setState(() {
        _filtro = novoFiltro;
        _paginaAtual = 0; // volta pra primeira página — a antiga pode nem existir mais no resultado filtrado
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final apostasFiltradas = _filtro.aplicar(widget.apostas);

    final totalPaginas = apostasFiltradas.isEmpty ? 1 : (apostasFiltradas.length / _itensPorPagina).ceil();
    final paginaSegura = _paginaAtual.clamp(0, totalPaginas - 1);
    final inicio = paginaSegura * _itensPorPagina;
    final fim = (inicio + _itensPorPagina).clamp(0, apostasFiltradas.length);
    final apostasDaPagina = apostasFiltradas.sublist(inicio, fim);

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
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    _filtro.temFiltroAtivo
                                        ? '${apostasFiltradas.length} de ${widget.apostas.length} apostas'
                                        : '${apostasFiltradas.length} apostas',
                                    style: const TextStyle(color: AppColors.textoSecundario, fontSize: 12.5),
                                  ),
                                ),
                                if (_filtro.temFiltroAtivo)
                                  TextButton(
                                    onPressed: () => setState(() {
                                      _filtro = const FiltroApostas();
                                      _paginaAtual = 0;
                                    }),
                                    child: const Text('Limpar filtro', style: TextStyle(fontSize: 12.5)),
                                  ),
                              ],
                            ),
                          ),
                          Expanded(
                            child: Builder(
                              builder: (context) {
                                final grupos = _agruparPorDia(apostasDaPagina);
                                return ListView.builder(
                                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
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
                          _BarraPaginacao(
                            paginaAtual: paginaSegura,
                            totalPaginas: totalPaginas,
                            itensPorPagina: _itensPorPagina,
                            onIrPara: (p) => setState(() => _paginaAtual = p),
                            onMudarItensPorPagina: (n) => setState(() {
                              _itensPorPagina = n;
                              _paginaAtual = 0;
                            }),
                          ),
                        ],
                      ),
      ),
    );
  }
}

class _BarraPaginacao extends StatelessWidget {
  final int paginaAtual; // 0-indexed
  final int totalPaginas;
  final int itensPorPagina;
  final ValueChanged<int> onIrPara;
  final ValueChanged<int> onMudarItensPorPagina;

  const _BarraPaginacao({
    required this.paginaAtual,
    required this.totalPaginas,
    required this.itensPorPagina,
    required this.onIrPara,
    required this.onMudarItensPorPagina,
  });

  @override
  Widget build(BuildContext context) {
    final naPrimeira = paginaAtual == 0;
    final naUltima = paginaAtual >= totalPaginas - 1;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: const BoxDecoration(
        color: AppColors.superficieAlta,
        border: Border(top: BorderSide(color: AppColors.borda)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          PopupMenuButton<int>(
            tooltip: 'Apostas por página',
            initialValue: itensPorPagina,
            color: AppColors.superficieAlta,
            onSelected: onMudarItensPorPagina,
            itemBuilder: (_) => const [20, 25, 50, 100]
                .map((n) => PopupMenuItem(value: n, child: Text('$n por página')))
                .toList(),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('$itensPorPagina', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                const Icon(Icons.arrow_drop_down, color: AppColors.textoSecundario, size: 18),
              ],
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                tooltip: 'Primeira página',
                onPressed: naPrimeira ? null : () => onIrPara(0),
                icon: const Icon(Icons.first_page, size: 20),
                visualDensity: VisualDensity.compact,
              ),
              IconButton(
                tooltip: 'Página anterior',
                onPressed: naPrimeira ? null : () => onIrPara(paginaAtual - 1),
                icon: const Icon(Icons.chevron_left, size: 20),
                visualDensity: VisualDensity.compact,
              ),
              SizedBox(
                width: 84,
                child: Text(
                  'Pág. ${paginaAtual + 1} de $totalPaginas',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
                ),
              ),
              IconButton(
                tooltip: 'Próxima página',
                onPressed: naUltima ? null : () => onIrPara(paginaAtual + 1),
                icon: const Icon(Icons.chevron_right, size: 20),
                visualDensity: VisualDensity.compact,
              ),
              IconButton(
                tooltip: 'Última página',
                onPressed: naUltima ? null : () => onIrPara(totalPaginas - 1),
                icon: const Icon(Icons.last_page, size: 20),
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
        ],
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
