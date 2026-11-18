import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import 'theme.dart';

/// Servidor grava UTC ("...Z"); aqui convertemos para o fuso local do aparelho.
DateTime? parseUtc(String? iso) {
  if (iso == null || iso.isEmpty) return null;
  final dt = DateTime.tryParse(iso);
  if (dt == null) return null;
  final utc = dt.isUtc ? dt : DateTime.utc(dt.year, dt.month, dt.day, dt.hour, dt.minute, dt.second);
  return utc.toLocal();
}

String formatarData(DateTime? dt) => dt == null ? '' : DateFormat('dd/MM/yyyy').format(dt);

String formatarDataHora(DateTime? dt) => dt == null ? '' : DateFormat("dd/MM/yyyy 'às' HH:mm").format(dt);

/// "há 5 min", "há 3 h", "há 2 dias"... Nunca negativo.
String tempoRelativo(DateTime? dt) {
  if (dt == null) return '';
  var diff = DateTime.now().difference(dt);
  if (diff.isNegative) diff = Duration.zero;
  if (diff.inSeconds < 60) return 'agora';
  if (diff.inMinutes < 60) return 'há ${diff.inMinutes} min';
  if (diff.inHours < 24) return 'há ${diff.inHours} h';
  if (diff.inDays < 7) return 'há ${diff.inDays} ${diff.inDays == 1 ? 'dia' : 'dias'}';
  if (diff.inDays < 30) return 'há ${diff.inDays ~/ 7} sem';
  if (diff.inDays < 365) return 'há ${diff.inDays ~/ 30} ${diff.inDays ~/ 30 == 1 ? 'mês' : 'meses'}';
  return 'há ${diff.inDays ~/ 365} ${diff.inDays ~/ 365 == 1 ? 'ano' : 'anos'}';
}

/// Decodifica Base64 (aceita com ou sem prefixo data:image/...;base64,).
Uint8List? decodeBase64(String? b64) {
  if (b64 == null || b64.isEmpty) return null;
  try {
    final limpo = b64.contains(',') ? b64.substring(b64.indexOf(',') + 1) : b64;
    return base64Decode(limpo.replaceAll(RegExp(r'\s'), ''));
  } catch (_) {
    return null;
  }
}

String somenteDigitos(String s) => s.replaceAll(RegExp(r'\D'), '');

/// (11) 91234-5678 / (11) 3456-7890
String formatarTelefone(String tel) {
  final d = somenteDigitos(tel);
  if (d.length == 11) return '(${d.substring(0, 2)}) ${d.substring(2, 7)}-${d.substring(7)}';
  if (d.length == 10) return '(${d.substring(0, 2)}) ${d.substring(2, 6)}-${d.substring(6)}';
  return tel;
}

/// Validação offline dos dígitos verificadores do CNPJ.
bool cnpjValido(String cnpj) {
  final d = somenteDigitos(cnpj);
  if (d.length != 14 || RegExp(r'^(\d)\1{13}$').hasMatch(d)) return false;
  int dv(String nums, List<int> pesos) {
    var soma = 0;
    for (var i = 0; i < pesos.length; i++) {
      soma += int.parse(nums[i]) * pesos[i];
    }
    final resto = soma % 11;
    return resto < 2 ? 0 : 11 - resto;
  }

  const p1 = [5, 4, 3, 2, 9, 8, 7, 6, 5, 4, 3, 2];
  const p2 = [6, 5, 4, 3, 2, 9, 8, 7, 6, 5, 4, 3, 2];
  final dv1 = dv(d.substring(0, 12), p1);
  final dv2 = dv(d.substring(0, 12) + dv1.toString(), p2);
  return d.substring(12) == '$dv1$dv2';
}

String formatarCnpj(String cnpj) {
  final d = somenteDigitos(cnpj);
  if (d.length != 14) return cnpj;
  return '${d.substring(0, 2)}.${d.substring(2, 5)}.${d.substring(5, 8)}/${d.substring(8, 12)}-${d.substring(12)}';
}

/// Abre o WhatsApp da ONG com mensagem pronta.
Future<bool> abrirWhatsApp(String? numero, String mensagem) async {
  if (numero == null || numero.isEmpty) return false;
  var d = somenteDigitos(numero);
  if (!d.startsWith('55')) d = '55$d';
  final uri = Uri.parse('https://wa.me/$d?text=${Uri.encodeComponent(mensagem)}');
  try {
    return await launchUrl(uri, mode: LaunchMode.externalApplication);
  } catch (_) {
    return false;
  }
}

void mostrarSnack(BuildContext context, String msg, {bool erro = false}) {
  if (!context.mounted) return;
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: erro ? AppColors.danger : AppColors.primary,
      duration: Duration(seconds: erro ? 5 : 3),
    ));
}

/// Rótulos e ícones por tipo de campanha.
class TipoCampanha {
  static const voluntariado = 'VOLUNTARIADO';
  static const doacao = 'DOACAO';
  static const financeiro = 'FINANCEIRO';

  static String rotulo(String tipo) => switch (tipo) {
        voluntariado => 'Voluntariado',
        doacao => 'Doação',
        financeiro => 'Financeiro',
        _ => tipo,
      };

  static IconData icone(String tipo) => switch (tipo) {
        voluntariado => Icons.group_rounded,
        doacao => Icons.redeem_rounded,
        financeiro => Icons.attach_money_rounded,
        _ => Icons.campaign_rounded,
      };

  static Color cor(String tipo) => switch (tipo) {
        voluntariado => AppColors.primary,
        doacao => AppColors.orange,
        financeiro => const Color(0xFF2E7D32),
        _ => AppColors.textGrey,
      };
}

class StatusInscricao {
  static String rotulo(String s) => switch (s) {
        'PENDENTE' => 'Pendente',
        'APROVADO' => 'Aprovado',
        'CONCLUIDO' => 'Concluído',
        'RECUSADO' => 'Recusado',
        _ => s,
      };

  static Color cor(String s) => switch (s) {
        'PENDENTE' => const Color(0xFFF08C00),
        'APROVADO' => AppColors.primary,
        'CONCLUIDO' => const Color(0xFF2E7D32),
        'RECUSADO' => AppColors.danger,
        _ => AppColors.textGrey,
      };

  static IconData icone(String s) => switch (s) {
        'PENDENTE' => Icons.hourglass_bottom_rounded,
        'APROVADO' => Icons.check_circle_outline_rounded,
        'CONCLUIDO' => Icons.verified_rounded,
        'RECUSADO' => Icons.cancel_outlined,
        _ => Icons.info_outline,
      };
}

const categoriasOng = ['Animais', 'Educação', 'Alimentação', 'Saúde', 'Meio Ambiente', 'Outros'];

String emojiCategoria(String c) => switch (c) {
      'Animais' => '🐶',
      'Educação' => '📚',
      'Alimentação' => '🍲',
      'Saúde' => '🩺',
      'Meio Ambiente' => '🌱',
      _ => '🤝',
    };
