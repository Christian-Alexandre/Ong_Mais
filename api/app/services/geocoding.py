"""Geocodificação de endereço (fallback quando a ONG não captura o GPS).

Usa o Nominatim (OpenStreetMap), gratuito e sem chave. Falhas são silenciosas:
sem coordenadas a ONG simplesmente não aparece no mapa.
"""
import logging

import requests

log = logging.getLogger(__name__)

NOMINATIM_URL = "https://nominatim.openstreetmap.org/search"


def geocodificar(endereco: str) -> tuple[float | None, float | None]:
    try:
        r = requests.get(
            NOMINATIM_URL,
            params={"q": endereco, "format": "json", "limit": 1, "countrycodes": "br"},
            headers={"User-Agent": "ONGMais/1.0 (projeto academico)"},
            timeout=6,
        )
        r.raise_for_status()
        resultados = r.json()
        if resultados:
            return float(resultados[0]["lat"]), float(resultados[0]["lon"])
    except Exception as e:  # noqa: BLE001
        log.warning("Falha ao geocodificar '%s': %s", endereco, e)
    return None, None
