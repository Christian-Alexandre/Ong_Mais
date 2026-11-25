import 'package:flutter/material.dart';

import '../../core/utils.dart';
import 'nova_campanha_sheet.dart';
import 'painel_screen.dart';
import 'impacto_screen.dart';

/// Barra inferior da ONG: Meu Painel | Nova Campanha | Impacto
class OngShell extends StatefulWidget {
  final String? mensagemInicial;
  const OngShell({super.key, this.mensagemInicial});

  @override
  State<OngShell> createState() => _OngShellState();
}

class _OngShellState extends State<OngShell> {
  int _aba = 0;
  final _painelKey = GlobalKey<PainelScreenState>();
  final _impactoKey = GlobalKey<ImpactoScreenState>();

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
      _impactoKey.currentState?.recarregar();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _aba,
        children: [
          PainelScreen(key: _painelKey, onPerfilAlterado: () => _impactoKey.currentState?.recarregar()),
          const SizedBox.shrink(), // "Nova Campanha" abre um bottom sheet, não troca de tela
          ImpactoScreen(key: _impactoKey),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _aba,
        onDestinationSelected: (i) {
          if (i == 1) {
            _novaCampanha();
            return;
          }
          if (i == 2 && _aba != 2) _impactoKey.currentState?.recarregar(); // números sempre frescos
          setState(() => _aba = i);
        },
        destinations: const [
          NavigationDestination(icon: Icon(Icons.dashboard_outlined), selectedIcon: Icon(Icons.dashboard_rounded), label: 'Meu Painel'),
          NavigationDestination(icon: Icon(Icons.add_circle_outline), selectedIcon: Icon(Icons.add_circle), label: 'Nova Campanha'),
          NavigationDestination(icon: Icon(Icons.insights_outlined), selectedIcon: Icon(Icons.insights), label: 'Impacto'),
        ],
      ),
    );
  }
}
