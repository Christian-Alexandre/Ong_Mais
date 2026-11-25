# Gera o APK de release do ONG Mais (ONG_Mais.apk na pasta do projeto)
# e instala nos aparelhos Android conectados (celular USB e/ou emulador).
# O APK sai apontando para o dominio do ngrok (ou para o IP do PC, se $dominioNgrok estiver vazio);
# da para trocar pela engrenagem na tela de login do app (nao precisa gerar de novo).
$ErrorActionPreference = 'Continue'
$env:Path = "$env:Path;C:\src\flutter\bin;$env:LOCALAPPDATA\Android\Sdk\platform-tools"
$raiz = $PSScriptRoot
$log = Join-Path $raiz 'saida_apk.txt'
"=== Gerar APK $(Get-Date) ===" | Out-File $log -Encoding utf8
function L($t, $cor = 'Gray') { Write-Host $t -ForegroundColor $cor; "$t" | Out-File $log -Append -Encoding utf8 }

# IP do PC na rede (ignora VPNs)
$cfg = Get-NetIPConfiguration | Where-Object {
    $_.IPv4DefaultGateway -and $_.NetAdapter.Status -eq 'Up' -and
    $_.InterfaceDescription -notmatch 'VPN|Radmin|Hamachi|Virtual|TAP|Tunnel|ZeroTier|Tailscale'
} | Select-Object -First 1
$ip = if ($cfg) { $cfg.IPv4Address[0].IPAddress } else { '10.0.2.2' }
# Dominio fixo do ngrok: com ele o APK funciona fora de casa (4G), desde que iniciar_tunel esteja rodando.
# Deixe vazio ('') para embutir o IP do PC na rede local.
$dominioNgrok = 'dismiss-duct-vacate.ngrok-free.dev'
$urlApi = if ($dominioNgrok) { "https://$dominioNgrok" } else { "http://${ip}:5000" }
L "API_BASE_URL embutido: $urlApi"

# APK sem a chave do Google Maps (o app usa OpenStreetMap): pode ser publicado no GitHub
$env:ONG_SEM_CHAVE_MAPS = '1'
Set-Location (Join-Path $raiz 'app')
L 'Compilando (release)... pode levar alguns minutos.' 'Cyan'
flutter build apk --release "--dart-define=API_BASE_URL=$urlApi" "--dart-define=USAR_GOOGLE_MAPS=false" 2>&1 |
    ForEach-Object { "$_" } | Tee-Object -FilePath $log -Append
$apk = Join-Path $raiz 'app\build\app\outputs\flutter-apk\app-release.apk'
if (-not (Test-Path $apk)) { L 'ERRO: APK nao foi gerado (veja acima).' 'Red'; Read-Host 'ENTER para fechar'; exit 1 }

$destino = Join-Path $raiz 'ONG_Mais.apk'
Copy-Item $apk $destino -Force
$mb = [math]::Round((Get-Item $destino).Length / 1MB, 1)
L "APK pronto: $destino ($mb MB)" 'Green'
# Copia para releases\ (versionada no GitHub, para baixar direto no celular)
$pastaRel = Join-Path $raiz 'releases'
New-Item -ItemType Directory -Force $pastaRel | Out-Null
Copy-Item $apk (Join-Path $pastaRel 'ONG_Mais.apk') -Force
L "Copia para o GitHub: releases\ONG_Mais.apk" 'Green'
# Copia para o site (pasta irma site_ong_mais\downloads), se existir
$pastaSite = Join-Path (Split-Path $raiz -Parent) 'site_ong_mais\downloads'
if (Test-Path $pastaSite) {
    Copy-Item $apk (Join-Path $pastaSite 'ONG_Mais.apk') -Force
    L "Copia para o site: $pastaSite\ONG_Mais.apk" 'Green'
}

# Instala nos aparelhos conectados
$devs = adb devices | Select-String '\tdevice$' | ForEach-Object { ($_ -split '\t')[0] }
foreach ($d in $devs) {
    L "Instalando em $d..."
    adb -s $d install -r $destino 2>&1 | ForEach-Object { L "  $_" }
}
if (-not $devs) { L 'Nenhum aparelho conectado; instale copiando o ONG_Mais.apk para o celular.' 'Yellow' }
L '=== CONCLUIDO ===' 'Green'
Start-Sleep 3
