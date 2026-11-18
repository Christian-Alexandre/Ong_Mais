import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../../core/api_service.dart';
import '../../core/config.dart';
import '../../core/theme.dart';
import '../../core/utils.dart';
import '../../models/models.dart';
import '../../widgets/common.dart';
import '../ong/perfil_publico_screen.dart';
import 'mapa_widget.dart';

/// Mapa de ONGs: busca por nome/causa, chips de categoria, pinos, minha localização,
/// atualizar e card inferior com distância (Haversine calculada na API).
class MapaScreen extends StatefulWidget {
  const MapaScreen({super.key});

  @override
  State<MapaScreen> createState() => _MapaScreenState();
}

class _MapaScreenState extends State<MapaScreen> {
  final _busca = TextEditingController();
  final _mapaKey = GlobalKey<MapaOngsWidgetState>();
  Timer? _debounce;

  List<Ong> _ongs = [];
  Ong? _selecionada;
  String _categoria = '';
  double? _lat;
  double? _lng;
  bool _carregando = true; // começa carregando (evita "Nenhuma ONG" antes da 1ª busca)
  String? _erro;

  // São Paulo como centro padrão
  static const _centroPadrao = (lat: -23.5505, lng: -46.6333);

  @override
  void initState() {
    super.initState();
    _localizar(silencioso: true).then((_) => _carregar());
  }

  @override
  void dispose() {
    _busca.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _localizar({bool silencioso = false}) async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) throw 'GPS desativado.';
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) perm = await Geolocator.requestPermission();
      if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) throw 'Permissão de localização negada.';
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, timeLimit: Duration(seconds: 12)),
      );
      if (!mounted) return;
      setState(() {
        _lat = pos.latitude;
        _lng = pos.longitude;
      });
      _mapaKey.currentState?.centralizar(pos.latitude, pos.longitude, zoom: 14);
    } catch (e) {
      if (!silencioso && mounted) mostrarSnack(context, 'Não foi possível obter sua localização: $e', erro: true);
    }
  }

  Future<void> _carregar() async {
    setState(() {
      _carregando = true;
      _erro = null;
    });
    try {
      final lista = await ApiService.instance.listarOngs(lat: _lat, lng: _lng, categoria: _categoria, q: _busca.text);
      if (!mounted) return;
      setState(() {
        _ongs = lista;
        if (_selecionada != null && !lista.any((o) => o.id == _selecionada!.id)) _selecionada = null;
        _selecionada ??= lista.where((o) => o.temCoordenadas).firstOrNull;
      });
    } catch (e) {
      if (mounted) setState(() => _erro = e.toString());
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  void _aoDigitar(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), _carregar);
  }

  void _selecionar(Ong o) {
    setState(() => _selecionada = o);
    if (o.temCoordenadas) _mapaKey.currentState?.centralizar(o.latitude!, o.longitude!);
  }

  @override
  Widget build(BuildContext context) {
    final comPino = _ongs.where((o) => o.temCoordenadas).toList();
    return Scaffold(
      body: Stack(children: [
        MapaOngsWidget(
          key: _mapaKey,
          ongs: comPino,
          latInicial: _lat ?? _centroPadrao.lat,
          lngInicial: _lng ?? _centroPadrao.lng,
          usarGoogle: AppConfig.usarGoogleMaps,
          onPinoTocado: _selecionar,
        ),
        // Busca + chips
        SafeArea(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Material(
                elevation: 4,
                shadowColor: Colors.black26,
                borderRadius: BorderRadius.circular(18),
                child: TextField(
                  controller: _busca,
                  onChanged: _aoDigitar,
                  decoration: InputDecoration(
                    hintText: 'Buscar ONGs por nome ou causa...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _busca.text.isEmpty
                        ? const Icon(Icons.tune_rounded, color: AppColors.primary)
                        : IconButton(icon: const Icon(Icons.close), onPressed: () {
                            _busca.clear();
                            _carregar();
                          }),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide.none),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide.none),
                  ),
                ),
              ),
            ),
            SizedBox(
              height: 46,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  _chip('Todas', ''),
                  for (final c in categoriasOng) _chip('${emojiCategoria(c)} $c', c),
                ],
              ),
            ),
            if (_erro != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Material(
                  color: AppColors.danger,
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(padding: const EdgeInsets.all(10), child: Text(_erro!, style: const TextStyle(color: Colors.white))),
                ),
              ),
          ]),
        ),
        // Botões laterais
        Positioned(
          right: 16,
          bottom: _selecionada == null ? 110 : 230,
          child: Column(children: [
            _botao(Icons.my_location_rounded, () => _localizar().then((_) => _carregar()), cor: AppColors.primary),
            const SizedBox(height: 10),
            _botao(_carregando ? Icons.hourglass_top_rounded : Icons.refresh_rounded, _carregando ? null : _carregar),
          ]),
        ),
        // Card inferior
        if (_selecionada != null)
          Positioned(
            left: 16,
            right: 16,
            bottom: 16,
            child: _CardOng(
              ong: _selecionada!,
              total: comPino.length,
              onAnterior: comPino.length > 1 ? () => _navegar(comPino, -1) : null,
              onProximo: comPino.length > 1 ? () => _navegar(comPino, 1) : null,
              onVerPerfil: () => Navigator.push(context, MaterialPageRoute(builder: (_) => PerfilPublicoScreen(ongId: _selecionada!.id))),
            ),
          )
        else if (_carregando)
          const Positioned(
            left: 16,
            right: 16,
            bottom: 16,
            child: Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
                  SizedBox(width: 12),
                  Text('Buscando ONGs próximas...', style: TextStyle(color: AppColors.textGrey)),
                ]),
              ),
            ),
          )
        else if (_erro == null)
          Positioned(
            left: 16,
            right: 16,
            bottom: 16,
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  _ongs.isEmpty ? 'Nenhuma ONG encontrada com esse filtro.' : 'As ONGs encontradas ainda não têm localização cadastrada.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.textGrey),
                ),
              ),
            ),
          ),
      ]),
    );
  }

  void _navegar(List<Ong> lista, int delta) {
    final i = lista.indexWhere((o) => o.id == _selecionada!.id);
    _selecionar(lista[(i + delta + lista.length) % lista.length]);
  }

  Widget _chip(String rotulo, String cat) {
    final ativo = _categoria == cat;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(rotulo),
        selected: ativo,
        showCheckmark: false,
        elevation: 2,
        labelStyle: TextStyle(color: ativo ? Colors.white : AppColors.textDark, fontWeight: FontWeight.w600),
        onSelected: (_) {
          setState(() => _categoria = cat);
          _carregar();
        },
      ),
    );
  }

  Widget _botao(IconData icone, VoidCallback? onTap, {Color cor = AppColors.textDark}) {
    return Material(
      color: Colors.white,
      elevation: 4,
      shadowColor: Colors.black26,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: SizedBox(width: 52, height: 52, child: Icon(icone, color: cor)),
      ),
    );
  }
}

class _CardOng extends StatelessWidget {
  final Ong ong;
  final int total;
  final VoidCallback? onAnterior;
  final VoidCallback? onProximo;
  final VoidCallback onVerPerfil;
  const _CardOng({required this.ong, required this.total, this.onAnterior, this.onProximo, required this.onVerPerfil});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 6,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(children: [
          Container(
            decoration: BoxDecoration(gradient: AppColors.gradient, borderRadius: BorderRadius.circular(14)),
            child: LogoBase64(base64: ong.logoBase64, tamanho: 70),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(ong.nomeFantasia, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: AppColors.textDark)),
              const SizedBox(height: 2),
              Text(ong.endereco ?? ong.categoria, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppColors.textGrey, fontSize: 13)),
              const SizedBox(height: 8),
              Row(children: [
                if (ong.distanciaKm != null)
                  Etiqueta(texto: '${ong.distanciaKm!.toStringAsFixed(1)} km', cor: AppColors.primary, icone: Icons.location_on)
                else
                  Etiqueta(texto: '${emojiCategoria(ong.categoria)} ${ong.categoria}', cor: AppColors.primary),
                const Spacer(),
                GestureDetector(
                  onTap: onVerPerfil,
                  child: const Row(mainAxisSize: MainAxisSize.min, children: [
                    Text('Ver Perfil', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 15)),
                    Icon(Icons.arrow_forward_rounded, color: AppColors.primary, size: 18),
                  ]),
                ),
              ]),
            ]),
          ),
          if (total > 1)
            Column(mainAxisSize: MainAxisSize.min, children: [
              InkWell(onTap: onAnterior, child: const Icon(Icons.keyboard_arrow_up_rounded, color: AppColors.textGrey)),
              InkWell(onTap: onProximo, child: const Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.textGrey)),
            ]),
        ]),
      ),
    );
  }
}
