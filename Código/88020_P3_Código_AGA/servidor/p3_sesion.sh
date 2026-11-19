#!/bin/bash
# P3 ASSIO - evidencias que cada integrante obtiene en SU PROPIA sesión SSH.
# Uso, ya dentro de la sesión SSH con la cuenta de trabajo:  bash /tmp/p3_sesion.sh A|B|C
# Guarda la salida en /tmp/p3_sesion_<usuario>.txt y pide al anfitrión las capturas (si escucha).

R="${1:-}"
case "$R" in
    A) S=structure-monitor.sh; SVC=structure-monitor ;;
    B) S=telemetry-monitor.sh; SVC=telemetry-monitor ;;
    C) S=supply-monitor.sh;    SVC=supply-monitor ;;
    *) echo "Uso: bash $0 A|B|C"; exit 1 ;;
esac
T=/opt/aurora6/tools/$S
H="$(hostname)"; ME="$(whoami)"
LOG="/tmp/p3_sesion_${ME}.txt"
exec > >(tee "$LOG") 2>&1

shot() {
    sleep 1
    if { exec 3<>/dev/tcp/10.0.2.2/8765; } 2>/dev/null; then
        printf 'GET /%s HTTP/1.0\r\n\r\n' "$1" >&3; cat <&3 >/dev/null; exec 3>&-
    fi
    sleep 1
}
ban() { clear; echo "### $1   [$(date '+%d/%m/%Y %H:%M:%S')]"; echo; }
u() { echo "$ME@$H:~\$ $*"; bash -c "$*" 2>&1; }

ban "2  Sesión SSH del miembro $R con su propia cuenta ($ME)"
u "whoami"
u "hostname"
u "id"
u 'echo "$SSH_CONNECTION"'
u 'echo "$SSH_TTY"; tty'
u "echo 'Prueba de sesión SSH P3 ($ME)' > ~/prueba_ssh_P3.txt"
u "ls -l ~/prueba_ssh_P3.txt; cat ~/prueba_ssh_P3.txt"
shot S_${R}_2_sesion

ban "5b Miembro $R ($ME): ¿puede mi rol modificar el script del servicio?"
u "ls -l $T"
u "test -w $T && echo 'ALERTA: modificable' || echo 'OK: sin escritura'"
u "test -w /opt/aurora6/tools && echo 'ALERTA: carpeta modificable' || echo 'OK: carpeta sin escritura'"
u "systemctl show $SVC.service -p User -p NoNewPrivileges -p PrivateTmp -p ProtectHome -p ProtectSystem"
u "systemctl is-active $SVC.service"
echo "$ME@$H:~\$ sudo -l"
sudo -l 2>&1
shot S_${R}_5b_escritura
echo
echo "Fin de las evidencias de $ME. Salida guardada en $LOG"
