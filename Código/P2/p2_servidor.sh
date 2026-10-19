#!/bin/bash
# ASSIO (88020) - Práctica 2: estructura, usuarios, grupos, DAC y ACLs
# Proyecto AURORA-6. Se ejecuta en el servidor Ubuntu con la cuenta de administración:
#   sudo bash p2_servidor.sh <bloque>
# Bloques: estructura | usuarios | dac751 | base | politica_A | politica_B | politica_C | semillas | verificar | todo

set -euo pipefail

# Nombres de las cuentas de trabajo (cámbialos por los acordados en el grupo)
USER_A="usuario_a"   # Miembro A: Ingeniería mecánica
USER_B="alonso"      # Miembro B: Aviónica y software
USER_C="ariadna"     # Miembro C: Compras y configuración

BASE="/srv/aurora6"

if [ "$(id -u)" -ne 0 ]; then
    echo "Ejecuta el script con sudo: sudo bash $0 <bloque>"
    exit 1
fi

for cmd in setfacl getfacl; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
        echo "Falta $cmd. Instálalo con: sudo apt install acl"
        exit 1
    fi
done

paso() { echo; echo "==> $*"; }

estructura() {
    paso "Creando la estructura de $BASE"
    mkdir -p "$BASE"/ingenieria/{mecanica,avionica,software} \
             "$BASE"/compras/{proveedores,pedidos} \
             "$BASE"/contabilidad/facturas \
             "$BASE"/documentacion/comun \
             "$BASE"/confidencial \
             "$BASE"/intercambio/{incoming,approved,quarantine}
    tree -d "$BASE" 2>/dev/null || find "$BASE" -type d | sort
}

usuarios() {
    paso "Creando grupos de departamento y grupo común"
    for g in mecanica avionica software compras proyecto; do
        getent group "$g" >/dev/null || groupadd "$g"
    done

    paso "Creando cuentas de trabajo (sin privilegios sudo)"
    for u in "$USER_A" "$USER_B" "$USER_C"; do
        id "$u" >/dev/null 2>&1 || useradd -m -s /bin/bash "$u"
    done

    usermod -aG mecanica,proyecto          "$USER_A"
    usermod -aG avionica,software,proyecto "$USER_B"
    usermod -aG compras,proyecto           "$USER_C"

    for u in "$USER_A" "$USER_B" "$USER_C"; do
        id "$u"
        groups "$u"
    done
    echo
    echo "Asigna ahora la contraseña de cada cuenta de forma interactiva:"
    echo "  sudo passwd $USER_A ; sudo passwd $USER_B ; sudo passwd $USER_C"
}

dac751() {
    paso "Ejercicio 751 sobre documentacion"
    chown root:proyecto "$BASE/documentacion"
    chmod 751 "$BASE/documentacion"
    ls -ld "$BASE/documentacion"
}

base() {
    paso "Permisos base de los niveles superiores"
    chown root:proyecto "$BASE" "$BASE/ingenieria" "$BASE/documentacion" "$BASE/intercambio"
    chmod 750           "$BASE" "$BASE/ingenieria" "$BASE/documentacion" "$BASE/intercambio"
    chown root:proyecto "$BASE"/intercambio/{incoming,approved,quarantine}
    chmod 750           "$BASE"/intercambio/{incoming,approved,quarantine}

    paso "confidencial: solo root (gestión mediante sudo)"
    chown root:root "$BASE/confidencial"
    chmod 700 "$BASE/confidencial"
    ls -ld "$BASE" "$BASE"/* "$BASE/confidencial"
}

politica_A() {
    paso "[Miembro A] mecanica: grupo mecanica rwx, ACL de lectura para $USER_B"
    chown root:mecanica "$BASE/ingenieria/mecanica"
    chmod 2770 "$BASE/ingenieria/mecanica"
    setfacl -m u:"$USER_B":r-x "$BASE/ingenieria/mecanica"
    setfacl -d -m u::rwx,g::rwx,o::---,u:"$USER_B":r-x "$BASE/ingenieria/mecanica"
    getfacl "$BASE/ingenieria/mecanica"
}

politica_B() {
    paso "[Miembro B] avionica: grupo avionica rwx, ACL de lectura para $USER_A"
    chown root:avionica "$BASE/ingenieria/avionica"
    chmod 2770 "$BASE/ingenieria/avionica"
    setfacl -m u:"$USER_A":r-x "$BASE/ingenieria/avionica"
    setfacl -d -m u::rwx,g::rwx,o::---,u:"$USER_A":r-x "$BASE/ingenieria/avionica"
    getfacl "$BASE/ingenieria/avionica"

    paso "[Miembro B] software: grupo software rwx"
    chown root:software "$BASE/ingenieria/software"
    chmod 2770 "$BASE/ingenieria/software"
    ls -ld "$BASE/ingenieria/software"
}

politica_C() {
    paso "[Miembro C] compras: grupo compras rwx (incluye proveedores y pedidos)"
    chown -R root:compras "$BASE/compras"
    chmod 2770 "$BASE/compras" "$BASE/compras/proveedores" "$BASE/compras/pedidos"
    ls -ld "$BASE/compras" "$BASE"/compras/*

    paso "[Miembro C] documentacion/comun: lectura para el grupo proyecto"
    chown root:proyecto "$BASE/documentacion/comun"
    chmod 2750 "$BASE/documentacion/comun"
    ls -ld "$BASE/documentacion/comun"

    paso "[Miembro C] contabilidad: cerrada; ACL de paso para $USER_C y de lectura en facturas"
    chown root:root "$BASE/contabilidad" "$BASE/contabilidad/facturas"
    chmod 750 "$BASE/contabilidad" "$BASE/contabilidad/facturas"
    setfacl -m u:"$USER_C":--x "$BASE/contabilidad"
    setfacl -m u:"$USER_C":r-x "$BASE/contabilidad/facturas"
    setfacl -d -m u::rwx,g::r-x,o::---,u:"$USER_C":r-x "$BASE/contabilidad/facturas"
    getfacl "$BASE/contabilidad" "$BASE/contabilidad/facturas"
}

semillas() {
    paso "Creando archivos de ejemplo para las pruebas de lectura"
    echo "Plan de ensayos estructurales AURORA-6 (documento de ejemplo)" > "$BASE/ingenieria/mecanica/plan_ensayos.txt"
    echo "Especificación de telemetría AURORA-6 (documento de ejemplo)"  > "$BASE/ingenieria/avionica/telemetria.txt"
    echo "Normas comunes del proyecto AURORA-6 (documento de ejemplo)"  > "$BASE/documentacion/comun/normas_proyecto.txt"
    echo "Factura 0001 (documento de ejemplo)"                          > "$BASE/contabilidad/facturas/factura_0001.txt"
    echo "Documento reservado (solo administración)"                    > "$BASE/confidencial/reservado.txt"
    chmod 640 "$BASE/documentacion/comun/normas_proyecto.txt"
    chmod 600 "$BASE/confidencial/reservado.txt"
    ls -l "$BASE/ingenieria/mecanica" "$BASE/ingenieria/avionica" \
          "$BASE/documentacion/comun" "$BASE/contabilidad/facturas"
}

verificar() {
    paso "Resumen de propietarios, permisos y ACLs"
    find "$BASE" -maxdepth 3 -type d -exec ls -ld {} + 
    echo
    getfacl -R -p "$BASE" 2>/dev/null | grep -v '^$' | grep -E '^# file|user:|group:|mask|other' || true
}

case "${1:-}" in
    estructura) estructura ;;
    usuarios)   usuarios ;;
    dac751)     dac751 ;;
    base)       base ;;
    politica_A) politica_A ;;
    politica_B) politica_B ;;
    politica_C) politica_C ;;
    semillas)   semillas ;;
    verificar)  verificar ;;
    todo)       estructura; usuarios; dac751; base; politica_A; politica_B; politica_C; semillas; verificar ;;
    *) echo "Uso: sudo bash $0 {estructura|usuarios|dac751|base|politica_A|politica_B|politica_C|semillas|verificar|todo}"; exit 1 ;;
esac
