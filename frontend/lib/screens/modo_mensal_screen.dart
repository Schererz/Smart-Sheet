import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/ciclo.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/evolucao_banca_chart.dart';

class ModoMensalScreen extends StatefulWidget {
  const ModoMensalScreen({super.key});

  @override
  State<ModoMensalScreen> createState() => _ModoMensalScreenState();
}

class _ModoMensalScreenState extends State<ModoMensalScreen> {
  final _api = ApiService();

  bool _carregando = true;
  bool _modoAtivado = false;
  CicloMensal? _cicloAtual;
  DashboardCiclo? _dashboard;
  List<CicloMensal> _historico = [];
  String? _erro;

  @override
  void initState() {
    super.initState();
    _carregarTudo();
  }

  Future<void> _carregarTudo() async {
    setState(() {
      _carregando = true;
      _erro = null;
    });
    try {
      final ativado = await _api.obterModoMensal();
      final historico = await _api.listarCiclos();
      DashboardCiclo? dashboard;
      CicloMensal? atual;
      if (ativado && historico.isNotEmpty) {
        atual = historico.firstWhere((c) => c.emAndamento, orElse: () => historico.first);
        dashboard = await _api.obterDashboardCiclo(atual.id);
      }
      setState(() {
        _modoAtivado = ativado;
        _historico = historico;
        _cicloAtual = atual;
        _dashboard = dashboard;
      });
    } catch (e) {
      setState(() => _erro = 'Não consegui carregar: $e');
    } finally {
      setState(() => _carregando = false);
    }
  }

  Future<void> _alternarModo(bool valor) async {
    try {
      await _api.definirModoMensal(valor);
      await _carregarTudo();
      if (valor && _cicloAtual == null && mounted) {
        _mostrarDialogoIniciar();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Não consegui salvar: $e')));
      }
    }
  }

  Future<void> _mostrarDialogoIniciar() async {
    final confirmou = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.superficieAlta,
        title: const Text('Iniciar novo mês?'),
        content: const Text(
          'A banca atual (o total de sempre) vira o ponto de partida desse novo ciclo. '
          'O histórico de antes continua salvo, só some da visão "deste mês".',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Iniciar')),
        ],
      ),
    );
    if (confirmou == true) {
      try {
        await _api.iniciarCiclo();
        _carregarTudo();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Não consegui iniciar: $e')));
        }
      }
    }
  }

  Future<void> _abrirCicloPassado(CicloMensal ciclo) async {
    try {
      final dashboard = await _api.obterDashboardCiclo(ciclo.id);
      if (mounted) {
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: AppColors.fundo,
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
          builder: (_) => DraggableScrollableSheet(
            initialChildSize: 0.85,
            expand: false,
            builder: (context, scrollController) => SingleChildScrollView(
              controller: scrollController,
              padding: const EdgeInsets.all(20),
              child: _ConteudoDashboardCiclo(dashboard: dashboard),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Não consegui abrir: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Modo mensal')),
      body: _carregando
          ? const Center(child: CircularProgressIndicator())
          : _erro != null
              ? Center(child: Text(_erro!, style: const TextStyle(color: AppColors.textoSecundario)))
              : RefreshIndicator(
                  onRefresh: _carregarTudo,
                  child: ListView(
                    padding: const EdgeInsets.all(20),
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(color: AppColors.superficie, borderRadius: BorderRadius.circular(14)),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Modo mensal', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                                  const SizedBox(height: 4),
                                  const Text(
                                    'Mostra a banca e o dashboard só do mês atual, guardando os anteriores no histórico.',
                                    style: TextStyle(color: AppColors.textoSecundario, fontSize: 12),
                                  ),
                                ],
                              ),
                            ),
                            Switch(value: _modoAtivado, onChanged: _alternarModo),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      if (!_modoAtivado)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 30),
                          child: Center(
                            child: Text(
                              'Modo mensal desligado — o app continua mostrando tudo normalmente, desde o início.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: AppColors.textoSecundario, fontSize: 13),
                            ),
                          ),
                        )
                      else if (_cicloAtual == null)
                        Column(
                          children: [
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 12),
                              child: Text(
                                'Nenhum ciclo iniciado ainda.',
                                style: TextStyle(color: AppColors.textoSecundario, fontSize: 13),
                              ),
                            ),
                            ElevatedButton(onPressed: _mostrarDialogoIniciar, child: const Text('Iniciar primeiro mês')),
                          ],
                        )
                      else ...[
                        if (_dashboard != null) _ConteudoDashboardCiclo(dashboard: _dashboard!),
                        const SizedBox(height: 16),
                        OutlinedButton.icon(
                          onPressed: _mostrarDialogoIniciar,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Iniciar novo mês'),
                        ),
                      ],
                      if (_historico.length > 1) ...[
                        const SizedBox(height: 28),
                        const Text('Meses anteriores', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5)),
                        const SizedBox(height: 10),
                        ..._historico.where((c) => c.id != _cicloAtual?.id).map(
                              (c) => Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                child: ListTile(
                                  tileColor: AppColors.superficie,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  title: Text(c.nome),
                                  subtitle: Text(DateFormat('dd/MM/yyyy').format(c.dataInicio)),
                                  trailing: const Icon(Icons.chevron_right, color: AppColors.textoSecundario),
                                  onTap: () => _abrirCicloPassado(c),
                                ),
                              ),
                            ),
                      ],
                    ],
                  ),
                ),
    );
  }
}

class _ConteudoDashboardCiclo extends StatelessWidget {
  final DashboardCiclo dashboard;
  const _ConteudoDashboardCiclo({required this.dashboard});

  @override
  Widget build(BuildContext context) {
    final formatoMoeda = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
    final corLucro = dashboard.lucroCiclo >= 0 ? AppColors.green : AppColors.red;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(dashboard.ciclo.nome, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
        const SizedBox(height: 10),
        Text(
          formatoMoeda.format(dashboard.bancaAtualCiclo),
          style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
        ),
        Text(
          '${dashboard.lucroCiclo >= 0 ? '+' : ''}${formatoMoeda.format(dashboard.lucroCiclo)} nesse mês · ${dashboard.totalApostasCiclo} apostas',
          style: TextStyle(color: corLucro, fontSize: 13, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 16),
        if (dashboard.evolucao.length > 1) EvolucaoBancaChart(pontos: dashboard.evolucao),
        const SizedBox(height: 18),
        if (dashboard.resumoPorCasa.isNotEmpty) ...[
          const Text('Por casa', style: TextStyle(color: AppColors.textoSecundario, fontSize: 12.5, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          ...dashboard.resumoPorCasa.map(
            (c) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('${c.casa} (${c.totalApostas})', style: const TextStyle(fontSize: 13)),
                  Text(
                    formatoMoeda.format(c.lucroTotal),
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: c.lucroTotal >= 0 ? AppColors.green : AppColors.red,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}
