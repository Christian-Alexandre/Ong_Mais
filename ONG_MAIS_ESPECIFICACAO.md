# ONG Mais — Especificação fechada (v1, 16/11/2026)

Reconstrução do zero. Anexar este arquivo + apresentacao_mobile.docx + prints do protótipo no novo chat.

## Stack
- App: Flutter (Dart), Android primeiro. Pacotes: google_maps_flutter, geolocator, image_picker, http, flutter_secure_storage, url_launcher, intl.
- API: Python 3 + Flask, Flask-JWT-Extended, Bcrypt, Marshmallow, SQLAlchemy 2.0, Flask-Migrate.
- Banco: MySQL em produção; SQLite para desenvolvimento/testes (troca por variável de ambiente DATABASE_URL).
- Fotos e logos em Base64 (MVP).
- Chave Google Maps: fornecida pelo usuário (colocar em android/app/src/main/AndroidManifest.xml). Fallback: OpenStreetMap (flutter_map) se a chave não funcionar.

## Perfis e navegação
- Voluntário (barra inferior): Feed de Campanhas | Mapa de ONGs | Meu Perfil  (confirmar: usuário escreveu "Perfil Público"; no protótipo é "Meu Perfil")
- ONG (barra inferior): Meu Painel | Nova Campanha | Perfil Público

## Telas
1. Login: e-mail/senha; "Teste Rápido 1-clique" (Conta ONG / Conta Voluntário com dados semeados); atalhos Criar Voluntário / Criar Nova ONG.
2. Cadastro Voluntário: nome, e-mail, senha, confirmar senha.
3. Cadastro ONG: logo (opcional), nome fantasia, CNPJ (validação offline de dígitos), categoria/causa (Animais, Educação, Alimentação, Saúde, Meio Ambiente, Outros), WhatsApp, endereço digitado, botão "Capturar minha localização atual" (opcional; se não capturar, tentar geocodificar o endereço; sem coordenadas a ONG não aparece no mapa), descrição, e-mail, senha, confirmar.
4. Feed (Voluntário): abas Explorar Ações (n) / Minhas Inscrições (n); busca por texto; chips Todos/Voluntariado/Doações/Financeiro; card com avatar+nome da ONG, tipo, tempo relativo (corrigir fuso: servidor grava UTC, app converte para local), foto, curtir (funcional, contador real "N pessoas apoiam"), comentar e compartilhar apenas visuais, botão Quero Ajudar, título, descrição, data de criação do post.
5. Minhas Inscrições: cards com status (Pendente/Aprovado/Concluído/Recusado), data, título, ONG, Cancelar Inscrição (só se Pendente).
6. Meu Perfil (Voluntário): avatar, nome, e-mail, badge; stats Ações Apoiadas (inscrições aprovadas/concluídas) e Horas Doadas (soma das horas das inscrições concluídas); editar nome e áreas de interesse; Salvar; ícones atualizar e sair.
7. Meu Painel (ONG): card com logo, nome, e-mail, CNPJ, nº campanhas ativas, WhatsApp, editar perfil; lista de campanhas (ícone por tipo, editar, excluir, "Gerenciar Voluntários Inscritos"); FAB Nova Campanha.
8. Nova Campanha (bottom sheet): tipo (Voluntariado/Doação/Financeiro), título, descrição, foto (Galeria/Câmera), Publicar. Sem campo de data (data = criação).
9. Gerenciar Voluntários Inscritos (nova tela): lista de inscritos com nome, interesses, status; ações Aprovar / Recusar / Concluir. Ao Concluir, a ONG informa as horas trabalhadas (campo numérico), que somam ao voluntário.
10. Mapa de ONGs: busca por nome/causa, chips de categoria, Google Maps com pinos das ONGs, botão minha localização e atualizar, card inferior com ONG, endereço, distância em km (Haversine), Ver Perfil.
11. Perfil Público da ONG: capa (imagem fixa/gradiente — manter), logo, nome, CNPJ, endereço, categoria, "Sobre", Campanhas Ativas, botão laranja QUERO AJUDAR (abre WhatsApp). Remover Resgates/Avaliação/Verificada.

## Regras de negócio
- Quero Ajudar: Voluntariado → cria inscrição Pendente e abre WhatsApp da ONG com mensagem pronta; Doação/Financeiro → só abre WhatsApp (confirmar — usuário respondeu "só encaminhar para o WhatsApp").
- Inscrição: Pendente → Aprovado → Concluído; ou Recusado. Voluntário pode cancelar enquanto Pendente.
- Busca por raio: laço O(n) com Haversine (mantém a análise T(n)=23n do trabalho acadêmico; muda só a fórmula).
- JWT salvo em flutter_secure_storage; papel (ONG/Voluntário) vem no token.
- Fora do escopo: recuperação de senha, push, gamificação, exclusão de conta.

## Modelo de dados (tabelas)
- tb_usuarios: id, email, senha_hash, papel (ONG|VOLUNTARIO), criado_em
- tb_ongs: id(=usuario), nome_fantasia, cnpj, categoria, whatsapp, endereco, latitude, longitude, descricao, logo_base64
- tb_voluntarios: id(=usuario), nome_completo, interesses (JSON), horas_trabalhadas
- tb_campanhas: id, ong_id, tipo, titulo, descricao, foto_base64, criado_em, ativa
- tb_inscricoes: id, campanha_id, voluntario_id, status, horas, criado_em
- tb_curtidas: campanha_id, voluntario_id (PK composta)

## Seed (Teste Rápido)
- ONG: Instituto Patinhas Carentes, contato@patinhascarentes.org.br / 123456, CNPJ válido, categoria Animais, WhatsApp 11987654321, 2 campanhas.
- Voluntário: Lucas Silva, voluntario@teste.com / 123456.
