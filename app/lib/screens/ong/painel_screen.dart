import 'package:flutter/material.dart';

import '../../core/api_service.dart';
import '../../core/session.dart';
import '../../core/theme.dart';
import '../../core/utils.dart';
import '../../main.dart';
import '../../models/models.dart';
import '../../widgets/common.dart';
import 'editar_perfil_ong_screen.dart';
import 'gerenciar_inscritos_screen.dart';
import 'nova_campanha_sheet.dart';

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
          LogoBase64(base64: ong.logoBase64, tamanho: 76),
          const SizedBox(width: 16),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(ong.nomeFantasia, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text(ong.email ?? '', style: const TextStyle(color: Colors.white70, fontSize: 14)),
            ]),
          ),
          IconButton(onPressed: _editarPerfil, icon: const Icon(Icons.edit, color: Colors.white)),
        ]),
        const Padding(padding: EdgeInsets.symmetric(vertical: 16), child: Divider(color: Colors.white30, height: 1)),
        Row(children: [
          Expanded(flex: 4, child: _info('CNPJ', ong.cnpj)),
          Expanded(flex: 2, child: _info('Campanhas', '$ativas ativa${ativas == 1 ? '' : 's'}')),
          Expanded(flex: 3, child: _info('WhatsApp', formatarTelefone(ong.whatsapp))),
        ]),
      ]),
    );
  }

  Widget _info(String rotulo, String valor) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(rotulo, style: const TextStyle(color: Colors.white70, fontSize: 13)),
        const SizedBox(height: 2),
        FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text(valor, maxLines: 1, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15))),
      ]);
}

class _CardCampanhaOng extends StatelessWidget {
  final Campanha campanha;
  final VoidCallback onEditar;
  final VoidCallback onExcluir;
  final VoidCallback onGerenciar;
  const _CardCampanhaOng({required this.campanha, required this.onEditar, required this.onExcluir, required this.onGerenciar});

  @override
  Widget build(BuildContext context) {
    final c = campanha;
    final cor = TipoCampanha.cor(c.tipo);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        if (c.fotoBase64 != null && c.fotoBase64!.isNotEmpty) FotoBase64(base64: c.fotoBase64, altura: 180),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 8, 0),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(color: cor.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(14)),
              child: Icon(TipoCampanha.icone(c.tipo), color: cor),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(c.titulo, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: AppColors.textDark)),
                const SizedBox(height: 4),
                if (c.descricao != null) Text(c.descricao!, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppColors.textGrey)),
                const SizedBox(height: 6),
                Row(children: [
                  Etiqueta(texto: TipoCampanha.rotulo(c.tipo), cor: cor),
                  const SizedBox(width: 8),
                  if (!c.ativa) const Etiqueta(texto: 'Inativa', cor: AppColors.textGrey),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      '${c.curtidas} ❤  •  ${formatarData(c.criadoEm)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.end,
                      style: const TextStyle(color: AppColors.textGrey, fontSize: 12),
                    ),
                  ),
                ]),
              ]),
            ),
            IconButton(onPressed: onEditar, icon: const Icon(Icons.edit_outlined, color: AppColors.primary)),
            IconButton(onPressed: onExcluir, icon: const Icon(Icons.delete_outline, color: AppColors.danger)),
          ]),
        ),
        const Padding(padding: EdgeInsets.fromLTRB(16, 12, 16, 0), child: Divider(height: 1)),
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
}
