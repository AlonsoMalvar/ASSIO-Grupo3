#!/bin/bash
# P2 ASSIO - fase 2: renombra las cuentas de B y C a alonso y ariadna,
# y ejecuta las pruebas de identificación (sección 2) y de validación (sección 7)
# con la identidad de cada integrante. Guarda todo en ~/p2_salidas_fase2.txt
# Uso: sudo bash ~/p2_fase2.sh
ADMIN="${SUDO_USER:-guillermo}"
LOG="/home/$ADMIN/p2_salidas_fase2.txt"
H="$(hostname)"
B=/srv/aurora6

sec() { echo; echo "################ $*"; }
# Ejecuta un comando con la identidad del usuario indicado y muestra un prompt como el de su terminal
t() { local u="$1"; shift; echo "$u@$H:~\$ $*"; sudo -u "$u" -H bash -c "cd ~ && $*" 2>&1; echo "[código de salida: $?]"; }

{
echo "##### P2 ASSIO - fase 2 - salidas reales del servidor"
echo "##### Fecha: $(date '+%Y-%m-%d %H:%M:%S %Z')   Host: $H   Admin: $ADMIN"

sec "Renombrar cuentas: usuario_b -> alonso, usuario_c -> ariadna"
for par in "usuario_b:alonso" "usuario_c:ariadna"; do
    viejo="${par%%:*}"; nuevo="${par##*:}"
    if id "$viejo" >/dev/null 2>&1 && ! id "$nuevo" >/dev/null 2>&1; then
        echo "\$ sudo usermod -l $nuevo -d /home/$nuevo -m $viejo"
        usermod -l "$nuevo" -d "/home/$nuevo" -m "$viejo" 2>&1
        echo "\$ sudo groupmod -n $nuevo $viejo"
        groupmod -n "$nuevo" "$viejo" 2>&1
    else
        echo "($viejo -> $nuevo: ya hecho o no aplicable)"
    fi
done

sec "Sección 1.4 - SSH y red en la VM"
echo "\$ ip -4 addr show enp0s3"; ip -4 addr show enp0s3 2>&1
echo "\$ systemctl is-active ssh.socket ssh"; systemctl is-active ssh.socket ssh 2>&1
echo "\$ ss -tlnp | grep ':22'"; ss -tlnp 2>&1 | grep ':22'
echo "\$ sshd -T | grep -i passwordauthentication"; sshd -T 2>/dev/null | grep -i passwordauthentication

sec "Sección 2 - Identificación con la cuenta de administración ($ADMIN)"
for c in "whoami" "hostname" "hostnamectl" "pwd" "ls -l /" "ls -la /home" "ls -la /root"; do t "$ADMIN" "$c"; done
echo "$ADMIN@$H:~\$ sudo ls -la /root"; ls -la /root 2>&1
for u in alonso ariadna; do
    sec "Sección 2 - Identificación con la cuenta de $u"
    for c in "whoami" "hostname" "pwd" "ls -la /home" "ls -la /root" "tree -d /srv/aurora6"; do t "$u" "$c"; done
done

sec "Sección 4.3 - Cuentas y grupos"
for u in usuario_a alonso ariadna; do echo "\$ id $u ; groups $u"; id "$u" 2>&1; groups "$u" 2>&1; done
echo "\$ getent group mecanica avionica software compras proyecto"; getent group mecanica avionica software compras proyecto
echo "\$ grep -E '^(usuario_a|alonso|ariadna):' /etc/passwd"; grep -E '^(usuario_a|alonso|ariadna):' /etc/passwd
echo "\$ ls -ld /home/usuario_a /home/alonso /home/ariadna"; ls -ld /home/usuario_a /home/alonso /home/ariadna 2>&1

sec "Sección 6.4 - getfacl tras el cambio de nombre (las ACL guardan el UID)"
getfacl -p $B/ingenieria/mecanica $B/ingenieria/avionica $B/contabilidad $B/contabilidad/facturas 2>&1
echo "\$ ls -ld (compras, comun, software)"; ls -ld $B/compras $B/compras/* $B/documentacion/comun $B/ingenieria/software 2>&1

sec "Sección 7.1 - Pruebas de usuario_a (Guillermo)"
U=usuario_a
t $U "whoami"; t $U "id"
t $U "echo 'Ensayo de vibración' > $B/ingenieria/mecanica/ensayo_A.txt"
t $U "ls -l $B/ingenieria/mecanica/ensayo_A.txt"
t $U "ls -l $B/ingenieria/avionica"
t $U "cat $B/ingenieria/avionica/telemetria.txt"
t $U "touch $B/ingenieria/avionica/intento_A.txt"
t $U "ls $B/contabilidad"
t $U "cd $B/confidencial"
t $U "ls $B/compras/pedidos"
t $U "cat $B/documentacion/comun/normas_proyecto.txt"
t $U "getfacl $B/ingenieria/mecanica"

sec "Sección 7.2 - Pruebas de alonso (Alonso)"
U=alonso
t $U "whoami"; t $U "id"
t $U "echo 'Log de telemetría' > $B/ingenieria/avionica/telemetria_B.log"
t $U "echo \"print('control')\" > $B/ingenieria/software/control_B.py"
t $U "ls -l $B/ingenieria/avionica $B/ingenieria/software"
t $U "ls -l $B/ingenieria/mecanica"
t $U "cat $B/ingenieria/mecanica/plan_ensayos.txt"
t $U "cat $B/ingenieria/mecanica/ensayo_A.txt"
t $U "touch $B/ingenieria/mecanica/intento_B.txt"
t $U "ls $B/compras/pedidos"
t $U "ls $B/confidencial"
t $U "cat $B/documentacion/comun/normas_proyecto.txt"
t $U "getfacl $B/ingenieria/avionica"

sec "Sección 7.3 - Pruebas de ariadna (Ariadna)"
U=ariadna
t $U "whoami"; t $U "id"
t $U "echo 'Pedido 001: tornillería' > $B/compras/pedidos/pedido_001.txt"
t $U "ls -l $B/compras/pedidos"
t $U "cat $B/contabilidad/facturas/factura_0001.txt"
t $U "cat $B/documentacion/comun/normas_proyecto.txt"
t $U "ls $B/contabilidad"
t $U "touch $B/ingenieria/mecanica/intento_C.txt"
t $U "touch $B/contabilidad/facturas/intento_C.txt"
t $U "cd $B/confidencial"
t $U "getfacl $B/contabilidad/facturas"

sec "Herencia de la ACL por defecto en el archivo creado por A"
getfacl -p $B/ingenieria/mecanica/ensayo_A.txt 2>&1

sec "Estado final"
tree -d $B 2>&1
find $B -maxdepth 3 -type d -exec ls -ld {} + 2>&1
} 2>&1 | tee "$LOG"
chown "$ADMIN": "$LOG"
echo; echo "Salidas guardadas en $LOG"
