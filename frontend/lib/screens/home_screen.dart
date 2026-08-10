import 'package:flutter/material.dart';

import '../models/aposta.dart';
import '../models/casa.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import 'apostas_screen.dart';
import 'aposta_form_screen.dart';
import 'dashboard_screen.dart';
import 'selecionar_casa_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _api = ApiService();

  int _abaAtual = 0;

  List<Aposta> _apostas = [];
  ResumoStats _resumo = ResumoStats.vazio();
  List<PontoEvolucaoBanca> _evolucao = [];
  List<PontoLucroDia> _lucroPorDia = [];
  List<ResumoPorCasa> _resumoPorCasa = [];
  bool _carregando = true;
  String? _erro;

  @override
  void initState() {
    super.initState();
    _iniciar();
  }

  Future<void> _iniciar() async {
    await _carregarTudo();
    await _verificarBancaInicial();
  }

  Future<void> _verificarBancaInicial() async {
    try {
      final config = await _api.obterConfiguracao();
      if (!config.definida && mounted) {
        await _abrirDialogoBanca(primeiraVez: true);
      }
    } catch (_) {
      // se der erro aqui não é crítico, o usuário ainda pode configurar depois pelo ícone de settings
    }
  }

  Future<void> _abrirDialogoBanca({bool primeiraVez = false}) async {
    final controlador = TextEditingController(
      text: primeiraVez ? '' : _resumo.bancaInicial.toStringAsFixed(2),
    );
    final valor = await showDialog<double>(
      context: context,
      barrierDismissible: !primeiraVez,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.superficieAlta,
        title: Text(primeiraVez ? 'Qual sua banca inicial?' : 'Editar banca inicial'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (primeiraVez)
              const Padding(
                padding: EdgeInsets.only(bottom: 12),
                child: Text(
                  'É o valor que você tem disponível pra apostar hoje. Isso é só o ponto de partida do gráfico de evolução — dá pra mudar depois.',
                  style: TextStyle(color: AppColors.textoSecundario, fontSize: 13),
                ),
              ),
            TextField(
              controller: controlador,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(hintText: 'R\$ 0,00'),
            ),
          ],
        ),
        actions: [
          if (!primeiraVez) TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          TextButton(
            onPressed: () {
              final texto = controlador.text.trim().replaceAll(',', '.');
              final numero = double.tryParse(texto) ?? 0;
              Navigator.pop(context, numero);
            },
            child: const Text('Salvar'),
          ),
        ],
      ),
    );

    if (valor != null) {
      try {
        await _api.definirBancaInicial(valor);
        await _carregarTudo();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Não consegui salvar a banca: $e')));
        }
      }
    }
  }

  Future<void> _carregarTudo() async {
    setState(() {
      _carregando = true;
      _erro = null;
    });
    try {
      final resultados = await Future.wait([
        _api.listarApostas(),
        _api.obterResumo(),
        _api.obterEvolucaoBanca(),
        _api.obterLucroPorDia(),
        _api.obterResumoPorCasa(),
      ]);
      setState(() {
        _apostas = resultados[0] as List<Aposta>;
        _resumo = resultados[1] as ResumoStats;
        _evolucao = resultados[2] as List<PontoEvolucaoBanca>;
        _lucroPorDia = resultados[3] as List<PontoLucroDia>;
        _resumoPorCasa = resultados[4] as List<ResumoPorCasa>;
      });
    } catch (e) {
      setState(() => _erro = 'Não consegui conectar com o servidor.\n$e');
    } finally {
      setState(() => _carregando = false);
    }
  }

  Future<void> _ciclarStatus(Aposta aposta) async {
    if (aposta.id == null) return;
    final indice = _apostas.indexWhere((a) => a.id == aposta.id);
    try {
      final atualizada = await _api.ciclarStatus(aposta.id!);
      setState(() {
        if (indice != -1) _apostas[indice] = atualizada;
      });
      final novoResumo = await _api.obterResumo();
      setState(() => _resumo = novoResumo);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Não consegui atualizar: $e')));
      }
    }
  }

  Future<void> _excluir(Aposta aposta) async {
    if (aposta.id == null) return;
    setState(() => _apostas.removeWhere((a) => a.id == aposta.id));
    try {
      await _api.deletarAposta(aposta.id!);
      final novoResumo = await _api.obterResumo();
      setState(() => _resumo = novoResumo);
    } catch (e) {
      _carregarTudo();
    }
  }

  Future<void> _abrirNovaAposta() async {
    final salvou = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const SelecionarCasaScreen()),
    );
    if (salvou == true) _carregarTudo();
  }

  Future<void> _editarAposta(Aposta aposta) async {
    final salvou = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => ApostaFormScreen(casa: aposta.casaDeApostas, apostaExistente: aposta),
      ),
    );
    if (salvou == true) _carregarTudo();
  }

  @override
  Widget build(BuildContext context) {
    final paginas = [
      DashboardScreen(
        resumo: _resumo,
        evolucao: _evolucao,
        apostas: _apostas,
        lucroPorDia: _lucroPorDia,
        resumoPorCasa: _resumoPorCasa,
        onEditarBanca: () => _abrirDialogoBanca(),
        onRefresh: _carregarTudo,
      ),
      ApostasScreen(
        apostas: _apostas,
        carregando: _carregando,
        erro: _erro,
        onTocarStatus: _ciclarStatus,
        onExcluir: _excluir,
        onEditar: _editarAposta,
        onRefresh: _carregarTudo,
      ),
    ];

    return Scaffold(
      body: IndexedStack(index: _abaAtual, children: paginas),
      floatingActionButton: FloatingActionButton(
        onPressed: _abrirNovaAposta,
        child: const Icon(Icons.add),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: BottomAppBar(
        color: AppColors.superficieAlta,
        shape: const CircularNotchedRectangle(),
        notchMargin: 8,
        child: SizedBox(
          height: 56,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _ItemNavegacao(
                icone: Icons.pie_chart_outline_rounded,
                iconeSelecionado: Icons.pie_chart_rounded,
                rotulo: 'Dashboard',
                selecionado: _abaAtual == 0,
                onTap: () => setState(() => _abaAtual = 0),
              ),
              const SizedBox(width: 48), // espaço reservado pro FAB no meio
              _ItemNavegacao(
                icone: Icons.receipt_long_outlined,
                iconeSelecionado: Icons.receipt_long_rounded,
                rotulo: 'Apostas',
                selecionado: _abaAtual == 1,
                onTap: () => setState(() => _abaAtual = 1),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ItemNavegacao extends StatelessWidget {
  final IconData icone;
  final IconData iconeSelecionado;
  final String rotulo;
  final bool selecionado;
  final VoidCallback onTap;

  const _ItemNavegacao({
    required this.icone,
    required this.iconeSelecionado,
    required this.rotulo,
    required this.selecionado,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cor = selecionado ? AppColors.destaque : AppColors.textoSecundario;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(selecionado ? iconeSelecionado : icone, color: cor, size: 24),
            const SizedBox(height: 2),
            Text(rotulo, style: TextStyle(color: cor, fontSize: 11, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}
