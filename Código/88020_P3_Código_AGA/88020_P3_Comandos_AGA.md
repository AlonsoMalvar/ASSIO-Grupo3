# Práctica 3: Comandos utilizados

**Asignatura:** Administración de Servicios de Sistemas Operativos (88020)
**Práctica:** P3 - Acceso remoto SSH y administración de servicios con systemd (proyecto AURORA-6)
**Grupo:** ASSIO-Grupo3

Documento del grupo. Cada comando lleva una explicación corta de lo que hace. La práctica se ejecutó el 19/11/2026 en el servidor del grupo (`server-asio-g3`, la misma VM de la P2), con la cuenta de administración `guillermo` y con la cuenta de trabajo de cada integrante: `usuario_a` (A, Guillermo), `alonso` (B, Alonso) y `ariadna` (C, Ariadna). Cada integrante administra un servicio systemd distinto:

| Miembro | Cuenta | Script del profesor | Servicio |
|---|---|---|---|
| A | `usuario_a` | `structure-monitor.sh` | `structure-monitor.service` |
| B | `alonso` | `telemetry-monitor.sh` | `telemetry-monitor.service` |
| C | `ariadna` | `supply-monitor.sh` | `supply-monitor.service` |

> Los comandos con `sudo` piden la contraseña de la cuenta con la que se ejecutan. Los bloques `sudo bash p3_servidor.sh <bloque>` son del script del grupo (`servidor/p3_servidor.sh`) y se lanzan desde la carpeta `~/p3` de la VM.

El código completo está en las carpetas de esta misma carpeta: `servidor/` (scripts de la VM), `unidades_systemd/` (estado final de las unidades) y `anfitrion_windows/` (automatización desde el PC anfitrión).

---

## Índice

* [1. Anfitrión Windows](#1-anfitrión-windows)
* [2. Red, SSH y systemctl](#2-red-ssh-y-systemctl)
* [3. Instalación de los simuladores](#3-instalación-de-los-simuladores)
* [4. Alonso · telemetry-monitor.service (miembro B)](#4-alonso--telemetry-monitorservice-miembro-b)
* [5. Guillermo (A) y Ariadna (C)](#5-guillermo-a-y-ariadna-c)
* [6. SSH: PermitRootLogin no](#6-ssh-permitrootlogin-no)
* [7. Ampliaciones](#7-ampliaciones)
* [8. Registros de SSH y estado final](#8-registros-de-ssh-y-estado-final)

---

## 1. Anfitrión Windows

Comandos del PC de Guillermo (PowerShell), que lanzan toda la práctica y guardan las salidas y las capturas (`anfitrion_windows/lanzar_p3.ps1` y `ejecutar_p3.ps1`).

```powershell
& "C:\Program Files\Oracle\VirtualBox\VBoxManage.exe" showvminfo server-asio-g3 --machinereadable | Select-String '^nic1=|^Forwarding'
```
Muestra el modo de red de la VM (NAT) y la regla de reenvío de puertos 2222 → 22.

```powershell
Get-NetTCPConnection -LocalPort 2222 -State Listen
Get-NetFirewallRule -DisplayName 'ASSIO SSH VM 2222'
```
Comprueba en qué interfaz escucha el puerto 2222 del anfitrión y si existe la regla de firewall de la P2.

```powershell
scp -P 2222 p3_servidor.sh p3_capturas.sh p3_sesion.sh structure-monitor.sh telemetry-monitor.sh supply-monitor.sh guillermo@127.0.0.1:~/
```
Copia a la VM los scripts del grupo y los tres simuladores del profesor.

```powershell
ssh -t -p 2222 guillermo@127.0.0.1 "mkdir -p ~/p3 && mv -f ~/p3_servidor.sh ~/p3_capturas.sh ~/p3_sesion.sh ~/structure-monitor.sh ~/telemetry-monitor.sh ~/supply-monitor.sh ~/p3/ && bash ~/p3/p3_capturas.sh fase1"
```
Entra en la VM con la cuenta de administración, ordena los archivos en `~/p3` y ejecuta la fase 1 (configuración y pruebas de los tres servicios).

```powershell
ssh -t -p 2222 alonso@127.0.0.1 "bash /tmp/p3_sesion.sh B"
```
Sesión SSH con la cuenta de cada integrante (aquí la de Alonso) y ejecución de sus evidencias (apartado 4.2). Igual con `usuario_a` (rol A) y `ariadna` (rol C).

```powershell
ssh -p 2222 -o PubkeyAuthentication=no -o NumberOfPasswordPrompts=1 root@127.0.0.1
```
Intento de acceso directo como root desde el anfitrión, que debe rechazarse (apartado 6).

```powershell
ssh -t -p 2222 guillermo@127.0.0.1 "bash ~/p3/p3_capturas.sh reinicio"
ssh-keyscan -T 3 -p 2222 127.0.0.1
ssh -t -p 2222 guillermo@127.0.0.1 "bash ~/p3/p3_capturas.sh fase2"
```
Reinicia la VM, espera a que `sshd` vuelva a responder y ejecuta la fase 2 (persistencia, registros de SSH y estado final).

```powershell
scp -P 2222 guillermo@127.0.0.1:~/p3/p3_salidas_*.txt guillermo@127.0.0.1:/tmp/p3_sesion_*.txt .
```
Trae a la carpeta local las salidas en texto de la VM.

---

## 2. Red, SSH y systemctl

### Red de la VM y SSH escuchando

```bash
ip -4 -br addr
ip route
```
Muestra la dirección de la VM (`10.0.2.15`, red NAT) y la tabla de rutas con la puerta de enlace.

```bash
sudo ss -tlnp | grep ':22 '
systemctl is-active ssh.socket ssh.service
```
Comprueba que `sshd` escucha en el puerto 22 y que `ssh.socket` y `ssh.service` están activos.

### systemctl con SSH (solo consulta)

```bash
systemctl status ssh --no-pager -n 0
systemctl is-active ssh
systemctl is-enabled ssh ssh.socket
sudo systemctl status ssh.socket --no-pager -n 0
```
Estado de SSH sin detenerlo, para no perder la sesión remota.

### systemctl con un servicio no crítico (`cron`)

```bash
systemctl status cron --no-pager -n 0
sudo systemctl stop cron
systemctl is-active cron
systemctl status cron --no-pager -n 0
```
Estado inicial, parada y comprobación de que queda `inactive`.

```bash
sudo systemctl start cron
systemctl is-active cron
sudo systemctl restart cron
sudo systemctl enable cron
systemctl is-enabled cron
systemctl status cron --no-pager -n 0
```
Arranque, reinicio y activación en el arranque. `active/inactive` indica si funciona ahora; `enabled/disabled`, si arranca solo al encender la máquina.

---

## 3. Instalación de los simuladores

```bash
ls -l ~/p3/*.sh
sudo bash p3_servidor.sh instalar
```
Lista los scripts entregados y ejecuta el bloque `instalar`: crea `/opt/aurora6/tools` (`mkdir -p`), copia en ella los tres simuladores del profesor sin modificarlos (`cp`) y muestra sus permisos tal como llegan (`ls -ld`, `ls -l`).

---

## 4. Alonso · telemetry-monitor.service (miembro B)

Cuenta `alonso` (grupos `avionica`, `software` y `proyecto`). Servicio: `telemetry-monitor.service`, que ejecuta `/opt/aurora6/tools/telemetry-monitor.sh`.

### 4.1. Comprobar el script y corregir los permisos

```bash
sudo bash p3_servidor.sh comprobar B
```
Comprueba que `/opt/aurora6/tools/telemetry-monitor.sh` existe, si tiene permiso de ejecución (`-x`) y que su sintaxis es correcta (`bash -n`). Llegó sin permiso de ejecución.

```bash
sudo bash p3_servidor.sh permisos B
```
Deja `/opt/aurora6` y `/opt/aurora6/tools` en `root:root` con 755 (`chown`, `chmod`) y el script en `root:root` con 755, y muestra la ruta con `namei -l` y los permisos con `stat`. Solo se corrige el script asignado.

```bash
namei -l /opt/aurora6/tools/telemetry-monitor.sh
stat -c '%U:%G %a %n' /opt/aurora6/tools/telemetry-monitor.sh
stat -c '%U:%G %a %n' /etc/systemd/system/telemetry-monitor.service
ls -ld /opt /opt/aurora6 /opt/aurora6/tools
```
Evidencia del propietario y los permisos del script, de cada carpeta de su ruta y de la unidad: todo es de `root` y ninguna carpeta es escribible por los usuarios de trabajo.

### 4.2. Sesión SSH con su propia cuenta

```bash
whoami
hostname
id
echo "$SSH_CONNECTION"
echo "$SSH_TTY"; tty
```
Identifican la sesión: usuario (`alonso`), servidor (`server-asio-g3`), grupos y origen de la conexión. `SSH_CONNECTION` son cuatro campos: IP y puerto del cliente, IP y puerto del servidor. Con el NAT de VirtualBox el cliente aparece como `10.0.2.2`, la puerta de enlace, no como la IP del PC.

```bash
echo 'Prueba de sesión SSH P3 (alonso)' > ~/prueba_ssh_P3.txt
ls -l ~/prueba_ssh_P3.txt; cat ~/prueba_ssh_P3.txt
```
Crea un archivo de prueba solo en su directorio personal y comprueba que es suyo.

```bash
ls -l /opt/aurora6/tools/telemetry-monitor.sh
test -w /opt/aurora6/tools/telemetry-monitor.sh && echo 'ALERTA: modificable' || echo 'OK: sin escritura'
test -w /opt/aurora6/tools && echo 'ALERTA: carpeta modificable' || echo 'OK: carpeta sin escritura'
```
Verifica, sin modificar nada, que su cuenta no puede escribir en el script ni en su carpeta.

```bash
systemctl show telemetry-monitor.service -p User -p NoNewPrivileges -p PrivateTmp -p ProtectHome -p ProtectSystem
systemctl is-active telemetry-monitor.service
sudo -l
```
Muestra la configuración efectiva y el estado del servicio. `sudo -l` responde que `alonso` no puede usar `sudo` en el servidor; si lo tuviera completo, anularía la protección del script.

### 4.3. Unidad systemd (configuración básica)

```bash
sudo bash p3_servidor.sh unidad B
```
Escribe `/etc/systemd/system/telemetry-monitor.service` (propietario `root`, 644), recarga systemd (`systemctl daemon-reload`), la activa y la arranca (`systemctl enable --now`) y comprueba `is-active` e `is-enabled`. La unidad básica es:

```ini
[Unit]
Description=AURORA-6 monitor de telemetría (miembro B, aviónica y software)
After=network.target

[Service]
Type=simple
User=alonso
ExecStart=/opt/aurora6/tools/telemetry-monitor.sh
Restart=on-failure
RestartSec=3

[Install]
WantedBy=multi-user.target
```
`User=alonso` hace que el servicio no corra como root. `Restart=on-failure` con `RestartSec=3` hace que systemd lo reinicie a los 3 segundos si falla.

```bash
systemctl status telemetry-monitor.service --no-pager -n 5
systemctl is-enabled telemetry-monitor.service
sudo journalctl -u telemetry-monitor.service --since '5 minutes ago' --no-pager | tail -n 6
sudo systemd-analyze security telemetry-monitor.service --no-pager | tail -n 1
```
Estado (`active`), arranque automático (`enabled`), líneas del registro y nivel de exposición de la unidad básica (9.2 UNSAFE).

### 4.4. Endurecimiento y mínimo privilegio

```bash
sudo bash p3_servidor.sh endurecer B
```
Guarda una copia de la unidad (`.bak`), añade a `[Service]` las opciones de aislamiento (con `ProtectSystem=full`), recarga systemd y reinicia el servicio. Las opciones añadidas son:

```ini
NoNewPrivileges=true
PrivateTmp=true
ProtectHome=true
ProtectSystem=full
```
`NoNewPrivileges` impide que el proceso y sus hijos ganen privilegios (por ejemplo con binarios `setuid`). `PrivateTmp` le da un `/tmp` propio, no compartido. `ProtectHome` hace inaccesibles `/home`, `/root` y `/run/user`. `ProtectSystem=full` deja `/usr`, `/boot` y `/etc` en solo lectura.

```bash
systemctl show telemetry-monitor.service -p User -p NoNewPrivileges -p PrivateTmp -p ProtectHome -p ProtectSystem
systemctl is-active telemetry-monitor.service
sudo systemd-analyze security telemetry-monitor.service --no-pager | tail -n 1
```
Comprueba la configuración efectiva y que el servicio sigue activo. La exposición baja de 9.2 a 8.4.

### 4.5. ProtectSystem=strict y su relación con la P2 (ampliación)

```bash
sudo bash p3_servidor.sh strict B | tail -n 4
systemctl show telemetry-monitor.service -p ProtectSystem
systemctl is-active telemetry-monitor.service
```
Sustituye `ProtectSystem=full` por `ProtectSystem=strict`, que pone todo el sistema de archivos en solo lectura, y comprueba que el simulador sigue funcionando (no escribe en disco).

```bash
sudo systemd-run --wait --pipe --quiet -p User=alonso -p ProtectSystem=strict touch /srv/aurora6/ingenieria/avionica/p3_rw_alonso.txt
sudo systemd-run --wait --pipe --quiet -p User=alonso -p ProtectSystem=strict -p ReadWritePaths=/srv/aurora6/ingenieria/avionica touch /srv/aurora6/ingenieria/avionica/p3_rw_alonso.txt
sudo ls -l /srv/aurora6/ingenieria/avionica/p3_rw_alonso.txt
sudo systemd-run --wait --pipe --quiet -p User=alonso -p ProtectSystem=strict -p ReadWritePaths=/srv/aurora6/ingenieria/mecanica touch /srv/aurora6/ingenieria/mecanica/p3_rw_alonso.txt
sudo rm -f /srv/aurora6/ingenieria/avionica/p3_rw_alonso.txt
```
Prueba con un proceso temporal de `alonso`: sin excepción da `Read-only file system`; con `ReadWritePaths` en `avionica` crea el archivo (propietario `alonso`, grupo `avionica`); con `ReadWritePaths` en `mecanica` sigue dando `Permission denied`, porque `ReadWritePaths` solo quita la restricción de systemd y no concede más permisos que los DAC y ACL de la P2. Al final borra el archivo de prueba.

### 4.6. Fallo provocado y recuperación automática

```bash
systemctl show telemetry-monitor.service -p MainPID -p NRestarts
sudo systemctl kill --kill-who=main --signal=SIGKILL telemetry-monitor.service
sleep 5
systemctl status telemetry-monitor.service --no-pager -n 0
systemctl show telemetry-monitor.service -p MainPID -p NRestarts
sudo journalctl -u telemetry-monitor.service --since '2 minutes ago' --no-pager | tail -n 9
```
Guarda el PID y el contador de reinicios, mata el proceso principal con `SIGKILL`, espera 5 segundos y comprueba que systemd ha arrancado un proceso nuevo (PID distinto y `NRestarts` pasa de 0 a 1). La recuperación automática es importante en software de monitorización, porque un fallo aislado no deja el sistema sin supervisión.

### 4.7. Registros del servicio

```bash
sudo journalctl -u telemetry-monitor.service -n 15 --no-pager
```
Muestra las últimas líneas del servicio (arranque del simulador, tramas con su latencia, fallo y reinicio). Cada línea indica fecha, equipo, unidad con el PID del proceso y mensaje. Los registros de SSH se revisan en el apartado 8.

---

## 5. Guillermo (A) y Ariadna (C)

Se ejecutan los mismos comandos del apartado 4, cambiando solo el rol, la cuenta, el servicio y las carpetas de la prueba de `ReadWritePaths` de P2:

| Parte | Guillermo (A) | Ariadna (C) |
|---|---|---|
| Rol en `p3_servidor.sh` | `A` | `C` |
| Cuenta | `usuario_a` | `ariadna` |
| Script | `structure-monitor.sh` | `supply-monitor.sh` |
| Servicio | `structure-monitor.service` | `supply-monitor.service` |
| `ReadWritePaths` permitido (P2) | `/srv/aurora6/ingenieria/mecanica` | `/srv/aurora6/compras/pedidos` |
| `ReadWritePaths` no autorizado | `/srv/aurora6/ingenieria/avionica` | `/srv/aurora6/contabilidad/facturas` |
| Sesión SSH | `bash /tmp/p3_sesion.sh A` | `bash /tmp/p3_sesion.sh C` |

---

## 6. SSH: PermitRootLogin no

```bash
sudo bash p3_servidor.sh ssh_root
```
Hace una copia de seguridad de `/etc/ssh/sshd_config` (`.bak_p3`), pone `PermitRootLogin no`, comprueba la sintaxis con `sshd -t` y, si es correcta, recarga SSH (`systemctl reload ssh`); si no, restaura la copia y no recarga.

```bash
sudo /usr/sbin/sshd -T -C user=root,host=localhost,addr=127.0.0.1 | grep -i permitrootlogin
sudo passwd -S root
```
Muestra la configuración efectiva (`permitrootlogin no`) y el estado de la cuenta root, porque en Ubuntu root puede estar bloqueado de antemano.

```bash
ssh -o BatchMode=yes -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@127.0.0.1 true
systemctl is-active ssh
sudo journalctl -u ssh -n 4 --no-pager
```
Intenta entrar como root desde la propia VM, sin cerrar la sesión administrativa: se rechaza, SSH sigue activo y el intento queda en el registro.

---

## 7. Ampliaciones

```bash
sudo systemd-analyze verify /etc/systemd/system/structure-monitor.service /etc/systemd/system/telemetry-monitor.service /etc/systemd/system/supply-monitor.service
```
Valida las tres unidades y comprueba su sintaxis sin errores.

```bash
sudo bash p3_servidor.sh extra B | tail -n 3
systemctl show telemetry-monitor.service -p PrivateNetwork -p CapabilityBoundingSet -p MemoryMax -p CPUQuotaPerSecUSec -p TasksMax
sudo systemd-analyze security telemetry-monitor.service --no-pager | tail -n 1
```
Añade un *drop-in* (`telemetry-monitor.service.d/20-endurecimiento-extra.conf`) con aislamiento adicional (sin red, dispositivos, kernel ni capacidades, filtro de llamadas al sistema) y límites de recursos (`MemoryMax=64M`, `CPUQuota=10%`, `TasksMax=16`). La exposición baja de 8.3 a 0.8 SAFE y el servicio sigue activo.

```bash
sudo bash p3_servidor.sh target
systemctl list-dependencies aurora6.target --no-pager
sudo systemctl stop aurora6.target; sleep 2; sudo bash p3_servidor.sh resumen
sudo systemctl start aurora6.target; sleep 3; sudo bash p3_servidor.sh resumen
```
Crea `aurora6.target`, que agrupa los tres servicios mediante `PartOf=` en un *drop-in* de cada uno, y comprueba que se pueden parar y arrancar juntos.

```bash
uptime -s; who -b
systemctl is-active aurora6.target; systemctl is-enabled aurora6.target
sudo journalctl -b -u structure-monitor.service -u telemetry-monitor.service -u supply-monitor.service --no-pager | grep -E 'Started|iniciado' | head -n 6
```
Tras reiniciar la VM, comprueba que los tres servicios y `aurora6.target` arrancan solos (`enabled`) y que `PermitRootLogin no` se mantiene.

---

## 8. Registros de SSH y estado final

```bash
sudo journalctl -u ssh -n 14 --no-pager
```
Muestra las conexiones de las tres cuentas de trabajo y el intento de acceso como root rechazado.

```bash
sudo bash p3_servidor.sh resumen
systemctl list-units 'structure-monitor*' 'telemetry-monitor*' 'supply-monitor*' --no-pager
ps -o user,pid,ppid,cmd -p $(pgrep -d, -f '/opt/aurora6/tools/')
```
Estado final de los tres servicios y comprobación de que cada simulador corre con la cuenta de su integrante (no como root) y con `systemd` (PID 1) como proceso padre.
