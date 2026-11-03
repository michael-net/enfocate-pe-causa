// Corta las conexiones que los navegadores ya tenían abiertas. El archivo hosts solo
// afecta a las conexiones nuevas: sin esto, una pestaña abierta sigue funcionando.
using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Linq;
using System.Management;
using System.Net;
using System.Runtime.InteropServices;

namespace Enfocate
{
    static class Conexiones
    {
        // Navegadores basados en Chromium: su red corre en un proceso aparte que el navegador
        // vuelve a abrir solo, sin cerrar pestañas.
        static readonly string[] Chromium = { "chrome.exe", "msedge.exe", "brave.exe", "opera.exe", "vivaldi.exe" };
        // Firefox maneja la red en su proceso principal: se cortan sus conexiones una por una.
        static readonly string[] ConRedPropia = { "firefox" };

        public static void Cortar()
        {
            try { ReiniciarRedDeChromium(); } catch { }
            CortarFirefox();
        }

        public static void CortarFirefox()
        {
            try { CortarTcp(); } catch { }
        }

        const string Regla = "Enfocate pe causa: corte";

        // Direcciones reales de los sitios. Se consultan antes de escribir hosts, que después las cambia.
        public static List<string> Direcciones(List<string> sitios)
        {
            var ips = new HashSet<string>();
            foreach (var s in sitios)
                foreach (var nombre in new[] { s, "www." + s })
                    try { foreach (var ip in Dns.GetHostAddresses(nombre)) if (!IPAddress.IsLoopback(ip)) ips.Add(ip.ToString()); }
                    catch { }
            return ips.ToList();
        }

        // Firefox guarda la dirección real hasta 60 s: sin esto, vuelve a conectarse después del corte.
        public static void BloquearDirecciones(List<string> ips)
        {
            QuitarBloqueo();
            if (ips.Count == 0) return;
            Netsh("advfirewall firewall add rule name=\"" + Regla + "\" dir=out action=block enable=yes remoteip=" + string.Join(",", ips));
        }

        public static void QuitarBloqueo() { Netsh("advfirewall firewall delete rule name=\"" + Regla + "\""); }

        static void Netsh(string args)
        {
            try
            {
                var i = new ProcessStartInfo("netsh.exe", args) { CreateNoWindow = true, UseShellExecute = false };
                using (var p = Process.Start(i)) p.WaitForExit(10000);
            }
            catch { }
        }

        static void ReiniciarRedDeChromium()
        {
            string filtro = "Name='" + string.Join("' OR Name='", Chromium) + "'";
            using (var q = new ManagementObjectSearcher("SELECT ProcessId, CommandLine FROM Win32_Process WHERE " + filtro))
            {
                foreach (ManagementObject o in q.Get())
                {
                    var linea = o["CommandLine"] as string;
                    if (linea == null || linea.IndexOf("network.mojom.NetworkService", StringComparison.Ordinal) < 0) continue;
                    try { using (var p = Process.GetProcessById(Convert.ToInt32(o["ProcessId"]))) p.Kill(); } catch { }
                }
            }
        }

        [StructLayout(LayoutKind.Sequential)]
        struct FilaTcp { public uint Estado, IpLocal, PuertoLocal, IpRemota, PuertoRemoto, Pid; }

        const int AfInet = 2, TablaConPidConexiones = 4;
        const uint Establecida = 5, BorrarTcb = 12;

        // Solo IPv4: Windows no tiene una forma de cortar conexiones IPv6 de otro proceso.
        static void CortarTcp()
        {
            var pids = new System.Collections.Generic.HashSet<int>();
            foreach (var n in ConRedPropia)
                foreach (var p in Process.GetProcessesByName(n)) { pids.Add(p.Id); p.Dispose(); }
            if (pids.Count == 0) return;

            int tam = 0;
            GetExtendedTcpTable(IntPtr.Zero, ref tam, false, AfInet, TablaConPidConexiones, 0);
            IntPtr tabla = Marshal.AllocHGlobal(tam);
            try
            {
                if (GetExtendedTcpTable(tabla, ref tam, false, AfInet, TablaConPidConexiones, 0) != 0) return;
                int filas = Marshal.ReadInt32(tabla);
                int ancho = Marshal.SizeOf(typeof(FilaTcp));
                for (int i = 0; i < filas; i++)
                {
                    var f = (FilaTcp)Marshal.PtrToStructure(new IntPtr(tabla.ToInt64() + 4 + i * ancho), typeof(FilaTcp));
                    int puerto = (int)(((f.PuertoRemoto & 0xFF) << 8) | ((f.PuertoRemoto >> 8) & 0xFF));
                    if (f.Estado != Establecida || (puerto != 443 && puerto != 80) || !pids.Contains((int)f.Pid)) continue;
                    f.Estado = BorrarTcb;
                    SetTcpEntry(ref f);
                }
            }
            finally { Marshal.FreeHGlobal(tabla); }
        }

        [DllImport("iphlpapi.dll")]
        static extern int GetExtendedTcpTable(IntPtr tabla, ref int tam, bool ordenar, int familia, int clase, int reservado);
        [DllImport("iphlpapi.dll")] static extern int SetTcpEntry(ref FilaTcp fila);
    }
}
