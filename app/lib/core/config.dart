import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Configurações do app.
class AppConfig {
  /// URL padrão definida no build (--dart-define=API_BASE_URL=...).
  /// - Emulador Android: http://10.0.2.2:5000
  /// - Celular físico na mesma rede: http://IP_DO_SEU_PC:5000
  static const String apiBaseUrlPadrao = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:5000',
  );

  static const _storage = FlutterSecureStorage();
  static const _kServidor = 'servidor_api';

  /// URL em uso. Pode ser trocada em tempo de execução (ícone de engrenagem no login).
  static String apiBaseUrl = apiBaseUrlPadrao;

  static Future<void> carregar() async {
    final salvo = await _storage.read(key: _kServidor);
    if (salvo != null && salvo.isNotEmpty) apiBaseUrl = salvo;
  }

  static Future<void> definirServidor(String url) async {
    var u = url.trim();
    if (u.isEmpty) {
      apiBaseUrl = apiBaseUrlPadrao;
      await _storage.delete(key: _kServidor);
      return;
    }
    if (!u.startsWith('http')) u = 'http://$u';
    if (!RegExp(r':\d+$').hasMatch(u.replaceAll(RegExp(r'/+$'), ''))) u = '${u.replaceAll(RegExp(r'/+$'), '')}:5000';
    apiBaseUrl = u;
    await _storage.write(key: _kServidor, value: u);
  }

  /// Mapa padrão: OpenStreetMap (flutter_map), gratuito e sem chave.
  /// Para usar Google Maps: chave com faturamento ativo + "Maps SDK for Android"
  /// no AndroidManifest.xml e rodar com --dart-define=USAR_GOOGLE_MAPS=true.
  static const bool usarGoogleMaps = bool.fromEnvironment(
    'USAR_GOOGLE_MAPS',
    defaultValue: false,
  );
}
