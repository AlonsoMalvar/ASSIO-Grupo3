#!/bin/bash
# P2 ASSIO - muestra cada bloque de pruebas en pantalla y pide al PC anfitrión
# (10.0.2.2, puerto 8765) que haga la captura de la ventana del terminal.
# Uso (cuenta guillermo): bash ~/p2_capturas.sh
H="$(hostname)"; B=/srv/aurora6
shot() {   # avisa al anfitrión para que capture la pantalla actual
    sleep 1
    exec 3<>/dev/tcp/10.0.2.2/8765 && { printf 'GET /%s HTTP/1.0\r\n\r\n' "$1" >&3; cat <&3 >/dev/null; exec 3>&-; }
    sleep 1
}
ban() { clear; echo "### $1   [$(date '+%d/%m/%Y %H:%M:%S')]"; echo; }
# Ejecuta como el usuario indicado mostrando su prompt
t() { local u="$1"; shift; echo "$u@$H:~\$ $*"; sudo -u "$u" -H bash -c "cd ~ && $*" 2>&1; }
# Ejecuta como guillermo (cuenta de administración), con sudo si se indica
g() { echo "guillermo@$H:~\$ $*"; bash -c "$*" 2>&1; }

sudo -v || exit 1

ban "1.4  SSH y red en la VM (cuenta de administración)"
g "ip -4 addr show enp0s3"; g "systemctl is-active ssh.socket ssh"; g "sudo ss -tlnp | grep ':22'"; g "sudo sshd -T | grep -i passwordauthentication"
shot 01_ssh_vm

ban "2  Identificación - Guillermo (guillermo, cuenta de administración) 1/3"
g "whoami"; g "hostname"; g "hostnamectl"; g "pwd"
shot 02_id_A1
ban "2  Identificación - Guillermo (guillermo) 2/3"
g "ls -l /"
shot 03_id_A2
ban "2  Identificación - Guillermo (guillermo) 3/3"
g "ls -la /home"; g "ls -la /root"; g "sudo ls -la /root"
shot 04_id_A3
ban "2  Identificación - Alonso (alonso, ejecutado con sudo -u alonso)"
for c in "whoami" "hostname" "pwd" "ls -la /home" "ls -la /root"; do t alonso "$c"; done
shot 05_id_B
ban "2  Identificación - Ariadna (ariadna, ejecutado con sudo -u ariadna)"
for c in "whoami" "hostname" "pwd" "ls -la /home" "ls -la /root"; do t ariadna "$c"; done
shot 06_id_C

ban "3  Estructura de la empresa (cuenta de administración)"
g "sudo tree -d $B"
shot 07_tree_A
ban "3  Estructura vista por Alonso (sudo -u alonso)"
t alonso "tree -d $B"
shot 08_tree_B
ban "3  Estructura vista por Ariadna (sudo -u ariadna)"
t ariadna "tree -d $B"
shot 09_tree_C

ban "4.3  Cuentas y grupos"
for u in usuario_a alonso ariadna; do g "id $u ; groups $u"; done
g "getent group mecanica avionica software compras proyecto"
g "grep -E '^(usuario_a|alonso|ariadna):' /etc/passwd"
shot 10_usuarios

ban "5  Configuración 751 sobre documentacion (se repite y se restaura 750)"
g "sudo chmod 751 $B/documentacion"; g "ls -ld $B/documentacion"
g "sudo chmod 750 $B/documentacion"; g "ls -ld $B/documentacion"
shot 11_dac751

ban "6.4  Miembro A: mecanica"
g "sudo getfacl -p $B/ingenieria/mecanica"; g "sudo ls -ld $B/ingenieria/mecanica"
shot 12_acl_A
ban "6.4  Miembro B: avionica y software"
g "sudo getfacl -p $B/ingenieria/avionica"; g "sudo ls -ld $B/ingenieria/avionica $B/ingenieria/software"
shot 13_acl_B
ban "6.4  Miembro C: compras, documentacion/comun y contabilidad"
g "sudo ls -ld $B/compras $B/compras/pedidos $B/compras/proveedores $B/documentacion/comun"
g "sudo getfacl -p $B/contabilidad $B/contabilidad/facturas"
shot 14_acl_C
ban "6.5  Archivos de ejemplo y resumen de permisos"
g "sudo ls -l $B/ingenieria/mecanica $B/ingenieria/avionica $B/documentacion/comun $B/contabilidad/facturas"
g "sudo find $B -maxdepth 3 -type d -exec ls -ld {} +"
shot 15_resumen

ban "7.1  Pruebas de usuario_a (Guillermo) 1/2 - sudo -u usuario_a"
t usuario_a "whoami"; t usuario_a "id"
t usuario_a "echo 'Ensayo de vibración' > $B/ingenieria/mecanica/ensayo_A.txt"
t usuario_a "ls -l $B/ingenieria/mecanica/ensayo_A.txt"
t usuario_a "ls -l $B/ingenieria/avionica"
t usuario_a "cat $B/ingenieria/avionica/telemetria.txt"
t usuario_a "touch $B/ingenieria/avionica/intento_A.txt"
shot 16_pruebas_A1
ban "7.1  Pruebas de usuario_a (Guillermo) 2/2 - sudo -u usuario_a"
t usuario_a "ls $B/contabilidad"
t usuario_a "cd $B/confidencial"
t usuario_a "ls $B/compras/pedidos"
t usuario_a "cat $B/documentacion/comun/normas_proyecto.txt"
t usuario_a "getfacl -p $B/ingenieria/mecanica"
shot 17_pruebas_A2

ban "7.2  Pruebas de alonso (Alonso) 1/2 - sudo -u alonso"
t alonso "whoami"; t alonso "id"
t alonso "echo 'Log de telemetría' > $B/ingenieria/avionica/telemetria_B.log"
t alonso "echo \"print('control')\" > $B/ingenieria/software/control_B.py"
t alonso "ls -l $B/ingenieria/avionica $B/ingenieria/software"
t alonso "ls -l $B/ingenieria/mecanica"
t alonso "cat $B/ingenieria/mecanica/plan_ensayos.txt"
shot 18_pruebas_B1
ban "7.2  Pruebas de alonso (Alonso) 2/2 - sudo -u alonso"
t alonso "cat $B/ingenieria/mecanica/ensayo_A.txt"
t alonso "touch $B/ingenieria/mecanica/intento_B.txt"
t alonso "ls $B/compras/pedidos"
t alonso "ls $B/confidencial"
t alonso "cat $B/documentacion/comun/normas_proyecto.txt"
t alonso "getfacl -p $B/ingenieria/avionica"
shot 19_pruebas_B2

ban "7.3  Pruebas de ariadna (Ariadna) 1/2 - sudo -u ariadna"
t ariadna "whoami"; t ariadna "id"
t ariadna "echo 'Pedido 001: tornillería' > $B/compras/pedidos/pedido_001.txt"
t ariadna "ls -l $B/compras/pedidos"
t ariadna "cat $B/contabilidad/facturas/factura_0001.txt"
t ariadna "cat $B/documentacion/comun/normas_proyecto.txt"
t ariadna "ls $B/contabilidad"
shot 20_pruebas_C1
ban "7.3  Pruebas de ariadna (Ariadna) 2/2 - sudo -u ariadna"
t ariadna "touch $B/ingenieria/mecanica/intento_C.txt"
t ariadna "touch $B/contabilidad/facturas/intento_C.txt"
t ariadna "cd $B/confidencial"
t ariadna "getfacl -p $B/contabilidad/facturas"
g "sudo getfacl -p $B/ingenieria/mecanica/ensayo_A.txt"
shot 21_pruebas_C2

clear; echo "Capturas terminadas."; shot fin
