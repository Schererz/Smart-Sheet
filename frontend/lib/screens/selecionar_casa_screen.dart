import 'package:flutter/material.dart';

import '../models/casa.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import 'aposta_form_screen.dart';
import 'capturar_aposta_screen.dart';

/// Tela que aparece ao clicar no "+": o usuário escolhe (ou cadastra) a
/// casa de apostas ANTES de mandar a imagem. Isso evita o OCR confundir
/// casas com layout parecido — já sabemos de qual casa é o print.
class SelecionarCasaScreen extends StatefulWidget {
  const SelecionarCasaScreen({super.key});

  @override
  State<SelecionarCasaScreen> createState() => _SelecionarCasaScreenState();
}

class _SelecionarCasaScreenState extends State<SelecionarCasaScreen> {
  final _api = ApiService();
  final _controladorNovaCasa = TextEditingController();
  List<Casa> _casas = [];
  bool _carregando = true;
  bool _adicionando = false;

  @override
  void initState() {
    super.initState();
    _carregarCasas();
  }

  Future<void> _carregarCasas() async {
    setState(() => _carregando = true);
    try {
      final casas = await _api.listarCasas();
      setState(() => _casas = casas);
    } catch (e) {
      _mostrarErro('Não consegui carregar as casas: $e');
    } finally {
      setState(() => _carregando = false);
    }
  }

  Future<void> _criarCasa() async {
    final nome = _controladorNovaCasa.text.trim();
    if (nome.isEmpty) return;
    try {
      await _api.criarCasa(nome);
      _controladorNovaCasa.clear();
      await _carregarCasas();
    } catch (e) {
      _mostrarErro('Não consegui cadastrar: $e');
    }
  }

  void _mostrarErro(String mensagem) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(mensagem)));
  }

  Future<void> _excluirCasa(Casa casa) async {
    final confirmou = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.superficieAlta,
        title: Text('Excluir ${casa.nome}?'),
        content: const Text('As apostas já registradas com essa casa continuam salvas, só a casa some da lista.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Excluir', style: TextStyle(color: AppColors.red)),
          ),
        ],
      ),
    );
    if (confirmou != true) return;
    try {
      await _api.deletarCasa(casa.id);
      await _carregarCasas();
    } catch (e) {
      _mostrarErro('Não consegui excluir: $e');
    }
  }

  Future<void> _definirBancaCasa(Casa casa) async {
    final controlador = TextEditingController(text: casa.bancaInicial?.toStringAsFixed(2) ?? '');
    final valor = await showDialog<double>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.superficieAlta,
        title: Text('Banca na ${casa.nome}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.only(bottom: 12),
              child: Text(
                'Quanto você depositou nessa casa? Isso permite ver a banca atual e o ROI específicos dela.',
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
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          TextButton(
            onPressed: () {
              final texto = controlador.text.trim().replaceAll(',', '.');
              Navigator.pop(context, double.tryParse(texto) ?? 0);
            },
            child: const Text('Salvar'),
          ),
        ],
      ),
    );
    if (valor == null) return;
    try {
      await _api.atualizarBancaCasa(casa.id, valor);
      await _carregarCasas();
    } catch (e) {
      _mostrarErro('Não consegui salvar: $e');
    }
  }

  void _escolherCasa(String nomeCasa) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.superficieAlta,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _MenuMetodoEntrada(nomeCasa: nomeCasa),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Escolha a casa')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controladorNovaCasa,
                    decoration: const InputDecoration(hintText: 'Cadastrar nova casa (ex: Betano)'),
                    onSubmitted: (_) => _criarCasa(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  onPressed: _adicionando ? null : _criarCasa,
                  icon: const Icon(Icons.add),
                ),
              ],
            ),
          ),
          Expanded(
            child: _carregando
                ? const Center(child: CircularProgressIndicator())
                : _casas.isEmpty
                    ? const _EstadoVazio()
                    : ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: _casas.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, i) {
                          final casa = _casas[i];
                          return Card(
                            child: ListTile(
                              title: Text(casa.nome, style: const TextStyle(fontWeight: FontWeight.w600)),
                              subtitle: Text(
                                casa.bancaInicial != null
                                    ? '${casa.vezesUsada} apostas · banca R\$ ${casa.bancaInicial!.toStringAsFixed(2)}'
                                    : (casa.vezesUsada == 1 ? '1 aposta registrada' : '${casa.vezesUsada} apostas registradas'),
                                style: const TextStyle(color: AppColors.textoSecundario, fontSize: 12.5),
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    onPressed: () => _definirBancaCasa(casa),
                                    icon: const Icon(Icons.account_balance_wallet_outlined, size: 20),
                                    color: AppColors.textoSecundario,
                                    tooltip: 'Definir banca',
                                  ),
                                  IconButton(
                                    onPressed: () => _excluirCasa(casa),
                                    icon: const Icon(Icons.delete_outline, size: 20),
                                    color: AppColors.textoSecundario,
                                  ),
                                  const Icon(Icons.chevron_right, color: AppColors.textoSecundario),
                                ],
                              ),
                              onTap: () => _escolherCasa(casa.nome),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}

class _EstadoVazio extends StatelessWidget {
  const _EstadoVazio();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.all(32),
      child: Center(
        child: Text(
          'Nenhuma casa cadastrada ainda.\nAdicione a primeira no campo acima.',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.textoSecundario),
        ),
      ),
    );
  }
}

/// Bottom sheet com as duas formas de registrar a aposta depois de escolher a casa.
class _MenuMetodoEntrada extends StatelessWidget {
  final String nomeCasa;
  const _MenuMetodoEntrada({required this.nomeCasa});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(nomeCasa, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined, color: AppColors.destaque),
              title: const Text('Ler print da aposta'),
              subtitle: const Text('OCR local, sem internet', style: TextStyle(color: AppColors.textoSecundario)),
              onTap: () {
                Navigator.pop(context); // fecha o bottom sheet
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => CapturarApostaScreen(casa: nomeCasa)),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.edit_outlined, color: AppColors.destaque),
              title: const Text('Digitar manualmente'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => ApostaFormScreen(casa: nomeCasa)),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
