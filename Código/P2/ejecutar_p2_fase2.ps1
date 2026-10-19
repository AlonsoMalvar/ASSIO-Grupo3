# Fase 2: renombra las cuentas a alonso y ariadna y ejecuta las pruebas de cada integrante.
# Pide la contraseña de guillermo (3 veces) y la de sudo (1 vez): escríbelas tú.
Set-Location $PSScriptRoot
Write-Host "1/3 Copiando el script a la VM (contraseña de guillermo)..."
scp -P 2222 p2_fase2.sh guillermo@127.0.0.1:~/
if (-not $?) { Write-Host "Fallo al copiar"; return }
Write-Host "2/3 Ejecutando en la VM (contraseña de guillermo y luego la de sudo)..."
ssh -t -p 2222 guillermo@127.0.0.1 "sudo bash ~/p2_fase2.sh"
Write-Host "3/3 Trayendo p2_salidas_fase2.txt (contraseña de guillermo)..."
scp -P 2222 guillermo@127.0.0.1:~/p2_salidas_fase2.txt .
if ($?) { Write-Host "LISTO: salidas en $PSScriptRoot\p2_salidas_fase2.txt" }
