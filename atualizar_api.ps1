# Reinicia a API para carregar codigo novo (aplica as migracoes do banco ao subir).
# Nao apaga dados. O tunel do ngrok pode continuar aberto.
$raiz = $PSScriptRoot
$log = Join-Path $raiz 'saida_atualizar.txt'
"=== Atualizar API $(Get-Date) ===" | Out-File $log -Encoding utf8
$procs = Get-CimInstance Win32_Process -Filter "Name like 'python%'" | Where-Object { $_.CommandLine -match 'run\.py' }
foreach ($p in $procs) { Stop-Process -Id $p.ProcessId -Force -ErrorAction SilentlyContinue }
"API antiga encerrada: $(@($procs).Count) processo(s)" | Out-File $log -Append -Encoding utf8
Start-Sleep 2
Start-Process -FilePath (Join-Path $raiz 'iniciar_api.cmd') -WorkingDirectory $raiz
'Nova API iniciada (veja api_log.txt).' | Out-File $log -Append -Encoding utf8
