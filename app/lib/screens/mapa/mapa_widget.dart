import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as g;
import 'package:latlong2/latlong.dart' as ll;

import '../../core/theme.dart';
import '../../models/models.dart';

/// Mapa com pinos das ONGs. Google Maps por padrão; fallback OpenStreetMap (flutter_map).
class MapaOngsWidget extends StatefulWidget {
  final List<Ong> ongs;
  final double latInicial;
  final double lngInicial;
  final bool usarGoogle;
  final void Function(Ong) onPinoTocado;

  const MapaOngsWidget({
    super.key,
    required this.ongs,
    required this.latInicial,
    required this.lngInicial,
    required this.usarGoogle,
    required this.onPinoTocado,
  });

  @override
  State<MapaOngsWidget> createState() => MapaOngsWidgetState();
}

class MapaOngsWidgetState extends State<MapaOngsWidget> {
  g.GoogleMapController? _google;
  final MapController _osm = MapController();
  bool _osmPronto = false;

  Future<void> centralizar(double lat, double lng, {double zoom = 15}) async {
    if (widget.usarGoogle) {
      await _google?.animateCamera(g.CameraUpdate.newLatLngZoom(g.LatLng(lat, lng), zoom));
    } else if (_osmPronto) {
      _osm.move(ll.LatLng(lat, lng), zoom);
    }
  }

  @override
  Widget build(BuildContext context) => widget.usarGoogle ? _buildGoogle() : _buildOsm();

  Widget _buildGoogle() {
    return g.GoogleMap(
      initialCameraPosition: g.CameraPosition(target: g.LatLng(widget.latInicial, widget.lngInicial), zoom: 13),
      myLocationEnabled: true,
      myLocationButtonEnabled: false,
      zoomControlsEnabled: false,
      mapToolbarEnabled: false,
      onMapCreated: (c) => _google = c,
      markers: {
        for (final o in widget.ongs)
          g.Marker(
            markerId: g.MarkerId('ong_${o.id}'),
            position: g.LatLng(o.latitude!, o.longitude!),
            infoWindow: g.InfoWindow(title: o.nomeFantasia, snippet: o.categoria),
            icon: g.BitmapDescriptor.defaultMarkerWithHue(g.BitmapDescriptor.hueGreen),
            onTap: () => widget.onPinoTocado(o),
          ),
      },
    );
  }

  Widget _buildOsm() {
    return FlutterMap(
      mapController: _osm,
      options: MapOptions(
        initialCenter: ll.LatLng(widget.latInicial, widget.lngInicial),
        initialZoom: 13,
        onMapReady: () => _osmPronto = true,
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'br.com.ongmais.app',
        ),
        MarkerLayer(
          markers: [
            for (final o in widget.ongs)
              Marker(
                point: ll.LatLng(o.latitude!, o.longitude!),
                width: 44,
                height: 44,
                child: GestureDetector(
                  onTap: () => widget.onPinoTocado(o),
                  child: const Icon(Icons.location_on, color: AppColors.primary, size: 40),
                ),
              ),
          ],
        ),
        const RichAttributionWidget(attributions: [TextSourceAttribution('© OpenStreetMap contributors')]),
      ],
    );
  }
}
