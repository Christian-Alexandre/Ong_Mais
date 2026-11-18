$ErrorActionPreference = 'Continue'
$env:Path = "$env:Path;C:\src\flutter\bin;$env:LOCALAPPDATA\Android\Sdk\platform-tools"
$log = Join-Path $PSScriptRoot 'saida_diagnostico.txt'
function L($t) { $t | Out-File $log -Append -Encoding utf8; Write-Host $t }
"=== Diagnostico $(Get-Date) ===" | Out-File $log -Encoding utf8

L "`n--- Processo escutando na porta 5000 ---"
$con = Get-NetTCPConnection -LocalPort 5000 -State Listen -ErrorAction SilentlyContinue
if ($con) {
    foreach ($c in $con) {
        $p = Get-Process -Id $c.OwningProcess -ErrorAction SilentlyContinue
        L ("{0}:{1}  PID {2}  {3}  {4}" -f $c.LocalAddress, $c.LocalPort, $c.OwningProcess, $p.ProcessName, $p.Path)
    }
} else { L 'NINGUEM escutando na porta 5000 (API parada).' }

L "`n--- Teste http://127.0.0.1:5000/ ---"
try { L (Invoke-WebRequest 'http://127.0.0.1:5000/' -UseBasicParsing -TimeoutSec 5).Content } catch { L "FALHOU: $($_.Exception.Message)" }

L "`n--- Placas de rede com gateway ---"
Get-NetIPConfiguration | Where-Object { $_.IPv4DefaultGateway } | ForEach-Object {
    L ("{0} | {1} | IP {2} | GW {3} | Perfil {4}" -f $_.InterfaceAlias, $_.InterfaceDescription, $_.IPv4Address[0].IPAddress, $_.IPv4DefaultGateway[0].NextHop, $_.NetProfile.NetworkCategory)
}
$ip = (Get-NetIPConfiguration | Where-Object { $_.IPv4DefaultGateway -and $_.InterfaceDescription -notmatch 'VPN|Radmin|Hamachi|Virtual|TAP|Tunnel|ZeroTier|Tailscale' } | Select-Object -First 1).IPv4Address[0].IPAddress
L "`n--- Teste http://${ip}:5000/ (IP da rede) ---"
try { L (Invoke-WebRequest "http://${ip}:5000/" -UseBasicParsing -TimeoutSec 5).Content } catch { L "FALHOU: $($_.Exception.Message)" }

L "`n--- Firewall: perfis ---"
Get-NetFirewallProfile | ForEach-Object { L ("{0}: ativo={1} entrada_padrao={2}" -f $_.Name, $_.Enabled, $_.DefaultInboundAction) }

L "`n--- Firewall: regras de entrada para python ---"
$regras = Get-NetFirewallApplicationFilter -ErrorAction SilentlyContinue | Where-Object { $_.Program -match 'python' }
if ($regras) {
    foreach ($f in $regras) {
        $r = $f | Get-NetFirewallRule
        if ($r.Direction -eq 'Inbound') { L ("{0} | acao={1} | ativo={2} | perfil={3} | {4}" -f $r.DisplayName, $r.Action, $r.Enabled, $r.Profile, $f.Program) }
    }
} else { L 'Nenhuma regra para python.' }
$porta = Get-NetFirewallPortFilter -Protocol TCP -ErrorAction SilentlyContinue | Where-Object { $_.LocalPort -eq '5000' }
foreach ($f in $porta) { $r = $f | Get-NetFirewallRule; L ("Regra porta 5000: {0} | acao={1} | ativo={2} | dir={3}" -f $r.DisplayName, $r.Action, $r.Enabled, $r.Direction) }

L "`n--- Dispositivos (adb) ---"
L ((adb devices -l 2>&1) | Out-String)
L "=== FIM ==="
Read-Host 'Diagnostico concluido. ENTER para fechar'
