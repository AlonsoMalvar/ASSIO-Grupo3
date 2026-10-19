# Abre una consola de 120x46, copia p2_capturas.sh a la VM y lo ejecuta.
# Pide la contraseña de guillermo (ssh) y luego la de sudo: escríbelas tú y no toques la ventana hasta que acabe.
$sh = [IO.File]::ReadAllText((Join-Path $PSScriptRoot "p2_capturas.sh"))
$b64 = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($sh))
$remote = "echo $b64 | base64 -d > ~/p2_capturas.sh && bash ~/p2_capturas.sh"
$cmd = "mode con: cols=120 lines=40; `$host.UI.RawUI.WindowTitle='server-asio-g3 (SSH)'; ssh -t -p 2222 guillermo@127.0.0.1 '$remote'"
Start-Process conhost.exe -ArgumentList "powershell.exe -NoExit -NoProfile -Command `"$cmd`""
