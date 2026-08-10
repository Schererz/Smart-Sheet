class Casa {
  final int id;
  final String nome;
  final int vezesUsada;
  final double? bancaInicial;

  Casa({required this.id, required this.nome, required this.vezesUsada, this.bancaInicial});

  factory Casa.fromJson(Map<String, dynamic> json) {
    return Casa(
      id: json['id'] as int,
      nome: json['nome'] as String,
      vezesUsada: json['vezes_usada'] as int,
      bancaInicial: (json['banca_inicial'] as num?)?.toDouble(),
    );
  }
}

class ResumoPorCasa {
  final String casa;
  final int totalApostas;
  final double totalApostado;
  final double lucroTotal;
  final double? taxaAcerto;
  final double? oddMedia;
  final double? roiApostado;
  final double? bancaInicial;
  final double? bancaAtual;
  final double? roiBanca;

  ResumoPorCasa({
    required this.casa,
    required this.totalApostas,
    required this.totalApostado,
    required this.lucroTotal,
    this.taxaAcerto,
    this.oddMedia,
    this.roiApostado,
    this.bancaInicial,
    this.bancaAtual,
    this.roiBanca,
  });

  factory ResumoPorCasa.fromJson(Map<String, dynamic> json) {
    return ResumoPorCasa(
      casa: json['casa'] as String,
      totalApostas: json['total_apostas'] as int,
      totalApostado: (json['total_apostado'] as num).toDouble(),
      lucroTotal: (json['lucro_total'] as num).toDouble(),
      taxaAcerto: (json['taxa_acerto'] as num?)?.toDouble(),
      oddMedia: (json['odd_media'] as num?)?.toDouble(),
      roiApostado: (json['roi_apostado'] as num?)?.toDouble(),
      bancaInicial: (json['banca_inicial'] as num?)?.toDouble(),
      bancaAtual: (json['banca_atual'] as num?)?.toDouble(),
      roiBanca: (json['roi_banca'] as num?)?.toDouble(),
    );
  }
}

class PontoLucroDia {
  final DateTime data;
  final double lucro;
  final int totalApostas;

  PontoLucroDia({required this.data, required this.lucro, required this.totalApostas});

  factory PontoLucroDia.fromJson(Map<String, dynamic> json) {
    return PontoLucroDia(
      data: DateTime.parse(json['data'] as String),
      lucro: (json['lucro'] as num).toDouble(),
      totalApostas: json['total_apostas'] as int,
    );
  }
}
