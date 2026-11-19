# Abre una consola de 120x40 y ejecuta ejecutar_p3.ps1 dentro (las capturas salen todas del mismo tamaño).
# Uso: powershell -ExecutionPolicy Bypass -File .\lanzar_p3.ps1   [-Usuarios usuario_a]
param([string[]]$Usuarios = @("usuario_a", "alonso", "ariadna"))
$lista = ($Usuarios | ForEach-Object { "'$_'" }) -join ","
$cmd = "mode con: cols=120 lines=40; `$host.UI.RawUI.WindowTitle='server-asio-g3 (SSH) P3'; & '$PSScriptRoot\ejecutar_p3.ps1' -Usuarios $lista"
Start-Process conhost.exe -ArgumentList "powershell.exe -NoExit -NoProfile -ExecutionPolicy Bypass -Command `"$cmd`""
