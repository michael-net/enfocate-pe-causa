# Experimento: corta las conexiones de los navegadores.
Get-CimInstance Win32_Process -Filter "Name='chrome.exe' or Name='msedge.exe'" |
  Where-Object { $_.CommandLine -like '*network.mojom.NetworkService*' } |
  ForEach-Object { Write-Host "red de $($_.Name) reiniciada"; Stop-Process -Id $_.ProcessId -Force }
New-NetFirewallRule -DisplayName 'Enfocate QUIC' -Direction Outbound -Protocol UDP -RemotePort 443 -Action Block | Out-Null
Add-Type @'
using System; using System.Runtime.InteropServices;
public static class Tcp {
  [StructLayout(LayoutKind.Sequential)] public struct Fila { public uint estado, ipL, puertoL, ipR, puertoR, pid; }
  [DllImport("iphlpapi.dll")] public static extern int GetExtendedTcpTable(IntPtr t, ref int n, bool o, int af, int clase, int r);
  [DllImport("iphlpapi.dll")] public static extern int SetTcpEntry(ref Fila f);
  public static int Cortar(int[] pids) {
    int n = 0; GetExtendedTcpTable(IntPtr.Zero, ref n, false, 2, 4, 0);
    IntPtr t = Marshal.AllocHGlobal(n); int c = 0;
    try {
      if (GetExtendedTcpTable(t, ref n, false, 2, 4, 0) != 0) return -1;
      int filas = Marshal.ReadInt32(t); int tam = Marshal.SizeOf(typeof(Fila));
      for (int i = 0; i < filas; i++) {
        var f = (Fila)Marshal.PtrToStructure(new IntPtr(t.ToInt64() + 4 + i * tam), typeof(Fila));
        int pr = ((int)(f.puertoR & 0xFF) << 8) | (int)((f.puertoR >> 8) & 0xFF);
        if (f.estado == 5 && (pr == 443 || pr == 80) && Array.IndexOf(pids, (int)f.pid) >= 0) {
          f.estado = 12; if (SetTcpEntry(ref f) == 0) c++;
        }
      }
    } finally { Marshal.FreeHGlobal(t); }
    return c;
  }
}
'@
$pids = @(Get-Process firefox, chrome, msedge -ErrorAction SilentlyContinue | ForEach-Object Id)
Write-Host "conexiones cortadas: $([Tcp]::Cortar($pids))"
