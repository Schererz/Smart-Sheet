import 'bloco_ocr.dart';

/// Espelha models.py::ResultadoAposta no backend. Nessa ordem porque é a
/// ordem do ciclo do botão de status: aberto -> green -> red -> aberto...
enum ResultadoAposta { aberto, green, red }

ResultadoAposta resultadoFromString(String valor) {
  return ResultadoAposta.values.firstWhere(
    (r) => r.name == valor,
    orElse: () => ResultadoAposta.aberto,
  );
}

class Aposta {
  final int? id;
  final DateTime data;
  final String casaDeApostas;
  final String? descricao;
  final double odd;
  final double valorApostado;
  final double? retornoPotencial;
  final double? aumentoPercentual;
  final ResultadoAposta resultado;
  final double? lucro;
  final String origem;
  final String? tipster;

  Aposta({
    this.id,
    required this.data,
    required this.casaDeApostas,
    this.descricao,
    required this.odd,
    required this.valorApostado,
    this.retornoPotencial,
    this.aumentoPercentual,
    this.resultado = ResultadoAposta.aberto,
    this.lucro,
    this.origem = 'manual',
    this.tipster,
  });

  factory Aposta.fromJson(Map<String, dynamic> json) {
    return Aposta(
      id: json['id'] as int?,
      data: DateTime.parse(json['data'] as String),
      casaDeApostas: json['casa_de_apostas'] as String,
      descricao: json['descricao'] as String?,
      odd: (json['odd'] as num).toDouble(),
      valorApostado: (json['valor_apostado'] as num).toDouble(),
      retornoPotencial: (json['retorno_potencial'] as num?)?.toDouble(),
      aumentoPercentual: (json['aumento_percentual'] as num?)?.toDouble(),
      resultado: resultadoFromString(json['resultado'] as String),
      lucro: (json['lucro'] as num?)?.toDouble(),
      origem: json['origem'] as String? ?? 'manual',
      tipster: json['tipster'] as String?,
    );
  }

  /// Formato esperado pelo POST /apostas/ (schemas.py::BetCreate).
  Map<String, dynamic> paraCriacao({
    List<BlocoOCR>? blocosOcr,
    RascunhoAposta? sugestaoOriginal,
  }) {
    return {
      'data': data.toIso8601String().split('T').first,
      'casa_de_apostas': casaDeApostas,
      'descricao': descricao,
      'odd': odd,
      'valor_apostado': valorApostado,
      'retorno_potencial': retornoPotencial,
      'aumento_percentual': aumentoPercentual,
      'resultado': resultado.name,
      'origem': origem,
      'tipster': tipster,
      if (blocosOcr != null) 'blocos_ocr': blocosOcr.map((b) => b.toJson()).toList(),
      if (sugestaoOriginal != null) 'sugestao_original': sugestaoOriginal.toJson(),
    };
  }
}

class ResumoStats {
  final int totalApostas;
  final double totalApostado;
  final double lucroTotal;
  final double? taxaAcerto;
  final double? roi;
  final double bancaInicial;
  final double bancaAtual;
  final double? oddMedia;
  final double? valorMedioApostado;
  final double? maiorLucro;
  final double? maiorPrejuizo;
  final int apostasEmAberto;

  ResumoStats({
    required this.totalApostas,
    required this.totalApostado,
    required this.lucroTotal,
    this.taxaAcerto,
    this.roi,
    this.bancaInicial = 0,
    this.bancaAtual = 0,
    this.oddMedia,
    this.valorMedioApostado,
    this.maiorLucro,
    this.maiorPrejuizo,
    this.apostasEmAberto = 0,
  });

  factory ResumoStats.fromJson(Map<String, dynamic> json) {
    return ResumoStats(
      totalApostas: json['total_apostas'] as int,
      totalApostado: (json['total_apostado'] as num).toDouble(),
      lucroTotal: (json['lucro_total'] as num).toDouble(),
      taxaAcerto: (json['taxa_acerto'] as num?)?.toDouble(),
      roi: (json['roi'] as num?)?.toDouble(),
      bancaInicial: (json['banca_inicial'] as num?)?.toDouble() ?? 0,
      bancaAtual: (json['banca_atual'] as num?)?.toDouble() ?? 0,
      oddMedia: (json['odd_media'] as num?)?.toDouble(),
      valorMedioApostado: (json['valor_medio_apostado'] as num?)?.toDouble(),
      maiorLucro: (json['maior_lucro'] as num?)?.toDouble(),
      maiorPrejuizo: (json['maior_prejuizo'] as num?)?.toDouble(),
      apostasEmAberto: json['apostas_em_aberto'] as int? ?? 0,
    );
  }

  factory ResumoStats.vazio() => ResumoStats(totalApostas: 0, totalApostado: 0, lucroTotal: 0);
}

class Configuracao {
  final double bancaInicial;
  final bool definida;

  Configuracao({required this.bancaInicial, required this.definida});

  factory Configuracao.fromJson(Map<String, dynamic> json) {
    return Configuracao(
      bancaInicial: (json['banca_inicial'] as num).toDouble(),
      definida: json['definida'] as bool,
    );
  }
}

class PontoEvolucaoBanca {
  final DateTime data;
  final double banca;
  final String? descricao;

  PontoEvolucaoBanca({required this.data, required this.banca, this.descricao});

  factory PontoEvolucaoBanca.fromJson(Map<String, dynamic> json) {
    return PontoEvolucaoBanca(
      data: DateTime.parse(json['data'] as String),
      banca: (json['banca'] as num).toDouble(),
      descricao: json['descricao'] as String?,
    );
  }
}
