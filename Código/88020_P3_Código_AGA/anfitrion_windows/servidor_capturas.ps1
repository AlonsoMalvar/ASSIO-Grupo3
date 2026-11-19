# Escucha solo en 127.0.0.1:8765 (la VM llega por 10.0.2.2 a través del NAT de VirtualBox).
# Cada petición GET /<nombre> captura la ventana en primer plano y la guarda en capturas\<nombre>.png
param([string]$OutDir = (Join-Path $PSScriptRoot "capturas"))
Add-Type -AssemblyName System.Drawing
Add-Type @"
using System; using System.Runtime.InteropServices;
public static class W {
  [StructLayout(LayoutKind.Sequential)] public struct RECT { public int L, T, R, B; }
  [DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
  [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out RECT r);
  [DllImport("user32.dll")] public static extern bool SetProcessDPIAware();
  [DllImport("dwmapi.dll")] public static extern int DwmGetWindowAttribute(IntPtr h, int a, out RECT r, int s);
}
"@
[void][W]::SetProcessDPIAware()
New-Item -ItemType Directory -Force $OutDir | Out-Null
$l = New-Object System.Net.Sockets.TcpListener([Net.IPAddress]::Loopback, 8765)
$l.Start(); Write-Host "Esperando peticiones en 127.0.0.1:8765"
while ($true) {
    $c = $l.AcceptTcpClient(); $s = $c.GetStream()
    $rd = New-Object IO.StreamReader($s); $line = $rd.ReadLine()
    $name = ($line -split ' ')[1].TrimStart('/') -replace '[^A-Za-z0-9_]', ''
    if ($name -and $name -ne 'fin') {
        $h = [W]::GetForegroundWindow(); $r = New-Object W+RECT
        if ([W]::DwmGetWindowAttribute($h, 9, [ref]$r, 16) -ne 0) { [void][W]::GetWindowRect($h, [ref]$r) }
        $w = $r.R - $r.L; $hh = $r.B - $r.T
        $bmp = New-Object Drawing.Bitmap $w, $hh; $gr = [Drawing.Graphics]::FromImage($bmp)
        $gr.CopyFromScreen($r.L, $r.T, 0, 0, $bmp.Size); $gr.Dispose()
        $bmp.Save((Join-Path $OutDir "$name.png"), [Drawing.Imaging.ImageFormat]::Png); $bmp.Dispose()
        Write-Host "Captura: $name ($w x $hh)"
    }
    $b = [Text.Encoding]::ASCII.GetBytes("HTTP/1.0 200 OK`r`nContent-Length: 2`r`n`r`nok"); $s.Write($b, 0, $b.Length); $c.Close()
    if ($name -eq 'fin') { break }
}
$l.Stop(); Write-Host "Fin"
