import 'package:flutter/material.dart';

import '../../core/utils.dart';
import '../mapa/mapa_screen.dart';
import 'feed_screen.dart';
import 'perfil_voluntario_screen.dart';

/// Barra inferior do Voluntário: Feed de Campanhas | Mapa | Meu Perfil
class VoluntarioShell extends StatefulWidget {
  final String? mensagemInicial;
  const VoluntarioShell({super.key, this.mensagemInicial});

  @override
  State<VoluntarioShell> createState() => _VoluntarioShellState();
}

class _VoluntarioShellState extends State<VoluntarioShell> {
  int _aba = 0;
  // Abas só são construídas na primeira visita (o Mapa não pede localização no login)
  final Set<int> _visitadas = {0};

  @override
  void initState() {
    super.initState();
    if (widget.mensagemInicial != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => mostrarSnack(context, widget.mensagemInicial!));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _aba,
        children: [
          const FeedScreen(),
          _visitadas.contains(1) ? const MapaScreen() : const SizedBox.shrink(),
          _visitadas.contains(2) ? const PerfilVoluntarioScreen() : const SizedBox.shrink(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _aba,
        onDestinationSelected: (i) => setState(() {
          _aba = i;
          _visitadas.add(i);
        }),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home_rounded), label: 'Feed de Campanhas'),
          NavigationDestination(icon: Icon(Icons.map_outlined), selectedIcon: Icon(Icons.map_rounded), label: 'Mapa'),
          NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person_rounded), label: 'Meu Perfil'),
        ],
      ),
    );
  }
}
