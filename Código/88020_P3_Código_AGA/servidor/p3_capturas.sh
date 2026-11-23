#!/bin/bash
# P3 ASSIO - ejecuta la práctica en el servidor mostrando cada bloque en pantalla y pide
# al PC anfitrión (10.0.2.2:8765, servidor_capturas.ps1) que capture la ventana del terminal.
# Uso (cuenta de administración guillermo, SIN sudo delante):
#   bash ~/p3/p3_capturas.sh fase1     configuración y pruebas de los tres servicios + SSH root
#   bash ~/p3/p3_capturas.sh fase2     registros de SSH tras las sesiones y estado final
# Las salidas se guardan también en ~/p3/p3_salidas_<fase>.txt

FASE="${1:-}"
DIR="$(cd "$(dirname "$0")" && pwd)"
H="$(hostname)"; ME="$(whoami)"
LOG="$DIR/p3_salidas_${FASE}.txt"
P3="sudo bash $DIR/p3_servidor.sh"

case "$FASE" in fase1|fase2) ;;
    reinicio) sudo -v && { echo "Reiniciando la VM ($(date))"; sudo systemctl reboot; }; exit 0 ;;
    *) echo "Uso: bash $0 fase1|reinicio|fase2"; exit 1 ;; esac
sudo -v || exit 1
exec > >(tee -a "$LOG") 2>&1
echo "##### P3 ASSIO - $FASE - $(date '+%Y-%m-%d %H:%M:%S %Z') - host $H - admin $ME"

shot() {   # avisa al anfitrión para que capture la ventana actual
    sleep 1
    if { exec 3<>/dev/tcp/10.0.2.2/8765; } 2>/dev/null; then
        printf 'GET /%s HTTP/1.0\r\n\r\n' "$1" >&3; cat <&3 >/dev/null; exec 3>&-
    else
        echo "(sin servidor de capturas: $1)"
    fi
    sleep 1
}
ban() { clear; echo "### $1   [$(date '+%d/%m/%Y %H:%M:%S')]"; echo; }
g() { echo "$ME@$H:~\$ $*"; bash -c "$*" 2>&1; }      # comando de la cuenta de administración

rol() {
    case "$1" in
        A) U=usuario_a; S=structure-monitor.sh; SVC=structure-monitor
           OK=/srv/aurora6/ingenieria/mecanica; NO=/srv/aurora6/ingenieria/avionica ;;
        B) U=alonso;    S=telemetry-monitor.sh; SVC=telemetry-monitor
           OK=/srv/aurora6/ingenieria/avionica; NO=/srv/aurora6/ingenieria/mecanica ;;
        C) U=ariadna;   S=supply-monitor.sh;    SVC=supply-monitor
           OK=/srv/aurora6/compras/pedidos;     NO=/srv/aurora6/contabilidad/facturas ;;
    esac
    T=/opt/aurora6/tools/$S
}
SHOWP="-p User -p NoNewPrivileges -p PrivateTmp -p ProtectHome -p ProtectSystem"

if [ "$FASE" = "fase1" ]; then

ban "1  Red de la VM y SSH escuchando en el puerto 22"
g "ip -4 -br addr"
g "ip route"
g "sudo ss -tlnp | grep ':22 '"
g "systemctl is-active ssh.socket ssh.service"
shot 01_red_vm

ban "3  systemctl con SSH (solo consulta: no se detiene desde la sesión remota)"
g "systemctl status ssh --no-pager -n 0"
g "systemctl is-active ssh"
g "systemctl is-enabled ssh ssh.socket"
g "sudo systemctl status ssh.socket --no-pager -n 0"
shot 02_ssh_systemctl

# Servicio de prueba no crítico: el primero que exista de esta lista
TS=""
for c in cron rsyslog unattended-upgrades; do
    systemctl cat "$c.service" >/dev/null 2>&1 && { TS=$c; break; }
done
TS="${TS:-cron}"

ban "3  systemctl con un servicio no crítico: $TS (1/2)"
g "systemctl status $TS --no-pager -n 0"
g "sudo systemctl stop $TS"
g "systemctl is-active $TS"
g "systemctl status $TS --no-pager -n 0"
shot 03_${TS//-/_}_1

ban "3  systemctl con un servicio no crítico: $TS (2/2)"
g "sudo systemctl start $TS"
g "systemctl is-active $TS"
g "sudo systemctl restart $TS"
g "sudo systemctl enable $TS"
g "systemctl is-enabled $TS"
g "systemctl status $TS --no-pager -n 0"
shot 04_${TS//-/_}_2

ban "4  Instalación de los simuladores proporcionados en /opt/aurora6/tools"
g "ls -l $DIR/*.sh"
g "$P3 instalar"
shot 05_instalar

for R in A B C; do
    rol $R
    ban "4  Miembro $R ($U): comprobación del script y corrección de permisos (5a)"
    g "$P3 comprobar $R"
    g "$P3 permisos $R"
    shot ${R}_4a_script

    ban "4  Miembro $R ($U): unidad $SVC.service (configuración básica)"
    g "$P3 unidad $R"
    shot ${R}_4b_unidad

    ban "4  Miembro $R ($U): estado y registros con la configuración básica"
    g "systemctl status $SVC.service --no-pager -n 5"
    g "systemctl is-enabled $SVC.service"
    g "sudo journalctl -u $SVC.service --since '5 minutes ago' --no-pager | tail -n 6"
    g "sudo systemd-analyze security $SVC.service --no-pager | tail -n 1"
    shot ${R}_4c_estado

    ban "5a Miembro $R ($U): propietario y permisos del ejecutable, su ruta y la unidad"
    g "namei -l $T"
    g "stat -c '%U:%G %a %n' $T"
    g "stat -c '%U:%G %a %n' /etc/systemd/system/$SVC.service"
    g "ls -ld /opt /opt/aurora6 /opt/aurora6/tools"
    shot ${R}_5a_permisos

    ban "5c-d Miembro $R ($U): endurecimiento y configuración efectiva"
    g "$P3 endurecer $R"
    g "systemctl show $SVC.service $SHOWP"
    g "systemctl is-active $SVC.service"
    g "sudo systemd-analyze security $SVC.service --no-pager | tail -n 1"
    shot ${R}_5cd_endurecido

    ban "5e Miembro $R ($U): ProtectSystem=strict y relación con DAC/ACL de P2"
    g "$P3 strict $R | tail -n 4"
    g "systemctl show $SVC.service -p ProtectSystem"
    g "systemctl is-active $SVC.service"
    g "sudo systemd-run --wait --pipe --quiet -p User=$U -p ProtectSystem=strict touch $OK/p3_rw_$U.txt"
    g "sudo systemd-run --wait --pipe --quiet -p User=$U -p ProtectSystem=strict -p ReadWritePaths=$OK touch $OK/p3_rw_$U.txt"
    g "sudo ls -l $OK/p3_rw_$U.txt"
    g "sudo systemd-run --wait --pipe --quiet -p User=$U -p ProtectSystem=strict -p ReadWritePaths=$NO touch $NO/p3_rw_$U.txt"
    g "sudo rm -f $OK/p3_rw_$U.txt"
    shot ${R}_5e_strict

    ban "6  Miembro $R ($U): fallo provocado (SIGKILL) y recuperación automática"
    g "systemctl show $SVC.service -p MainPID -p NRestarts"
    g "sudo systemctl kill --kill-who=main --signal=SIGKILL $SVC.service"
    g "sleep 5"
    g "systemctl status $SVC.service --no-pager -n 0"
    g "systemctl show $SVC.service -p MainPID -p NRestarts"
    g "sudo journalctl -u $SVC.service --since '2 minutes ago' --no-pager | tail -n 9"
    shot ${R}_6_fallo

    ban "7  Miembro $R ($U): registros del servicio"
    g "sudo journalctl -u $SVC.service -n 15 --no-pager"
    shot ${R}_7_logs
done

# ---------------- Ampliaciones
ban "10.1 Ampliación: validación de las unidades y stop limpio frente a fallo (miembro A)"
g "sudo systemd-analyze verify /etc/systemd/system/structure-monitor.service /etc/systemd/system/telemetry-monitor.service /etc/systemd/system/supply-monitor.service && echo 'verify: sin errores'"
g "systemctl show structure-monitor.service -p NRestarts"
g "sudo systemctl kill --signal=SIGTERM structure-monitor.service; sleep 5"
g "systemctl show structure-monitor.service -p ActiveState -p Result -p NRestarts"
g "sudo systemctl start structure-monitor.service; systemctl is-active structure-monitor.service"
g "sudo systemctl stop structure-monitor.service; sleep 5; systemctl is-active structure-monitor.service"
g "sudo systemctl start structure-monitor.service; systemctl is-active structure-monitor.service"
shot E1_verify_stop

for R in A B C; do
    rol $R
    ban "10.2 Ampliación: aislamiento adicional y límites de recursos, miembro $R ($U)"
    g "sudo systemd-analyze security $SVC.service --no-pager | tail -n 1"
    g "$P3 extra $R | tail -n 3"
    g "systemctl show $SVC.service -p PrivateNetwork -p CapabilityBoundingSet -p MemoryMax -p CPUQuotaPerSecUSec -p TasksMax"
    g "sudo systemd-analyze security $SVC.service --no-pager | tail -n 1"
    g "systemctl status $SVC.service --no-pager -n 3 | grep -E 'Active|Memory|Tasks|CPU|monitor'"
    shot ${R}_E2_extra
done

ban "10.3 Ampliación: aurora6.target agrupa y controla los tres servicios"
g "$P3 target"
g "systemctl list-dependencies aurora6.target --no-pager"
g "sudo systemctl stop aurora6.target; sleep 2; $P3 resumen"
g "sudo systemctl start aurora6.target; sleep 3; $P3 resumen"
shot E3_target

ban "8  SSH: PermitRootLogin no"
g "$P3 ssh_root"
g "sudo /usr/sbin/sshd -T -C user=root,host=localhost,addr=127.0.0.1 | grep -i permitrootlogin"
g "sudo passwd -S root"
shot 08_ssh_root_1

ban "8  SSH: intento de acceso como root desde la propia VM (sin cerrar esta sesión)"
g "ssh -o BatchMode=yes -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@127.0.0.1 true"
g "systemctl is-active ssh"
g "sudo journalctl -u ssh -n 4 --no-pager"
shot 08_ssh_root_2

# Script de evidencias que cada cuenta de trabajo ejecutará en su propia sesión SSH
sudo install -o root -g root -m 755 "$DIR/p3_sesion.sh" /tmp/p3_sesion.sh

else   # fase2 (después del reinicio de la VM)

ban "10.4 Ampliación: persistencia tras reiniciar la VM (enable y PermitRootLogin)"
g "uptime -s; who -b"
g "$P3 resumen"
g "systemctl is-active aurora6.target; systemctl is-enabled aurora6.target"
g "sudo journalctl -b -u structure-monitor.service -u telemetry-monitor.service -u supply-monitor.service --no-pager | grep -E 'Started|iniciado' | head -n 6"
g "sudo /usr/sbin/sshd -T -C user=root,host=localhost,addr=127.0.0.1 | grep -i permitrootlogin"
shot E4_reinicio

ban "7  Registros de SSH tras las sesiones de los integrantes y el intento como root"
g "sudo journalctl -u ssh -n 14 --no-pager"
shot 09_ssh_logs

ban "9  Estado final de los servicios de AURORA-6"
g "$P3 resumen"
g "systemctl list-units 'structure-monitor*' 'telemetry-monitor*' 'supply-monitor*' --no-pager"
g "ps -o user,pid,ppid,cmd -p \$(pgrep -d, -f '/opt/aurora6/tools/')"
shot 10_resumen

clear; echo "Capturas terminadas."; shot fin
fi
