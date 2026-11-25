import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

import '../models/models.dart';
import 'utils.dart';

const _verde = PdfColor.fromInt(0xFF1E8E5A);
const _verdeClaro = PdfColor.fromInt(0xFFE6F4EC);
const _cinza = PdfColor.fromInt(0xFF6C757D);

/// Data da participação: dia do turno, se houver; senão, a data da inscrição.
DateTime? _dataDaAcao(Inscricao i) => i.turno?.inicio ?? i.criadoEm;

/// Gera o PDF do certificado de horas com as participações concluídas.
Future<Uint8List> gerarCertificadoPdf(Voluntario v, List<Inscricao> concluidas) async {
  final total = concluidas.fold<int>(0, (s, i) => s + i.horas);
  final hoje = DateTime.now();
  final codigo = 'ONGM-${v.id.toString().padLeft(4, '0')}-${hoje.year}${hoje.month.toString().padLeft(2, '0')}${hoje.day.toString().padLeft(2, '0')}-$total';
  final ongs = concluidas.map((i) => i.ongNome ?? '').where((n) => n.isNotEmpty).toSet();

  final doc = pw.Document(title: 'Certificado de Voluntariado - ${v.nomeCompleto}', author: 'ONG Mais');
  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.fromLTRB(48, 40, 48, 40),
      theme: pw.ThemeData.withFont(base: pw.Font.helvetica(), bold: pw.Font.helveticaBold()),
      header: (ctx) => ctx.pageNumber == 1
          ? pw.SizedBox()
          : pw.Text('Certificado de Voluntariado - ${v.nomeCompleto}', style: const pw.TextStyle(color: _cinza, fontSize: 9)),
      footer: (ctx) => pw.Container(
        padding: const pw.EdgeInsets.only(top: 8),
        decoration: const pw.BoxDecoration(border: pw.Border(top: pw.BorderSide(color: _verdeClaro, width: 1))),
        child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
          pw.Text('Emitido pelo aplicativo ONG Mais em ${formatarData(hoje)}  |  Código: $codigo', style: const pw.TextStyle(color: _cinza, fontSize: 9)),
          pw.Text('Página ${ctx.pageNumber}/${ctx.pagesCount}', style: const pw.TextStyle(color: _cinza, fontSize: 9)),
        ]),
      ),
      build: (ctx) => [
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(vertical: 22, horizontal: 24),
          decoration: pw.BoxDecoration(color: _verde, borderRadius: pw.BorderRadius.circular(12)),
          child: pw.Row(children: [
            pw.Container(
              width: 46,
              height: 46,
              alignment: pw.Alignment.center,
              decoration: const pw.BoxDecoration(color: PdfColors.white, shape: pw.BoxShape.circle),
              child: pw.Text('+', style: pw.TextStyle(color: _verde, fontSize: 30, fontWeight: pw.FontWeight.bold)),
            ),
            pw.SizedBox(width: 14),
            pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
              pw.Text('ONG Mais', style: pw.TextStyle(color: PdfColors.white, fontSize: 22, fontWeight: pw.FontWeight.bold)),
              pw.Text('Conectando voluntários a ONGs', style: const pw.TextStyle(color: PdfColors.white, fontSize: 11)),
            ]),
          ]),
        ),
        pw.SizedBox(height: 34),
        pw.Center(
          child: pw.Text('CERTIFICADO DE VOLUNTARIADO',
              style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold, color: _verde, letterSpacing: 1.5)),
        ),
        pw.SizedBox(height: 24),
        pw.Paragraph(
          textAlign: pw.TextAlign.justify,
          style: const pw.TextStyle(fontSize: 13, lineSpacing: 5),
          text: 'Certificamos que ${v.nomeCompleto} participou como voluntário(a) de '
              '${concluidas.length == 1 ? '1 ação' : '${concluidas.length} ações'} '
              '${ongs.length == 1 ? 'da organização ${ongs.first}' : 'de ${ongs.length} organizações'} '
              'cadastrada${ongs.length == 1 ? '' : 's'} no aplicativo ONG Mais, '
              'totalizando $total ${total == 1 ? 'hora' : 'horas'} de trabalho voluntário, conforme registrado pelas próprias ONGs.',
        ),
        pw.SizedBox(height: 16),
        pw.Container(
          padding: const pw.EdgeInsets.all(14),
          decoration: pw.BoxDecoration(color: _verdeClaro, borderRadius: pw.BorderRadius.circular(10)),
          child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceAround, children: [
            _numero('$total h', 'horas de voluntariado'),
            _numero('${concluidas.length}', concluidas.length == 1 ? 'ação concluída' : 'ações concluídas'),
            _numero('${ongs.length}', ongs.length == 1 ? 'ONG apoiada' : 'ONGs apoiadas'),
          ]),
        ),
        pw.SizedBox(height: 22),
        pw.Text('Participações', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 8),
        pw.TableHelper.fromTextArray(
          headers: ['Campanha', 'ONG', 'Data', 'Horas'],
          data: [
            for (final i in concluidas) [i.campanhaTitulo ?? '-', i.ongNome ?? '-', formatarData(_dataDaAcao(i)), '${i.horas}h'],
          ],
          headerStyle: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 11),
          headerDecoration: const pw.BoxDecoration(color: _verde),
          cellStyle: const pw.TextStyle(fontSize: 10.5),
          oddRowDecoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFFF8F9FA)),
          cellAlignments: {2: pw.Alignment.center, 3: pw.Alignment.centerRight},
          columnWidths: {0: const pw.FlexColumnWidth(3), 1: const pw.FlexColumnWidth(2.4), 2: const pw.FlexColumnWidth(1.3), 3: const pw.FlexColumnWidth(0.8)},
          border: null,
          cellPadding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 6),
        ),
        pw.SizedBox(height: 40),
        pw.Center(
          child: pw.Column(children: [
            pw.Container(width: 220, height: 1, color: PdfColors.grey600),
            pw.SizedBox(height: 4),
            pw.Text(v.nomeCompleto, style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
            pw.Text('Voluntário(a)${v.membroDesde != null ? ' desde ${formatarData(v.membroDesde)}' : ''}', style: const pw.TextStyle(color: _cinza, fontSize: 10)),
          ]),
        ),
      ],
    ),
  );
  return doc.save();
}

pw.Widget _numero(String valor, String rotulo) => pw.Column(children: [
      pw.Text(valor, style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold, color: _verde)),
      pw.Text(rotulo, style: const pw.TextStyle(fontSize: 10, color: _cinza)),
    ]);

/// Gera e abre o compartilhamento do PDF (salvar, WhatsApp, e-mail, Drive...).
Future<void> compartilharCertificado(Voluntario v, List<Inscricao> concluidas) async {
  final bytes = await gerarCertificadoPdf(v, concluidas);
  final nome = 'certificado_ong_mais_${somenteLetras(v.nomeCompleto)}.pdf';
  await SharePlus.instance.share(ShareParams(
    files: [XFile.fromData(bytes, name: nome, mimeType: 'application/pdf')],
    fileNameOverrides: [nome],
    subject: 'Certificado de Voluntariado - ONG Mais',
    text: 'Meu certificado de voluntariado: ${concluidas.fold<int>(0, (s, i) => s + i.horas)}h pelo ONG Mais 💚',
  ));
}

String somenteLetras(String s) {
  final base = s.toLowerCase().trim().split(RegExp(r'\s+')).first;
  const de = 'áàâãäéèêëíìîïóòôõöúùûüç';
  const para = 'aaaaaeeeeiiiiooooouuuuc';
  final b = StringBuffer();
  for (final ch in base.split('')) {
    final i = de.indexOf(ch);
    final c = i >= 0 ? para[i] : ch;
    if (RegExp(r'[a-z0-9]').hasMatch(c)) b.write(c);
  }
  return b.isEmpty ? 'voluntario' : b.toString();
}
