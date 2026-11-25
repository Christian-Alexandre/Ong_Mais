import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../core/api_service.dart';
import '../core/utils.dart';

typedef LocalizacaoCapturada = ({double lat, double lng, String? endereco});

/// Pega o GPS e descobre o endereço (rua, número, bairro, cidade - UF) pela API.
/// Retorna null se o usuário negar a permissão ou o GPS falhar (já mostra a mensagem).
/// Se só o endereço falhar, devolve as coordenadas com endereco = null.
Future<LocalizacaoCapturada?> capturarLocalizacaoComEndereco(BuildContext context) async {
  try {
    if (!await Geolocator.isLocationServiceEnabled()) throw 'Ative o GPS do aparelho.';
    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) perm = await Geolocator.requestPermission();
    if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) {
      throw 'Permissão de localização negada.';
    }
    final pos = await Geolocator.getCurrentPosition(locationSettings: const LocationSettings(accuracy: LocationAccuracy.high));
    String? endereco;
    try {
      endereco = await ApiService.instance.enderecoDaLocalizacao(pos.latitude, pos.longitude);
    } catch (_) {
      if (context.mounted) mostrarSnack(context, 'Localização capturada, mas não achamos o endereço. Digite-o no campo.', erro: true);
    }
    return (lat: pos.latitude, lng: pos.longitude, endereco: endereco);
  } catch (e) {
    if (context.mounted) mostrarSnack(context, 'Não foi possível capturar a localização: $e', erro: true);
    return null;
  }
}
