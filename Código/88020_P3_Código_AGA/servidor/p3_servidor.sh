#!/bin/bash
# ASSIO (88020) - Práctica 3: servicios systemd de AURORA-6, mínimo privilegio y SSH
# Se ejecuta en el servidor Ubuntu con la cuenta de administración:
#   sudo bash p3_servidor.sh <bloque> [A|B|C]
# Bloques con rol:  comprobar | permisos | unidad | endurecer | strict
# Bloques sin rol:  instalar | ssh_root | resumen
# Ampliaciones:     extra R (aislamiento adicional y límites) | target (aurora6.target)
# Los tres simuladores del profesor deben estar en la misma carpeta que este script.

set -uo pipefail

# Cuentas de trabajo de P2 (servidor del grupo). En otra VM, cámbialas por las tuyas.
USER_A="${USER_A:-usuario_a}"   # Miembro A: Guillermo, ingeniería mecánica
USER_B="${USER_B:-alonso}"      # Miembro B: Alonso, aviónica y software
USER_C="${USER_C:-ariadna}"     # Miembro C: Ariadna, compras

TOOLS="/opt/aurora6/tools"
UNITS="/etc/systemd/system"
SRC="$(cd "$(dirname "$0")" && pwd)"
BASE="/srv/aurora6"

if [ "$(id -u)" -ne 0 ]; then
    echo "Ejecuta el script con sudo: sudo bash $0 <bloque> [A|B|C]"
    exit 1
fi

paso() { echo; echo "==> $*"; }

# Datos de cada rol: usuario, script, servicio, descripción y rutas para la prueba de ReadWritePaths
rol() {
    case "${1:-}" in
        A) R_USER="$USER_A"; R_SCRIPT="structure-monitor.sh"; R_SVC="structure-monitor"
           R_DESC="AURORA-6 monitor de la estructura (miembro A, mecánica)"
           R_OK="$BASE/ingenieria/mecanica"; R_NO="$BASE/ingenieria/avionica" ;;
        B) R_USER="$USER_B"; R_SCRIPT="telemetry-monitor.sh"; R_SVC="telemetry-monitor"
           R_DESC="AURORA-6 monitor de telemetría (miembro B, aviónica y software)"
           R_OK="$BASE/ingenieria/avionica"; R_NO="$BASE/ingenieria/mecanica" ;;
        C) R_USER="$USER_C"; R_SCRIPT="supply-monitor.sh"; R_SVC="supply-monitor"
           R_DESC="AURORA-6 monitor de suministros (miembro C, compras)"
           R_OK="$BASE/compras/pedidos"; R_NO="$BASE/contabilidad/facturas" ;;
        *) echo "Indica el rol: A, B o C"; exit 1 ;;
    esac
    R_UNIT="$UNITS/$R_SVC.service"
    id "$R_USER" >/dev/null 2>&1 || { echo "No existe la cuenta $R_USER (créala en P2)"; exit 1; }
}

# Escribe la unidad. Nivel: basica (apartado 4), full (5c) o strict (5e)
escribir_unidad() {
    local nivel="$1"
    {
        echo "[Unit]"
        echo "Description=$R_DESC"
        echo "After=network.target"
        echo
        echo "[Service]"
        echo "Type=simple"
        echo "User=$R_USER"
        echo "ExecStart=$TOOLS/$R_SCRIPT"
        echo "Restart=on-failure"
        echo "RestartSec=3"
        if [ "$nivel" != "basica" ]; then
            echo "# Endurecimiento (P3, apartado 5)"
            echo "NoNewPrivileges=true"
            echo "PrivateTmp=true"
            echo "ProtectHome=true"
            if [ "$nivel" = "strict" ]; then
                echo "ProtectSystem=strict"
            else
                echo "ProtectSystem=full"
            fi
        fi
        echo
        echo "[Install]"
        echo "WantedBy=multi-user.target"
    } > "$R_UNIT"
    chown root:root "$R_UNIT"
    chmod 644 "$R_UNIT"
    echo "Unidad escrita en $R_UNIT:"
    cat "$R_UNIT"
}

instalar() {
    paso "Instalando los simuladores proporcionados en $TOOLS (sin modificarlos)"
    mkdir -p "$TOOLS"
    for s in structure-monitor.sh telemetry-monitor.sh supply-monitor.sh; do
        if [ ! -f "$SRC/$s" ]; then echo "Falta $SRC/$s: pídeselo al profesor, no lo sustituyas"; exit 1; fi
        cp "$SRC/$s" "$TOOLS/$s"
    done
    echo "Estado tal como se han copiado (antes de corregir permisos):"
    ls -ld /opt/aurora6 "$TOOLS"
    ls -l "$TOOLS"
}

comprobar() {
    rol "$1"
    paso "[$1] Comprobando que $TOOLS/$R_SCRIPT existe y puede ejecutarse"
    [ -f "$TOOLS/$R_SCRIPT" ] && echo "Existe: $TOOLS/$R_SCRIPT" || { echo "NO existe $TOOLS/$R_SCRIPT"; exit 1; }
    [ -x "$TOOLS/$R_SCRIPT" ] && echo "Tiene permiso de ejecución" || echo "NO tiene permiso de ejecución (se corrige en el bloque permisos)"
    bash -n "$TOOLS/$R_SCRIPT" && echo "Sintaxis de bash correcta (bash -n)"
    head -n 2 "$TOOLS/$R_SCRIPT"
}

permisos() {
    rol "$1"
    paso "[$1] El script y las carpetas de su ruta quedan en manos de root (solo el script asignado)"
    chown root:root /opt/aurora6 "$TOOLS"
    chmod 755 /opt/aurora6 "$TOOLS"
    chown root:root "$TOOLS/$R_SCRIPT"
    chmod 755 "$TOOLS/$R_SCRIPT"
    namei -l "$TOOLS/$R_SCRIPT"
    stat -c "%U:%G %a %n" "$TOOLS/$R_SCRIPT"
    [ -f "$R_UNIT" ] && stat -c "%U:%G %a %n" "$R_UNIT"
    true
}

unidad() {
    rol "$1"
    paso "[$1] Creando $R_SVC.service con la configuración básica del enunciado"
    escribir_unidad basica
    systemctl daemon-reload
    systemctl enable --now "$R_SVC.service"
    sleep 3
    systemctl is-active "$R_SVC.service"
    systemctl is-enabled "$R_SVC.service"
}

endurecer() {
    rol "$1"
    paso "[$1] Añadiendo NoNewPrivileges, PrivateTmp, ProtectHome y ProtectSystem=full"
    cp "$R_UNIT" "$R_UNIT.bak"
    escribir_unidad full
    systemctl daemon-reload
    systemctl restart "$R_SVC.service"
    sleep 3
    systemctl is-active "$R_SVC.service"
}

strict() {
    rol "$1"
    paso "[$1] Ampliación: ProtectSystem=strict"
    escribir_unidad strict
    systemctl daemon-reload
    systemctl restart "$R_SVC.service"
    sleep 3
    systemctl is-active "$R_SVC.service"
}

ssh_root() {
    local cfg=/etc/ssh/sshd_config
    paso "Deshabilitando el acceso SSH directo como root (PermitRootLogin no)"
    [ -f "$cfg.bak_p3" ] || cp -p "$cfg" "$cfg.bak_p3"
    echo "Copia de seguridad: $cfg.bak_p3"
    echo "Antes:"; grep -nE '^[[:space:]]*#?[[:space:]]*PermitRootLogin' "$cfg"
    if grep -qE '^[[:space:]]*PermitRootLogin' "$cfg"; then
        sed -i -E 's/^[[:space:]]*PermitRootLogin.*/PermitRootLogin no/' "$cfg"
    elif grep -qE '^[[:space:]]*#[[:space:]]*PermitRootLogin' "$cfg"; then
        sed -i -E '0,/^[[:space:]]*#[[:space:]]*PermitRootLogin.*/s//PermitRootLogin no/' "$cfg"
    else
        echo "PermitRootLogin no" >> "$cfg"
    fi
    echo "Después:"; grep -nE '^[[:space:]]*#?[[:space:]]*PermitRootLogin' "$cfg"
    echo "Archivos incluidos que también la definen (el primero que se lee gana):"
    grep -HniE '^[[:space:]]*PermitRootLogin' /etc/ssh/sshd_config.d/*.conf 2>/dev/null || echo "(ninguno)"
    if /usr/sbin/sshd -t; then
        echo "sshd -t: sintaxis correcta, se recarga ssh"
        systemctl reload ssh
    else
        echo "sshd -t ha fallado: se restaura la copia y NO se recarga"
        cp -p "$cfg.bak_p3" "$cfg"
        exit 1
    fi
}

# ---------------- Ampliaciones (no exigidas por el enunciado)
target() {
    paso "Ampliación: aurora6.target agrupa los tres servicios (PartOf= mediante drop-in)"
    cat > "$UNITS/aurora6.target" <<EOT
[Unit]
Description=AURORA-6 servicios de monitorización (grupo 3)
Wants=structure-monitor.service telemetry-monitor.service supply-monitor.service

[Install]
WantedBy=multi-user.target
EOT
    chmod 644 "$UNITS/aurora6.target"
    for s in structure-monitor telemetry-monitor supply-monitor; do
        mkdir -p "$UNITS/$s.service.d"
        printf '[Unit]\nPartOf=aurora6.target\n' > "$UNITS/$s.service.d/10-aurora6-target.conf"
        chmod 644 "$UNITS/$s.service.d/10-aurora6-target.conf"
    done
    cat "$UNITS/aurora6.target"
    systemctl daemon-reload
    systemctl enable aurora6.target
}

extra() {
    rol "$1"
    local d="$UNITS/$R_SVC.service.d" f
    f="$d/20-endurecimiento-extra.conf"
    paso "[$1] Ampliación: aislamiento adicional y límites de recursos (drop-in $f)"
    mkdir -p "$d"
    cat > "$f" <<'EOT'
[Service]
# El simulador no usa red, dispositivos, kernel ni capacidades: se le quitan
PrivateNetwork=true
PrivateDevices=true
ProtectKernelTunables=true
ProtectKernelModules=true
ProtectKernelLogs=true
ProtectControlGroups=true
ProtectClock=true
ProtectHostname=true
ProtectProc=invisible
RestrictSUIDSGID=true
RestrictNamespaces=true
RestrictRealtime=true
LockPersonality=true
MemoryDenyWriteExecute=true
SystemCallArchitectures=native
SystemCallFilter=@system-service
CapabilityBoundingSet=
RestrictAddressFamilies=AF_UNIX
UMask=0077
# Límites de recursos: un fallo del simulador no puede agotar la máquina
MemoryMax=64M
CPUQuota=10%
TasksMax=16
EOT
    chmod 644 "$f"
    systemctl daemon-reload
    systemctl restart "$R_SVC.service"
    sleep 4
    if [ "$(systemctl is-active "$R_SVC.service")" != "active" ]; then
        echo "El servicio no arranca con el drop-in extra: se documenta y se retira"
        journalctl -u "$R_SVC.service" -n 8 --no-pager
        rm -f "$f"; systemctl daemon-reload; systemctl restart "$R_SVC.service"
    fi
    systemctl is-active "$R_SVC.service"
}

resumen() {
    paso "Estado final de los tres servicios"
    for s in structure-monitor telemetry-monitor supply-monitor; do
        printf '%-28s %-8s %-8s\n' "$s.service" "$(systemctl is-active $s.service)" "$(systemctl is-enabled $s.service 2>/dev/null)"
    done
}

case "${1:-}" in
    instalar)  instalar ;;
    comprobar) comprobar "${2:-}" ;;
    permisos)  permisos "${2:-}" ;;
    unidad)    unidad "${2:-}" ;;
    endurecer) endurecer "${2:-}" ;;
    strict)    strict "${2:-}" ;;
    ssh_root)  ssh_root ;;
    resumen)   resumen ;;
    target)    target ;;
    extra)     extra "${2:-}" ;;
    todo)      instalar
               for r in A B C; do comprobar $r; permisos $r; unidad $r; endurecer $r; done
               target; for r in A B C; do extra $r; done
               ssh_root; resumen ;;
    *) echo "Uso: sudo bash $0 {instalar|comprobar R|permisos R|unidad R|endurecer R|strict R|extra R|target|ssh_root|resumen|todo}  (R = A, B o C)"; exit 1 ;;
esac
