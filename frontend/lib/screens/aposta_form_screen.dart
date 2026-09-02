import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:intl/intl.dart';

import '../models/aposta.dart';
import '../models/bloco_ocr.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';

class ApostaFormScreen extends StatefulWidget {
  final String casa;
  final String origem; // 'manual' ou 'ocr'
  final RascunhoAposta? rascunho; // preenchido quando vem do OCR
  final List<BlocoOCR>? blocosOcr; // guardado junto com a aposta (dataset de treino)
  final Uint8List? imagemBytes; // exibida no formulário, útil se o OCR errar e precisar ajustar na mão
  final Aposta? apostaExistente; // preenchido quando é EDIÇÃO de uma aposta já salva

  const ApostaFormScreen({
    super.key,
    required this.casa,
    this.origem = 'manual',
    this.rascunho,
    this.blocosOcr,
    this.imagemBytes,
    this.apostaExistente,
  });

  @override
  State<ApostaFormScreen> createState() => _ApostaFormScreenState();
}

class _ApostaFormScreenState extends State<ApostaFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _api = ApiService();

  late final TextEditingController _descricao;
  late final TextEditingController _tipster;
  late final TextEditingController _odd;
  late final TextEditingController _valorApostado;
  late final TextEditingController _retornoPotencial;
  DateTime _data = DateTime.now();
  bool _salvando = false;

  bool _turbinada = false;
  double? _aumentoPercentual;
  static const _opcoesAumento = [10.0, 25.0, 30.0, 50.0];

  late ResultadoAposta _resultado;

  @override
  void initState() {
    super.initState();
    final r = widget.rascunho;
    final a = widget.apostaExistente;

    _descricao = TextEditingController(text: a?.descricao ?? r?.descricao ?? '');
    _tipster = TextEditingController(text: a?.tipster ?? '');
    _odd = TextEditingController(text: (a?.odd ?? r?.odd)?.toStringAsFixed(2) ?? '');
    _valorApostado = TextEditingController(text: (a?.valorApostado ?? r?.valorApostado)?.toStringAsFixed(2) ?? '');
    _retornoPotencial = TextEditingController(
      text: (a?.retornoPotencial ?? r?.retornoPotencial)?.toStringAsFixed(2) ?? '',
    );

    if (a != null) {
      _data = a.data;
      _resultado = a.resultado;
      if (a.aumentoPercentual != null) {
        _turbinada = true;
        _aumentoPercentual = a.aumentoPercentual;
      }
    } else {
      if (r?.aumentoPercentual != null) {
        _turbinada = true;
        _aumentoPercentual = r!.aumentoPercentual;
      }
      if (r?.dataSugerida != null) {
        _data = r!.dataSugerida!;
      }
      _resultado = r?.resultadoSugerido != null ? resultadoFromString(r!.resultadoSugerido!) : ResultadoAposta.aberto;
    }

    // Recalcula o retorno turbinado sempre que odd/valor mudam, sem precisar
    // esperar o usuário terminar de digitar tudo.
    _odd.addListener(_recalcularSeTurbinada);
    _valorApostado.addListener(_recalcularSeTurbinada);
    if (_turbinada && widget.apostaExistente == null) _recalcularSeTurbinada();
  }

  @override
  void dispose() {
    _descricao.dispose();
    _tipster.dispose();
    _odd.dispose();
    _valorApostado.dispose();
    _retornoPotencial.dispose();
    super.dispose();
  }

  double? _paraDouble(String texto) {
    if (texto.trim().isEmpty) return null;
    return double.tryParse(texto.trim().replaceAll(',', '.'));
  }

  /// Mesma fórmula do backend (models.py::calcular_retorno_com_aumento):
  /// o aumento é aplicado sobre o LUCRO, não sobre o retorno total.
  /// Calculado localmente pra dar feedback instantâneo, sem round-trip de rede.
  double _calcularRetornoTurbinado(double valor, double odd, double aumento) {
    final lucroNormal = valor * (odd - 1);
    final lucroAumentado = lucroNormal * (1 + aumento / 100);
    return valor + lucroAumentado;
  }

  void _recalcularSeTurbinada() {
    if (!_turbinada || _aumentoPercentual == null) return;
    final odd = _paraDouble(_odd.text);
    final valor = _paraDouble(_valorApostado.text);
    if (odd == null || valor == null) return;
    final retorno = _calcularRetornoTurbinado(valor, odd, _aumentoPercentual!);
    _retornoPotencial.text = retorno.toStringAsFixed(2);
  }

  void _selecionarAumento(double? valor) {
    setState(() => _aumentoPercentual = valor);
    _recalcularSeTurbinada();
  }

  Future<double?> _pedirPorcentagemCustomizada() async {
    final controlador = TextEditingController();
    return showDialog<double>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.superficieAlta,
        title: const Text('Qual a porcentagem do aumento?'),
        content: TextField(
          controller: controlador,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(hintText: 'Ex: 40'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          TextButton(
            onPressed: () => Navigator.pop(context, _paraDouble(controlador.text)),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _selecionarData() async {
    final escolhida = await showDatePicker(
      context: context,
      initialDate: _data,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (escolhida != null) setState(() => _data = escolhida);
  }

  Future<void> _salvar() async {
    if (!_formKey.currentState!.validate()) return;
    if (_turbinada && _aumentoPercentual == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Escolha a porcentagem do aumento, ou desative a opção turbinada.')),
      );
      return;
    }
    setState(() => _salvando = true);

    try {
      if (widget.apostaExistente != null) {
        await _api.atualizarAposta(widget.apostaExistente!.id!, {
          'data': _data.toIso8601String().split('T').first,
          'descricao': _descricao.text.trim().isEmpty ? null : _descricao.text.trim(),
          'odd': _paraDouble(_odd.text),
          'valor_apostado': _paraDouble(_valorApostado.text),
          'retorno_potencial': _paraDouble(_retornoPotencial.text),
          'aumento_percentual': _turbinada ? _aumentoPercentual : null,
          'resultado': _resultado.name,
          'tipster': _tipster.text.trim().isEmpty ? null : _tipster.text.trim(),
        });
      } else {
        final aposta = Aposta(
          data: _data,
          casaDeApostas: widget.casa,
          descricao: _descricao.text.trim().isEmpty ? null : _descricao.text.trim(),
          odd: _paraDouble(_odd.text)!,
          valorApostado: _paraDouble(_valorApostado.text)!,
          retornoPotencial: _paraDouble(_retornoPotencial.text),
          aumentoPercentual: _turbinada ? _aumentoPercentual : null,
          resultado: _resultado,
          origem: widget.origem,
          tipster: _tipster.text.trim().isEmpty ? null : _tipster.text.trim(),
        );
        await _api.criarAposta(aposta, blocosOcr: widget.blocosOcr, sugestaoOriginal: widget.rascunho);
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Não consegui salvar: $e')));
      }
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final vindoDoOcr = widget.origem == 'ocr';
    final editando = widget.apostaExistente != null;

    return Scaffold(
      appBar: AppBar(title: Text(editando ? 'Editar aposta' : (vindoDoOcr ? 'Confirmar aposta' : 'Nova aposta'))),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            if (widget.imagemBytes != null)
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.borda),
                ),
                clipBehavior: Clip.antiAlias,
                child: Image.memory(widget.imagemBytes!, height: 220, width: double.infinity, fit: BoxFit.contain),
              ),
            if (vindoDoOcr)
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: AppColors.destaque.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.info_outline, color: AppColors.destaque, size: 18),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Confira os campos abaixo — foram lidos da imagem automaticamente.',
                        style: TextStyle(fontSize: 12.5, color: AppColors.textoPrimario),
                      ),
                    ),
                  ],
                ),
              ),
            if (vindoDoOcr && widget.rascunho?.textoLimpo != null && widget.rascunho!.textoLimpo!.trim().isNotEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(color: AppColors.superficie, borderRadius: BorderRadius.circular(10)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Se algum campo veio errado, copie o texto abaixo e cole na descrição:',
                            style: TextStyle(fontSize: 12, color: AppColors.textoSecundario),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.copy_outlined, size: 18),
                          color: AppColors.destaque,
                          tooltip: 'Copiar',
                          onPressed: () async {
                            await Clipboard.setData(ClipboardData(text: widget.rascunho!.textoLimpo!));
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Copiado!')),
                              );
                            }
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    SelectableText(
                      widget.rascunho!.textoLimpo!,
                      style: const TextStyle(fontSize: 13, color: AppColors.textoPrimario),
                    ),
                  ],
                ),
              ),
            if (vindoDoOcr && widget.blocosOcr != null && widget.blocosOcr!.isNotEmpty)
              Theme(
                data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                child: ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  title: const Text('Ver texto bruto (debug)', style: TextStyle(fontSize: 12.5, color: AppColors.textoSecundario)),
                  collapsedIconColor: AppColors.textoSecundario,
                  iconColor: AppColors.textoSecundario,
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(color: AppColors.superficie, borderRadius: BorderRadius.circular(10)),
                      child: SelectableText(
                        widget.blocosOcr!.map((b) => b.texto).join('\n'),
                        style: const TextStyle(fontSize: 12, fontFamily: 'monospace', color: AppColors.textoSecundario),
                      ),
                    ),
                  ],
                ),
              ),
            _RotuloCampo('Casa'),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(color: AppColors.superficie, borderRadius: BorderRadius.circular(12)),
              child: Text(widget.casa, style: const TextStyle(fontWeight: FontWeight.w600)),
            ),
            const SizedBox(height: 16),
            _RotuloCampo('Data'),
            InkWell(
              onTap: _selecionarData,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(color: AppColors.superficieAlta, borderRadius: BorderRadius.circular(12)),
                child: Row(
                  children: [
                    Text(DateFormat('dd/MM/yyyy').format(_data)),
                    const Spacer(),
                    const Icon(Icons.calendar_today_outlined, size: 18, color: AppColors.textoSecundario),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            _RotuloCampo('Status'),
            Row(
              children: [
                _ChipStatus(
                  rotulo: 'Aberto',
                  cor: AppColors.aberto,
                  selecionado: _resultado == ResultadoAposta.aberto,
                  onTap: () => setState(() => _resultado = ResultadoAposta.aberto),
                ),
                const SizedBox(width: 8),
                _ChipStatus(
                  rotulo: 'Green',
                  cor: AppColors.green,
                  selecionado: _resultado == ResultadoAposta.green,
                  onTap: () => setState(() => _resultado = ResultadoAposta.green),
                ),
                const SizedBox(width: 8),
                _ChipStatus(
                  rotulo: 'Red',
                  cor: AppColors.red,
                  selecionado: _resultado == ResultadoAposta.red,
                  onTap: () => setState(() => _resultado = ResultadoAposta.red),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _RotuloCampo('Descrição'),
            TextFormField(
              controller: _descricao,
              decoration: const InputDecoration(hintText: 'Ex: Flamengo x Palmeiras - Over 2.5'),
            ),
            const SizedBox(height: 16),
            _RotuloCampo('Tipster (opcional)'),
            TextFormField(
              controller: _tipster,
              decoration: const InputDecoration(hintText: 'Ex: Girino, Props'),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _CampoNumerico(
                    rotulo: 'Odd',
                    controlador: _odd,
                    obrigatorio: true,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _CampoNumerico(
                    rotulo: 'Valor apostado',
                    controlador: _valorApostado,
                    obrigatorio: true,
                    prefixo: 'R\$ ',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: AppColors.superficie, borderRadius: BorderRadius.circular(12)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Ganho aumentado (turbinada)',
                          style: TextStyle(fontWeight: FontWeight.w600, color: _turbinada ? null : AppColors.textoSecundario),
                        ),
                      ),
                      Switch(
                        value: _turbinada,
                        onChanged: (valor) {
                          setState(() => _turbinada = valor);
                          if (valor) {
                            _recalcularSeTurbinada();
                          }
                        },
                      ),
                    ],
                  ),
                  if (_turbinada) ...[
                    const SizedBox(height: 4),
                    const Text(
                      'O retorno abaixo é calculado automaticamente com o aumento sobre o lucro.',
                      style: TextStyle(fontSize: 12, color: AppColors.textoSecundario),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      children: [
                        ..._opcoesAumento.map((valor) => ChoiceChip(
                              label: Text('${valor.toStringAsFixed(0)}%'),
                              selected: _aumentoPercentual == valor,
                              onSelected: (_) => _selecionarAumento(valor),
                            )),
                        ActionChip(
                          label: Text(
                            _aumentoPercentual != null && !_opcoesAumento.contains(_aumentoPercentual)
                                ? '${_aumentoPercentual!.toStringAsFixed(0)}%'
                                : 'Outro %',
                          ),
                          onPressed: () async {
                            final valor = await _pedirPorcentagemCustomizada();
                            if (valor != null) _selecionarAumento(valor);
                          },
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),
            _CampoNumerico(
              rotulo: _turbinada ? 'Retorno potencial (calculado)' : 'Retorno potencial (opcional)',
              controlador: _retornoPotencial,
              obrigatorio: false,
              prefixo: 'R\$ ',
              somenteLeitura: _turbinada,
            ),
            const SizedBox(height: 28),
            ElevatedButton(
              onPressed: _salvando ? null : _salvar,
              child: _salvando
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : Text(editando ? 'Salvar alterações' : 'Salvar aposta'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChipStatus extends StatelessWidget {
  final String rotulo;
  final Color cor;
  final bool selecionado;
  final VoidCallback onTap;

  const _ChipStatus({
    required this.rotulo,
    required this.cor,
    required this.selecionado,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: selecionado ? cor.withValues(alpha: 0.18) : AppColors.superficie,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: selecionado ? cor.withValues(alpha: 0.6) : AppColors.borda),
        ),
        child: Text(
          rotulo,
          style: TextStyle(
            color: selecionado ? cor : AppColors.textoSecundario,
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}

class _RotuloCampo extends StatelessWidget {
  final String texto;
  const _RotuloCampo(this.texto);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(texto, style: const TextStyle(fontSize: 12.5, color: AppColors.textoSecundario, fontWeight: FontWeight.w600)),
    );
  }
}

class _CampoNumerico extends StatelessWidget {
  final String rotulo;
  final TextEditingController controlador;
  final bool obrigatorio;
  final String? prefixo;
  final bool somenteLeitura;

  const _CampoNumerico({
    required this.rotulo,
    required this.controlador,
    required this.obrigatorio,
    this.prefixo,
    this.somenteLeitura = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _RotuloCampo(rotulo),
        TextFormField(
          controller: controlador,
          readOnly: somenteLeitura,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(hintText: prefixo != null ? '${prefixo}0,00' : '0,00'),
          validator: (valor) {
            if (!obrigatorio) return null;
            if (valor == null || valor.trim().isEmpty) return 'Obrigatório';
            if (double.tryParse(valor.trim().replaceAll(',', '.')) == null) return 'Número inválido';
            return null;
          },
        ),
      ],
    );
  }
}
