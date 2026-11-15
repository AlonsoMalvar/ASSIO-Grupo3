# Práctica 2: Comandos utilizados

**Asignatura:** Administración de Servicios de Sistemas Operativos (88020)
**Práctica:** P2 - Sistema de archivos, comandos, usuarios y permisos (proyecto AURORA-6)
**Grupo:** ASSIO-Grupo3

Documento del grupo. Cada comando lleva una explicación corta de lo que hace. Guillermo montó el servidor del grupo (`server-asio-g3`) en su PC y Alonso y Ariadna se conectaron a él desde sus portátiles. Además, Alonso y Ariadna repitieron la práctica completa en sus propias máquinas virtuales.

> Los comandos con `sudo` piden la contraseña de la cuenta de administración de cada máquina.

---

## Índice

* [1. Guillermo · servidor del grupo (Windows + VirtualBox)](#1-guillermo--servidor-del-grupo-windows--virtualbox)
* [2. Alonso · su VM (Windows)](#2-alonso--su-vm-windows)
* [3. Ariadna · su VM (macOS)](#3-ariadna--su-vm-macos)
* [4. Conexión de Alonso y Ariadna al servidor del grupo](#4-conexión-de-alonso-y-ariadna-al-servidor-del-grupo)

---

## 1. Guillermo · servidor del grupo (Windows + VirtualBox)

### Preparar el PC anfitrión

```powershell
bcdedit /set hypervisorlaunchtype off
```

Desactiva el hipervisor de Windows (junto con la Integridad de memoria) para que VirtualBox pueda usar VT-x. Sin esto la VM se quedaba colgada al arrancar. Se revierte con `bcdedit /set hypervisorlaunchtype auto`.

```powershell
& "C:\Program Files\Oracle\VirtualBox\VBoxManage.exe" startvm "server-asio-g3" --type gui
```

Arranca la VM del servidor con su ventana.

```powershell
ssh -p 2222 guillermo@127.0.0.1
```

Entra en la VM por SSH a través del reenvío de puertos 2222 → 22. Se usa `127.0.0.1` y no `localhost`, porque en Windows `localhost` va por IPv6 y la regla solo escuchaba en 127.0.0.1.

### Identificación del sistema

```bash
whoami
```

Muestra el usuario de la sesión: `guillermo`.

```bash
hostname
hostnamectl
```

Nombre del servidor (`server-asio-g3`) y datos del sistema: Ubuntu 26.04.1 LTS, kernel 7.0.0-38, virtualización oracle.

```bash
pwd
```

Directorio de trabajo: `/home/guillermo`.

```bash
ls -l /
ls -la /home
```

Directorios de primer nivel del sistema y carpetas personales de los usuarios.

```bash
ls -la /root
sudo ls -la /root
```

Sin `sudo` da `Permission denied` porque `/root` es la carpeta del superusuario; con `sudo` muestra su contenido.

### Paquetes y estructura

```bash
sudo apt install -y acl tree
```

Instala `setfacl`/`getfacl` (ACL) y `tree` (árbol de directorios).

```bash
sudo bash p2_servidor.sh estructura
```

Crea toda la estructura con un `mkdir -p` y la muestra con `tree -d /srv/aurora6` (17 directories, contando la raíz).

### Usuarios y grupos

```bash
sudo bash p2_servidor.sh usuarios
```

Crea los grupos `mecanica`, `avionica`, `software`, `compras` y `proyecto` (`groupadd`), las cuentas `usuario_a`, `alonso` y `ariadna` (`useradd -m -s /bin/bash`) y sus pertenencias (`usermod -aG`).

```bash
sudo usermod -l alonso -d /home/alonso -m usuario_b
sudo groupmod -n alonso usuario_b
sudo usermod -l ariadna -d /home/ariadna -m usuario_c
sudo groupmod -n ariadna usuario_c
```

Renombra las cuentas de B y C a los nombres acordados. Las ACL guardan el UID, así que siguen funcionando sin repetir `setfacl`.

```bash
sudo passwd alonso
sudo passwd ariadna
```

Pone contraseña a las cuentas para que puedan entrar por SSH.

```bash
id usuario_a ; groups usuario_a
id alonso ; groups alonso
id ariadna ; groups ariadna
getent group mecanica avionica software compras proyecto
```

Comprueba UID, grupo primario y grupos de cada cuenta, y los miembros de cada grupo.

### Permisos 751 y permisos base

```bash
sudo bash p2_servidor.sh dac751
```

Pone `documentacion` a `root:proyecto` con permisos 751 y lo comprueba con `ls -ld` (`drwxr-x--x`).

```bash
sudo bash p2_servidor.sh base
```

Deja `/srv/aurora6`, `ingenieria`, `documentacion` e `intercambio` en 750 para el grupo `proyecto`, y `confidencial` en 700 solo para root.

### Políticas y ACL

```bash
sudo bash p2_servidor.sh politica_A
```

`mecanica`: grupo `mecanica` con 2770 y ACL `u:alonso:r-x` (también por defecto).

```bash
sudo bash p2_servidor.sh politica_B
```

`avionica`: grupo `avionica` con 2770 y ACL `u:usuario_a:r-x`; `software`: grupo `software` con 2770.

```bash
sudo bash p2_servidor.sh politica_C
```

`compras` y subcarpetas: grupo `compras` con 2770; `documentacion/comun`: `proyecto` con 2750; `contabilidad`: ACL de paso `u:ariadna:--x`; `facturas`: ACL `u:ariadna:r-x` (también por defecto).

```bash
sudo bash p2_servidor.sh semillas
sudo bash p2_servidor.sh verificar
```

Crea archivos de ejemplo para las pruebas y muestra un resumen de propietarios, permisos y ACL.

```bash
getfacl -p /srv/aurora6/ingenieria/mecanica
```

Muestra la ACL completa: `user:alonso:r-x`, `group::rwx`, `mask::rwx`, `other::---` y las entradas `default:`.

### Pruebas con la cuenta usuario_a (miembro A)

```bash
echo 'Ensayo de vibración' > /srv/aurora6/ingenieria/mecanica/ensayo_A.txt
```

Escritura permitida en su departamento. El archivo queda con grupo `mecanica` (setgid) y hereda la ACL por defecto.

```bash
cat /srv/aurora6/ingenieria/avionica/telemetria.txt
```

Lectura permitida en aviónica gracias a la ACL `r-x`.

```bash
touch /srv/aurora6/ingenieria/avionica/intento_A.txt
```

Escritura rechazada: `Permission denied`, la ACL no incluye `w`.

```bash
ls /srv/aurora6/contabilidad
cd /srv/aurora6/confidencial
ls /srv/aurora6/compras/pedidos
```

Accesos prohibidos: los tres dan `Permission denied`.

### Al terminar

```powershell
Remove-NetFirewallRule -DisplayName "ASSIO SSH VM 2222"
bcdedit /set hypervisorlaunchtype auto
```

Cierra el puerto del firewall y vuelve a activar el hipervisor de Windows.

---

## 2. Alonso · su VM (Windows)

VM de la P1 (hostname `server-assio-03`), cuenta de administración `al`, cuenta de trabajo `alonso`. Se conecta por SSH desde PowerShell a través del reenvío de puertos 2222 → 22 de VirtualBox.

### Copiar el script y entrar en la VM

```powershell
cd $HOME\Downloads
dir p2_servidor.sh
scp -P 2222 p2_servidor.sh al@127.0.0.1:~/
```

Va a la carpeta de descargas, comprueba que existe el script y lo copia a la carpeta personal de `al` dentro de la VM.

```powershell
ssh -p 2222 al@127.0.0.1
```

Entra en la VM por SSH con la cuenta de administración. Se usa `127.0.0.1` y no `localhost` por el mismo motivo que en el servidor del grupo. A partir de aquí, los comandos se escriben dentro de la VM.

### Dejar el script listo

```bash
pwd
ls -l p2_servidor.sh
```

Comprueba que está en `/home/al` y que el archivo se ha copiado.

```bash
sed -i 's/\r$//' p2_servidor.sh
bash -n p2_servidor.sh && echo "sintaxis OK"
less p2_servidor.sh
```

Quita los saltos de línea de Windows, comprueba la sintaxis sin ejecutar nada y permite leer el script antes de lanzarlo con `sudo` (se sale con `q`).

### Identificación del sistema

```bash
whoami
hostname
hostnamectl
pwd
ls -l /
```

Usuario (`al`), nombre del equipo, datos del sistema, directorio de trabajo y directorios de primer nivel.

```bash
ls -la /home
ls -la /root
sudo ls -la /root
```

Carpetas personales de los usuarios. Sin `sudo`, `/root` da `Permission denied`; con `sudo` muestra su contenido.

### Paquetes, estructura y usuarios

```bash
sudo apt update && sudo apt install -y acl tree
```

Instala `setfacl`/`getfacl` (ACL) y `tree` (árbol de directorios).

```bash
sudo bash p2_servidor.sh estructura
```

Crea la estructura bajo `/srv/aurora6` y la muestra con `tree` (17 directories, contando la raíz).

```bash
sudo bash p2_servidor.sh usuarios
```

Crea los grupos y las cuentas `usuario_a`, `alonso` y `ariadna` sin privilegios de `sudo`, y muestra sus identificadores y grupos.

```bash
sudo passwd usuario_a
sudo passwd alonso
sudo passwd ariadna
```

Pone contraseña a las tres cuentas de trabajo (solo valen en su VM).

### Permisos 751, permisos base y políticas

```bash
sudo bash p2_servidor.sh dac751
sudo bash p2_servidor.sh base
```

`dac751` pone `documentacion` a `root:proyecto` con permisos 751 (`drwxr-x--x`). `base` deja los niveles superiores en 750 para el grupo `proyecto` y `confidencial` en 700 solo para root.

```bash
sudo bash p2_servidor.sh politica_A
sudo bash p2_servidor.sh politica_B
sudo bash p2_servidor.sh politica_C
```

Aplican las políticas de cada miembro. La suya es `politica_B`: `avionica` (grupo `avionica` con 2770 y ACL `u:usuario_a:r-x`, también por defecto) y `software` (grupo `software` con 2770).

```bash
sudo bash p2_servidor.sh semillas
sudo bash p2_servidor.sh verificar
```

Crea los archivos de ejemplo para las pruebas y muestra un resumen de propietarios, permisos y ACL.

### Pruebas con la cuenta alonso (miembro B)

```powershell
ssh -p 2222 alonso@127.0.0.1
```

Vuelve a entrar en la VM, ahora con la cuenta de trabajo `alonso`, que es con la que se hacen las pruebas.

```bash
whoami
id
```

Muestra el usuario (`alonso`) y sus grupos: `avionica`, `software` y `proyecto`.

```bash
echo 'Log de telemetría' > /srv/aurora6/ingenieria/avionica/telemetria_B.log
echo "print('control')" > /srv/aurora6/ingenieria/software/control_B.py
ls -l /srv/aurora6/ingenieria/avionica /srv/aurora6/ingenieria/software
```

Escrituras permitidas en aviónica y software. Los archivos nuevos quedan con el grupo de su carpeta (setgid).

```bash
ls -l /srv/aurora6/ingenieria/mecanica
cat /srv/aurora6/ingenieria/mecanica/plan_ensayos.txt
```

Lectura permitida en mecánica por la ACL `u:alonso:r-x`.

```bash
touch /srv/aurora6/ingenieria/mecanica/intento_B.txt
ls /srv/aurora6/compras/pedidos
ls /srv/aurora6/confidencial
```

Escritura y accesos rechazados: `Permission denied` en los tres.

```bash
cat /srv/aurora6/documentacion/comun/normas_proyecto.txt
```

Lectura permitida en la documentación común por pertenecer al grupo `proyecto`.

```bash
getfacl /srv/aurora6/ingenieria/avionica
```

ACL de su recurso: `user:usuario_a:r-x` y entradas `default:`.

### Al terminar

```bash
sudo poweroff
```

Apaga la VM (desde la cuenta `al`).

---

## 3. Ariadna · su VM (macOS)

VM de la P1 en un MacBook Air M2 (arm64, hostname `server-asio-g3`), cuenta de administración `adminasv`, cuenta de trabajo `ariadna`.

```bash
sudo adduser adminasv
sudo usermod -aG sudo adminasv
sudo gpasswd -d ariadna sudo
```

Crea una cuenta de administración aparte y quita `sudo` a `ariadna`, que en la P1 era la de administración, para que quede como cuenta de trabajo.

```bash
whoami ; hostname ; hostnamectl ; pwd ; ls -l /
ls -la /home ; ls -la /root ; sudo ls -la /root
```

Identificación del sistema con la cuenta `adminasv`.

```bash
sudo bash p2.sh estructura
sudo bash p2.sh usuarios
sudo bash p2.sh dac751
sudo bash p2.sh base
sudo bash p2.sh politicaA
sudo bash p2.sh politicaB
sudo bash p2.sh politicaC
sudo bash p2.sh semillas
```

El script del grupo con traza de comandos (`set -x`), para que en las capturas se vean las órdenes. Su parte es `politicaC`: compras, documentación común y la ACL de facturas.

### Pruebas con la cuenta ariadna (miembro C)

```bash
touch /srv/aurora6/compras/pedidos/pedido001.txt
```

Escritura permitida en compras. El archivo queda con grupo `compras` por el setgid.

```bash
cat /srv/aurora6/contabilidad/facturas/factura_0001.txt
cat /srv/aurora6/documentacion/comun/normas_proyecto.txt
```

Lecturas permitidas en facturas (ACL) y en la documentación común.

```bash
ls /srv/aurora6/contabilidad
```

`Permiso denegado`: con `--x` puede atravesar `contabilidad` pero no listarla.

```bash
touch /srv/aurora6/ingenieria/mecanica/intentoC.txt
touch /srv/aurora6/contabilidad/facturas/intentoC.txt
cd /srv/aurora6/confidencial
```

Escrituras y acceso rechazados: `Permission denied`.

```bash
getfacl /srv/aurora6/contabilidad/facturas
```

ACL de su recurso: `user:ariadna:r-x` y entradas `default:`.

---

## 4. Conexión de Alonso y Ariadna al servidor del grupo

### En el PC de Guillermo (PowerShell como administrador)

```powershell
& "C:\Program Files\Oracle\VirtualBox\VBoxManage.exe" controlvm "server-asio-g3" natpf1 delete ssh
& "C:\Program Files\Oracle\VirtualBox\VBoxManage.exe" controlvm "server-asio-g3" natpf1 "ssh,tcp,,2222,10.0.2.15,22"
```

Cambia la regla de reenvío para que escuche en todas las interfaces del PC (IP anfitrión vacía), no solo en 127.0.0.1.

```powershell
New-NetFirewallRule -DisplayName "ASSIO SSH VM 2222" -Direction Inbound -Protocol TCP -LocalPort 2222 -RemoteAddress LocalSubnet -Action Allow -Profile Any
```

Abre el puerto 2222 en el firewall de Windows solo para equipos de la misma subred.

```powershell
ipconfig
```

IP del PC servidor en la Wi-Fi: `10.168.8.56`.

### Ariadna (macOS)

```bash
nc -vz 10.168.8.56 2222
ssh -p 2222 ariadna@10.168.8.56
whoami ; hostname ; id
```

Comprueba que llega al puerto (`succeeded`) y entra con su cuenta. Sale `ariadna`, `server-asio-g3` y los grupos `compras` y `proyecto`.

### Alonso (Windows)

```powershell
Test-NetConnection 10.168.8.56 -Port 2222
ssh -p 2222 alonso@10.168.8.56
```

Comprueba el puerto (`TcpTestSucceeded : True`) y entra con su cuenta. Dentro, `whoami`, `hostname` e `id` muestran `alonso`, `server-asio-g3` y los grupos `avionica`, `software` y `proyecto`.

