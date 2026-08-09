/// Um bloco de texto detectado pelo OCR na imagem, com posição normalizada
/// (0 a 1) em relação ao tamanho da imagem. Espelha app/schemas.py::BlocoOCR
/// do backend.
class BlocoOCR {
  final String texto;
  final double x;
  final double y;
  final double largura;
  final double altura;

  BlocoOCR({
    required this.texto,
    required this.x,
    required this.y,
    required this.largura,
    required this.altura,
  });

  factory BlocoOCR.fromJson(Map<String, dynamic> json) {
    return BlocoOCR(
      texto: json['texto'] as String,
      x: (json['x'] as num).toDouble(),
      y: (json['y'] as num).toDouble(),
      largura: (json['largura'] as num).toDouble(),
      altura: (json['altura'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toJson() => {
        'texto': texto,
        'x': x,
        'y': y,
        'largura': largura,
        'altura': altura,
      };
}

/// O rascunho que o backend sugere depois de analisar os blocos — o usuário
/// confirma ou corrige antes de salvar. Espelha schemas.py::RascunhoAposta.
class RascunhoAposta {
  final double? odd;
  final double? valorApostado;
  final double? retornoPotencial;
  final double? aumentoPercentual;
  final String? descricao;
  final String? resultadoSugerido;

  RascunhoAposta({
    this.odd,
    this.valorApostado,
    this.retornoPotencial,
    this.aumentoPercentual,
    this.descricao,
    this.resultadoSugerido,
  });

  factory RascunhoAposta.fromJson(Map<String, dynamic> json) {
    return RascunhoAposta(
      odd: (json['odd'] as num?)?.toDouble(),
      valorApostado: (json['valor_apostado'] as num?)?.toDouble(),
      retornoPotencial: (json['retorno_potencial'] as num?)?.toDouble(),
      aumentoPercentual: (json['aumento_percentual'] as num?)?.toDouble(),
      descricao: json['descricao'] as String?,
      resultadoSugerido: json['resultado_sugerido'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'odd': odd,
        'valor_apostado': valorApostado,
        'retorno_potencial': retornoPotencial,
        'aumento_percentual': aumentoPercentual,
        'descricao': descricao,
        'resultado_sugerido': resultadoSugerido,
      };
}
