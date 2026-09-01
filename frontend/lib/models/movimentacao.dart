enum TipoMovimentacao { deposito, saque }

extension TipoMovimentacaoJson on TipoMovimentacao {
  String get valor => this == TipoMovimentacao.deposito ? 'deposito' : 'saque';

  static TipoMovimentacao fromJson(String v) => v == 'deposito' ? TipoMovimentacao.deposito : TipoMovimentacao.saque;
}

class Movimentacao {
  final int id;
  final int casaId;
  final TipoMovimentacao tipo;
  final double valor;
  final DateTime data;

  Movimentacao({
    required this.id,
    required this.casaId,
    required this.tipo,
    required this.valor,
    required this.data,
  });

  factory Movimentacao.fromJson(Map<String, dynamic> json) {
    return Movimentacao(
      id: json['id'] as int,
      casaId: json['casa_id'] as int,
      tipo: TipoMovimentacaoJson.fromJson(json['tipo'] as String),
      valor: (json['valor'] as num).toDouble(),
      data: DateTime.parse(json['data'] as String),
    );
  }
}

class ItemBancaLocalizacao {
  final String casa;
  final double valor;

  ItemBancaLocalizacao({required this.casa, required this.valor});

  factory ItemBancaLocalizacao.fromJson(Map<String, dynamic> json) {
    return ItemBancaLocalizacao(
      casa: json['casa'] as String,
      valor: (json['valor'] as num).toDouble(),
    );
  }
}

class BancaPorLocalizacao {
  final double banco;
  final List<ItemBancaLocalizacao> casas;
  final double total;

  BancaPorLocalizacao({required this.banco, required this.casas, required this.total});

  factory BancaPorLocalizacao.fromJson(Map<String, dynamic> json) {
    return BancaPorLocalizacao(
      banco: (json['banco'] as num).toDouble(),
      casas: (json['casas'] as List).map((j) => ItemBancaLocalizacao.fromJson(j)).toList(),
      total: (json['total'] as num).toDouble(),
    );
  }
}
