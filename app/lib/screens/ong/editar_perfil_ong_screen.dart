import 'package:flutter/material.dart';

import '../../core/api_service.dart';
import '../../core/catalogo.dart';
import '../../core/theme.dart';
import '../../core/utils.dart';
import '../../models/models.dart';
import '../../widgets/common.dart';
import '../../widgets/interesses.dart';
import '../../widgets/localizacao.dart';

class EditarPerfilOngScreen extends StatefulWidget {
  final Ong ong;
  const EditarPerfilOngScreen({super.key, required this.ong});

  @override
  State<EditarPerfilOngScreen> createState() => _EditarPerfilOngScreenState();
}

class _EditarPerfilOngScreenState extends State<EditarPerfilOngScreen> {
  final _form = GlobalKey<FormState>();
  late final _nome = TextEditingController(text: widget.ong.nomeFantasia);
  late final _whats = TextEditingController(text: formatarTelefone(widget.ong.whatsapp));
  late final _endereco = TextEditingController(text: widget.ong.endereco ?? '');
  late final _descricao = TextEditingController(text: widget.ong.descricao ?? '');
  late String _categoria = categoriasOng.contains(widget.ong.categoria) ? widget.ong.categoria : 'Outros';
  late List<String> _areas = [...widget.ong.areasAtuacao];
  late String? _logo = widget.ong.logoBase64;
  late double? _lat = widget.ong.latitude;
  late double? _lng = widget.ong.longitude;
  bool _salvando = false;
  bool _capturando = false;

  @override
  void dispose() {
    for (final c in [_nome, _whats, _endereco, _descricao]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _capturar() async {
    setState(() => _capturando = true);
    final loc = await capturarLocalizacaoComEndereco(context);
    if (!mounted) return;
    setState(() {
      _capturando = false;
      if (loc == null) return;
      _lat = loc.lat;
      _lng = loc.lng;
      if (loc.endereco != null) _endereco.text = loc.endereco!;
    });
    if (loc != null) mostrarSnack(context, loc.endereco != null ? 'Endereço atualizado pela sua localização. Confira o número.' : 'Localização capturada!');
  }

  Future<void> _salvar() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _salvando = true);
    try {
      await ApiService.instance.atualizarOng({
        'nome_fantasia': _nome.text.trim(),
        'categoria': _categoria,
        'areas_atuacao': _areas,
        'whatsapp': _whats.text.trim(),
        'endereco': _endereco.text.trim().isEmpty ? null : _endereco.text.trim(),
        'latitude': _lat,
        'longitude': _lng,
        'descricao': _descricao.text.trim().isEmpty ? null : _descricao.text.trim(),
        'logo_base64': _logo,
      });
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (mounted) mostrarSnack(context, 'Erro ao salvar: $e', erro: true);
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final logoBytes = decodeBase64(_logo);
    return Scaffold(
      appBar: AppBar(title: const Text('Editar Perfil da ONG')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _form,
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Center(
              child: GestureDetector(
                onTap: () async {
                  final b64 = await escolherImagemBase64(context);
                  if (b64 != null) setState(() => _logo = b64);
                },
                child: Stack(children: [
                  Container(
                    width: 110,
                    height: 110,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFFF1F3F5),
                      border: Border.all(color: AppColors.primary, width: 2),
                      image: logoBytes != null ? DecorationImage(image: MemoryImage(logoBytes), fit: BoxFit.cover) : null,
                    ),
                    child: logoBytes == null ? const Icon(Icons.apartment_rounded, size: 44, color: AppColors.primary) : null,
                  ),
                  const Positioned(
                    right: 2,
                    bottom: 2,
                    child: CircleAvatar(radius: 16, backgroundColor: AppColors.primary, child: Icon(Icons.photo_camera, size: 16, color: Colors.white)),
                  ),
                ]),
              ),
            ),
            const SizedBox(height: 8),
            const Center(child: Text('Toque para alterar o logo', style: TextStyle(color: AppColors.textGrey))),
            const SizedBox(height: 20),
            CampoRotulado(
              rotulo: 'Nome da ONG',
              campo: TextFormField(
                controller: _nome,
                decoration: const InputDecoration(prefixIcon: Icon(Icons.apartment_rounded)),
                validator: (v) => (v == null || v.trim().length < 2) ? 'Informe o nome' : null,
              ),
            ),
            CampoRotulado(
              rotulo: 'CNPJ (não editável)',
              campo: TextFormField(
                initialValue: widget.ong.cnpj,
                enabled: false,
                decoration: const InputDecoration(prefixIcon: Icon(Icons.badge_outlined)),
              ),
            ),
            CampoRotulado(
              rotulo: 'Categoria / Causa',
              campo: DropdownButtonFormField<String>(
                initialValue: _categoria,
                decoration: const InputDecoration(prefixIcon: Icon(Icons.category_outlined)),
                items: categoriasOng.map((c) => DropdownMenuItem(value: c, child: Text('${emojiCategoria(c)}  $c'))).toList(),
                onChanged: (v) => setState(() {
                  _categoria = v ?? _categoria;
                  _areas = _areas.where((a) => (areasPorCategoria[_categoria] ?? const []).contains(a)).toList();
                }),
              ),
            ),
            CampoRotulado(
              rotulo: 'Áreas de atuação',
              campo: SeletorAreas(categoria: _categoria, selecionadas: _areas, onChanged: (l) => setState(() => _areas = l)),
            ),
            CampoRotulado(
              rotulo: 'WhatsApp',
              campo: TextFormField(
                controller: _whats,
                keyboardType: TextInputType.phone,
                inputFormatters: [TelefoneFormatter()],
                autovalidateMode: AutovalidateMode.onUserInteraction,
                decoration: const InputDecoration(hintText: '(11) 98765-4321', prefixIcon: Icon(Icons.phone_outlined)),
                validator: telefoneErro,
              ),
            ),
            CampoRotulado(
              rotulo: 'Endereço da Sede',
              campo: TextFormField(controller: _endereco, decoration: const InputDecoration(prefixIcon: Icon(Icons.location_on_outlined))),
            ),
            OutlinedButton.icon(
              onPressed: _capturando ? null : _capturar,
              icon: _capturando ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.my_location_rounded),
              label: Text(_lat == null ? 'Usar minha localização atual' : 'Atualizar endereço pela localização atual'),
            ),
            const SizedBox(height: 16),
            CampoRotulado(
              rotulo: 'Sobre a ONG',
              campo: TextFormField(controller: _descricao, maxLines: 5, decoration: const InputDecoration(hintText: 'Conte sobre o trabalho e a missão da ONG...')),
            ),
            ElevatedButton.icon(
              onPressed: _salvando ? null : _salvar,
              icon: _salvando ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.save_outlined),
              label: const Text('Salvar Alterações'),
            ),
          ]),
        ),
      ),
    );
  }
}
