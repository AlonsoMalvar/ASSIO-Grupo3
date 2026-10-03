# Comandos de la Práctica 1 · Grupo 3

ASSIO (88020) · Instalación de Ubuntu Server en una máquina virtual

Aquí está cada comando con una explicación corta de lo que hace. Cada uno hizo la instalación en su ordenador, así que van separados por persona. El resumen general está en el [README](README.md).

## Índice

- [1. Ariadna · macOS](#1-ariadna--macos)
- [2. Guillermo · Windows](#2-guillermo--windows)
- [3. Alonso · Windows](#3-alonso--windows)

---

# 1. Ariadna · macOS

En el Mac gran parte de la configuración la hice desde el Terminal con VBoxManage, porque la instalación desatendida se había quedado marcada y había que arreglar la VM. Luego comprobé todo dentro del servidor y por SSH.

### Arreglar y preparar la VM

```bash
VBoxManage controlvm "server-assio-asv" poweroff 2>/dev/null
```
Apago la VM de golpe. El `2>/dev/null` es para que no salgan los errores.

```bash
VBoxManage modifyvm "server-assio-asv" --name "server-asio-asv"
```
Le cambio el nombre, que estaba mal escrito (`assio` en vez de `asio`).

```bash
VM="server-asio-asv"
```
Guardo el nombre en una variable para no escribirlo en cada comando.

### Poner la ISO y el arranque

```bash
ISO=$(find ~/Downloads ~/Desktop ~/Documents -iname "ubuntu*live-server-arm64*.iso" 2>/dev/null | head -1)
```
Busco la ISO de Ubuntu Server arm64 en Descargas, Escritorio y Documentos y me quedo con la primera.

```bash
echo "ISO encontrada: $ISO"
```
Miro la ruta para asegurarme de que la ha encontrado.

```bash
VBoxManage storageattach "$VM" --storagectl "VirtioSCSI" --port 1 --device 0 --type dvddrive --medium "$ISO"
```
Meto la ISO en la unidad de CD (puerto 1 del controlador VirtioSCSI).

```bash
VBoxManage modifyvm "$VM" --boot1 dvd --boot2 disk --boot3 none --boot4 none
```
Pongo que arranque primero desde el CD y después desde el disco.

### Red y limpieza

```bash
VBoxManage modifyvm "$VM" --nat-pf1 "ssh,tcp,127.0.0.1,2222,10.0.2.15,22"
```
Creo la regla para SSH: lo que llegue al puerto 2222 del Mac va al 22 de la VM.

```bash
VBoxManage closemedium dvd "{4305f807-c587-45e2-8b01-ecf32ebda175}" 2>/dev/null
```
Quito la ISO extra que dejó la instalación desatendida.

### Comprobar la VM desde el Mac

```bash
VBoxManage showvminfo "$VM" | grep -E "^Name|Memory size|Number of CPUs|Boot Device|NIC 1|Rule|VirtioSCSI"
```
Miro el nombre, la memoria, las CPUs, el orden de arranque, la red y la regla de SSH.

```bash
VBoxManage showmediuminfo disk "$(VBoxManage showvminfo "$VM" --machinereadable | grep '"VirtioSCSI-0-0"' | cut -d'"' -f4)" | grep -E "Capacity|Format variant"
```
Miro el disco: 25 GB y dinámico.

### Comprobar dentro del servidor

```bash
lsblk -f
```
Veo las particiones con su sistema de archivos y dónde está montada cada una (`/boot/efi`, swap, `/` y `/home`).

```bash
df -hT
```
Espacio usado y libre de cada partición, en unidades fáciles de leer y con el tipo.

```bash
swapon
```
Compruebo que la swap está activa: `/dev/sda2`, 2 GB.

```bash
hostnamectl
```
Nombre del servidor y datos del sistema: Ubuntu 26.04.1 LTS, arm64.

```bash
whoami
```
Sale `ariadna`.

```bash
groups
```
Los grupos del usuario: `ariadna`, `adm`, `cdrom`, `sudo`, `dip`, `plugdev`, `users` y `lxd`.

### Probar SSH desde el Mac

```bash
ssh -p 2222 ariadna@127.0.0.1
```
Entro en la VM desde el Terminal del Mac por el puerto 2222. Así compruebo a la vez que la regla de reenvío funciona.

---

# 2. Guillermo · Windows

Aquí todo se hizo con la interfaz de VirtualBox, así que solo hay comandos de comprobación, ya dentro del servidor.

```bash
hostname
```
Miro el nombre del servidor.

```bash
id guillermo
```
Miro el usuario y sus grupos. Entre ellos sale `sudo`.

```bash
systemctl status ssh
```
Compruebo que OpenSSH está funcionando: `active (running)`.

```bash
ip a
```
Miro la red: la interfaz `enp0s3` tiene la IP `10.0.2.15/24`.

```bash
lsblk
```
Miro las particiones: raíz de 22 GB y swap de 3 GB.

---

# 3. Alonso · Windows

Igual que Guillermo, la instalación fue por la interfaz y los comandos son para comprobar el resultado.

```bash
hostname
```
Sale `server-asio-03`.

```bash
id
```
Veo el UID, el grupo principal y el resto de grupos. El usuario `al` está en `sudo`.

```bash
lsblk
```
Los discos y particiones en árbol: `sda` de 25 GB, con swap de 2 GB, raíz de 12 GB y `/home` de 11 GB.

```bash
df -h
```
Espacio usado y libre de cada partición. La raíz usa 3,5 GB (32 %).

```bash
systemct1 status ssh
```
Aquí me equivoqué: puse un `1` en vez de una `l` y salió `command not found`.

```bash
systemctl status ssh
```
Ahora sí: el servicio está `active (running)` y escuchando en el puerto 22.
