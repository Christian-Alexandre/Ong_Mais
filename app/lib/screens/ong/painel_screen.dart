import 'package:flutter/material.dart';

import '../../core/api_service.dart';
import '../../core/session.dart';
import '../../core/theme.dart';
import '../../core/utils.dart';
import '../../main.dart';
import '../../models/models.dart';
import '../../widgets/comentarios_sheet.dart';
import '../../widgets/common.dart';
import '../../widgets/compartilhar.dart';
import 'editar_perfil_ong_screen.dart';
import 'gerenciar_inscritos_screen.dart';
import 'nova_campanha_sheet.dart';
import 'perfil_publico_screen.dart';

/// Meu Painel (ONG): card da ONG + lista de campanhas + FAB Nova Campanha.
class PainelScreen extends StatefulWidget {
  final VoidCallback? onPerfilAlterado;
  const PainelScreen({super.key, this.onPerfilAlterado});

  @override
  State<PainelScreen> createState() => PainelScreenState();
}

class PainelScreenState extends State<PainelScreen> {
  Ong? _ong;
  List<Campanha>? _campanhas;
  String? _erro;
  bool _carregando = false;

  @override
  void initState() {
    super.initState();
    final p = Session.instance.perfil;
    if (p != null) _ong = Ong.fromJson(p);
    recarregar();
  }

  Future<void> recarregar() async {
    setState(() {
      _carregando = true;
      _erro = null;
    });
    try {
      final r = await Future.wait([ApiService.instance.meuPerfilOng(), ApiService.instance.minhasCampanhas()]);
      if (!mounted) return;
      setState(() {
        _ong = r[0] as Ong;
        _campanhas = r[1] as List<Campanha>;
      });
    } catch (e) {
      if (mounted) setState(() => _erro = e.toString());
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  Future<void> _editarPerfil() async {
    if (_ong == null) return;
    final alterado = await Navigator.push<bool>(context, MaterialPageRoute(builder: (_) => EditarPerfilOngScreen(ong: _ong!)));
    if (alterado == true) {
      await recarregar();
      widget.onPerfilAlterado?.call();
    }
  }

  void _verPerfilPublico() {
    if (_ong == null) return;
    Navigator.push(context, MaterialPageRoute(builder: (_) => PerfilPublicoScreen(ongId: _ong!.id, modoDono: true)));
  }

  Future<void> _nova() async {
    final criada = await mostrarNovaCampanha(context);
    if (criada == true) {
      if (mounted) mostrarSnack(context, 'Campanha publicada com sucesso!');
      await recarregar();
      widget.onPerfilAlterado?.call();
    }
  }

  Future<void> _editar(Campanha c) async {
    final alterada = await mostrarNovaCampanha(context, editar: c);
    if (alterada == true) {
      if (mounted) mostrarSnack(context, 'Campanha atualizada!');
      await recarregar();
      widget.onPerfilAlterado?.call();
    }
  }

  Future<void> _excluir(Campanha c) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Excluir campanha?'),
        content: Text('"${c.titulo}" e suas inscrições serão removidas. Esta ação não pode ser desfeita.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Excluir', style: TextStyle(color: AppColors.danger))),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ApiService.instance.excluirCampanha(c.id);
      if (mounted) mostrarSnack(context, 'Campanha excluída.');
      await recarregar();
      widget.onPerfilAlterado?.call();
    } catch (e) {
      if (mounted) mostrarSnack(context, 'Erro ao excluir: $e', erro: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ong = _ong;
    final ativas = _campanhas?.where((c) => c.ativa).length ?? ong?.campanhasAtivas ?? 0;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Painel da ONG'),
        actions: [
          IconButton(onPressed: _verPerfilPublico, icon: const Icon(Icons.visibility_outlined, color: AppColors.primary), tooltip: 'Ver como os voluntários me veem'),
          IconButton(onPressed: _editarPerfil, icon: const Icon(Icons.edit_outlined, color: AppColors.primary), tooltip: 'Editar perfil'),
          IconButton(onPressed: _carregando ? null : recarregar, icon: const Icon(Icons.refresh_rounded, color: AppColors.primary), tooltip: 'Atualizar'),
          IconButton(onPressed: () => sairDaConta(context), icon: const Icon(Icons.logout_rounded, color: AppColors.danger), tooltip: 'Sair'),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _nova,
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Nova Campanha', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: ong == null
          ? (_erro != null ? ErroCarregamento(mensagem: _erro!, onTentar: recarregar) : const Center(child: CircularProgressIndicator()))
          : RefreshIndicator(
              onRefresh: recarregar,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                children: [
                  _cardOng(ong, ativas),
                  const SizedBox(height: 20),
                  Row(children: [
                    const Text('Suas Campanhas', style: TextStyle(fontSize: 21, fontWeight: FontWeight.bold, color: AppColors.textDark)),
                    const Spacer(),
                    Text('${_campanhas?.length ?? 0} no total', style: const TextStyle(color: AppColors.textGrey)),
                  ]),
                  const SizedBox(height: 12),
                  if (_erro != null) ErroCarregamento(mensagem: _erro!, onTentar: recarregar),
                  if (_campanhas == null && _erro == null) const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator())),
                  if (_campanhas != null && _campanhas!.isEmpty)
                    const ListaVazia(icone: Icons.campaign_outlined, titulo: 'Nenhuma campanha ainda', subtitulo: 'Toque em "Nova Campanha" para publicar a primeira.'),
                  if (_campanhas != null)
                    for (final c in _campanhas!) ...[
                      _CardCampanhaOng(
                        campanha: c,
                        onEditar: () => _editar(c),
                        onExcluir: () => _excluir(c),
                        onGerenciar: () => Navigator.push(context, MaterialPageRoute(builder: (_) => GerenciarInscritosScreen(campanha: c))).then((_) => recarregar()),
                        onComentarios: () async {
                          final total = await abrirComentarios(context, c);
                          if (total != null && mounted) setState(() => c.comentarios = total);
                        },
                      ),
                      const SizedBox(height: 14),
                    ],
                ],
              ),
            ),
    );
  }

  Widget _cardOng(Ong ong, int ativas) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [AppColors.primary, Color(0xFF0A4F48)], begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          LogoBase64(base64: ong.logoBase64, tamanho: 72),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(ong.nomeFantasia, style: const TextStyle(color: Colors.white, fontSize: 21, fontWeight: FontWeight.bold, height: 1.2)),
              const SizedBox(height: 4),
              Text(ong.email ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white70, fontSize: 13.5)),
              const SizedBox(height: 8),
              _pilula('${emojiCategoria(ong.categoria)} ${ong.categoria}'),
            ]),
          ),
          IconButton(onPressed: _editarPerfil, icon: const Icon(Icons.edit, color: Colors.white), tooltip: 'Editar perfil'),
        ]),
        const SizedBox(height: 10),
        InkWell(
          onTap: _verPerfilPublico,
          borderRadius: BorderRadius.circular(20),
          child: const Padding(
            padding: EdgeInsets.symmetric(vertical: 4),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.visibility_outlined, color: Colors.white, size: 18),
              SizedBox(width: 6),
              Text('Ver como os voluntários me veem', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, decoration: TextDecoration.underline, decorationColor: Colors.white)),
            ]),
          ),
        ),
        if (ong.areasAtuacao.isNotEmpty) ...[
          const SizedBox(height: 12),
          Wrap(spacing: 6, runSpacing: 6, children: [for (final a in ong.areasAtuacao) _pilula(a, leve: true)]),
        ],
        const SizedBox(height: 16),
        // CNPJ em linha própria (não espreme mais os outros dados)
        _linhaInfo(Icons.badge_outlined, 'CNPJ', ong.cnpj),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: _blocoInfo(Icons.campaign_outlined, 'Campanhas ativas', '$ativas')),
          const SizedBox(width: 10),
          Expanded(child: _blocoInfo(Icons.chat_outlined, 'WhatsApp', formatarTelefone(ong.whatsapp))),
        ]),
      ]),
    );
  }

  Widget _pilula(String texto, {bool leve = false}) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(color: Colors.white.withValues(alpha: leve ? 0.14 : 0.22), borderRadius: BorderRadius.circular(20)),
        child: Text(texto, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 12.5)),
      );

  Widget _linhaInfo(IconData icone, String rotulo, String valor) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(14)),
        child: Row(children: [
          Icon(icone, color: Colors.white70, size: 20),
          const SizedBox(width: 10),
          Text(rotulo, style: const TextStyle(color: Colors.white70, fontSize: 13)),
          const Spacer(),
          Text(valor, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15, letterSpacing: 0.3)),
        ]),
      );

  Widget _blocoInfo(IconData icone, String rotulo, String valor) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(14)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(icone, color: Colors.white70, size: 18),
            const SizedBox(width: 6),
            Flexible(child: Text(rotulo, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white70, fontSize: 12.5))),
          ]),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(valor, maxLines: 1, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
          ),
        ]),
      );
}

class _CardCampanhaOng extends StatelessWidget {
  final Campanha campanha;
  final VoidCallback onEditar;
  final VoidCallback onExcluir;
  final VoidCallback onGerenciar;
  final VoidCallback onComentarios;
  const _CardCampanhaOng({required this.campanha, required this.onEditar, required this.onExcluir, required this.onGerenciar, required this.onComentarios});

  @override
  Widget build(BuildContext context) {
    final c = campanha;
    final cor = TipoCampanha.cor(c.tipo);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        if (c.fotoBase64 != null && c.fotoBase64!.isNotEmpty) FotoBase64(base64: c.fotoBase64, altura: 180),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 4, 0),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(color: cor.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(14)),
              child: Icon(TipoCampanha.icone(c.tipo), color: cor),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Wrap(spacing: 6, runSpacing: 4, children: [
                  Etiqueta(texto: TipoCampanha.rotulo(c.tipo), cor: cor),
                  if (!c.ativa) const Etiqueta(texto: 'Inativa', cor: AppColors.textGrey),
                ]),
                const SizedBox(height: 6),
                Text(c.titulo, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: AppColors.textDark, height: 1.25)),
              ]),
            ),
            PopupMenuButton<String>(
              tooltip: 'Opções',
              icon: const Icon(Icons.more_vert_rounded, color: AppColors.textGrey),
              onSelected: (op) {
                if (op == 'editar') onEditar();
                if (op == 'compartilhar') compartilharCampanha(context, c);
                if (op == 'excluir') onExcluir();
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'editar', child: ListTile(leading: Icon(Icons.edit_outlined, color: AppColors.primary), title: Text('Editar'), contentPadding: EdgeInsets.zero)),
                PopupMenuItem(value: 'compartilhar', child: ListTile(leading: Icon(Icons.share_outlined, color: AppColors.primary), title: Text('Compartilhar'), contentPadding: EdgeInsets.zero)),
                PopupMenuItem(value: 'excluir', child: ListTile(leading: Icon(Icons.delete_outline, color: AppColors.danger), title: Text('Excluir', style: TextStyle(color: AppColors.danger)), contentPadding: EdgeInsets.zero)),
              ],
            ),
          ]),
        ),
        if (c.descricao != null && c.descricao!.trim().isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
            child: Text(c.descricao!, maxLines: 3, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Color(0xFF495057), height: 1.4)),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Wrap(spacing: 14, runSpacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
            _numero(Icons.favorite_rounded, '${c.curtidas}', AppColors.danger),
            _numero(Icons.mode_comment_outlined, '${c.comentarios}', AppColors.primary),
            if (c.tipo == TipoCampanha.voluntariado) _numero(Icons.people_alt_outlined, '${c.inscritos}', AppColors.primary),
            _numero(Icons.calendar_today_outlined, formatarData(c.criadoEm), AppColors.textGrey),
          ]),
        ),
        const Padding(padding: EdgeInsets.fromLTRB(16, 12, 16, 0), child: Divider(height: 1)),
        InkWell(
          onTap: onComentarios,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
            child: Row(children: [
              const Icon(Icons.mode_comment_outlined, color: AppColors.primary),
              const SizedBox(width: 8),
              Text('Comentários${c.comentarios > 0 ? ' (${c.comentarios})' : ''}', style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 15)),
              const Spacer(),
              const Icon(Icons.chevron_right_rounded, color: AppColors.primary),
            ]),
          ),
        ),
        const Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: Divider(height: 1)),
        if (c.tipo == TipoCampanha.voluntariado)
          InkWell(
            onTap: onGerenciar,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
              child: Row(children: [
                const Icon(Icons.people_alt_outlined, color: AppColors.primary),
                const SizedBox(width: 8),
                Text('Gerenciar Voluntários Inscritos${c.inscritos > 0 ? ' (${c.inscritos})' : ''}', style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 15)),
                const Spacer(),
                const Icon(Icons.chevron_right_rounded, color: AppColors.primary),
              ]),
            ),
          )
        else
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 12, 16, 14),
            child: Text('Contato dos interessados pelo WhatsApp.', style: TextStyle(color: AppColors.textGrey, fontSize: 13)),
          ),
      ]),
    );
  }

  Widget _numero(IconData icone, String texto, Color cor) => Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icone, size: 16, color: cor),
        const SizedBox(width: 4),
        Text(texto, style: const TextStyle(color: AppColors.textGrey, fontSize: 13, fontWeight: FontWeight.w600)),
      ]);
}
