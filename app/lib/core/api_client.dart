import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import 'config.dart';
import 'session.dart';

class ApiException implements Exception {
  final int status;
  final String mensagem;
  final Map<String, dynamic>? detalhes;
  ApiException(this.status, this.mensagem, [this.detalhes]);

  @override
  String toString() {
    if (detalhes == null || detalhes!.isEmpty) return mensagem;
    final campos = detalhes!.entries.map((e) {
      final v = e.value;
      return '${e.key}: ${v is List ? v.join(', ') : v}';
    }).join('\n');
    return '$mensagem\n$campos';
  }
}

/// Cliente HTTP mínimo para a API Flask. Injeta o JWT da sessão.
class ApiClient {
  ApiClient._();
  static final ApiClient instance = ApiClient._();

  static const _timeout = Duration(seconds: 20);

  /// Chamado quando a API recusa o token (401) de um usuário logado:
  /// o main.dart limpa a sessão e volta para o login.
  static void Function()? onSessaoExpirada;

  Uri _uri(String path, [Map<String, String>? query]) {
    final base = AppConfig.apiBaseUrl.replaceAll(RegExp(r'/$'), '');
    return Uri.parse('$base$path').replace(queryParameters: query);
  }

  Map<String, String> _headers() => {
        'Content-Type': 'application/json; charset=utf-8',
        'Accept': 'application/json',
        if (Session.instance.token != null) 'Authorization': 'Bearer ${Session.instance.token}',
      };

  Future<dynamic> get(String path, {Map<String, String>? query}) =>
      _send(() => http.get(_uri(path, query), headers: _headers()));

  Future<dynamic> post(String path, [Object? body]) =>
      _send(() => http.post(_uri(path), headers: _headers(), body: jsonEncode(body ?? {})));

  Future<dynamic> put(String path, [Object? body]) =>
      _send(() => http.put(_uri(path), headers: _headers(), body: jsonEncode(body ?? {})));

  Future<dynamic> patch(String path, [Object? body]) =>
      _send(() => http.patch(_uri(path), headers: _headers(), body: jsonEncode(body ?? {})));

  Future<dynamic> delete(String path) => _send(() => http.delete(_uri(path), headers: _headers()));

  Future<dynamic> _send(Future<http.Response> Function() fn) async {
    http.Response resp;
    try {
      resp = await fn().timeout(_timeout);
    } on SocketException {
      throw ApiException(0, 'Não foi possível conectar ao servidor (${AppConfig.apiBaseUrl}). Confira se a API está rodando e ajuste o endereço na engrenagem da tela de login.');
    } on HttpException catch (e) {
      throw ApiException(0, 'Falha de rede: ${e.message}');
    } catch (e) {
      throw ApiException(0, 'Falha de rede: $e');
    }

    dynamic data;
    final texto = utf8.decode(resp.bodyBytes);
    try {
      data = texto.isEmpty ? null : jsonDecode(texto);
    } catch (_) {
      data = {'erro': texto};
    }

    if (resp.statusCode >= 200 && resp.statusCode < 300) return data;

    if (resp.statusCode == 401 && Session.instance.logado && !resp.request!.url.path.startsWith('/auth/')) {
      onSessaoExpirada?.call();
    }

    final msg = (data is Map && data['erro'] != null) ? data['erro'].toString() : 'Erro ${resp.statusCode}';
    final detalhes = (data is Map && data['detalhes'] is Map) ? Map<String, dynamic>.from(data['detalhes']) : null;
    throw ApiException(resp.statusCode, msg, detalhes);
  }
}
