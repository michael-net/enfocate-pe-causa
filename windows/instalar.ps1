# Compila e instala Enfócate pe causa en Windows 10 u 11.
# Uso: doble clic en instalar.cmd, o: powershell -ExecutionPolicy Bypass -File windows\instalar.ps1
param([string]$Sid, [switch]$Elevado)
$ErrorActionPreference = 'Stop'
$aqui = $PSScriptRoot
$destino = Join-Path $env:ProgramFiles 'Enfócate pe causa'
$datos = Join-Path $env:ProgramData 'Enfocate'
$servicio = 'EnfocateSesion'

if (-not $Elevado) {
    # Primera parte, como tu usuario: anota quién eres y pide permiso de administrador.
    if ([Environment]::OSVersion.Version.Major -lt 10) { Write-Host 'Necesitas Windows 10 u 11.'; exit 1 }
    $yo = [Security.Principal.WindowsIdentity]::GetCurrent().User.Value
    Get-ChildItem $aqui -Recurse -File | Unblock-File -ErrorAction SilentlyContinue
    Write-Host 'Windows te pedirá permiso de administrador para instalar el servicio de bloqueo...'
    try {
        $p = Start-Process powershell -Verb RunAs -Wait -PassThru -ArgumentList @(
            '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', "`"$PSCommandPath`"", '-Sid', $yo, '-Elevado')
    } catch { Write-Host 'Instalación cancelada.'; exit 1 }
    if ($p.ExitCode -ne 0) { Write-Host 'La instalación no terminó.'; exit 1 }
    # Se abre sin sesión automática: esa arranca desde el próximo inicio de sesión.
    Start-Process (Join-Path $destino 'Enfocate.exe') -ArgumentList '--sin-auto'
    Write-Host 'Listo. Busca el icono en la bandeja del sistema, abajo a la derecha.'
    Write-Host 'Si no lo ves, haz clic en la flecha ^ de la bandeja y arrástralo a la barra de tareas.'
    exit 0
}

try {
    if (-not $Sid) { throw 'Ejecuta instalar.cmd, no este archivo directamente.' }
    # El compilador de C# viene con .NET Framework 4, incluido en Windows 10 y 11.
    $csc = @("$env:WINDIR\Microsoft.NET\Framework64\v4.0.30319\csc.exe",
             "$env:WINDIR\Microsoft.NET\Framework\v4.0.30319\csc.exe") | Where-Object { Test-Path $_ } | Select-Object -First 1
    if (-not $csc) { throw 'No encontré .NET Framework 4. Actívalo en "Activar o desactivar las características de Windows".' }

    Write-Host 'Compilando...'
    $tmp = Join-Path $env:TEMP ('enfocate-' + [guid]::NewGuid())
    New-Item -ItemType Directory $tmp | Out-Null
    & $csc /nologo /codepage:65001 /optimize /target:winexe "/out:$tmp\Enfocate.exe" `
        /r:System.Windows.Forms.dll /r:System.Drawing.dll "$aqui\Comun.cs" "$aqui\app\Bandeja.cs"
    if ($LASTEXITCODE) { throw 'No se pudo compilar la app.' }
    & $csc /nologo /codepage:65001 /optimize /target:exe "/out:$tmp\EnfocateServicio.exe" `
        /r:System.ServiceProcess.dll "$aqui\Comun.cs" "$aqui\servicio\Servicio.cs"
    if ($LASTEXITCODE) { throw 'No se pudo compilar el servicio.' }

    # Una versión anterior: se detiene para reemplazarla. Una sesión activa sigue al volver a arrancar.
    $existe = Get-Service $servicio -ErrorAction SilentlyContinue
    if ($existe) { Stop-Service $servicio -Force }
    Get-Process Enfocate -ErrorAction SilentlyContinue | Stop-Process -Force
    Start-Sleep -Seconds 1
    New-Item -ItemType Directory -Force $destino | Out-Null
    Copy-Item "$tmp\*.exe" $destino -Force
    Remove-Item $tmp -Recurse -Force

    # Datos: solo SYSTEM y los administradores escriben; cualquier usuario lee.
    New-Item -ItemType Directory -Force (Join-Path $datos 'ordenes') | Out-Null
    icacls $datos /inheritance:r /grant:r '*S-1-5-18:(OI)(CI)F' '*S-1-5-32-544:(OI)(CI)F' '*S-1-5-32-545:(OI)(CI)RX' | Out-Null
    # En la carpeta de órdenes cualquier usuario puede crear archivos. El servicio solo acepta los tuyos.
    icacls (Join-Path $datos 'ordenes') /grant '*S-1-5-32-545:(WD)' | Out-Null
    Set-Content (Join-Path $datos 'owner') $Sid -Encoding ASCII
    foreach ($f in 'sites', 'apps') {
        $r = Join-Path $datos $f
        if (-not (Test-Path $r)) { New-Item -ItemType File $r | Out-Null }
    }
    # Por defecto, la sesión automática deja libre WhatsApp.
    $skip = Join-Path $datos 'auto-skip'
    if (-not (Test-Path $skip)) { Set-Content $skip 'WhatsApp' -Encoding ASCII }

    if (-not $existe) {
        New-Service -Name $servicio -BinaryPathName "`"$destino\EnfocateServicio.exe`"" -DisplayName 'Enfócate pe causa' `
            -Description 'Lleva el tiempo de las sesiones y aplica el bloqueo.' -StartupType Automatic | Out-Null
    }
    sc.exe failure $servicio reset= 60 actions= restart/2000/restart/2000/restart/5000 | Out-Null
    Start-Service $servicio

    # La app se abre sola al iniciar sesión, solo en tu cuenta.
    $run = "Registry::HKEY_USERS\$Sid\Software\Microsoft\Windows\CurrentVersion\Run"
    if (-not (Test-Path $run)) { New-Item $run -Force | Out-Null }
    Set-ItemProperty $run -Name 'Enfocate pe causa' -Value "`"$destino\Enfocate.exe`""
    Write-Host 'Servicio instalado.'
    exit 0
} catch {
    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host $_.InvocationInfo.PositionMessage
    # En una ventana normal, espera para que se pueda leer el error.
    try { Read-Host 'Presiona Enter para cerrar' | Out-Null } catch { }
    exit 1
}
