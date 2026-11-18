import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../core/theme.dart';
import '../core/utils.dart';

/// Avatar circular a partir de Base64, com ícone de fallback.
class AvatarBase64 extends StatelessWidget {
  final String? base64;
  final double raio;
  final IconData fallback;
  final Color? fundo;
  final Color? corIcone;
  const AvatarBase64({
    super.key,
    this.base64,
    this.raio = 24,
    this.fallback = Icons.person,
    this.fundo,
    this.corIcone,
  });

  @override
  Widget build(BuildContext context) {
    final bytes = decodeBase64(base64);
    return CircleAvatar(
      radius: raio,
      backgroundColor: fundo ?? Colors.white.withValues(alpha: 0.25),
      backgroundImage: bytes != null ? MemoryImage(bytes) : null,
      child: bytes == null ? Icon(fallback, size: raio * 1.1, color: corIcone ?? Colors.white) : null,
    );
  }
}

/// Logo quadrada arredondada a partir de Base64.
class LogoBase64 extends StatelessWidget {
  final String? base64;
  final double tamanho;
  const LogoBase64({super.key, this.base64, this.tamanho = 64});

  @override
  Widget build(BuildContext context) {
    final bytes = decodeBase64(base64);
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: tamanho,
        height: tamanho,
        color: Colors.white.withValues(alpha: 0.2),
        child: bytes != null
            ? Image.memory(bytes, fit: BoxFit.cover)
            : Icon(Icons.apartment_rounded, color: Colors.white, size: tamanho * 0.55),
      ),
    );
  }
}

/// Foto de campanha (Base64) ou nada.
class FotoBase64 extends StatelessWidget {
  final String? base64;
  final double? altura;
  final BorderRadius? radius;
  const FotoBase64({super.key, this.base64, this.altura, this.radius});

  @override
  Widget build(BuildContext context) {
    final bytes = decodeBase64(base64);
    if (bytes == null) return const SizedBox.shrink();
    return ClipRRect(
      borderRadius: radius ?? BorderRadius.zero,
      child: Image.memory(bytes, height: altura, width: double.infinity, fit: BoxFit.cover, gaplessPlayback: true),
    );
  }
}

/// Abre Galeria ou Câmera e devolve a imagem em Base64 (redimensionada).
Future<String?> escolherImagemBase64(BuildContext context, {ImageSource? origem}) async {
  final picker = ImagePicker();
  final src = origem ??
      await showModalBottomSheet<ImageSource>(
        context: context,
        builder: (_) => SafeArea(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            ListTile(leading: const Icon(Icons.photo_library_outlined), title: const Text('Galeria'), onTap: () => Navigator.pop(context, ImageSource.gallery)),
            ListTile(leading: const Icon(Icons.photo_camera_outlined), title: const Text('Câmera'), onTap: () => Navigator.pop(context, ImageSource.camera)),
          ]),
        ),
      );
  if (src == null) return null;
  try {
    final x = await picker.pickImage(source: src, maxWidth: 1080, maxHeight: 1080, imageQuality: 75);
    if (x == null) return null;
    return base64Encode(await x.readAsBytes());
  } catch (e) {
    if (context.mounted) mostrarSnack(context, 'Não foi possível abrir a imagem: $e', erro: true);
    return null;
  }
}

class CampoRotulado extends StatelessWidget {
  final String rotulo;
  final Widget campo;
  const CampoRotulado({super.key, required this.rotulo, required this.campo});

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(rotulo, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.textDark)),
      const SizedBox(height: 8),
      campo,
      const SizedBox(height: 16),
    ]);
  }
}

class CampoSenha extends StatefulWidget {
  final TextEditingController controller;
  final String hint;
  final IconData icone;
  final String? Function(String?)? validator;
  const CampoSenha({super.key, required this.controller, this.hint = 'Mínimo de 6 caracteres', this.icone = Icons.lock_outline, this.validator});

  @override
  State<CampoSenha> createState() => _CampoSenhaState();
}

class _CampoSenhaState extends State<CampoSenha> {
  bool _oculta = true;
  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: widget.controller,
      obscureText: _oculta,
      validator: widget.validator,
      decoration: InputDecoration(
        hintText: widget.hint,
        prefixIcon: Icon(widget.icone),
        suffixIcon: IconButton(
          icon: Icon(_oculta ? Icons.visibility_outlined : Icons.visibility_off_outlined, color: AppColors.textGrey),
          onPressed: () => setState(() => _oculta = !_oculta),
        ),
      ),
    );
  }
}

/// Chip de status/tipo.
class Etiqueta extends StatelessWidget {
  final String texto;
  final Color cor;
  final IconData? icone;
  const Etiqueta({super.key, required this.texto, required this.cor, this.icone});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: cor.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (icone != null) ...[Icon(icone, size: 16, color: cor), const SizedBox(width: 4)],
        Text(texto, style: TextStyle(color: cor, fontWeight: FontWeight.bold, fontSize: 13)),
      ]),
    );
  }
}

/// Estado vazio padrão de listas.
class ListaVazia extends StatelessWidget {
  final IconData icone;
  final String titulo;
  final String? subtitulo;
  const ListaVazia({super.key, required this.icone, required this.titulo, this.subtitulo});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(icone, size: 64, color: AppColors.textGrey.withValues(alpha: 0.5)),
          const SizedBox(height: 12),
          Text(titulo, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: AppColors.textDark), textAlign: TextAlign.center),
          if (subtitulo != null) ...[
            const SizedBox(height: 6),
            Text(subtitulo!, style: const TextStyle(color: AppColors.textGrey), textAlign: TextAlign.center),
          ],
        ]),
      ),
    );
  }
}

/// Mensagem de erro com botão tentar novamente.
class ErroCarregamento extends StatelessWidget {
  final String mensagem;
  final VoidCallback onTentar;
  const ErroCarregamento({super.key, required this.mensagem, required this.onTentar});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.cloud_off_rounded, size: 56, color: AppColors.danger),
          const SizedBox(height: 12),
          Text(mensagem, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.textGrey)),
          const SizedBox(height: 16),
          OutlinedButton.icon(onPressed: onTentar, icon: const Icon(Icons.refresh), label: const Text('Tentar novamente')),
        ]),
      ),
    );
  }
}

/// Barra de app do feed: logo + título + atualizar.
class MarcaOngMais extends StatelessWidget {
  final double tamanho;
  const MarcaOngMais({super.key, this.tamanho = 22});
  @override
  Widget build(BuildContext context) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      const Icon(Icons.volunteer_activism_rounded, color: AppColors.primary, size: 30),
      const SizedBox(width: 8),
      Text('ONG Mais', style: TextStyle(fontSize: tamanho, fontWeight: FontWeight.bold, color: AppColors.textDark)),
    ]);
  }
}
