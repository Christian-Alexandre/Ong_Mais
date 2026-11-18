# Instala o Flutter SDK (stable) em C:\src\flutter, ajusta o PATH e prepara o app ONG Mais.
# Execute com duplo clique em "instalar_flutter.cmd".
$ErrorActionPreference = 'Continue'
$ProgressPreference = 'SilentlyContinue'
$destino = 'C:\src'
$flutterBin = "$destino\flutter\bin"
$appDir = Join-Path $PSScriptRoot 'app'

function Passo($t) { Write-Host "`n=== $t ===" -ForegroundColor Cyan }

# 1) Git (o Flutter exige)
Passo 'Verificando Git'
if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    Write-Host 'Git nao encontrado. Instalando pelo winget...' -ForegroundColor Yellow
    winget install --id Git.Git -e --source winget --accept-package-agreements --accept-source-agreements
    $env:Path = [Environment]::GetEnvironmentVariable('Path', 'Machine') + ';' + [Environment]::GetEnvironmentVariable('Path', 'User')
}
git --version

# 2) Flutter SDK
Passo 'Flutter SDK'
if (Test-Path "$flutterBin\flutter.bat") {
    Write-Host "Flutter ja existe em $flutterBin" -ForegroundColor Green
} else {
    Write-Host 'Baixando a versao stable (aprox. 1 GB, pode levar alguns minutos)...'
    $r = Invoke-RestMethod 'https://storage.googleapis.com/flutter_infra_release/releases/releases_windows.json'
    $stable = $r.releases | Where-Object { $_.hash -eq $r.current_release.stable } | Select-Object -First 1
    $zip = Join-Path $env:TEMP 'flutter_stable.zip'
    Invoke-WebRequest ($r.base_url + '/' + $stable.archive) -OutFile $zip
    Write-Host "Extraindo em $destino ..."
    New-Item -ItemType Directory -Force $destino | Out-Null
    Expand-Archive $zip -DestinationPath $destino -Force
    Remove-Item $zip -ErrorAction SilentlyContinue
}

# 3) PATH do usuario
Passo 'PATH'
$userPath = [Environment]::GetEnvironmentVariable('Path', 'User')
if ($userPath -notlike "*$flutterBin*") {
    [Environment]::SetEnvironmentVariable('Path', "$userPath;$flutterBin", 'User')
    Write-Host "Adicionado $flutterBin ao PATH do usuario."
} else { Write-Host 'PATH ja configurado.' }
$env:Path = "$env:Path;$flutterBin"

# 4) flutter doctor
Passo 'flutter doctor'
flutter --version
flutter doctor

# 5) Projeto Android do app
Passo 'Gerando projeto Android em app/'
Set-Location $appDir
flutter create --org br.com.ongmais --platforms android --project-name ong_mais .
flutter pub get

# 6) minSdk = 23
Passo 'Ajustando minSdk = 23'
$gradleKts = 'android\app\build.gradle.kts'
$gradle = 'android\app\build.gradle'
if (Test-Path $gradleKts) {
    (Get-Content $gradleKts -Raw) -replace 'minSdk\s*=\s*flutter\.minSdkVersion', 'minSdk = 23' | Set-Content $gradleKts -NoNewline
    Write-Host "minSdk ajustado em $gradleKts"
} elseif (Test-Path $gradle) {
    (Get-Content $gradle -Raw) -replace 'minSdkVersion\s+flutter\.minSdkVersion', 'minSdkVersion 23' | Set-Content $gradle -NoNewline
    Write-Host "minSdk ajustado em $gradle"
}

Passo 'CONCLUIDO'
Write-Host 'Feche e reabra o terminal do Android Studio para o PATH valer.' -ForegroundColor Green
Write-Host 'Falta apenas: colar a chave do Google Maps em app\android\app\src\main\AndroidManifest.xml' -ForegroundColor Yellow
Write-Host 'Se o flutter doctor acima mostrou [X] em Android toolchain, rode: flutter doctor --android-licenses'
Read-Host 'Pressione ENTER para fechar'
