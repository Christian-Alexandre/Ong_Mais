# Deixa a API do ONG Mais acessivel pela internet (4G, outra rede) via ngrok,
# no endereco fixo https://dismiss-duct-vacate.ngrok-free.dev
# Enquanto esta janela estiver aberta: o PC nao entra em suspensao e o tunel fica no ar.
$ErrorActionPreference = 'Continue'
$raiz = $PSScriptRoot
$dominio = 'dismiss-duct-vacate.ngrok-free.dev'
$log = Join-Path $raiz 'saida_tunel.txt'
"=== Tunel ngrok $(Get-Date) ===" | Out-File $log -Encoding utf8
function L($t, $cor = 'Gray') { Write-Host $t -ForegroundColor $cor; "$t" | Out-File $log -Append -Encoding utf8 }
function Fim($t) { L $t 'Red'; Read-Host 'ENTER para fechar'; exit 1 }

# --- 1. ngrok instalado? (instala pelo winget, pacote oficial Ngrok.Ngrok) ---
function AchaNgrok {
    $c = Get-Command ngrok -ErrorAction SilentlyContinue
    if ($c) { return $c.Source }
    $p = Get-ChildItem "$env:LOCALAPPDATA\Microsoft\WinGet\Packages" -Recurse -Filter ngrok.exe -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($p) { return $p.FullName }
    return $null
}
$ngrok = AchaNgrok
if (-not $ngrok) {
    L 'ngrok nao encontrado. Instalando pelo winget (pacote oficial Ngrok.Ngrok)...' 'Cyan'
    winget install --id Ngrok.Ngrok -e --accept-source-agreements --accept-package-agreements 2>&1 | ForEach-Object { L "  $_" }
    $ngrok = AchaNgrok
    if (-not $ngrok) { Fim 'Nao consegui instalar o ngrok. Instale em https://ngrok.com/download e rode de novo.' }
}
L "ngrok: $ngrok"
# O winget instala uma versao antiga; o servico do ngrok exige uma recente
L 'Atualizando o ngrok (se houver versao nova)...'
& $ngrok update 2>&1 | ForEach-Object { L "  $_" }
$versao = ((& $ngrok version) 2>&1 | Out-String).Trim()
L $versao

# --- 2. Authtoken (voce cola; fica salvo so neste PC) ---
$temToken = $false
foreach ($arq in @("$env:LOCALAPPDATA\ngrok\ngrok.yml", "$env:USERPROFILE\AppData\Local\ngrok\ngrok.yml", "$env:USERPROFILE\.config\ngrok\ngrok.yml")) {
    if ((Test-Path $arq) -and (Select-String -Path $arq -Pattern 'authtoken' -Quiet)) { $temToken = $true }
}
if (-not $temToken) {
    L 'Falta o authtoken do ngrok. Vou abrir a pagina "Your Authtoken": copie o token de la.' 'Yellow'
    Start-Process 'https://dashboard.ngrok.com/get-started/your-authtoken'
    $token = Read-Host 'Cole aqui o authtoken e tecle ENTER'
    if (-not $token.Trim()) { Fim 'Nenhum token informado.' }
    & $ngrok config add-authtoken $token.Trim() 2>&1 | Out-Null
    if ($LASTEXITCODE -ne 0) { Fim 'O ngrok recusou o token. Confira e rode de novo.' }
    L 'Authtoken salvo.' 'Green'
}

# --- 3. API rodando na porta 5000? ---
function ApiNoAr { try { $t = New-Object Net.Sockets.TcpClient; $t.Connect('127.0.0.1', 5000); $t.Close(); return $true } catch { return $false } }
if (-not (ApiNoAr)) {
    L 'API parada: iniciando...' 'Cyan'
    Start-Process -FilePath (Join-Path $raiz 'iniciar_api.cmd') -WorkingDirectory $raiz
    for ($i = 0; $i -lt 30 -and -not (ApiNoAr); $i++) { Start-Sleep 1 }
    if (-not (ApiNoAr)) { Fim 'A API nao subiu (veja api_log.txt).' }
}
L 'API no ar (porta 5000).' 'Green'

# --- 4. Nao deixar o PC dormir enquanto esta janela estiver aberta ---
Add-Type -Namespace Win -Name Energia -MemberDefinition '[DllImport("kernel32.dll")] public static extern uint SetThreadExecutionState(uint f);'
[Win.Energia]::SetThreadExecutionState([uint32]'0x80000001') | Out-Null

# --- 5. Tunel ---
L ''
L "Endereco publico: https://$dominio" 'Green'
L 'No app: engrenagem da tela de login > deixe em branco (APK novo) ou digite o endereco acima.' 'Green'
L 'Para encerrar: Ctrl+C ou feche esta janela.' 'Yellow'
L ''
# --url nas versoes novas; --domain nas antigas (3.3 a 3.15)
$opcao = '--url'
if ($versao -match 'version 3\.(\d+)\.' -and [int]$Matches[1] -lt 16) { $opcao = '--domain'; $alvo = $dominio } else { $alvo = "https://$dominio" }
& $ngrok http 5000 $opcao $alvo --log "$raiz\saida_ngrok.txt"
L "ngrok encerrou (codigo $LASTEXITCODE). Veja saida_ngrok.txt." 'Yellow'
Read-Host 'ENTER para fechar'
