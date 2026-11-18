import 'package:flutter/material.dart';

import '../../core/session.dart';
import '../../core/utils.dart';
import 'nova_campanha_sheet.dart';
import 'painel_screen.dart';
import 'perfil_publico_screen.dart';

/// Barra inferior da ONG: Meu Painel | Nova Campanha | Perfil Público
class OngShell extends StatefulWidget {
  final String? mensagemInicial;
  const OngShell({super.key, this.mensagemInicial});

  @override
  State<OngShell> createState() => _OngShellState();
}

class _OngShellState extends State<OngShell> {
  int _aba = 0;
  final _painelKey = GlobalKey<PainelScreenState>();
  int _versaoPerfil = 0; // força recarregar o perfil público após edições

  @override
  void initState() {
    super.initState();
    if (widget.mensagemInicial != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => mostrarSnack(context, widget.mensagemInicial!));
    }
  }

  Future<void> _novaCampanha() async {
    final criada = await mostrarNovaCampanha(context);
    if (criada == true) {
      if (mounted) mostrarSnack(context, 'Campanha publicada com sucesso!');
      _painelKey.currentState?.recarregar();
      setState(() => _versaoPerfil++);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ongId = (Session.instance.perfil?['id'] as num?)?.toInt() ?? 0;
    return Scaffold(
      body: IndexedStack(
        index: _aba,
        children: [
          PainelScreen(key: _painelKey, onPerfilAlterado: () => setState(() => _versaoPerfil++)),
          const SizedBox.shrink(), // "Nova Campanha" abre um bottom sheet, não troca de tela
          PerfilPublicoScreen(key: ValueKey('perfil_$_versaoPerfil'), ongId: ongId, modoDono: true),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _aba,
        onDestinationSelected: (i) {
          if (i == 1) {
            _novaCampanha();
            return;
          }
          setState(() => _aba = i);
        },
        destinations: const [
          NavigationDestination(icon: Icon(Icons.dashboard_outlined), selectedIcon: Icon(Icons.dashboard_rounded), label: 'Meu Painel'),
          NavigationDestination(icon: Icon(Icons.add_circle_outline), selectedIcon: Icon(Icons.add_circle), label: 'Nova Campanha'),
          NavigationDestination(icon: Icon(Icons.visibility_outlined), selectedIcon: Icon(Icons.visibility), label: 'Perfil Público'),
        ],
      ),
    );
  }
}
