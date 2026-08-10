import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'api_service.dart';

/// Guarda a sessão atual (token + nome de usuário) na MEMÓRIA — é daqui
/// que o ApiService lê o token pra mandar em toda requisição. Também
/// persiste no disco (SharedPreferences) pra não precisar logar de novo
/// toda vez que o app abre.
class SessaoAtual {
  static String? token;
  static String? nomeUsuario;

  static bool get logado => token != null;
}

class AuthException implements Exception {
  final String mensagem;
  AuthException(this.mensagem);
  @override
  String toString() => mensagem;
}

class AuthService {
  final String baseUrl;
  AuthService({String? baseUrl}) : baseUrl = baseUrl ?? ApiConfig.baseUrl;

  static const _chaveToken = 'auth_token';
  static const _chaveNome = 'auth_nome_usuario';

  Uri _uri(String caminho) => Uri.parse('$baseUrl$caminho');

  void _verificarErro(http.Response resposta) {
    if (resposta.statusCode >= 400) {
      String detalhe = resposta.body;
      try {
        detalhe = (jsonDecode(resposta.body) as Map)['detail']?.toString() ?? detalhe;
      } catch (_) {}
      throw AuthException(detalhe);
    }
  }

  /// Roda na abertura do app: se tiver uma sessão salva no aparelho,
  /// carrega ela pra memória e confirma com o backend que ainda é válida.
  Future<bool> restaurarSessaoSalva() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(_chaveToken);
    final nome = prefs.getString(_chaveNome);
    if (token == null) return false;

    SessaoAtual.token = token;
    SessaoAtual.nomeUsuario = nome;

    // Confirma com o backend que o token ainda é válido (não foi invalidado
    // por um login em outro lugar, por exemplo).
    try {
      final resposta = await http.get(_uri('/auth/eu'), headers: {'Authorization': 'Bearer $token'});
      if (resposta.statusCode != 200) {
        await _limparSessaoSalva();
        return false;
      }
      return true;
    } catch (_) {
      // sem internet no momento — mantém a sessão salva mesmo assim,
      // melhor deixar tentar usar o app do que forçar logout por causa
      // de uma falha de rede passageira.
      return true;
    }
  }

  Future<void> registrar(String nomeUsuario, String senha) async {
    final resposta = await http.post(
      _uri('/auth/registrar'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'nome_usuario': nomeUsuario, 'senha': senha}),
    );
    _verificarErro(resposta);
    await _salvarSessao(jsonDecode(utf8.decode(resposta.bodyBytes)));
  }

  Future<void> login(String nomeUsuario, String senha) async {
    final resposta = await http.post(
      _uri('/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'nome_usuario': nomeUsuario, 'senha': senha}),
    );
    _verificarErro(resposta);
    await _salvarSessao(jsonDecode(utf8.decode(resposta.bodyBytes)));
  }

  Future<void> logout() async {
    final token = SessaoAtual.token;
    if (token != null) {
      try {
        await http.post(_uri('/auth/logout'), headers: {'Authorization': 'Bearer $token'});
      } catch (_) {
        // mesmo que a chamada falhe (sem internet, etc.), desloga localmente
      }
    }
    await _limparSessaoSalva();
  }

  Future<void> _salvarSessao(Map<String, dynamic> json) async {
    final token = json['token'] as String;
    final nome = (json['usuario'] as Map)['nome_usuario'] as String;

    SessaoAtual.token = token;
    SessaoAtual.nomeUsuario = nome;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_chaveToken, token);
    await prefs.setString(_chaveNome, nome);
  }

  Future<void> _limparSessaoSalva() async {
    SessaoAtual.token = null;
    SessaoAtual.nomeUsuario = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_chaveToken);
    await prefs.remove(_chaveNome);
  }
}
