# Sobe a API Flask e grava a saida em api_log.txt (na pasta ong_mais)
$raiz = $PSScriptRoot
$log = Join-Path $raiz 'api_log.txt'
Set-Location (Join-Path $raiz 'api')
$env:PYTHONUNBUFFERED = '1'
"=== API iniciada em $(Get-Date) ===" | Out-File $log -Encoding utf8
if (-not (Test-Path '.venv\Scripts\python.exe')) {
    'Criando venv e instalando dependencias...' | Tee-Object -FilePath $log -Append
    python -m venv .venv 2>&1 | Tee-Object -FilePath $log -Append
    .\.venv\Scripts\python.exe -m pip install -r requirements.txt 2>&1 | Tee-Object -FilePath $log -Append
}
if (-not (Test-Path '.env')) { Copy-Item '.env.example' '.env' }
.\.venv\Scripts\python.exe run.py 2>&1 | ForEach-Object { "$_" } | Tee-Object -FilePath $log -Append
'=== API ENCERRADA ===' | Tee-Object -FilePath $log -Append
Read-Host 'A API parou. ENTER para fechar'
