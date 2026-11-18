# Apaga todos os dados do banco (MySQL ou SQLite) e recria so com as contas do Teste Rapido.
$ErrorActionPreference = 'Continue'
$raiz = $PSScriptRoot
$log = Join-Path $raiz 'saida_limpar.txt'
"=== Limpeza de dados $(Get-Date) ===" | Out-File $log -Encoding utf8
function L($t, $cor = 'Gray') { Write-Host $t -ForegroundColor $cor; "$t" | Out-File $log -Append -Encoding utf8 }

Write-Host 'Isto APAGA todas as ONGs, voluntarios, campanhas e inscricoes (fica so o seed).' -ForegroundColor Yellow
Write-Host 'Para CANCELAR, feche esta janela nos proximos 10 segundos.' -ForegroundColor Yellow
for ($i = 10; $i -gt 0; $i--) { Write-Host -NoNewline "$i "; Start-Sleep 1 }
Write-Host ''

# Para a API (libera o banco)
$procs = Get-CimInstance Win32_Process -Filter "Name like 'python%'" | Where-Object { $_.CommandLine -match 'run\.py' }
foreach ($p in $procs) { Stop-Process -Id $p.ProcessId -Force -ErrorAction SilentlyContinue }
if ($procs) { L 'API encerrada.' }

Set-Location (Join-Path $raiz 'api')
$env:FLASK_APP = 'run.py'
& .\.venv\Scripts\python.exe -m flask reset-db --yes 2>&1 | ForEach-Object { "$_" } | Tee-Object -FilePath $log -Append
if ($LASTEXITCODE -ne 0) { L 'ERRO ao limpar (veja acima).' 'Red'; Read-Host 'ENTER para fechar'; exit 1 }

Start-Process -FilePath (Join-Path $raiz 'iniciar_api.cmd') -WorkingDirectory $raiz
L 'Banco limpo (so o seed) e API reiniciada.' 'Green'
L '=== CONCLUIDO ===' 'Green'
Start-Sleep 3
