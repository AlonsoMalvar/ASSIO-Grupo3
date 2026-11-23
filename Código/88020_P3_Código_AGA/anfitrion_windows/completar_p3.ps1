param([string[]]$Usuarios = @("usuario_a"))
Set-Location $PSScriptRoot
$VM = "server-asio-g3"; $VBM = "C:\Program Files\Oracle\VirtualBox\VBoxManage.exe"; $ADM = "guillermo@127.0.0.1"
$Rol = @{ "usuario_a" = "A"; "alonso" = "B"; "ariadna" = "C" }
function Shot($n) { try { Invoke-WebRequest -UseBasicParsing "http://127.0.0.1:8765/$n" -TimeoutSec 20 | Out-Null } catch { Write-Host "(sin captura $n)" } }
function Ban($t) { Clear-Host; Write-Host "### $t   [$(Get-Date -Format 'dd/MM/yyyy HH:mm:ss')]"; Write-Host "" }
Start-Process powershell.exe -WindowStyle Minimized -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSScriptRoot\servidor_capturas.ps1`""
Start-Sleep -Seconds 3
Ban "Pulsa Enter con ESTA ventana delante para empezar"; Read-Host | Out-Null
Ban "1  Anfitrion: reenvio de puertos NAT de $VM y exposicion del puerto 2222"
$t = & {
  "PS> VBoxManage showvminfo $VM --machinereadable | Select-String '^nic1=|^Forwarding'"
  & $VBM showvminfo $VM --machinereadable | Select-String '^nic1=|^Forwarding' | ForEach-Object { $_.Line }
  ""; "PS> Get-NetTCPConnection -LocalPort 2222 -State Listen"
  Get-NetTCPConnection -LocalPort 2222 -State Listen -ErrorAction SilentlyContinue | Format-Table LocalAddress, LocalPort, State, OwningProcess -AutoSize | Out-String
  "PS> Get-NetFirewallRule -DisplayName 'ASSIO SSH VM 2222'"
  $fw = Get-NetFirewallRule -DisplayName "ASSIO SSH VM 2222" -ErrorAction SilentlyContinue
  if ($fw) { $fw | Format-Table DisplayName, Enabled, Direction, Action -AutoSize | Out-String } else { "No existe la regla de firewall 'ASSIO SSH VM 2222'" }
}
$t | Tee-Object -FilePath "p3_salidas_anfitrion.txt"
Shot "00_anfitrion_nat"
foreach ($u in $Usuarios) {
  Ban "Sesion SSH de $u (contrasena de $u; despues sudo -l pide otra vez la de $u)"
  ssh -t -p 2222 guillermo@127.0.0.1 "sudo install -o root -g root -m 755 ~/p3/p3_sesion.sh /tmp/p3_sesion.sh"
  ssh -t -p 2222 "$u@127.0.0.1" "bash /tmp/p3_sesion.sh $($Rol[$u])"
}
Ban "Fase 2 en la VM (contrasena de guillermo y despues la de sudo)"
ssh -t -p 2222 $ADM "bash ~/p3/p3_capturas.sh fase2"
Ban "Trayendo las salidas (contrasena de guillermo)"
scp -P 2222 "${ADM}:~/p3/p3_salidas_*.txt" "${ADM}:/tmp/p3_sesion_*.txt" .
Write-Host "LISTO"