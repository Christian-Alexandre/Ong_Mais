import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../core/theme.dart';
import '../core/utils.dart';
import '../models/models.dart';

/// Site de apresentação do projeto (o link vai junto no compartilhamento).
const siteOngMais = 'https://siteongmais.vercel.app';

String textoCompartilhamento(Campanha c, {String? nomeOng}) {
  final ong = nomeOng ?? c.ongNome ?? 'uma ONG';
  final descricao = (c.descricao ?? '').trim();
  final resumo = descricao.length > 180 ? '${descricao.substring(0, 177)}...' : descricao;
  final chamada = switch (c.tipo) {
    TipoCampanha.voluntariado => 'Precisa de voluntários!',
    TipoCampanha.doacao => 'Está recebendo doações!',
    TipoCampanha.financeiro => 'Precisa de apoio financeiro!',
    _ => 'Precisa da sua ajuda!',
  };
  return [
    '💚 ${c.titulo}',
    '$ong — $chamada',
    if (resumo.isNotEmpty) '\n$resumo',
    if (c.ongWhatsapp != null && c.ongWhatsapp!.isNotEmpty) '\n📲 Fale com a ONG: ${formatarTelefone(c.ongWhatsapp!)}',
    '\nConheça o ONG Mais: $siteOngMais',
  ].join('\n');
}

Future<void> compartilharCampanha(BuildContext context, Campanha c, {String? nomeOng}) async {
  final box = context.findRenderObject() as RenderBox?;
  try {
    await SharePlus.instance.share(ShareParams(
      text: textoCompartilhamento(c, nomeOng: nomeOng),
      subject: c.titulo,
      sharePositionOrigin: box == null ? null : box.localToGlobal(Offset.zero) & box.size,
    ));
  } catch (e) {
    if (context.mounted) mostrarSnack(context, 'Não foi possível compartilhar: $e', erro: true);
  }
}

/// Botão de compartilhar (abre a folha do Android: WhatsApp, Instagram, e-mail...).
class BotaoCompartilhar extends StatelessWidget {
  final Campanha campanha;
  final String? nomeOng;
  final bool compacto;
  const BotaoCompartilhar({super.key, required this.campanha, this.nomeOng, this.compacto = false});

  @override
  Widget build(BuildContext context) {
    return Builder(
      builder: (ctx) => IconButton(
        onPressed: () => compartilharCampanha(ctx, campanha, nomeOng: nomeOng),
        tooltip: 'Compartilhar',
        visualDensity: compacto ? VisualDensity.compact : null,
        icon: Icon(Icons.share_outlined, size: compacto ? 22 : 26, color: compacto ? AppColors.primary : null),
      ),
    );
  }
}
