param([switch]$Reiniciar)
# Liga o emulador Android (o primeiro AVD), instala o ONG_Mais.apk e abre o app.
$ErrorActionPreference = 'Continue'
$sdk = Join-Path $env:LOCALAPPDATA 'Android\Sdk'
$env:Path = "$env:Path;$sdk\platform-tools;$sdk\emulator"
$raiz = $PSScriptRoot
$log = Join-Path $raiz 'saida_emulador.txt'
"=== Emulador $(Get-Date) ===" | Out-File $log -Encoding utf8
function L($t) { Write-Host $t; "$t" | Out-File $log -Append -Encoding utf8 }

$ligado = adb devices | Select-String 'emulator-\d+\s+device'
if ($Reiniciar -and $ligado) { L 'Desligando o emulador...'; adb emu kill | Out-Null; Start-Sleep 8; $ligado = $null }
if (-not $ligado) {
    $avd = (emulator -list-avds | Where-Object { $_ -and $_ -notmatch '^INFO' } | Select-Object -First 1)
    if (-not $avd) { L 'ERRO: nenhum emulador (AVD) encontrado.'; Start-Sleep 5; exit 1 }
    L "Ligando o emulador $avd..."
    Start-Process -FilePath (Join-Path $sdk 'emulator\emulator.exe') -ArgumentList "-avd $avd"
    adb wait-for-device
    $t = 0
    while ((adb shell getprop sys.boot_completed 2>$null) -notmatch '1' -and $t -lt 180) { Start-Sleep 3; $t += 3 }
    Start-Sleep 5
}
L 'Emulador pronto.'
$apk = Join-Path $raiz 'ONG_Mais.apk'
L "Instalando $apk..."
$devs = adb devices | Select-String '\tdevice$' | ForEach-Object { ($_ -split '\t')[0] }
foreach ($d in $devs) {
    L "  $d"
    adb -s $d install -r $apk 2>&1 | ForEach-Object { L "    $_" }
    adb -s $d shell monkey -p br.com.ongmais.ong_mais -c android.intent.category.LAUNCHER 1 2>&1 | Out-Null
}
L '=== CONCLUIDO ==='
Start-Sleep 3
