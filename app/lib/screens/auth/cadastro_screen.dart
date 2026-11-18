import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';

import '../../core/api_service.dart';
import '../../core/theme.dart';
import '../../core/utils.dart';
import '../../main.dart';
import '../../widgets/common.dart';

/// Cadastro com alternância Voluntário / Sou ONG (como no protótipo).
class CadastroScreen extends StatefulWidget {
  final bool iniciarComoOng;
  const CadastroScreen({super.key, this.iniciarComoOng = false});

  @override
  State<CadastroScreen> createState() => _CadastroScreenState();
}

class _CadastroScreenState extends State<CadastroScreen> {
  late bool _ong = widget.iniciarComoOng;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Criar Nova Conta')),
      body: SafeArea(
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(color: const Color(0xFFE9ECEF), borderRadius: BorderRadius.circular(14)),
              child: Row(children: [
                _aba('Voluntário', Icons.person_outline, !_ong, () => setState(() => _ong = false)),
                _aba('Sou ONG', Icons.apartment_rounded, _ong, () => setState(() => _ong = true)),
              ]),
            ),
          ),
          Expanded(child: _ong ? const _FormOng() : const _FormVoluntario()),
        ]),
      ),
    );
  }

  Widget _aba(String texto, IconData icone, bool ativa, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: ativa ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(11),
            boxShadow: ativa ? [const BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 2))] : null,
          ),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(icone, size: 20, color: ativa ? AppColors.primary : AppColors.textGrey),
            const SizedBox(width: 6),
            Text(texto, style: TextStyle(fontWeight: FontWeight.bold, color: ativa ? AppColors.primary : AppColors.textGrey)),
          ]),
        ),
      ),
    );
  }
}

Widget _rodapeLogin(BuildContext context) => Padding(
      padding: const EdgeInsets.only(top: 18),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        const Text('Já possui conta? ', style: TextStyle(color: AppColors.textGrey)),
        GestureDetector(
          onTap: () => Navigator.pop(context),
          child: const Text('Fazer Login', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
        ),
      ]),
    );

String? _validaEmail(String? v) => (v == null || !RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(v.trim())) ? 'Informe um e-mail válido' : null;
String? _validaSenha(String? v) => (v == null || v.length < 6) ? 'Mínimo de 6 caracteres' : null;

// ------------------------------------------------------------ Voluntário

class _FormVoluntario extends StatefulWidget {
  const _FormVoluntario();
  @override
  State<_FormVoluntario> createState() => _FormVoluntarioState();
}

class _FormVoluntarioState extends State<_FormVoluntario> {
  final _form = GlobalKey<FormState>();
  final _nome = TextEditingController();
  final _email = TextEditingController();
  final _senha = TextEditingController();
  final _confirma = TextEditingController();
  bool _carregando = false;

  @override
  void dispose() {
    for (final c in [_nome, _email, _senha, _confirma]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _cadastrar() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _carregando = true);
    try {
      await ApiService.instance.registrarVoluntario(nome: _nome.text, email: _email.text, senha: _senha.text, confirmar: _confirma.text);
      if (!mounted) return;
      irParaHome(context, mensagem: 'Bem-vindo(a), ${_nome.text.trim()}! Cadastro realizado.');
    } catch (e) {
      if (mounted) mostrarSnack(context, 'Erro ao cadastrar voluntário: $e', erro: true);
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      child: Form(
        key: _form,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          CampoRotulado(
            rotulo: 'Nome Completo',
            campo: TextFormField(
              controller: _nome,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(hintText: 'Ex: Ana Maria Silva', prefixIcon: Icon(Icons.person_outline)),
              validator: (v) => (v == null || v.trim().length < 2) ? 'Informe seu nome' : null,
            ),
          ),
          CampoRotulado(
            rotulo: 'E-mail',
            campo: TextFormField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(hintText: 'exemplo@email.com', prefixIcon: Icon(Icons.mail_outline)),
              validator: _validaEmail,
            ),
          ),
          CampoRotulado(rotulo: 'Senha', campo: CampoSenha(controller: _senha, validator: _validaSenha)),
          CampoRotulado(
            rotulo: 'Confirmar Senha',
            campo: CampoSenha(
              controller: _confirma,
              hint: 'Repita a senha',
              icone: Icons.lock_clock_outlined,
              validator: (v) => v != _senha.text ? 'As senhas não conferem' : null,
            ),
          ),
          ElevatedButton(
            onPressed: _carregando ? null : _cadastrar,
            child: _carregando ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('Concluir Cadastro de Voluntário'),
          ),
          _rodapeLogin(context),
        ]),
      ),
    );
  }
}

// ------------------------------------------------------------ ONG

class _FormOng extends StatefulWidget {
  const _FormOng();
  @override
  State<_FormOng> createState() => _FormOngState();
}

class _FormOngState extends State<_FormOng> {
  final _form = GlobalKey<FormState>();
  final _nome = TextEditingController();
  final _cnpj = TextEditingController();
  final _whats = TextEditingController();
  final _endereco = TextEditingController();
  final _descricao = TextEditingController();
  final _email = TextEditingController();
  final _senha = TextEditingController();
  final _confirma = TextEditingController();
  String _categoria = categoriasOng.first;
  String? _logoBase64;
  double? _lat;
  double? _lng;
  bool _carregando = false;
  bool _capturando = false;

  @override
  void dispose() {
    for (final c in [_nome, _cnpj, _whats, _endereco, _descricao, _email, _senha, _confirma]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _capturarLocalizacao() async {
    setState(() => _capturando = true);
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        throw 'Ative o GPS do aparelho.';
      }
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) perm = await Geolocator.requestPermission();
      if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) {
        throw 'Permissão de localização negada.';
      }
      final pos = await Geolocator.getCurrentPosition(locationSettings: const LocationSettings(accuracy: LocationAccuracy.high));
      setState(() {
        _lat = pos.latitude;
        _lng = pos.longitude;
      });
      if (mounted) mostrarSnack(context, 'Localização capturada: ${pos.latitude.toStringAsFixed(5)}, ${pos.longitude.toStringAsFixed(5)}');
    } catch (e) {
      if (mounted) mostrarSnack(context, 'Não foi possível capturar a localização: $e', erro: true);
    } finally {
      if (mounted) setState(() => _capturando = false);
    }
  }

  Future<void> _cadastrar() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _carregando = true);
    try {
      await ApiService.instance.registrarOng({
        'nome_fantasia': _nome.text.trim(),
        'cnpj': _cnpj.text.trim(),
        'categoria': _categoria,
        'whatsapp': _whats.text.trim(),
        'endereco': _endereco.text.trim().isEmpty ? null : _endereco.text.trim(),
        'latitude': _lat,
        'longitude': _lng,
        'descricao': _descricao.text.trim().isEmpty ? null : _descricao.text.trim(),
        'logo_base64': _logoBase64,
        'email': _email.text.trim(),
        'senha': _senha.text,
        'confirmar_senha': _confirma.text,
      });
      if (!mounted) return;
      irParaHome(context, mensagem: 'ONG ${_nome.text.trim()} cadastrada com sucesso!');
    } catch (e) {
      if (mounted) mostrarSnack(context, 'Erro ao cadastrar ONG: $e', erro: true);
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final logoBytes = decodeBase64(_logoBase64);
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      child: Form(
        key: _form,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Center(
            child: GestureDetector(
              onTap: () async {
                final b64 = await escolherImagemBase64(context);
                if (b64 != null) setState(() => _logoBase64 = b64);
              },
              child: Column(children: [
                Stack(children: [
                  Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFFF1F3F5),
                      border: Border.all(color: AppColors.primary, width: 2),
                      image: logoBytes != null ? DecorationImage(image: MemoryImage(logoBytes), fit: BoxFit.cover) : null,
                    ),
                    child: logoBytes == null ? const Icon(Icons.apartment_rounded, size: 48, color: AppColors.primary) : null,
                  ),
                  Positioned(
                    right: 4,
                    bottom: 4,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: const BoxDecoration(shape: BoxShape.circle, color: AppColors.primary),
                      child: const Icon(Icons.photo_camera, size: 16, color: Colors.white),
                    ),
                  ),
                ]),
                const SizedBox(height: 8),
                const Text('Adicionar Logo (Opcional)', style: TextStyle(color: AppColors.textGrey)),
              ]),
            ),
          ),
          const SizedBox(height: 20),
          CampoRotulado(
            rotulo: 'Nome da ONG (Nome Fantasia)',
            campo: TextFormField(
              controller: _nome,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(hintText: 'Ex: Instituto Patinhas Carentes', prefixIcon: Icon(Icons.apartment_rounded)),
              validator: (v) => (v == null || v.trim().length < 2) ? 'Informe o nome da ONG' : null,
            ),
          ),
          CampoRotulado(
            rotulo: 'CNPJ',
            campo: TextFormField(
              controller: _cnpj,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(14), _CnpjFormatter()],
              decoration: const InputDecoration(hintText: '00.000.000/0000-00', prefixIcon: Icon(Icons.badge_outlined)),
              validator: (v) => cnpjValido(v ?? '') ? null : 'CNPJ inválido',
            ),
          ),
          CampoRotulado(
            rotulo: 'Categoria / Causa',
            campo: DropdownButtonFormField<String>(
              initialValue: _categoria,
              decoration: const InputDecoration(prefixIcon: Icon(Icons.category_outlined)),
              items: categoriasOng.map((c) => DropdownMenuItem(value: c, child: Text('${emojiCategoria(c)}  $c'))).toList(),
              onChanged: (v) => setState(() => _categoria = v ?? _categoria),
            ),
          ),
          CampoRotulado(
            rotulo: 'WhatsApp / Telefone de Contato',
            campo: TextFormField(
              controller: _whats,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(hintText: 'Ex: (11) 98765-4321', prefixIcon: Icon(Icons.phone_outlined)),
              validator: (v) => somenteDigitos(v ?? '').length < 10 ? 'Informe DDD + número' : null,
            ),
          ),
          CampoRotulado(
            rotulo: 'Endereço da Sede',
            campo: TextFormField(
              controller: _endereco,
              decoration: const InputDecoration(hintText: 'Ex: Av. Paulista, 1000 - São Paulo, SP', prefixIcon: Icon(Icons.location_on_outlined)),
            ),
          ),
          OutlinedButton.icon(
            onPressed: _capturando ? null : _capturarLocalizacao,
            icon: _capturando
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : Icon(_lat == null ? Icons.my_location_rounded : Icons.check_circle_rounded),
            label: Text(_lat == null ? 'Capturar minha localização atual' : 'Localização capturada ✓'),
          ),
          const SizedBox(height: 6),
          const Text(
            'Opcional. Sem a captura, tentaremos localizar pelo endereço; sem coordenadas a ONG não aparece no mapa.',
            style: TextStyle(fontSize: 12, color: AppColors.textGrey),
          ),
          const SizedBox(height: 16),
          CampoRotulado(
            rotulo: 'Descrição das Atividades',
            campo: TextFormField(
              controller: _descricao,
              maxLines: 4,
              decoration: const InputDecoration(
                hintText: 'Conte brevemente sobre o trabalho e a missão da ONG...',
                prefixIcon: Padding(padding: EdgeInsets.only(bottom: 60), child: Icon(Icons.description_outlined)),
              ),
            ),
          ),
          CampoRotulado(
            rotulo: 'E-mail',
            campo: TextFormField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(hintText: 'exemplo@email.com', prefixIcon: Icon(Icons.mail_outline)),
              validator: _validaEmail,
            ),
          ),
          CampoRotulado(rotulo: 'Senha', campo: CampoSenha(controller: _senha, validator: _validaSenha)),
          CampoRotulado(
            rotulo: 'Confirmar Senha',
            campo: CampoSenha(
              controller: _confirma,
              hint: 'Repita a senha',
              icone: Icons.lock_clock_outlined,
              validator: (v) => v != _senha.text ? 'As senhas não conferem' : null,
            ),
          ),
          ElevatedButton(
            onPressed: _carregando ? null : _cadastrar,
            child: _carregando ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('Concluir Cadastro da ONG'),
          ),
          _rodapeLogin(context),
        ]),
      ),
    );
  }
}

/// Máscara 00.000.000/0000-00
class _CnpjFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final d = somenteDigitos(newValue.text);
    final b = StringBuffer();
    for (var i = 0; i < d.length && i < 14; i++) {
      if (i == 2 || i == 5) b.write('.');
      if (i == 8) b.write('/');
      if (i == 12) b.write('-');
      b.write(d[i]);
    }
    final t = b.toString();
    return TextEditingValue(text: t, selection: TextSelection.collapsed(offset: t.length));
  }
}
