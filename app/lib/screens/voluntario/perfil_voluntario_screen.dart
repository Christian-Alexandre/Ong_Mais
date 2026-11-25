import 'package:flutter/material.dart';

import '../../core/api_service.dart';
import '../../core/certificado.dart';
import '../../core/session.dart';
import '../../core/theme.dart';
import '../../core/utils.dart';
import '../../main.dart';
import '../../models/models.dart';
import '../../widgets/common.dart';
import '../../widgets/interesses.dart';

class PerfilVoluntarioScreen extends StatefulWidget {
  const PerfilVoluntarioScreen({super.key});

  @override
  State<PerfilVoluntarioScreen> createState() => _PerfilVoluntarioScreenState();
}

class _PerfilVoluntarioScreenState extends State<PerfilVoluntarioScreen> {
  final _nome = TextEditingController();
  List<String> _interesses = [];
  Voluntario? _vol;
  String? _erro;
  bool _salvando = false;
  bool _gerandoCertificado = false;

  Future<void> _certificado() async {
    final v = _vol;
    if (v == null) return;
    setState(() => _gerandoCertificado = true);
    try {
      final concluidas = (await ApiService.instance.minhasInscricoes()).where((i) => i.status == 'CONCLUIDO' && i.horas > 0).toList();
      if (!mounted) return;
      if (concluidas.isEmpty) {
        mostrarSnack(context, 'Você ainda não tem participações concluídas. Quando a ONG concluir sua participação, as horas entram no certificado.');
        return;
      }
      await compartilharCertificado(v, concluidas);
    } catch (e) {
      if (mounted) mostrarSnack(context, 'Erro ao gerar o certificado: $e', erro: true);
    } finally {
      if (mounted) setState(() => _gerandoCertificado = false);
    }
  }

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
    super.dispose();
  }

  void _aplicar(Voluntario v) {
    _vol = v;
    _nome.text = v.nomeCompleto;
    _interesses = [...v.interesses];
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
      final v = await ApiService.instance.atualizarVoluntario(nome: _nome.text, interesses: _interesses);
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

  Future<void> _trocarFoto(String? b64) async {
    setState(() => _salvando = true);
    try {
      final v = await ApiService.instance.atualizarFotoVoluntario(b64);
      if (!mounted) return;
      setState(() => _aplicar(v));
      mostrarSnack(context, b64 == null ? 'Foto removida.' : 'Foto de perfil atualizada!');
    } catch (e) {
      if (mounted) mostrarSnack(context, 'Erro ao salvar a foto: $e', erro: true);
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  Future<void> _editarInteresses() async {
    final nova = await escolherInteresses(context, _interesses);
    if (nova == null || !mounted) return;
    setState(() => _interesses = nova);
    await _salvar();
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
                      SeletorFotoPerfil(fotoBase64: v.fotoBase64, nome: v.nomeCompleto, raio: 46, fundoEscuro: true, onAlterada: _trocarFoto),
                      const SizedBox(height: 4),
                      Text(v.fotoBase64 == null ? 'Toque para adicionar uma foto' : 'Toque para trocar a foto', style: const TextStyle(color: Colors.white70, fontSize: 12)),
                      const SizedBox(height: 16),
                      Text(v.nomeCompleto, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text(v.email ?? '', style: const TextStyle(color: Colors.white70, fontSize: 15)),
                      if (v.membroDesde != null) Text('Voluntário desde ${formatarData(v.membroDesde)}', style: const TextStyle(color: Colors.white70, fontSize: 13)),
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
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      leading: const CircleAvatar(backgroundColor: Color(0xFFE6F4EC), child: Icon(Icons.workspace_premium_rounded, color: AppColors.primary)),
                      title: const Text('Certificado de horas', style: TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: const Text('PDF com suas participações concluídas, para a faculdade ou o currículo.'),
                      trailing: _gerandoCertificado
                          ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.picture_as_pdf_outlined, color: AppColors.danger),
                      onTap: _gerandoCertificado ? null : _certificado,
                    ),
                  ),
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
                        const SizedBox(height: 4),
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
                  const SizedBox(height: 16),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(children: [
                          const Icon(Icons.favorite_rounded, color: AppColors.primary),
                          const SizedBox(width: 8),
                          const Expanded(child: Text('Meus Interesses', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textDark))),
                          TextButton.icon(onPressed: _salvando ? null : _editarInteresses, icon: const Icon(Icons.edit_outlined, size: 18), label: const Text('Editar')),
                        ]),
                        const SizedBox(height: 4),
                        const Text('As ONGs e campanhas mostram o que vocês têm em comum.', style: TextStyle(color: AppColors.textGrey, fontSize: 13)),
                        const SizedBox(height: 14),
                        ChipsInteresses(itens: _interesses, vazio: 'Toque em Editar e escolha as causas que você apoia.'),
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
