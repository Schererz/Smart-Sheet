import 'dart:ui' as ui;
import 'package:image_picker/image_picker.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

import '../models/bloco_ocr.dart';

/// Tira/escolhe uma foto e roda o reconhecimento de texto TOTALMENTE no
/// aparelho (ML Kit é offline — não depende de internet, e só funciona no
/// celular). Cada linha reconhecida vira um BlocoOCR com posição normalizada
/// (0 a 1), pra poder comparar blocos de imagens com tamanhos diferentes.
///
/// Usa XFile (não File do dart:io) em todo o serviço — assim esse arquivo
/// compila normalmente tanto pro celular quanto pra web, mesmo que o
/// reconhecimento em si (lerBlocos) só funcione no celular.
class OcrService {
  final ImagePicker _picker = ImagePicker();
  final TextRecognizer _recognizer = TextRecognizer(script: TextRecognitionScript.latin);

  Future<XFile?> escolherImagem({required bool daCamera}) async {
    return _picker.pickImage(
      source: daCamera ? ImageSource.camera : ImageSource.gallery,
      imageQuality: 90,
    );
  }

  /// Escolhe várias imagens de uma vez na galeria — usado pra montar a fila
  /// de apostas pra processar uma por uma, sem precisar reabrir o fluxo a
  /// cada print.
  Future<List<XFile>> escolherMultiplasImagens() async {
    return _picker.pickMultiImage(imageQuality: 90);
  }

  /// Processa a imagem e devolve os blocos de texto com posição normalizada.
  /// Usa cada LINHA reconhecida (não o bloco inteiro) pra ter granularidade
  /// suficiente pra separar odd/valor/retorno mesmo quando estão próximos.
  ///
  /// SÓ FUNCIONA NO CELULAR — o ML Kit é uma biblioteca nativa Android/iOS.
  /// Na web, use ApiService.lerImagemViaServidor em vez disso.
  Future<List<BlocoOCR>> lerBlocos(XFile imagem) async {
    final inputImage = InputImage.fromFilePath(imagem.path);
    final RecognizedText resultado = await _recognizer.processImage(inputImage);

    final tamanho = await _tamanhoDaImagem(imagem);
    final larguraImg = tamanho.width;
    final alturaImg = tamanho.height;
    if (larguraImg == 0 || alturaImg == 0) return [];

    final blocos = <BlocoOCR>[];
    for (final bloco in resultado.blocks) {
      for (final linha in bloco.lines) {
        final r = linha.boundingBox;
        blocos.add(BlocoOCR(
          texto: linha.text,
          x: r.left / larguraImg,
          y: r.top / alturaImg,
          largura: r.width / larguraImg,
          altura: r.height / alturaImg,
        ));
      }
    }
    return blocos;
  }

  Future<ui.Size> _tamanhoDaImagem(XFile imagem) async {
    final bytes = await imagem.readAsBytes();
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    return ui.Size(frame.image.width.toDouble(), frame.image.height.toDouble());
  }

  void dispose() {
    _recognizer.close();
  }
}
