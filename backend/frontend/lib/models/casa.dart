class Casa {
  final int id;
  final String nome;
  final int vezesUsada;

  Casa({required this.id, required this.nome, required this.vezesUsada});

  factory Casa.fromJson(Map<String, dynamic> json) {
    return Casa(
      id: json['id'] as int,
      nome: json['nome'] as String,
      vezesUsada: json['vezes_usada'] as int,
    );
  }
}
