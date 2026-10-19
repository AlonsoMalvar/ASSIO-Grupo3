# Copia los scripts a la VM, ejecuta la P2 con sudo y trae las salidas reales.
# Pide la contraseña de guillermo (scp/ssh) y la de sudo: escríbelas tú.
Set-Location $PSScriptRoot
Write-Host "1/3 Copiando scripts a la VM (contraseña de guillermo)..."
scp -P 2222 p2_servidor.sh p2_run.sh guillermo@127.0.0.1:~/
if (-not $?) { Write-Host "Fallo al copiar"; return }
Write-Host "2/3 Ejecutando la P2 en la VM (contraseña de guillermo y luego la de sudo)..."
ssh -t -p 2222 guillermo@127.0.0.1 "sudo bash ~/p2_run.sh"
Write-Host "3/3 Trayendo p2_salidas.txt (contraseña de guillermo)..."
scp -P 2222 guillermo@127.0.0.1:~/p2_salidas.txt .
if ($?) { Write-Host "LISTO: salidas en $PSScriptRoot\p2_salidas.txt" }
