# Escolhe um dispositivo Android (celular ou emulador) e roda o app, gravando a saida em saida_flutter_run.txt
# Mapa: $true = Google Maps (exige chave autorizada no Google Cloud); $false = OpenStreetMap (sem chave)
$usarGoogleMaps = $false

$env:Path = "$env:Path;C:\src\flutter\bin"
$raiz = $PSScriptRoot
$log = Join-Path $raiz ('saida_flutter_run_' + (Get-Date -Format 'HHmmss') + '.txt')
Set-Location (Join-Path $raiz 'app')

function DispositivoAndroid {
    $json = flutter devices --machine 2>$null | Out-String
    try { $lista = $json | ConvertFrom-Json } catch { return $null }
    $android = @($lista | Where-Object { $_.targetPlatform -like 'android*' })
    # Prefere o celular fisico (USB) quando o emulador tambem estiver aberto
    $fisico = $android | Where-Object { -not $_.emulator } | Select-Object -First 1
    if ($fisico) { return $fisico }
    return $android | Select-Object -First 1
}

"=== $(Get-Date) ===" | Out-File $log -Encoding utf8
$dev = DispositivoAndroid
if (-not $dev) {
    Write-Host 'Nenhum Android conectado. Tentando abrir um emulador...' -ForegroundColor Yellow
    $emus = flutter emulators 2>&1 | Out-String
    $emus | Out-File $log -Append -Encoding utf8
    $linha = $emus -split "`n" | Where-Object { $_ -match 'android' -and $_ -notmatch '^\s*Id\b' -and $_ -match '^\S' } | Select-Object -First 1
    $id = if ($linha) { ($linha -split '\s+')[0] } else { $null }
    if ($id) {
        flutter emulators --launch $id.Trim() 2>&1 | Out-File $log -Append -Encoding utf8
        for ($i = 0; $i -lt 24 -and -not $dev; $i++) { Start-Sleep 5; $dev = DispositivoAndroid }
    }
}
if (-not $dev) {
    $msg = 'ERRO: nenhum dispositivo Android. Crie um emulador no Device Manager do Android Studio ou conecte o celular com depuracao USB.'
    Write-Host $msg -ForegroundColor Red; $msg | Out-File $log -Append -Encoding utf8
    Read-Host 'ENTER para fechar'; exit 1
}

"Dispositivo: $($dev.name) ($($dev.id)) emulador=$($dev.emulator)" | Tee-Object -FilePath $log -Append
$extra = @()
if (-not $dev.emulator) {
    # Celular fisico: usa o IP do PC na rede local
    # IP da placa com gateway padrao (Wi-Fi/cabo real), ignorando VPNs (Radmin, Hamachi etc.)
    $cfg = Get-NetIPConfiguration | Where-Object {
        $_.IPv4DefaultGateway -and $_.NetAdapter.Status -eq 'Up' -and
        $_.InterfaceDescription -notmatch 'VPN|Radmin|Hamachi|Virtual|TAP|Tunnel|ZeroTier|Tailscale'
    } | Select-Object -First 1
    $ip = if ($cfg) { $cfg.IPv4Address[0].IPAddress } else { $null }
    if (-not $ip) {
        $ip = (Get-NetIPAddress -AddressFamily IPv4 | Where-Object { $_.IPAddress -match '^(192\.168|10\.|172\.(1[6-9]|2\d|3[01]))' } | Select-Object -First 1).IPAddress
    }
    $extra = @("--dart-define=API_BASE_URL=http://${ip}:5000")
    "API_BASE_URL=http://${ip}:5000" | Tee-Object -FilePath $log -Append
}
$extra += "--dart-define=USAR_GOOGLE_MAPS=$($usarGoogleMaps.ToString().ToLower())"
"USAR_GOOGLE_MAPS=$usarGoogleMaps" | Tee-Object -FilePath $log -Append
flutter run -d $dev.id @extra 2>&1 | Tee-Object -FilePath $log -Append
Read-Host 'flutter run terminou. ENTER para fechar'
