# Publica o projeto em https://github.com/Christian-Alexandre/Ong_Mais
#  - tira a chave do Google do AndroidManifest (vai para android\local.properties, fora do Git)
#  - cria o repositorio Git local, faz o commit inicial e envia para o GitHub (branch main)
#  - bloqueia o envio se achar chave de API, .env ou local.properties entre os arquivos versionados
# No primeiro push o Git abre o navegador para voce entrar no GitHub (login seu, nada e gravado aqui).
$ErrorActionPreference = 'Continue'
$raiz = $PSScriptRoot
$log = Join-Path $raiz 'saida_github.txt'
$remoto = 'https://github.com/Christian-Alexandre/Ong_Mais.git'
"=== Publicacao GitHub $(Get-Date) ===" | Out-File $log -Encoding utf8
function L($t, $cor = 'Gray') { Write-Host $t -ForegroundColor $cor; "$t" | Out-File $log -Append -Encoding utf8 }
function Falha($t) { L "ERRO: $t" 'Red'; Read-Host 'ENTER para fechar'; exit 1 }
$utf8 = New-Object System.Text.UTF8Encoding($false)

if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    $env:Path = [Environment]::GetEnvironmentVariable('Path', 'Machine') + ';' + [Environment]::GetEnvironmentVariable('Path', 'User')
    if (-not (Get-Command git -ErrorAction SilentlyContinue)) { Falha 'Git nao encontrado. Instale em https://git-scm.com e rode de novo.' }
}
L (git --version)
Set-Location $raiz

# --- 1. Chave do Google fora do codigo ---
$manifest = Join-Path $raiz 'app\android\app\src\main\AndroidManifest.xml'
$localProps = Join-Path $raiz 'app\android\local.properties'
$xml = [IO.File]::ReadAllText($manifest)
$m = [regex]::Match($xml, 'android:value="(AIza[0-9A-Za-z_\-]+)"')
if ($m.Success) {
    $chave = $m.Groups[1].Value
    $props = if (Test-Path $localProps) { [IO.File]::ReadAllText($localProps) } else { '' }
    if ($props -notmatch 'MAPS_API_KEY=') {
        if ($props.Length -gt 0 -and -not $props.EndsWith("`n")) { $props += "`r`n" }
        $props += "MAPS_API_KEY=$chave`r`n"
        [IO.File]::WriteAllText($localProps, $props, $utf8)
    }
    $xml = $xml.Replace("android:value=`"$chave`"", 'android:value="${MAPS_API_KEY}"')
    [IO.File]::WriteAllText($manifest, $xml, $utf8)
    L 'Chave do Google movida do AndroidManifest para android\local.properties (fora do Git).' 'Green'
} elseif ($xml -match 'COLE_SUA_CHAVE') {
    $xml = $xml.Replace('COLE_SUA_CHAVE_DO_GOOGLE_MAPS_AQUI', '${MAPS_API_KEY}')
    [IO.File]::WriteAllText($manifest, $xml, $utf8)
    L 'Manifest ajustado para ler MAPS_API_KEY do local.properties.'
} else { L 'Manifest ja usa ${MAPS_API_KEY}.' }

# --- 2. Repositorio local ---
if (-not (Test-Path (Join-Path $raiz '.git'))) {
    git init -b main 2>&1 | ForEach-Object { L $_ }
}
if (-not (git config user.name)) {
    $nome = Read-Host 'Seu nome para os commits (ex: Christian Alexandre)'
    git config user.name "$nome"
}
if (-not (git config user.email)) {
    $email = Read-Host 'Seu e-mail do GitHub (para os commits)'
    git config user.email "$email"
}
L "Autor dos commits: $(git config user.name)"

git add -A 2>&1 | Out-Null

# --- 3. Trava de seguranca ---
$vazou = @()
$vazou += git grep --cached -I -l -E 'AIza[0-9A-Za-z_-]{20,}' 2>$null
$vazou += git ls-files | Where-Object { $_ -match '(^|/)\.env$' -or $_ -match 'local\.properties$' -or $_ -match '\.db$' }
$vazou = $vazou | Where-Object { $_ } | Sort-Object -Unique
if ($vazou) {
    git reset -q 2>&1 | Out-Null
    Falha "Arquivos com segredo seriam enviados: $($vazou -join ', '). Nada foi publicado."
}
$qtd = (git diff --cached --name-only | Measure-Object).Count
L "Arquivos no commit: $qtd"
git diff --cached --name-only | Out-File $log -Append -Encoding utf8

# --- 4. Commit ---
if ($qtd -gt 0) {
    $msg = @"
Reconstrucao do ONG Mais: API Flask + app Flutter

- API Flask (JWT, Bcrypt, Marshmallow, SQLAlchemy 2.0, Flask-Migrate) com testes
- Migracao inicial para MySQL e script configurar_mysql
- App Flutter com as 11 telas da especificacao (mapa OpenStreetMap)
- Scripts de apoio para Windows (iniciar_api, app_celular, diagnostico)

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01KAnntMtmy2ayX2JRmU8mE5
"@
    $tmp = Join-Path $env:TEMP 'ong_mais_commit.txt'
    [IO.File]::WriteAllText($tmp, $msg, $utf8)
    git commit -q -F $tmp 2>&1 | ForEach-Object { L $_ }
    Remove-Item $tmp -ErrorAction SilentlyContinue
}
L (git log --oneline -1)

# --- 5. Push ---
if (-not (git remote | Select-String -Quiet '^origin$')) { git remote add origin $remoto }
L "Enviando para $remoto (o navegador pode abrir para voce entrar no GitHub)..." 'Cyan'
git push -u origin main 2>&1 | ForEach-Object { L $_ }
if ($LASTEXITCODE -ne 0) { Falha 'O push falhou (veja acima).' }
L '=== PUBLICADO ===' 'Green'
L 'https://github.com/Christian-Alexandre/Ong_Mais'
Read-Host 'ENTER para fechar'
