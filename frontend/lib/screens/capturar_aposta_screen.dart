import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart' show XFile;

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

  final List<XFile> _fila = [];
  int _totalNaFila = 0; // guarda o tamanho original pra mostrar "X de Y"
  bool _processando = false;
  String? _erro;
  int _salvas = 0;

  /// No celular usa o ML Kit local (offline). Na web, que não tem ML Kit,
  /// manda a imagem pro backend ler via Google Cloud Vision.
  Future<List<BlocoOCR>> _lerImagem(XFile imagem) {
    if (kIsWeb) return _api.lerImagemViaServidor(imagem);
    return _ocr.lerBlocos(imagem);
  }

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
        final bytesImagem = await imagem.readAsBytes();
        final blocos = await _lerImagem(imagem);
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
              imagemBytes: bytesImagem,
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
            if (kIsWeb)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: AppColors.destaque.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text(
                  'Na versão web, a leitura da imagem acontece no servidor (pode levar alguns segundos a mais que no celular).',
                  style: TextStyle(fontSize: 12, color: AppColors.textoSecundario),
                ),
              ),
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
                if (!kIsWeb)
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _processando ? null : _adicionarDaCamera,
                      icon: const Icon(Icons.camera_alt_outlined),
                      label: const Text('Câmera'),
                    ),
                  ),
                if (!kIsWeb) const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _processando ? null : _adicionarDaGaleria,
                    icon: const Icon(Icons.photo_library_outlined),
                    label: Text(kIsWeb ? 'Escolher imagens' : 'Galeria (várias)'),
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
