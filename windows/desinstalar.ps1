# Desinstala Enfócate pe causa. No funciona durante una sesión activa.
# Uso: doble clic en desinstalar.cmd
param([string]$Sid, [switch]$Elevado)
$ErrorActionPreference = 'Stop'
$destino = Join-Path $env:ProgramFiles 'Enfócate pe causa'
$datos = Join-Path $env:ProgramData 'Enfocate'
$servicio = 'EnfocateSesion'

# Hay sesión activa si la fase bloquea y no ha vencido.
function SesionActiva {
    $estado = Join-Path $datos 'sesion.state'
    if (-not (Test-Path $estado)) { return $false }
    $v = @{}
    Get-Content $estado | ForEach-Object { $p = $_ -split '=', 2; if ($p.Count -eq 2) { $v[$p[0]] = $p[1] } }
    $ahora = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
    return ($v['phase'] -in 'focus', 'work') -and ([long]$v['end'] -gt $ahora)
}

if (-not $Elevado) {
    if (SesionActiva) { Write-Host 'Hay una sesión activa. Podrás desinstalar cuando termine.'; exit 1 }
    $yo = [Security.Principal.WindowsIdentity]::GetCurrent().User.Value
    try {
        $p = Start-Process powershell -Verb RunAs -Wait -PassThru -ArgumentList @(
            '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', "`"$PSCommandPath`"", '-Sid', $yo, '-Elevado')
    } catch { Write-Host 'Cancelado.'; exit 1 }
    if ($p.ExitCode -ne 0) { exit 1 }
    Write-Host 'Desinstalado. No queda ningún dato de la app en tu PC.'
    exit 0
}

try {
    if (SesionActiva) { throw 'Hay una sesión activa. Podrás desinstalar cuando termine.' }
    if (Get-Service $servicio -ErrorAction SilentlyContinue) {
        Stop-Service $servicio -Force
        sc.exe delete $servicio | Out-Null
    }
    Get-Process Enfocate, EnfocateServicio -ErrorAction SilentlyContinue | Stop-Process -Force
    Start-Sleep -Seconds 1

    $hosts = "$env:WINDIR\System32\drivers\etc\hosts"
    $t = [IO.File]::ReadAllText($hosts, [Text.Encoding]::Default)
    $n = [regex]::Replace($t, '(?ms)^# >>> focus block >>>\r?\n.*?^# <<< focus block <<<\r?\n?', '')
    if ($n -ne $t) { [IO.File]::WriteAllText($hosts, $n, [Text.Encoding]::Default) }
    ipconfig /flushdns | Out-Null

    Remove-Item $destino, $datos -Recurse -Force -ErrorAction SilentlyContinue
    Remove-ItemProperty "Registry::HKEY_USERS\$Sid\Software\Microsoft\Windows\CurrentVersion\Run" `
        -Name 'Enfocate pe causa' -ErrorAction SilentlyContinue
    exit 0
} catch {
    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host $_.InvocationInfo.PositionMessage
    # En una ventana normal, espera para que se pueda leer el error.
    try { Read-Host 'Presiona Enter para cerrar' | Out-Null } catch { }
    exit 1
}
