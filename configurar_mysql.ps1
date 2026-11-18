# Configura o MySQL local para a API do ONG Mais:
#  1) cria o banco ong_mais e um usuario proprio (ong_mais) com senha gerada
#  2) grava api\.env apontando para o MySQL (backup do anterior em .env.sqlite.bak)
#  3) aplica as migracoes (flask db upgrade) e o seed (contas do Teste Rapido)
#  4) reinicia a API
# Nao precisa da senha do root: da para criar o banco pelo MySQL Workbench (opcao 2).
$ErrorActionPreference = 'Stop'
$raiz = $PSScriptRoot
$api = Join-Path $raiz 'api'
$log = Join-Path $raiz 'saida_mysql.txt'
"=== Configuracao MySQL $(Get-Date) ===" | Out-File $log -Encoding utf8
function L($t, $cor = 'Gray') { Write-Host $t -ForegroundColor $cor; $t | Out-File $log -Append -Encoding utf8 }
function Falha($t) { L "ERRO: $t" 'Red'; Read-Host 'ENTER para fechar'; exit 1 }

function NovaSenha($n) {
    $chars = 'ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz23456789'.ToCharArray()
    $bytes = New-Object byte[] $n
    [System.Security.Cryptography.RandomNumberGenerator]::Create().GetBytes($bytes)
    -join ($bytes | ForEach-Object { $chars[$_ % $chars.Length] })
}

# --- 1. MySQL instalado e rodando ---
$mysql = Get-ChildItem 'C:\Program Files\MySQL\MySQL Server *\bin\mysql.exe' -ErrorAction SilentlyContinue | Select-Object -First 1 -ExpandProperty FullName
if (-not $mysql) { Falha 'mysql.exe nao encontrado em C:\Program Files\MySQL.' }
L "MySQL: $mysql"
$svc = Get-Service -Name 'MySQL*' -ErrorAction SilentlyContinue | Where-Object { $_.Name -notmatch 'Router' } | Select-Object -First 1
if ($svc) {
    L "Servico $($svc.Name): $($svc.Status)"
    if ($svc.Status -ne 'Running') { Falha "O servico $($svc.Name) esta parado. Inicie em services.msc (ou pelo MySQL Workbench) e rode de novo." }
}

# Servidor respondendo na porta 3306?
$porta = $false
try { $tc = New-Object Net.Sockets.TcpClient; $porta = $tc.ConnectAsync('127.0.0.1', 3306).Wait(2000) -and $tc.Connected; $tc.Close() } catch {}
if (-not $porta) {
    L 'O servidor MySQL NAO esta rodando (nada na porta 3306).' 'Red'
    if (-not $svc) {
        L 'Nao existe servico do MySQL no Windows: o servidor foi instalado mas nunca configurado.' 'Yellow'
        L 'Abra "MySQL Installer - Community" no menu Iniciar > MySQL Server > Reconfigure,' 'Yellow'
        L 'defina a senha do root, marque "Windows Service" (MySQL80) e clique em Execute.' 'Yellow'
        L 'Depois rode este script de novo (opcao 1, com a senha que voce definiu).' 'Yellow'
    }
    Falha 'MySQL indisponivel.'
}

# --- 2/3. Banco + usuario da aplicacao ---
$appPwd = NovaSenha 24
$sqlApp = @"
CREATE DATABASE IF NOT EXISTS ong_mais CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER IF NOT EXISTS 'ong_mais'@'localhost' IDENTIFIED BY '$appPwd';
ALTER USER 'ong_mais'@'localhost' IDENTIFIED BY '$appPwd';
GRANT ALL PRIVILEGES ON ong_mais.* TO 'ong_mais'@'localhost';
FLUSH PRIVILEGES;
"@

function SqlComo($usuario, $senha, $sql, $banco = '') {
    $env:MYSQL_PWD = $senha
    $eap = $ErrorActionPreference; $ErrorActionPreference = 'Continue'
    try {
        $margs = @('-u', $usuario, '-h', '127.0.0.1', '-P', '3306', '--protocol=TCP', '-N', '-B')
        if ($banco) { $margs += $banco }
        $out = $sql | & $mysql @margs 2>&1
        if ($LASTEXITCODE -ne 0) { throw ($out | Out-String) }
        return $out
    } finally { Remove-Item Env:MYSQL_PWD -ErrorAction SilentlyContinue; $ErrorActionPreference = $eap }
}

Write-Host ''
Write-Host 'Como criar o banco?' -ForegroundColor Cyan
Write-Host '  [1] Sei a senha do root do MySQL (digito aqui)'
Write-Host '  [2] NAO sei a senha: vou executar um SQL no MySQL Workbench'
$op = Read-Host 'Escolha 1 ou 2'

$criado = $false
if ($op -eq '1') {
    $sec = Read-Host 'Senha do root' -AsSecureString
    $rootPwd = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($sec))
    try {
        SqlComo 'root' $rootPwd $sqlApp | Out-Null
        $criado = $true
        L "Banco 'ong_mais' e usuario 'ong_mais'@'localhost' criados (via root)." 'Green'
    } catch {
        L "Nao conectou como root (senha errada?). Vamos pelo Workbench." 'Yellow'
    }
    $rootPwd = $null
}

if (-not $criado) {
    $sqlFile = Join-Path $raiz 'criar_banco_mysql.local.sql'
    "-- Gerado por configurar_mysql.ps1. Execute no MySQL Workbench (conexao Local instance / root).`r`n$sqlApp" |
        Out-File $sqlFile -Encoding ascii
    try { Set-Clipboard -Value $sqlApp } catch {}
    Write-Host ''
    Write-Host 'O SQL ja foi COPIADO para a area de transferencia. Agora:' -ForegroundColor Cyan
    Write-Host '  1. Abra o MySQL Workbench e entre na conexao "Local instance MySQL80" (root).'
    Write-Host '  2. Se abrir uma aba de consulta vazia, clique nela e cole (Ctrl+V).'
    Write-Host '     (sem aba? menu File > New Query Tab)'
    Write-Host '  3. Clique no raio (Execute) ou Ctrl+Shift+Enter. Deve aparecer tudo verde embaixo.'
    Write-Host "  (o mesmo SQL esta salvo em $sqlFile)"
    for ($i = 1; $i -le 5 -and -not $criado; $i++) {
        Read-Host 'Depois de executar no Workbench, pressione ENTER'
        try {
            SqlComo 'ong_mais' $appPwd 'SELECT 1;' 'ong_mais' | Out-Null
            $criado = $true
            L "Banco 'ong_mais' e usuario 'ong_mais' confirmados (via Workbench)." 'Green'
        } catch {
            L "Ainda nao consegui entrar com o usuario ong_mais. Confira se o SQL rodou sem erro e tente de novo." 'Yellow'
        }
    }
    Remove-Item $sqlFile -ErrorAction SilentlyContinue
    if (-not $criado) { Falha 'Banco nao configurado. Nada foi alterado na API.' }
}

# --- 4. api\.env ---
$envFile = Join-Path $api '.env'
if (Test-Path $envFile) {
    $bak = Join-Path $api '.env.sqlite.bak'
    if (-not (Test-Path $bak)) { Copy-Item $envFile $bak; L "Backup do .env anterior: api\.env.sqlite.bak" }
}
$jwt = NovaSenha 64
@"
# Gerado por configurar_mysql.ps1 em $(Get-Date -Format 'dd/MM/yyyy HH:mm') - NAO versionar
DATABASE_URL=mysql+pymysql://ong_mais:$appPwd@127.0.0.1:3306/ong_mais?charset=utf8mb4
JWT_SECRET_KEY=$jwt
FLASK_DEBUG=1
AUTO_SEED=1
"@ | Out-File $envFile -Encoding ascii
L 'api\.env atualizado para MySQL (senha do usuario ong_mais e chave JWT gerados).' 'Green'

# --- 5. Parar API em execucao (servidor de desenvolvimento) ---
$procs = Get-CimInstance Win32_Process -Filter "Name like 'python%'" | Where-Object { $_.CommandLine -match 'run\.py' }
foreach ($p in $procs) { Stop-Process -Id $p.ProcessId -Force -ErrorAction SilentlyContinue; L "API anterior encerrada (PID $($p.ProcessId))." }

# --- 6. Dependencias, migracoes e seed ---
Set-Location $api
$py = Join-Path $api '.venv\Scripts\python.exe'
if (-not (Test-Path $py)) { Falha 'venv da API nao encontrado (api\.venv). Rode o iniciar_api.cmd uma vez antes.' }
$ErrorActionPreference = 'Continue'
L 'Instalando/atualizando dependencias...'
& $py -m pip install -q -r requirements.txt 2>&1 | Out-File $log -Append -Encoding utf8
$env:FLASK_APP = 'run.py'
L 'Aplicando migracoes (flask db upgrade)...'
& $py -m flask db upgrade 2>&1 | Tee-Object -FilePath $log -Append
if ($LASTEXITCODE -ne 0) { Falha 'flask db upgrade falhou (veja acima).' }
L 'Criando contas do Teste Rapido (flask seed)...'
& $py -m flask seed 2>&1 | Tee-Object -FilePath $log -Append

# --- 7. Conferencia ---
$tabelas = try { SqlComo 'ong_mais' $appPwd 'SHOW TABLES;' 'ong_mais' } catch { $_.Exception.Message }
$usuarios = try { SqlComo 'ong_mais' $appPwd 'SELECT COUNT(*) FROM tb_usuarios;' 'ong_mais' } catch { $_.Exception.Message }
L "Tabelas no MySQL: $($tabelas -join ', ')"
L "Usuarios cadastrados: $usuarios"

# --- 8. Sobe a API de novo ---
Start-Process -FilePath (Join-Path $raiz 'iniciar_api.cmd') -WorkingDirectory $raiz
L 'API reiniciada com MySQL (janela "ONG Mais API").' 'Green'
L '=== CONCLUIDO ===' 'Green'
Read-Host 'ENTER para fechar'
