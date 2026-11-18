import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'core/api_client.dart';
import 'core/config.dart';
import 'core/session.dart';
import 'core/theme.dart';
import 'core/utils.dart';
import 'screens/auth/login_screen.dart';
import 'screens/ong/ong_shell.dart';
import 'screens/voluntario/voluntario_shell.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('pt_BR');
  await AppConfig.carregar();
  await Session.instance.carregar();
  ApiClient.onSessaoExpirada = _sessaoExpirada;
  runApp(const OngMaisApp());
}

final navigatorKey = GlobalKey<NavigatorState>();
bool _redirecionando = false;

/// Token recusado pela API (expirou ou a chave do servidor mudou): volta para o login.
Future<void> _sessaoExpirada() async {
  if (_redirecionando) return;
  _redirecionando = true;
  await Session.instance.sair();
  final nav = navigatorKey.currentState;
  if (nav != null) {
    nav.pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const LoginScreen()), (_) => false);
    final ctx = navigatorKey.currentContext;
    if (ctx != null) mostrarSnack(ctx, 'Sua sessão expirou. Entre novamente.', erro: true);
  }
  _redirecionando = false;
}

class OngMaisApp extends StatelessWidget {
  const OngMaisApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ONG Mais',
      navigatorKey: navigatorKey,
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      locale: const Locale('pt', 'BR'),
      supportedLocales: const [Locale('pt', 'BR')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: const _Raiz(),
    );
  }
}

/// Decide a tela inicial pelo papel salvo no token.
class _Raiz extends StatelessWidget {
  const _Raiz();

  @override
  Widget build(BuildContext context) {
    final s = Session.instance;
    if (!s.logado) return const LoginScreen();
    return s.isOng ? const OngShell() : const VoluntarioShell();
  }
}

/// Navega para a home correta após login/cadastro, limpando a pilha.
void irParaHome(BuildContext context, {String? mensagem}) {
  final s = Session.instance;
  final Widget home = s.isOng ? OngShell(mensagemInicial: mensagem) : VoluntarioShell(mensagemInicial: mensagem);
  Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => home), (_) => false);
}

Future<void> sairDaConta(BuildContext context) async {
  await Session.instance.sair();
  if (!context.mounted) return;
  Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const LoginScreen()), (_) => false);
}
