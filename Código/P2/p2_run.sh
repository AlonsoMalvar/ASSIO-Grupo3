#!/bin/bash
# Ejecuta p2_servidor.sh (todo) y guarda las salidas reales en ~/p2_salidas.txt
# Uso: sudo bash ~/p2_run.sh
LOG="/home/${SUDO_USER:-guillermo}/p2_salidas.txt"
cd "$(dirname "$0")"
{
echo "##### P2 ASSIO - salidas reales del servidor"
echo "##### Fecha: $(date '+%Y-%m-%d %H:%M:%S %Z')"
echo "##### Host: $(hostname)   Admin: ${SUDO_USER:-?}"
echo
for p in acl tree; do
    dpkg -s "$p" >/dev/null 2>&1 || { echo "==> Instalando $p"; apt-get install -y "$p" 2>&1 | tail -n 2; }
done

echo; echo "################ sudo bash p2_servidor.sh todo"
bash p2_servidor.sh todo 2>&1
echo "(código de salida del script: $?)"

echo; echo "################ tree -d /srv/aurora6"
tree -d /srv/aurora6 2>&1

echo; echo "################ ls -l /srv/aurora6 (y subniveles)"
ls -l /srv/aurora6 2>&1
ls -l /srv/aurora6/ingenieria /srv/aurora6/compras /srv/aurora6/documentacion /srv/aurora6/intercambio 2>&1
ls -ld /srv/aurora6/contabilidad /srv/aurora6/contabilidad/facturas /srv/aurora6/confidencial 2>&1

echo; echo "################ getfacl de los directorios con ACL"
getfacl -p /srv/aurora6/ingenieria/mecanica /srv/aurora6/ingenieria/avionica \
           /srv/aurora6/contabilidad /srv/aurora6/contabilidad/facturas 2>&1

echo; echo "################ id de las cuentas"
for u in usuario_a usuario_b usuario_c; do id "$u" 2>&1; done
echo; getent group mecanica avionica software compras proyecto 2>&1
} | tee "$LOG"
chown "${SUDO_USER:-guillermo}": "$LOG"
echo; echo "Salidas guardadas en $LOG"
