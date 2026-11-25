import 'package:flutter/material.dart';

import '../core/api_client.dart';
import '../core/api_service.dart';
import '../core/theme.dart';
import '../core/utils.dart';
import '../models/models.dart';
import '../screens/ong/perfil_voluntario_publico_screen.dart';
import 'common.dart';

/// Abre os comentários da campanha. Retorna o total atualizado (ou null se não mudou).
Future<int?> abrirComentarios(BuildContext context, Campanha campanha) {
  return showModalBottomSheet<int>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (_) => _ComentariosSheet(campanha: campanha),
  );
}

class _ComentariosSheet extends StatefulWidget {
  final Campanha campanha;
  const _ComentariosSheet({required this.campanha});

  @override
  State<_ComentariosSheet> createState() => _ComentariosSheetState();
}

class _ComentariosSheetState extends State<_ComentariosSheet> {
  final _texto = TextEditingController();
  final _rolagem = ScrollController();
  List<Comentario>? _lista;
  String? _erro;
  bool _enviando = false;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  @override
  void dispose() {
    _texto.dispose();
    _rolagem.dispose();
    super.dispose();
  }

  Future<void> _carregar() async {
    setState(() => _erro = null);
    try {
      final l = await ApiService.instance.comentarios(widget.campanha.id);
      if (mounted) setState(() => _lista = l);
    } catch (e) {
      if (mounted) setState(() => _erro = e.toString());
    }
  }

  void _rolarParaFim() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_rolagem.hasClients) {
        _rolagem.animateTo(_rolagem.position.maxScrollExtent, duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
      }
    });
  }

  Future<void> _enviar() async {
    final t = _texto.text.trim();
    if (t.isEmpty || _enviando) return;
    setState(() => _enviando = true);
    try {
      final novo = await ApiService.instance.comentar(widget.campanha.id, t);
      _texto.clear();
      if (!mounted) return;
      setState(() => _lista = [...?_lista, novo]);
      _rolarParaFim();
    } on ApiException catch (e) {
      if (mounted) mostrarSnack(context, e.toString(), erro: true);
    } catch (e) {
      if (mounted) mostrarSnack(context, e.toString(), erro: true);
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  Future<void> _apagar(Comentario c) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Apagar comentário?'),
        content: Text('"${c.texto}"', maxLines: 4, overflow: TextOverflow.ellipsis),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Apagar', style: TextStyle(color: AppColors.danger))),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ApiService.instance.apagarComentario(c.id);
      if (mounted) setState(() => _lista = _lista?.where((x) => x.id != c.id).toList());
    } catch (e) {
      if (mounted) mostrarSnack(context, e.toString(), erro: true);
    }
  }

  void _fechar() => Navigator.pop(context, _lista?.length);

  @override
  Widget build(BuildContext context) {
    final teclado = MediaQuery.of(context).viewInsets.bottom;
    final total = _lista?.length ?? widget.campanha.comentarios;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _fechar();
      },
      child: Padding(
        padding: EdgeInsets.only(bottom: teclado),
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.75,
          child: Column(children: [
            const SizedBox(height: 10),
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.black12, borderRadius: BorderRadius.circular(4))),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 8, 4),
              child: Row(children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Comentários ($total)', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppColors.textDark)),
                    Text(widget.campanha.titulo, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppColors.textGrey)),
                  ]),
                ),
                IconButton(onPressed: _fechar, icon: const Icon(Icons.close_rounded)),
              ]),
            ),
            const Divider(height: 1),
            Expanded(child: _corpo()),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 8, 10),
              child: Row(children: [
                Expanded(
                  child: TextField(
                    controller: _texto,
                    maxLength: 500,
                    minLines: 1,
                    maxLines: 4,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(hintText: 'Escreva um comentário...', counterText: '', isDense: true),
                    onSubmitted: (_) => _enviar(),
                  ),
                ),
                const SizedBox(width: 6),
                IconButton.filled(
                  onPressed: _enviando ? null : _enviar,
                  style: IconButton.styleFrom(backgroundColor: AppColors.primary),
                  icon: _enviando
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.send_rounded, color: Colors.white),
                ),
              ]),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _corpo() {
    if (_erro != null) return Center(child: ErroCarregamento(mensagem: _erro!, onTentar: _carregar));
    if (_lista == null) return const Center(child: CircularProgressIndicator());
    if (_lista!.isEmpty) {
      return const ListaVazia(
        icone: Icons.mode_comment_outlined,
        titulo: 'Nenhum comentário ainda',
        subtitulo: 'Tire uma dúvida ou deixe uma mensagem de apoio.',
      );
    }
    return ListView.separated(
      controller: _rolagem,
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: _lista!.length,
      separatorBuilder: (context, index) => const SizedBox(height: 2),
      itemBuilder: (_, i) {
        final c = _lista![i];
        // qualquer pessoa logada (ONG ou voluntário) abre o perfil de um voluntário que comentou
        final podeVerPerfil = !c.daOng;
        return ListTile(
          titleAlignment: ListTileTitleAlignment.top,
          onTap: podeVerPerfil
              ? () => Navigator.push(context, MaterialPageRoute(builder: (_) => PerfilVoluntarioPublicoScreen(voluntarioId: c.usuarioId, nomeInicial: c.autorNome)))
              : null,
          leading: c.daOng
              ? AvatarBase64(base64: c.autorLogoBase64, raio: 18, fallback: Icons.apartment_rounded, fundo: AppColors.primary.withValues(alpha: 0.15), corIcone: AppColors.primary)
              : AvatarVoluntario(fotoBase64: c.autorFotoBase64, nome: c.autorNome, raio: 18),
          title: Row(children: [
            Flexible(child: Text(c.autorNome, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: podeVerPerfil ? AppColors.primaryDark : AppColors.textDark))),
            if (c.daOng) ...[const SizedBox(width: 6), const Etiqueta(texto: 'ONG', cor: AppColors.primary)],
            const SizedBox(width: 6),
            Text(tempoRelativo(c.criadoEm), style: const TextStyle(color: AppColors.textGrey, fontSize: 12)),
          ]),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(c.texto, style: const TextStyle(color: AppColors.textDark, fontSize: 15, height: 1.3)),
          ),
          trailing: c.podeApagar
              ? IconButton(onPressed: () => _apagar(c), icon: const Icon(Icons.delete_outline, size: 20, color: AppColors.textGrey), tooltip: 'Apagar')
              : null,
        );
      },
    );
  }
}
