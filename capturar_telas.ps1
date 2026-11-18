# Captura a tela do emulador a cada 3 s (por 8 min) em telas\ - usado para a apresentacao.
$env:Path = "$env:Path;$env:LOCALAPPDATA\Android\Sdk\platform-tools"
$dir = Join-Path $PSScriptRoot 'telas'
New-Item -ItemType Directory -Force $dir | Out-Null
$ultimo = ''
$fim = (Get-Date).AddMinutes(8)
Write-Host 'Capturando a tela do emulador a cada 3 s por 8 minutos. Feche para parar.'
while ((Get-Date) -lt $fim) {
    $tmp = Join-Path $dir 'tmp.png'
    cmd /c "adb -s emulator-5554 exec-out screencap -p > `"$tmp`""
    if ((Test-Path $tmp) -and (Get-Item $tmp).Length -gt 1000) {
        $h = (Get-FileHash $tmp -Algorithm MD5).Hash
        if ($h -ne $ultimo) {
            $nome = 'tela_' + (Get-Date -Format 'HHmmss') + '.png'
            Move-Item $tmp (Join-Path $dir $nome) -Force
            Write-Host "salvo $nome"
            $ultimo = $h
        }
    }
    Start-Sleep 3
}
