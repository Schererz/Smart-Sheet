class StatusUnidade {
  final double? unidadeAtual;
  final DateTime? dataUltimoRecalculo;
  final int intervaloDias;
  final DateTime? proximaDataRecalculo;
  final bool recalculoPendente;
  final double unidadeSeRecalcularAgora;

  StatusUnidade({
    required this.unidadeAtual,
    required this.dataUltimoRecalculo,
    required this.intervaloDias,
    required this.proximaDataRecalculo,
    required this.recalculoPendente,
    required this.unidadeSeRecalcularAgora,
  });

  factory StatusUnidade.fromJson(Map<String, dynamic> json) {
    return StatusUnidade(
      unidadeAtual: (json['unidade_atual'] as num?)?.toDouble(),
      dataUltimoRecalculo:
          json['data_ultimo_recalculo'] != null ? DateTime.parse(json['data_ultimo_recalculo'] as String) : null,
      intervaloDias: json['intervalo_dias'] as int,
      proximaDataRecalculo:
          json['proxima_data_recalculo'] != null ? DateTime.parse(json['proxima_data_recalculo'] as String) : null,
      recalculoPendente: json['recalculo_pendente'] as bool,
      unidadeSeRecalcularAgora: (json['unidade_se_recalcular_agora'] as num).toDouble(),
    );
  }
}

class ItemSugestaoDeposito {
  final String casa;
  final double lucroPeriodo;
  final double participacaoPct;
  final double sugerido;

  ItemSugestaoDeposito({
    required this.casa,
    required this.lucroPeriodo,
    required this.participacaoPct,
    required this.sugerido,
  });

  factory ItemSugestaoDeposito.fromJson(Map<String, dynamic> json) {
    return ItemSugestaoDeposito(
      casa: json['casa'] as String,
      lucroPeriodo: (json['lucro_periodo'] as num).toDouble(),
      participacaoPct: (json['participacao_pct'] as num).toDouble(),
      sugerido: (json['sugerido'] as num).toDouble(),
    );
  }
}

class SugestaoDeposito {
  final List<ItemSugestaoDeposito> sugestoes;
  final double bancoSugerido;
  final double novaUnidadeSugerida;
  final bool bancaInsuficienteParaMinimos;

  SugestaoDeposito({
    required this.sugestoes,
    required this.bancoSugerido,
    required this.novaUnidadeSugerida,
    required this.bancaInsuficienteParaMinimos,
  });

  factory SugestaoDeposito.fromJson(Map<String, dynamic> json) {
    return SugestaoDeposito(
      sugestoes: (json['sugestoes'] as List).map((j) => ItemSugestaoDeposito.fromJson(j)).toList(),
      bancoSugerido: (json['banco_sugerido'] as num).toDouble(),
      novaUnidadeSugerida: (json['nova_unidade_sugerida'] as num).toDouble(),
      bancaInsuficienteParaMinimos: json['banca_insuficiente_para_minimos'] as bool,
    );
  }
}
