import 'package:flutter/material.dart';

import '../../core/api_service.dart';
import '../../core/catalogo.dart';
import '../../core/session.dart';
import '../../core/theme.dart';
import '../../core/utils.dart';
import '../../models/models.dart';
import '../../widgets/common.dart';
import '../../widgets/compartilhar.dart';
import '../../widgets/interesses.dart';

/// Perfil Público da ONG. Usado pelo voluntário (via mapa/feed) e pela própria ONG (botão "Ver como os voluntários me veem" no painel).
class PerfilPublicoScreen extends StatefulWidget {
  final int ongId;
  final bool modoDono;
  /// true quando a tela é uma aba (sem botão voltar)
  final bool embutido;
  const PerfilPublicoScreen({super.key, required this.ongId, this.modoDono = false, this.embutido = false});

  @override
  State<PerfilPublicoScreen> createState() => _PerfilPublicoScreenState();
}

class _PerfilPublicoScreenState extends State<PerfilPublicoScreen> {
  Ong? _ong;
  String? _erro;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    setState(() => _erro = null);
    try {
      final o = await ApiService.instance.perfilPublicoOng(widget.ongId);
      if (mounted) setState(() => _ong = o);
    } catch (e) {
      if (mounted) setState(() => _erro = e.toString());
    }
  }

  List<String> get _meusInteresses => (Session.instance.perfil?['interesses'] as List? ?? []).map((e) => e.toString()).toList();

  Future<void> _queroAjudar() async {
    final o = _ong!;
    final ok = await abrirWhatsApp(o.whatsapp, 'Olá, ${o.nomeFantasia}! Encontrei a ONG no ONG Mais e gostaria de ajudar. Como posso contribuir?');
    if (!ok && mounted) mostrarSnack(context, 'Não foi possível abrir o WhatsApp.', erro: true);
  }

  @override
  Widget build(BuildContext context) {
    final o = _ong;
    final embutido = widget.embutido;
    return Scaffold(
      body: o == null
          ? SafeArea(
              child: Column(children: [
                if (!embutido) Align(alignment: Alignment.centerLeft, child: BackButton(onPressed: () => Navigator.pop(context))),
                Expanded(child: _erro != null ? ErroCarregamento(mensagem: _erro!, onTentar: _carregar) : const Center(child: CircularProgressIndicator())),
              ]),
            )
          : RefreshIndicator(
              onRefresh: _carregar,
              child: CustomScrollView(slivers: [
                SliverAppBar(
                  expandedHeight: 220,
                  pinned: true,
                  automaticallyImplyLeading: !embutido,
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  actions: [IconButton(onPressed: _carregar, icon: const Icon(Icons.refresh_rounded))],
                  flexibleSpace: FlexibleSpaceBar(
                    background: Container(
                      decoration: const BoxDecoration(gradient: LinearGradient(colors: [AppColors.primaryDark, AppColors.accent], begin: Alignment.topCenter, end: Alignment.bottomCenter)),
                      child: Center(child: Icon(Icons.volunteer_activism_rounded, size: 110, color: Colors.white.withValues(alpha: 0.25))),
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Container(
                    transform: Matrix4.translationValues(0, -24, 0),
                    decoration: const BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
                    padding: const EdgeInsets.fromLTRB(20, 24, 20, 110),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Container(
                          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 8)]),
                          padding: const EdgeInsets.all(4),
                          child: o.logoBase64 == null
                              ? const SizedBox(width: 76, height: 76, child: Icon(Icons.volunteer_activism_rounded, color: AppColors.primary, size: 44))
                              : LogoBase64(base64: o.logoBase64, tamanho: 76),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(o.nomeFantasia, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.textDark)),
                            const SizedBox(height: 4),
                            Text('CNPJ: ${o.cnpj}', style: const TextStyle(color: AppColors.textGrey)),
                            const SizedBox(height: 6),
                            Etiqueta(texto: '${emojiCategoria(o.categoria)} ${o.categoria}', cor: AppColors.primary),
                          ]),
                        ),
                      ]),
                      const SizedBox(height: 14),
                      if (o.endereco != null && o.endereco!.isNotEmpty)
                        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          const Icon(Icons.location_on_outlined, color: AppColors.primary, size: 20),
                          const SizedBox(width: 6),
                          Expanded(child: Text(o.endereco!, style: const TextStyle(color: AppColors.textDark, fontSize: 15))),
                        ]),
                      if (!o.temCoordenadas && widget.modoDono)
                        const Padding(
                          padding: EdgeInsets.only(top: 8),
                          child: Text('⚠ Sua ONG não tem localização cadastrada e não aparece no mapa. Edite o perfil e capture a localização.', style: TextStyle(color: AppColors.orange, fontSize: 13)),
                        ),
                      if (Session.instance.isVoluntario) ...[
                        const SizedBox(height: 16),
                        FaixaEmComum(emComum: emComum(o.tags, _meusInteresses), com: 'com você'),
                      ],
                      if (o.areasAtuacao.isNotEmpty) ...[
                        const SizedBox(height: 22),
                        const Text('Áreas de Atuação', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textDark)),
                        const SizedBox(height: 10),
                        ChipsInteresses(itens: o.areasAtuacao, emComum: Session.instance.isVoluntario ? emComum(o.areasAtuacao, _meusInteresses) : const []),
                      ],
                      const SizedBox(height: 22),
                      const Text('Sobre a ONG', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textDark)),
                      const SizedBox(height: 8),
                      Text(
                        (o.descricao == null || o.descricao!.isEmpty) ? 'Esta ONG ainda não escreveu uma descrição.' : o.descricao!,
                        style: const TextStyle(fontSize: 15, height: 1.5, color: Color(0xFF3B4252)),
                      ),
                      const SizedBox(height: 22),
                      Row(children: [
                        const Text('Campanhas Ativas', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textDark)),
                        const SizedBox(width: 8),
                        Etiqueta(texto: '${o.campanhas.length}', cor: AppColors.primary),
                      ]),
                      const SizedBox(height: 12),
                      if (o.campanhas.isEmpty)
                        const Text('Nenhuma campanha ativa no momento.', style: TextStyle(color: AppColors.textGrey))
                      else
                        for (final c in o.campanhas) ...[
                          Card(
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Row(children: [
                                  Etiqueta(texto: TipoCampanha.rotulo(c.tipo).toUpperCase(), cor: TipoCampanha.cor(c.tipo)),
                                  const Spacer(),
                                  Text('${tempoRelativo(c.criadoEm)} • ${formatarData(c.criadoEm)}', style: const TextStyle(color: AppColors.textGrey, fontSize: 12)),
                                ]),
                                const SizedBox(height: 10),
                                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                  Expanded(child: Text(c.titulo, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.textDark))),
                                  BotaoCompartilhar(campanha: c, nomeOng: o.nomeFantasia, compacto: true),
                                ]),
                                if (c.descricao != null) ...[
                                  const SizedBox(height: 4),
                                  Text(c.descricao!, maxLines: 3, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppColors.textGrey)),
                                ],
                              ]),
                            ),
                          ),
                          const SizedBox(height: 12),
                        ],
                    ]),
                  ),
                ),
              ]),
            ),
      bottomSheet: (o == null || (widget.modoDono && Session.instance.isOng))
          ? null
          : Container(
              color: AppColors.background,
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 20),
              child: ElevatedButton.icon(
                onPressed: _queroAjudar,
                icon: const Icon(Icons.favorite_rounded),
                label: const Text('QUERO AJUDAR', style: TextStyle(letterSpacing: 1)),
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.orange, minimumSize: const Size.fromHeight(58)),
              ),
            ),
    );
  }
}
