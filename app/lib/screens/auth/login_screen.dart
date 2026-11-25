import 'package:flutter/material.dart';

import '../../core/api_service.dart';
import '../../core/config.dart';
import '../../core/session.dart';
import '../../core/theme.dart';
import '../../core/utils.dart';
import '../../main.dart';
import '../../widgets/common.dart';
import 'cadastro_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _senha = TextEditingController();
  bool _carregando = false;

  @override
  void dispose() {
    _email.dispose();
    _senha.dispose();
    super.dispose();
  }

  Future<void> _entrar() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _carregando = true);
    try {
      await ApiService.instance.login(_email.text, _senha.text);
      if (!mounted) return;
      final s = Session.instance;
      final perfil = s.perfil ?? const <String, dynamic>{};
      final nome = s.isOng ? perfil['nome_fantasia'] : perfil['nome_completo'];
      irParaHome(context, mensagem: 'Bem-vindo(a), $nome! (${s.isOng ? '🏢 ONG' : '🤝 Voluntário'})');
    } catch (e) {
      if (mounted) mostrarSnack(context, 'Erro ao entrar: $e', erro: true);
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  Future<void> _configurarServidor() async {
    final ctrl = TextEditingController(text: AppConfig.apiBaseUrl);
    final salvar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Endereço do servidor'),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('IP do PC onde a API está rodando (mesma rede Wi-Fi). Ex: 192.168.0.10:5000', style: TextStyle(color: AppColors.textGrey)),
          const SizedBox(height: 12),
          TextField(
            controller: ctrl,
            keyboardType: TextInputType.url,
            autocorrect: false,
            decoration: const InputDecoration(prefixIcon: Icon(Icons.dns_outlined), hintText: 'dismiss-duct-vacate.ngrok-free.dev ou 192.168.0.10'),
          ),
          const SizedBox(height: 6),
          const Text('Deixe vazio para voltar ao padrão do build.', style: TextStyle(fontSize: 12, color: AppColors.textGrey)),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Salvar')),
        ],
      ),
    );
    if (salvar != true) return;
    await AppConfig.definirServidor(ctrl.text);
    if (mounted) mostrarSnack(context, 'Servidor: ${AppConfig.apiBaseUrl}');
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButtonLocation: FloatingActionButtonLocation.endTop,
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(top: 8),
        child: IconButton(
          tooltip: 'Servidor: ${AppConfig.apiBaseUrl}',
          icon: const Icon(Icons.settings_outlined, color: AppColors.textGrey),
          onPressed: _configurarServidor,
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 40, 24, 24),
          child: Form(
            key: _form,
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Center(
                child: Container(
                  width: 110,
                  height: 110,
                  decoration: BoxDecoration(
                    gradient: AppColors.gradient,
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: [BoxShadow(color: AppColors.primary.withValues(alpha: 0.35), blurRadius: 24, offset: const Offset(0, 10))],
                  ),
                  child: const Icon(Icons.volunteer_activism_rounded, color: Colors.white, size: 60),
                ),
              ),
              const SizedBox(height: 20),
              const Text('ONG Mais', textAlign: TextAlign.center, style: TextStyle(fontSize: 34, fontWeight: FontWeight.bold, color: AppColors.textDark)),
              const SizedBox(height: 6),
              const Text('Acesse sua conta de ONG ou Voluntário', textAlign: TextAlign.center, style: TextStyle(color: AppColors.textGrey, fontSize: 15)),
              const SizedBox(height: 32),
              CampoRotulado(
                rotulo: 'E-mail cadastrado',
                campo: TextFormField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  autocorrect: false,
                  decoration: const InputDecoration(hintText: 'seuemail@exemplo.com', prefixIcon: Icon(Icons.mail_outline)),
                  validator: (v) => (v == null || !v.contains('@')) ? 'Informe um e-mail válido' : null,
                ),
              ),
              CampoRotulado(
                rotulo: 'Senha',
                campo: CampoSenha(
                  controller: _senha,
                  hint: '••••••••',
                  validator: (v) => (v == null || v.isEmpty) ? 'Informe a senha' : null,
                ),
              ),
              ElevatedButton.icon(
                onPressed: _carregando ? null : () => _entrar(),
                icon: _carregando
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.login_rounded),
                label: const Text('Entrar na Plataforma'),
              ),
              const SizedBox(height: 24),
              const Row(children: [
                Expanded(child: Divider()),
                Padding(padding: EdgeInsets.symmetric(horizontal: 12), child: Text('Ainda não tem conta?', style: TextStyle(color: AppColors.textGrey))),
                Expanded(child: Divider()),
              ]),
              const SizedBox(height: 16),
              Row(children: [
                Expanded(
                  child: _AtalhoCadastro(
                    icone: Icons.person_add_alt_1_outlined,
                    texto: 'Criar Voluntário',
                    cor: AppColors.textDark,
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CadastroScreen(iniciarComoOng: false))),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _AtalhoCadastro(
                    icone: Icons.add_business_outlined,
                    texto: 'Criar Nova ONG',
                    cor: AppColors.primary,
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CadastroScreen(iniciarComoOng: true))),
                  ),
                ),
              ]),
            ]),
          ),
        ),
      ),
    );
  }
}

class _AtalhoCadastro extends StatelessWidget {
  final IconData icone;
  final String texto;
  final Color cor;
  final VoidCallback onTap;
  const _AtalhoCadastro({required this.icone, required this.texto, required this.cor, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), border: Border.all(color: cor.withValues(alpha: 0.6), width: 1.5)),
        child: Column(children: [
          Icon(icone, color: cor, size: 26),
          const SizedBox(height: 6),
          Text(texto, style: TextStyle(color: cor, fontWeight: FontWeight.bold)),
        ]),
      ),
    );
  }
}
