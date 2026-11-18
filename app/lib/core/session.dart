import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Sessão do usuário: JWT + papel + perfil, guardados no flutter_secure_storage.
class Session {
  Session._();
  static final Session instance = Session._();

  static const _storage = FlutterSecureStorage();
  static const _kToken = 'jwt';
  static const _kPapel = 'papel';
  static const _kPerfil = 'perfil';

  String? token;
  String? papel; // 'ONG' | 'VOLUNTARIO'
  Map<String, dynamic>? perfil;

  bool get logado => token != null;
  bool get isOng => papel == 'ONG';
  bool get isVoluntario => papel == 'VOLUNTARIO';

  Future<void> carregar() async {
    token = await _storage.read(key: _kToken);
    papel = await _storage.read(key: _kPapel);
    final p = await _storage.read(key: _kPerfil);
    perfil = p == null ? null : jsonDecode(p) as Map<String, dynamic>;
  }

  Future<void> salvar({required String token, required String papel, required Map<String, dynamic> perfil}) async {
    this.token = token;
    this.papel = papel;
    this.perfil = perfil;
    await _storage.write(key: _kToken, value: token);
    await _storage.write(key: _kPapel, value: papel);
    await _storage.write(key: _kPerfil, value: jsonEncode(perfil));
  }

  Future<void> atualizarPerfil(Map<String, dynamic> novo) async {
    perfil = novo;
    await _storage.write(key: _kPerfil, value: jsonEncode(novo));
  }

  Future<void> sair() async {
    token = null;
    papel = null;
    perfil = null;
    // Apaga só os dados da sessão (mantém o endereço do servidor configurado)
    await _storage.delete(key: _kToken);
    await _storage.delete(key: _kPapel);
    await _storage.delete(key: _kPerfil);
  }
}
