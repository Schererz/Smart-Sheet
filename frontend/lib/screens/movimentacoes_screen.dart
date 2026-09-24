import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/casa.dart';
import '../models/movimentacao.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/barra_banca_localizacao.dart';
import '../widgets/carregando_animado.dart';
import '../widgets/seletor_periodo.dart';

class MovimentacoesScreen extends StatefulWidget {
  const MovimentacoesScreen({super.key});

  @override
  State<MovimentacoesScreen> createState() => _MovimentacoesScreenState();
}

class _MovimentacoesScreenState extends State<MovimentacoesScreen> with SingleTickerProviderStateMixin {
  final _api = ApiService();
  late final TabController _abas;

  bool _carregando = true;
  String? _erro;
  List<Casa> _casas = [];

  /// Aba Depósito: capital puro (depósito − saque), % da banca INICIAL fixa.
  BancaPorLocalizacao? _capitalPorCasa;

  /// Aba Saque: saldo real (depósito − saque + lucro), % da banca ATUAL.
  BancaPorLocalizacao? _bancaLocalizacao;

  List<Movimentacao> _movimentacoes = [];

  PeriodoSelecionado _periodo = PeriodoSelecionado.tudo;
  int? _casaFiltro;

  @override
  void initState() {
    super.initState();
    _abas = TabController(length: 2, vsync: this);
    _carregarTudo();
  }

  @override
  void dispose() {
    _abas.dispose();
    super.dispose();
  }

  bool get _abaDeposito => _abas.index == 0;

  Future<void> _carregarTudo() async {
    setState(() {
      _carregando = true;
      _erro = null;
    });
    try {
      final resultados = await Future.wait([
        _api.listarCasas(),
        _api.obterCapitalPorCasa(),
        _api.obterBancaPorLocalizacao(),
        _api.listarMovimentacoes(
          casaId: _casaFiltro,
          dataInicio: _periodo.inicio,
          dataFim: _periodo.fim,
        ),
      ]);
      setState(() {
        _casas = resultados[0] as List<Casa>;
        _capitalPorCasa = resultados[1] as BancaPorLocalizacao;
        _bancaLocalizacao = resultados[2] as BancaPorLocalizacao;
        _movimentacoes = resultados[3] as List<Movimentacao>;
      });
    } catch (e) {
      setState(() => _erro = 'Não consegui carregar: $e');
    } finally {
      setState(() => _carregando = false);
    }
  }

  /// Só troca o filtro (período ou casa) — as casas cadastradas e as duas
  /// barras não mudam com isso, só a lista de movimentações precisa
  /// refletir o filtro novo.
  Future<void> _recarregarMovimentacoes() async {
    try {
      final movimentacoes = await _api.listarMovimentacoes(
        casaId: _casaFiltro,
        dataInicio: _periodo.inicio,
        dataFim: _periodo.fim,
      );
      setState(() => _movimentacoes = movimentacoes);
    } catch (e) {
      setState(() => _erro = 'Não consegui carregar: $e');
    }
  }

  /// Depois de criar/excluir uma movimentação: a lista de casas continua
  /// a mesma, só as duas barras e a lista de movimentações mudam.
  Future<void> _recarregarAposMovimentacao() async {
    try {
      final resultados = await Future.wait([
        _api.obterCapitalPorCasa(),
        _api.obterBancaPorLocalizacao(),
        _api.listarMovimentacoes(
          casaId: _casaFiltro,
          dataInicio: _periodo.inicio,
          dataFim: _periodo.fim,
        ),
      ]);
      setState(() {
        _capitalPorCasa = resultados[0] as BancaPorLocalizacao;
        _bancaLocalizacao = resultados[1] as BancaPorLocalizacao;
        _movimentacoes = resultados[2] as List<Movimentacao>;
      });
    } catch (e) {
      setState(() => _erro = 'Não consegui carregar: $e');
    }
  }

  String _nomeCasa(int casaId) {
    final casa = _casas.where((c) => c.id == casaId).toList();
    return casa.isEmpty ? 'Casa #$casaId' : casa.first.nome;
  }

  Future<void> _abrirFormularioNovo() async {
    if (_casas.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cadastre uma casa primeiro (tela de escolher casa).')),
      );
      return;
    }
    final salvou = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.superficieAlta,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _FormularioMovimentacao(
        casas: _casas,
        tipoInicial: _abaDeposito ? TipoMovimentacao.deposito : TipoMovimentacao.saque,
      ),
    );
    if (salvou == true) _recarregarAposMovimentacao();
  }

  Future<void> _excluir(Movimentacao mov) async {
    try {
      await _api.deletarMovimentacao(mov.id);
      _recarregarAposMovimentacao();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Não consegui excluir: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Saques e depósitos'),
        bottom: TabBar(
          controller: _abas,
          onTap: (_) => setState(() {}), // só pra atualizar qual barra/lista aparece
          tabs: const [
            Tab(text: 'Depósito'),
            Tab(text: 'Saque'),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _abrirFormularioNovo,
        child: const Icon(Icons.add),
      ),
      body: _carregando
          ? const CarregandoAnimado()
          : _erro != null
              ? Center(child: Text(_erro!, style: const TextStyle(color: AppColors.textoSecundario)))
              : RefreshIndicator(
                  onRefresh: _carregarTudo,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                    children: [
                      if (_abaDeposito)
                        _ResumoDeposito(dados: _capitalPorCasa)
                      else
                        _CartaoBarra(
                          titulo: 'Disponível pra sacar (com lucro)',
                          subtitulo: 'Já soma o lucro/prejuízo de cada casa — é o que realmente dá pra sacar agora.',
                          dados: _bancaLocalizacao,
                        ),
                      const SizedBox(height: 20),
                      const Text('Histórico', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5)),
                      const SizedBox(height: 10),
                      SeletorPeriodo(
                        selecionado: _periodo,
                        onSelecionar: (p) {
                          setState(() => _periodo = p);
                          _recarregarMovimentacoes();
                        },
                      ),
                      const SizedBox(height: 10),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            _ChipCasa(
                              rotulo: 'Todas as casas',
                              selecionado: _casaFiltro == null,
                              onTap: () {
                                setState(() => _casaFiltro = null);
                                _recarregarMovimentacoes();
                              },
                            ),
                            ..._casas.map(
                              (c) => Padding(
                                padding: const EdgeInsets.only(left: 6),
                                child: _ChipCasa(
                                  rotulo: c.nome,
                                  selecionado: _casaFiltro == c.id,
                                  onTap: () {
                                    setState(() => _casaFiltro = c.id);
                                    _recarregarMovimentacoes();
                                  },
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      _ListaMovimentacoes(
                        movimentacoes: _movimentacoes
                            .where((m) => m.tipo == (_abaDeposito ? TipoMovimentacao.deposito : TipoMovimentacao.saque))
                            .toList(),
                        nomeCasa: _nomeCasa,
                        onExcluir: _excluir,
                      ),
                    ],
                  ),
                ),
    );
  }
}

class _CartaoBarra extends StatelessWidget {
  final String titulo;
  final String subtitulo;
  final BancaPorLocalizacao? dados;

  const _CartaoBarra({required this.titulo, required this.subtitulo, required this.dados});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppColors.superficie, borderRadius: BorderRadius.circular(14)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(titulo, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5)),
          const SizedBox(height: 4),
          Text(subtitulo, style: const TextStyle(color: AppColors.textoSecundario, fontSize: 12)),
          const SizedBox(height: 12),
          if (dados != null) BarraBancaLocalizacao(dados: dados!),
        ],
      ),
    );
  }
}

/// Aba Depósito, sem barra nem porcentagem — só o total depositado, quanto
/// está em cada casa, e o que sobra "no banco" (pode ficar negativo, o que
/// significa que você depositou mais do que sua banca configurada).
class _ResumoDeposito extends StatelessWidget {
  final BancaPorLocalizacao? dados;
  const _ResumoDeposito({required this.dados});

  @override
  Widget build(BuildContext context) {
    final formatoMoeda = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
    final d = dados;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppColors.superficie, borderRadius: BorderRadius.circular(14)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Capital alocado (sem lucro)', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5)),
          const SizedBox(height: 4),
          const Text(
            'Só o que você depositou/sacou de verdade — não muda sozinho com o resultado das apostas.',
            style: TextStyle(color: AppColors.textoSecundario, fontSize: 12),
          ),
          const SizedBox(height: 14),
          if (d == null)
            const Center(child: Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator()))
          else ...[
            if (d.casas.isNotEmpty) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Total depositado', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5)),
                  Text(
                    formatoMoeda.format(d.casas.fold<double>(0, (s, c) => s + c.valor)),
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              ...d.casas.map(
                (c) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(c.casa, style: const TextStyle(fontSize: 13, color: AppColors.textoSecundario)),
                      Text(formatoMoeda.format(c.valor), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ),
              const Divider(height: 24),
            ],
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('No banco (fora das casas)', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5)),
                Text(
                  formatoMoeda.format(d.banco),
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13.5,
                    color: d.banco < 0 ? AppColors.red : null,
                  ),
                ),
              ],
            ),
            if (d.banco < 0)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text(
                  'Negativo = você depositou mais do que sua banca configurada — esse tanto veio do seu bolso, fora da banca.',
                  style: TextStyle(fontSize: 11.5, color: AppColors.textoSecundario),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _ListaMovimentacoes extends StatelessWidget {
  final List<Movimentacao> movimentacoes;
  final String Function(int) nomeCasa;
  final void Function(Movimentacao) onExcluir;

  const _ListaMovimentacoes({required this.movimentacoes, required this.nomeCasa, required this.onExcluir});

  @override
  Widget build(BuildContext context) {
    final formatoMoeda = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
    final formatoData = DateFormat('dd/MM/yyyy');

    if (movimentacoes.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 20),
        child: Center(
          child: Text(
            'Nenhuma movimentação nesse período/filtro.',
            style: TextStyle(color: AppColors.textoSecundario, fontSize: 13),
          ),
        ),
      );
    }

    return Column(
      children: movimentacoes.map((mov) {
        final eDeposito = mov.tipo == TipoMovimentacao.deposito;
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: AppColors.superficie, borderRadius: BorderRadius.circular(10)),
          child: Row(
            children: [
              Icon(
                eDeposito ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
                color: eDeposito ? AppColors.green : AppColors.red,
                size: 20,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(nomeCasa(mov.casaId), style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5)),
                    Text(formatoData.format(mov.data), style: const TextStyle(color: AppColors.textoSecundario, fontSize: 12)),
                  ],
                ),
              ),
              Text(
                formatoMoeda.format(mov.valor),
                style: TextStyle(fontWeight: FontWeight.w700, color: eDeposito ? AppColors.green : AppColors.red),
              ),
              IconButton(
                onPressed: () => onExcluir(mov),
                icon: const Icon(Icons.close, size: 18),
                color: AppColors.textoSecundario,
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

class _ChipCasa extends StatelessWidget {
  final String rotulo;
  final bool selecionado;
  final VoidCallback onTap;

  const _ChipCasa({required this.rotulo, required this.selecionado, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selecionado ? AppColors.destaque.withValues(alpha: 0.18) : AppColors.superficie,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: selecionado ? AppColors.destaque.withValues(alpha: 0.6) : AppColors.borda),
        ),
        child: Text(
          rotulo,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            color: selecionado ? AppColors.destaque : AppColors.textoSecundario,
          ),
        ),
      ),
    );
  }
}

class _FormularioMovimentacao extends StatefulWidget {
  final List<Casa> casas;
  final TipoMovimentacao tipoInicial;
  const _FormularioMovimentacao({required this.casas, this.tipoInicial = TipoMovimentacao.deposito});

  @override
  State<_FormularioMovimentacao> createState() => _FormularioMovimentacaoState();
}

class _FormularioMovimentacaoState extends State<_FormularioMovimentacao> {
  final _api = ApiService();
  late Casa _casaEscolhida;
  late TipoMovimentacao _tipo;
  final _valorController = TextEditingController();
  DateTime _data = DateTime.now();
  bool _salvando = false;
  String? _erro;

  @override
  void initState() {
    super.initState();
    _casaEscolhida = widget.casas.first;
    _tipo = widget.tipoInicial;
  }

  @override
  void dispose() {
    _valorController.dispose();
    super.dispose();
  }

  Future<void> _escolherData() async {
    final escolhida = await showDatePicker(
      context: context,
      initialDate: _data,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (escolhida != null) setState(() => _data = escolhida);
  }

  Future<void> _salvar() async {
    final valor = double.tryParse(_valorController.text.trim().replaceAll(',', '.'));
    if (valor == null || valor <= 0) {
      setState(() => _erro = 'Digite um valor válido.');
      return;
    }
    setState(() {
      _salvando = true;
      _erro = null;
    });
    try {
      await _api.criarMovimentacao(casaId: _casaEscolhida.id, tipo: _tipo, valor: valor, data: _data);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      setState(() => _erro = '$e');
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Novo lançamento', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => setState(() => _tipo = TipoMovimentacao.deposito),
                    style: OutlinedButton.styleFrom(
                      backgroundColor: _tipo == TipoMovimentacao.deposito ? AppColors.green.withValues(alpha: 0.18) : null,
                      side: BorderSide(color: _tipo == TipoMovimentacao.deposito ? AppColors.green : AppColors.borda),
                    ),
                    child: Text('Depósito', style: TextStyle(color: _tipo == TipoMovimentacao.deposito ? AppColors.green : null)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => setState(() => _tipo = TipoMovimentacao.saque),
                    style: OutlinedButton.styleFrom(
                      backgroundColor: _tipo == TipoMovimentacao.saque ? AppColors.red.withValues(alpha: 0.18) : null,
                      side: BorderSide(color: _tipo == TipoMovimentacao.saque ? AppColors.red : AppColors.borda),
                    ),
                    child: Text('Saque', style: TextStyle(color: _tipo == TipoMovimentacao.saque ? AppColors.red : null)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<Casa>(
              initialValue: _casaEscolhida,
              decoration: const InputDecoration(labelText: 'Casa'),
              items: widget.casas.map((c) => DropdownMenuItem(value: c, child: Text(c.nome))).toList(),
              onChanged: (c) => setState(() => _casaEscolhida = c!),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _valorController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Valor', hintText: 'R\$ 0,00'),
            ),
            const SizedBox(height: 12),
            InkWell(
              onTap: _escolherData,
              child: InputDecorator(
                decoration: const InputDecoration(labelText: 'Data'),
                child: Text(DateFormat('dd/MM/yyyy').format(_data)),
              ),
            ),
            if (_erro != null) ...[
              const SizedBox(height: 10),
              Text(_erro!, style: const TextStyle(color: AppColors.red, fontSize: 12.5)),
            ],
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _salvando ? null : _salvar,
              child: _salvando ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Salvar'),
            ),
          ],
        ),
      ),
    );
  }
}
