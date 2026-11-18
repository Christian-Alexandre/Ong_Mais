import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/api_service.dart';
import '../../core/theme.dart';
import '../../core/utils.dart';
import '../../models/models.dart';
import '../../widgets/common.dart';

/// Abre o bottom sheet de Nova Campanha (ou edição). Retorna true se salvou.
Future<bool?> mostrarNovaCampanha(BuildContext context, {Campanha? editar}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
    builder: (_) => _NovaCampanhaSheet(editar: editar),
  );
}

class _NovaCampanhaSheet extends StatefulWidget {
  final Campanha? editar;
  const _NovaCampanhaSheet({this.editar});

  @override
  State<_NovaCampanhaSheet> createState() => _NovaCampanhaSheetState();
}

class _NovaCampanhaSheetState extends State<_NovaCampanhaSheet> {
  late final _titulo = TextEditingController(text: widget.editar?.titulo ?? '');
  late final _descricao = TextEditingController(text: widget.editar?.descricao ?? '');
  late String _tipo = widget.editar?.tipo ?? TipoCampanha.voluntariado;
  late String? _foto = widget.editar?.fotoBase64;
  bool _salvando = false;

  bool get _edicao => widget.editar != null;

  @override
  void dispose() {
    _titulo.dispose();
    _descricao.dispose();
    super.dispose();
  }

  Future<void> _escolherFoto(ImageSource src) async {
    final b64 = await escolherImagemBase64(context, origem: src);
    if (b64 != null) setState(() => _foto = b64);
  }

  Future<void> _publicar() async {
    if (_titulo.text.trim().length < 2) {
      mostrarSnack(context, 'Informe o título da campanha.', erro: true);
      return;
    }
    setState(() => _salvando = true);
    try {
      if (_edicao) {
        await ApiService.instance.editarCampanha(widget.editar!.id, {
          'tipo': _tipo,
          'titulo': _titulo.text.trim(),
          'descricao': _descricao.text.trim().isEmpty ? null : _descricao.text.trim(),
          'foto_base64': _foto,
        });
      } else {
        await ApiService.instance.criarCampanha(
          tipo: _tipo,
          titulo: _titulo.text,
          descricao: _descricao.text.trim().isEmpty ? null : _descricao.text,
          fotoBase64: _foto,
        );
      }
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (mounted) mostrarSnack(context, 'Erro ao salvar campanha: $e', erro: true);
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final fotoBytes = decodeBase64(_foto);
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.85,
        maxChildSize: 0.95,
        minChildSize: 0.5,
        builder: (_, scroll) => ListView(
          controller: scroll,
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          children: [
            Center(child: Container(width: 44, height: 5, decoration: BoxDecoration(color: const Color(0xFFD9DEE3), borderRadius: BorderRadius.circular(3)))),
            const SizedBox(height: 14),
            Row(children: [
              Text(_edicao ? 'Editar Campanha' : 'Nova Campanha', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.textDark)),
              const Spacer(),
              IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
            ]),
            const SizedBox(height: 10),
            const Text('Tipo de Ação', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: 10),
            Row(children: [
              _tipoBtn(TipoCampanha.voluntariado),
              const SizedBox(width: 10),
              _tipoBtn(TipoCampanha.doacao),
              const SizedBox(width: 10),
              _tipoBtn(TipoCampanha.financeiro),
            ]),
            const SizedBox(height: 20),
            TextField(
              controller: _titulo,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(hintText: 'Título da Campanha'),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _descricao,
              maxLines: 5,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(hintText: 'Descrição e Instruções'),
            ),
            const SizedBox(height: 20),
            const Text('Foto da Campanha', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: 10),
            if (fotoBytes != null) ...[
              Stack(children: [
                ClipRRect(borderRadius: BorderRadius.circular(14), child: Image.memory(fotoBytes, height: 180, width: double.infinity, fit: BoxFit.cover)),
                Positioned(
                  top: 8,
                  right: 8,
                  child: CircleAvatar(
                    backgroundColor: Colors.black54,
                    child: IconButton(icon: const Icon(Icons.close, color: Colors.white), onPressed: () => setState(() => _foto = null)),
                  ),
                ),
              ]),
              const SizedBox(height: 10),
            ],
            Row(children: [
              Expanded(child: OutlinedButton.icon(onPressed: () => _escolherFoto(ImageSource.gallery), icon: const Icon(Icons.photo_library_outlined), label: const Text('Galeria'))),
              const SizedBox(width: 12),
              Expanded(child: OutlinedButton.icon(onPressed: () => _escolherFoto(ImageSource.camera), icon: const Icon(Icons.photo_camera_outlined), label: const Text('Câmera'))),
            ]),
            const SizedBox(height: 22),
            ElevatedButton(
              onPressed: _salvando ? null : _publicar,
              child: _salvando
                  ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : Text(_edicao ? 'Salvar Alterações' : 'Publicar Campanha'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tipoBtn(String tipo) {
    final ativo = _tipo == tipo;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _tipo = tipo),
        borderRadius: BorderRadius.circular(14),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: ativo ? AppColors.primary.withValues(alpha: 0.1) : const Color(0xFFF1F3F5),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: ativo ? AppColors.primary : Colors.transparent, width: 2),
          ),
          child: Column(children: [
            Icon(TipoCampanha.icone(tipo), color: ativo ? AppColors.primary : AppColors.textDark),
            const SizedBox(height: 6),
            Text(TipoCampanha.rotulo(tipo), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: ativo ? AppColors.primary : AppColors.textDark)),
          ]),
        ),
      ),
    );
  }
}
