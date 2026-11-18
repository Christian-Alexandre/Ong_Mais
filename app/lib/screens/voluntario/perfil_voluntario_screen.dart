import 'package:flutter/material.dart';

import '../../core/api_service.dart';
import '../../core/session.dart';
import '../../core/theme.dart';
import '../../core/utils.dart';
import '../../main.dart';
import '../../models/models.dart';
import '../../widgets/common.dart';

class PerfilVoluntarioScreen extends StatefulWidget {
  const PerfilVoluntarioScreen({super.key});

  @override
  State<PerfilVoluntarioScreen> createState() => _PerfilVoluntarioScreenState();
}

class _PerfilVoluntarioScreenState extends State<PerfilVoluntarioScreen> {
  final _nome = TextEditingController();
  final _interesses = TextEditingController();
  Voluntario? _vol;
  String? _erro;
  bool _salvando = false;

  @override
  void initState() {
    super.initState();
    final p = Session.instance.perfil;
    if (p != null) _aplicar(Voluntario.fromJson(p));
    _carregar();
  }

  @override
  void dispose() {
    _nome.dispose();
    _interesses.dispose();
    super.dispose();
  }

  void _aplicar(Voluntario v) {
    _vol = v;
    _nome.text = v.nomeCompleto;
    _interesses.text = v.interesses.join(', ');
  }

  Future<void> _carregar() async {
    setState(() => _erro = null);
    try {
      final v = await ApiService.instance.meuPerfilVoluntario();
      if (mounted) setState(() => _aplicar(v));
    } catch (e) {
      if (mounted) setState(() => _erro = e.toString());
    }
  }

  Future<void> _salvar() async {
    if (_nome.text.trim().length < 2) {
      mostrarSnack(context, 'Informe seu nome completo.', erro: true);
      return;
    }
    setState(() => _salvando = true);
    try {
      final interesses = _interesses.text.split(RegExp(r'[,;\n]')).map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
      final v = await ApiService.instance.atualizarVoluntario(nome: _nome.text, interesses: interesses);
      if (!mounted) return;
      setState(() => _aplicar(v));
      FocusScope.of(context).unfocus();
      mostrarSnack(context, 'Perfil atualizado com sucesso!');
    } catch (e) {
      if (mounted) mostrarSnack(context, 'Erro ao salvar: $e', erro: true);
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final v = _vol;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Meu Perfil'),
        actions: [
          IconButton(onPressed: _carregar, icon: const Icon(Icons.refresh_rounded, color: AppColors.primary), tooltip: 'Atualizar'),
          IconButton(onPressed: () => sairDaConta(context), icon: const Icon(Icons.logout_rounded, color: AppColors.danger), tooltip: 'Sair'),
        ],
      ),
      body: v == null
          ? (_erro != null ? ErroCarregamento(mensagem: _erro!, onTentar: _carregar) : const Center(child: CircularProgressIndicator()))
          : RefreshIndicator(
              onRefresh: _carregar,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
                    decoration: BoxDecoration(gradient: AppColors.gradient, borderRadius: BorderRadius.circular(22)),
                    child: Column(children: [
                      const AvatarBase64(raio: 44, fallback: Icons.person_rounded),
                      const SizedBox(height: 16),
                      Text(v.nomeCompleto, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text(v.email ?? '', style: const TextStyle(color: Colors.white70, fontSize: 15)),
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(20)),
                        child: const Row(mainAxisSize: MainAxisSize.min, children: [
                          Icon(Icons.volunteer_activism_rounded, color: Colors.white, size: 18),
                          SizedBox(width: 6),
                          Text('Perfil de Voluntário Ativo', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        ]),
                      ),
                    ]),
                  ),
                  const SizedBox(height: 16),
                  Row(children: [
                    Expanded(child: _stat(Icons.check_circle_outline_rounded, '${v.acoesApoiadas}', 'Ações Apoiadas')),
                    const SizedBox(width: 16),
                    Expanded(child: _stat(Icons.timer_outlined, '${v.horasTrabalhadas}h', 'Horas Doadas')),
                  ]),
                  const SizedBox(height: 16),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        const Text('Informações Pessoais', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textDark)),
                        const SizedBox(height: 18),
                        TextField(
                          controller: _nome,
                          textCapitalization: TextCapitalization.words,
                          decoration: const InputDecoration(labelText: 'Nome Completo', prefixIcon: Icon(Icons.person_outline)),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _interesses,
                          maxLines: 3,
                          decoration: const InputDecoration(
                            labelText: 'Áreas de Interesse / Habilidades',
                            hintText: 'Ex: Resgate animal, ensino, tecnologia, distribuição de alimentos...',
                            alignLabelWithHint: true,
                            prefixIcon: Padding(padding: EdgeInsets.only(bottom: 44), child: Icon(Icons.interests_outlined)),
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text('Separe por vírgula.', style: TextStyle(fontSize: 12, color: AppColors.textGrey)),
                        const SizedBox(height: 18),
                        ElevatedButton.icon(
                          onPressed: _salvando ? null : _salvar,
                          icon: _salvando
                              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                              : const Icon(Icons.save_outlined),
                          label: const Text('Salvar Alterações'),
                        ),
                      ]),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
    );
  }

  Widget _stat(IconData icone, String valor, String rotulo) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 22),
        child: Column(children: [
          Icon(icone, color: AppColors.primary, size: 32),
          const SizedBox(height: 8),
          Text(valor, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: AppColors.textDark)),
          Text(rotulo, style: const TextStyle(color: AppColors.textGrey)),
        ]),
      ),
    );
  }
}
