# P3 ASSIO - ejecuta toda la práctica en server-asio-g3 desde el PC anfitrión y guarda salidas y capturas.
# Lo abre lanzar_p3.ps1 en una consola de 120x40. Las contraseñas las escribes tú cuando se piden:
#   guillermo (ssh/scp) 5 veces, sudo 3 veces, y cada cuenta de trabajo 2 veces (ssh y sudo -l).
# Si no conoces la contraseña de alonso o ariadna: .\lanzar_p3.ps1 -Usuarios usuario_a
param([string[]]$Usuarios = @("usuario_a", "alonso", "ariadna"))
Set-Location $PSScriptRoot
$VM  = "server-asio-g3"
$VBM = "C:\Program Files\Oracle\VirtualBox\VBoxManage.exe"
$ADM = "guillermo@127.0.0.1"
$Rol = @{ "usuario_a" = "A"; "alonso" = "B"; "ariadna" = "C" }
function Shot($n) { try { Invoke-WebRequest -UseBasicParsing "http://127.0.0.1:8765/$n" -TimeoutSec 20 | Out-Null } catch { Write-Host "(sin captura $n)" } }
function Ban($t) { Clear-Host; Write-Host "### $t   [$(Get-Date -Format 'dd/MM/yyyy HH:mm:ss')]"; Write-Host "" }

if (-not ((& $VBM list runningvms) -match $VM)) { Write-Host "Arranca primero la VM $VM y vuelve a lanzar el script."; return }

# Servidor de capturas (guarda en .\capturas)
Start-Process powershell.exe -WindowStyle Minimized -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSScriptRoot\servidor_capturas.ps1`""
Start-Sleep -Seconds 3

# 1) Regla de reenvío del NAT y exposición del puerto 2222 en el anfitrión
Ban "1  Anfitrion: reenvio de puertos NAT de $VM y exposicion del puerto 2222"
$host_txt = & {
    "PS> VBoxManage showvminfo $VM --machinereadable | Select-String '^nic1=|^Forwarding'"
    & $VBM showvminfo $VM --machinereadable | Select-String '^nic1=|^Forwarding' | ForEach-Object { $_.Line }
    ""
    "PS> Get-NetTCPConnection -LocalPort 2222 -State Listen"
    Get-NetTCPConnection -LocalPort 2222 -State Listen -ErrorAction SilentlyContinue | Format-Table LocalAddress, LocalPort, State, OwningProcess -AutoSize | Out-String
    "PS> Get-NetFirewallRule -DisplayName 'ASSIO SSH VM 2222'"
    $fw = Get-NetFirewallRule -DisplayName "ASSIO SSH VM 2222" -ErrorAction SilentlyContinue
    if ($fw) { $fw | Format-Table DisplayName, Enabled, Direction, Action -AutoSize | Out-String } else { "No existe la regla de firewall 'ASSIO SSH VM 2222'" }
}
$host_txt | Tee-Object -FilePath "p3_salidas_anfitrion.txt"
Shot "00_anfitrion_nat"

# 2) Copia de los scripts a la VM y fase 1 (cuenta de administración)
Ban "Copiando scripts a la VM (contrasena de guillermo)"
scp -P 2222 p3_servidor.sh p3_capturas.sh p3_sesion.sh structure-monitor.sh telemetry-monitor.sh supply-monitor.sh "${ADM}:~/"
if (-not $?) { Write-Host "Fallo al copiar"; return }
Ban "Fase 1 en la VM (contrasena de guillermo y despues la de sudo)"
ssh -t -p 2222 $ADM "mkdir -p ~/p3 && mv -f ~/p3_servidor.sh ~/p3_capturas.sh ~/p3_sesion.sh ~/structure-monitor.sh ~/telemetry-monitor.sh ~/supply-monitor.sh ~/p3/ && bash ~/p3/p3_capturas.sh fase1"

# 3) Sesión SSH de cada integrante con su propia cuenta (apartados 2 y 5b)
foreach ($u in $Usuarios) {
    Ban "Sesion SSH de $u (contrasena de $u; despues sudo -l pide otra vez la de $u)"
    ssh -t -p 2222 "$u@127.0.0.1" "bash /tmp/p3_sesion.sh $($Rol[$u])"
}

# 4) Intento de acceso directo como root desde el anfitrión (apartado 8)
Ban "8  Intento de acceso SSH como root desde el anfitrion: pulsa Enter sin escribir nada"
Write-Host "PS> ssh -p 2222 -o PubkeyAuthentication=no -o NumberOfPasswordPrompts=1 root@127.0.0.1"
ssh -p 2222 -o PubkeyAuthentication=no -o NumberOfPasswordPrompts=1 root@127.0.0.1
Write-Host "(codigo de salida de ssh: $LASTEXITCODE)"
Shot "08_root_desde_anfitrion"

# 5) Reinicio de la VM para comprobar que los servicios y PermitRootLogin persisten (ampliación)
Ban "Reinicio de la VM (contrasena de guillermo y despues la de sudo)"
ssh -t -p 2222 $ADM "bash ~/p3/p3_capturas.sh reinicio"
Write-Host "Esperando a que la VM vuelva a arrancar..."
Start-Sleep -Seconds 20
for ($i = 0; $i -lt 40; $i++) {
    # VirtualBox escucha en 2222 aunque la VM no haya arrancado: se espera a que sshd responda de verdad
    if (ssh-keyscan -T 3 -p 2222 127.0.0.1 2>$null) { break }
    Start-Sleep -Seconds 5
}
Start-Sleep -Seconds 25

# 6) Fase 2 (persistencia, registros de SSH y estado final) y recogida de las salidas
Ban "Fase 2 en la VM (contrasena de guillermo y despues la de sudo)"
ssh -t -p 2222 $ADM "bash ~/p3/p3_capturas.sh fase2"
Ban "Trayendo las salidas (contrasena de guillermo)"
scp -P 2222 "${ADM}:~/p3/p3_salidas_*.txt" "${ADM}:/tmp/p3_sesion_*.txt" .
Write-Host ""
Write-Host "LISTO. Salidas en $PSScriptRoot (p3_salidas_*.txt, p3_sesion_*.txt) y capturas en $PSScriptRoot\capturas"
