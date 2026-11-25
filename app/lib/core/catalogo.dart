import 'package:flutter/services.dart';

/// Catálogo de causas: categoria da ONG -> áreas de atuação.
/// Cópia de api/app/catalogo.py — mantenha as duas iguais.
const Map<String, List<String>> areasPorCategoria = {
  'Animais': ['Adoção', 'Resgate de animais', 'Cuidados veterinários', 'Castração', 'Lar temporário', 'Alimentação animal'],
  'Educação': ['Reforço escolar', 'Alfabetização', 'Cursos profissionalizantes', 'Inclusão digital', 'Leitura e cultura', 'Educação infantil'],
  'Alimentação': ['Cestas básicas', 'Refeições comunitárias', 'Combate ao desperdício', 'Hortas comunitárias', 'Banco de alimentos'],
  'Saúde': ['Apoio a pacientes', 'Saúde mental', 'Doação de sangue', 'Campanhas de prevenção', 'Cuidado de idosos', 'Pessoas com deficiência'],
  'Meio Ambiente': ['Reflorestamento', 'Reciclagem', 'Limpeza de praias e rios', 'Educação ambiental', 'Proteção da fauna'],
  'Outros': ['Assistência social', 'Moradia', 'Esporte e lazer', 'Cultura e arte', 'Direitos humanos', 'Emergências e desastres'],
};

/// Rótulos que representam uma ONG para comparar com os interesses do voluntário:
/// a categoria (ex.: "Animais") + as áreas de atuação (ex.: "Adoção").
List<String> tagsDaOng(String? categoria, List<String> areas) => [
      if (categoria != null && categoria.isNotEmpty) categoria,
      ...areas,
    ];

String _norm(String s) => s.trim().toLowerCase();

/// Pontos em comum (estilo Tinder): itens de [a] que também aparecem em [b], na ordem de [a].
List<String> emComum(List<String> a, List<String> b) {
  final conjunto = b.map(_norm).toSet();
  final vistos = <String>{};
  return [
    for (final x in a)
      if (conjunto.contains(_norm(x)) && vistos.add(_norm(x))) x,
  ];
}

// ---------------------------------------------------------------- Telefone

/// DDDs em uso no Brasil (Anatel). Mesma lista da API.
const Set<int> dddsValidos = {
  11, 12, 13, 14, 15, 16, 17, 18, 19,
  21, 22, 24, 27, 28,
  31, 32, 33, 34, 35, 37, 38,
  41, 42, 43, 44, 45, 46, 47, 48, 49,
  51, 53, 54, 55,
  61, 62, 63, 64, 65, 66, 67, 68, 69,
  71, 73, 74, 75, 77, 79,
  81, 82, 83, 84, 85, 86, 87, 88, 89,
  91, 92, 93, 94, 95, 96, 97, 98, 99,
};

/// null se o telefone (DDD + número) é válido; senão a mensagem de erro.
/// Celular: DDD + 9 dígitos começando com 9. Fixo: DDD + 8 dígitos começando com 2 a 5.
String? telefoneErro(String? valor) {
  var d = (valor ?? '').replaceAll(RegExp(r'\D'), '');
  if ((d.length == 12 || d.length == 13) && d.startsWith('55')) d = d.substring(2);
  if (d.isEmpty) return 'Informe o WhatsApp com DDD';
  if (d.length != 10 && d.length != 11) return 'Informe DDD + número (ex.: (11) 98765-4321)';
  final ddd = int.parse(d.substring(0, 2));
  if (!dddsValidos.contains(ddd)) return 'DDD $ddd não existe';
  final numero = d.substring(2);
  if (numero.length == 9 && numero[0] != '9') return 'Celular deve começar com 9 depois do DDD';
  if (numero.length == 8 && !'2345'.contains(numero[0])) return 'Número fixo inválido (celular precisa do 9)';
  if (RegExp(r'^(\d)\1+$').hasMatch(numero)) return 'Número inválido';
  return null;
}

/// Máscara (11) 98765-4321 / (11) 3456-7890 enquanto digita.
class TelefoneFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    var d = newValue.text.replaceAll(RegExp(r'\D'), '');
    if (d.length > 11) d = d.substring(0, 11);
    final b = StringBuffer();
    for (var i = 0; i < d.length; i++) {
      if (i == 0) b.write('(');
      if (i == 2) b.write(') ');
      // traço: depois do 5º número no celular (11 dígitos), do 4º no fixo
      if (d.length == 11 && i == 7) b.write('-');
      if (d.length <= 10 && i == 6) b.write('-');
      b.write(d[i]);
    }
    final texto = b.toString();
    return TextEditingValue(text: texto, selection: TextSelection.collapsed(offset: texto.length));
  }
}
