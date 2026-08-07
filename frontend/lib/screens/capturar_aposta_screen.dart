import 'dart:io';
import 'package:flutter/material.dart';

import '../models/bloco_ocr.dart';
import '../services/api_service.dart';
import '../services/ocr_service.dart';
import '../theme/app_theme.dart';
import 'aposta_form_screen.dart';

class CapturarApostaScreen extends StatefulWidget {
  final String casa;
  const CapturarApostaScreen({super.key, required this.casa});

  @override
  State<CapturarApostaScreen> createState() => _CapturarApostaScreenState();
}

class _CapturarApostaScreenState extends State<CapturarApostaScreen> {
  final _ocr = OcrService();
  final _api = ApiService();

  final List<File> _fila = [];
  int _totalNaFila = 0; // guarda o tamanho original pra mostrar "X de Y"
  bool _processando = false;
  String? _erro;
  int _salvas = 0;

  Future<void> _adicionarDaCamera() async {
    setState(() => _erro = null);
    final arquivo = await _ocr.escolherImagem(daCamera: true);
    if (arquivo == null) return; // usuário cancelou
    setState(() {
      _fila.add(arquivo);
      _totalNaFila = _fila.length;
    });
    if (!_processando) _processarFila();
  }

  Future<void> _adicionarDaGaleria() async {
    setState(() => _erro = null);
    final arquivos = await _ocr.escolherMultiplasImagens();
    if (arquivos.isEmpty) return; // usuário cancelou
    setState(() {
      _fila.addAll(arquivos);
      _totalNaFila = _fila.length;
    });
    if (!_processando) _processarFila();
  }

  Future<void> _processarFila() async {
    setState(() => _processando = true);

    while (_fila.isNotEmpty) {
      final imagem = _fila.removeAt(0);
      setState(() {}); // atualiza o contador "X de Y" na tela

      try {
        final blocos = await _ocr.lerBlocos(imagem);
        final rascunho = await _api.analisarBlocos(widget.casa, blocos);

        if (!mounted) return;
        final salvou = await Navigator.push<bool>(
          context,
          MaterialPageRoute(
            builder: (_) => ApostaFormScreen(
              casa: widget.casa,
              origem: 'ocr',
              rascunho: rascunho,
              blocosOcr: blocos,
              imagemCapturada: imagem,
            ),
          ),
        );
        if (salvou == true) _salvas++;
      } catch (e) {
        if (mounted) {
          setState(() => _erro = 'Não consegui processar uma das imagens: $e');
        }
      }
    }

    _totalNaFila = 0;
    if (mounted) setState(() => _processando = false);

    // Fila acabou: se salvou pelo menos uma, avisa a tela anterior pra recarregar.
    if (_salvas > 0 && mounted) {
      Navigator.pop(context, true);
    }
  }

  @override
  void dispose() {
    _ocr.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final naFila = _fila.length;
    final posicaoAtual = _totalNaFila - naFila; // já processadas + a atual

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _processando && _totalNaFila > 1
              ? 'Print ${posicaoAtual.clamp(1, _totalNaFila)} de $_totalNaFila — ${widget.casa}'
              : 'Print da ${widget.casa}',
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: AppColors.superficie,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.borda),
                ),
                clipBehavior: Clip.antiAlias,
                child: _processando
                    ? const Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircularProgressIndicator(),
                            SizedBox(height: 16),
                            Text('Lendo a imagem...', style: TextStyle(color: AppColors.textoSecundario)),
                          ],
                        ),
                      )
                    : const Center(
                        child: Padding(
                          padding: EdgeInsets.all(24),
                          child: Text(
                            'Tire uma foto do print da aposta,\nou escolha uma ou várias da galeria',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: AppColors.textoSecundario),
                          ),
                        ),
                      ),
              ),
            ),
            if (_erro != null) ...[
              const SizedBox(height: 12),
              Text(_erro!, style: const TextStyle(color: AppColors.red), textAlign: TextAlign.center),
            ],
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _processando ? null : _adicionarDaCamera,
                    icon: const Icon(Icons.camera_alt_outlined),
                    label: const Text('Câmera'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _processando ? null : _adicionarDaGaleria,
                    icon: const Icon(Icons.photo_library_outlined),
                    label: const Text('Galeria (várias)'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
