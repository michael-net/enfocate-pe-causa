// Servicio de Windows de "Enfócate pe causa". Se ejecuta como SYSTEM. Dos modos:
//   - Sesión de enfoque: un bloque continuo. No se cancela ni se acorta, solo se extiende.
//   - Pomodoro: rondas de trabajo (bloqueado) y descanso (libre). Solo se puede
//     terminar durante un descanso, y solo se quitan rondas futuras.
// La bandeja solo envía órdenes: las reglas se cumplen aquí.
using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.IO;
using System.Linq;
using System.Runtime.InteropServices;
using System.Security.Principal;
using System.ServiceProcess;
using System.Text;
using System.Threading;

namespace Enfocate
{
    public class Servicio : ServiceBase
    {
        public const string Nombre = "EnfocateSesion";

        const long AutoS = 2700;      // sesión automática: 45 min
        const long ExtenderS = 1800;  // +30 min
        const long MaxS = 43200;      // tope: 12 h restantes
        const long TrabajoS = 1500;   // pomodoro: 25 min
        const long DescansoS = 300;   // pomodoro: 5 min
        const int RondasDef = 4;
        const int RondasMax = 20;
        const long VencidaS = 600;    // si una fase venció hace más de esto, la PC estuvo apagada o dormida

        const string MarcaInicio = "# >>> focus block >>>";
        const string MarcaFin = "# <<< focus block <<<";

        string fase = "idle";
        long fin;
        int ronda, rondas;
        bool auto;
        SecurityIdentifier dueno;
        Thread hilo;
        volatile bool parar;

        public Servicio() { ServiceName = Nombre; CanStop = true; CanShutdown = true; }

        public static void Main(string[] args)
        {
            if (args.Length > 0 && args[0] == "--consola")
            {
                // Para probar sin instalar el servicio (como administrador).
                var s = new Servicio();
                s.Bucle();
                return;
            }
            Run(new Servicio());
        }

        protected override void OnStart(string[] args)
        {
            parar = false;
            hilo = new Thread(Bucle) { IsBackground = true };
            hilo.Start();
        }

        protected override void OnStop() { parar = true; if (hilo != null) hilo.Join(5000); }
        protected override void OnShutdown() { OnStop(); }

        void Bucle()
        {
            Directory.CreateDirectory(Rutas.Ordenes);
            try { dueno = new SecurityIdentifier(File.ReadAllText(Rutas.Dueno).Trim()); } catch { dueno = null; }
            CargarEstado();
            Guardar();
            int vuelta = 0;
            while (!parar)
            {
                // Cada orden es un archivo propio, para no perder órdenes seguidas.
                string[] archivos;
                try { archivos = Directory.GetFiles(Rutas.Ordenes, "cmd-*"); } catch { archivos = new string[0]; }
                Array.Sort(archivos, StringComparer.Ordinal);
                foreach (var f in archivos)
                {
                    var c = LeerOrden(f);
                    try { File.Delete(f); } catch { }
                    Ejecutar(c);
                    Guardar();
                }

                long ahora = Reloj.Ahora();
                if (fase != "idle" && ahora >= fin + VencidaS)
                {
                    IrAIdle();
                    Guardar();
                }
                else if (fase != "idle" && ahora >= fin)
                {
                    switch (fase)
                    {
                        case "focus": IrAIdle(); break;
                        case "work":
                            if (ronda >= rondas) IrAIdle();
                            else { fase = "break"; fin = ahora + DescansoS; }
                            break;
                        case "break":
                            if (ronda >= rondas) IrAIdle();
                            else { ronda++; IniciarTrabajo(); }
                            break;
                    }
                    Guardar();
                }

                // El bloqueo se vuelve a aplicar cada 2 s, por si alguien lo cambió.
                if (vuelta++ % 2 == 0) Aplicar();
                EscribirStatus();
                Thread.Sleep(1000);
            }
        }

        // Solo se aceptan archivos normales creados por el dueño de la PC.
        string LeerOrden(string f)
        {
            try
            {
                var info = new FileInfo(f);
                if ((info.Attributes & FileAttributes.ReparsePoint) != 0 || dueno == null) return "";
                var owner = File.GetAccessControl(f).GetOwner(typeof(SecurityIdentifier));
                if (!dueno.Equals(owner)) return "";
                var buf = new byte[200];
                int n;
                using (var fs = new FileStream(f, FileMode.Open, FileAccess.Read, FileShare.ReadWrite | FileShare.Delete))
                    n = fs.Read(buf, 0, buf.Length);
                return Encoding.UTF8.GetString(buf, 0, n).Split('\n')[0].Trim('\r', ' ');
            }
            catch { return ""; }
        }

        void Ejecutar(string c)
        {
            long ahora = Reloj.Ahora();
            switch (c)
            {
                case "focus60": case "focus90": case "focus120": case "focus180":
                    if (fase == "idle" && HayQueBloquear(false))
                    {
                        fase = "focus"; auto = false; fin = ahora + long.Parse(c.Substring(5)) * 60;
                    }
                    return;
                case "auto":
                    if (fase == "idle" && HayQueBloquear(true)) { fase = "focus"; auto = true; fin = ahora + AutoS; }
                    return;
                case "extend":
                    if (fase == "focus" && fin + ExtenderS - ahora <= MaxS) fin += ExtenderS;
                    return;
                case "pomodoro":
                    if (fase == "idle" && HayQueBloquear(false)) { rondas = RondasDef; ronda = 1; auto = false; IniciarTrabajo(); }
                    return;
                case "stop":   // solo durante un descanso
                    if (fase == "break") IrAIdle();
                    return;
                case "add":
                    if ((fase == "work" || fase == "break") && rondas < RondasMax) rondas++;
                    return;
                case "remove":  // solo rondas futuras
                    if ((fase == "work" || fase == "break") && rondas > ronda) rondas--;
                    return;
            }
            int sp = c.IndexOf(' ');
            if (sp < 0) return;
            string op = c.Substring(0, sp), valor = c.Substring(sp + 1);
            switch (op)
            {
                case "site+": EditarLista(Rutas.Sitios, Listas.Sitio, valor, "on"); break;
                case "site-": EditarLista(Rutas.Sitios, Listas.Sitio, valor, "off"); break;
                case "siteX": EditarLista(Rutas.Sitios, Listas.Sitio, valor, "del"); break;
                case "app+": EditarLista(Rutas.Apps, Listas.App, valor, "on"); break;
                case "app-": EditarLista(Rutas.Apps, Listas.App, valor, "off"); break;
                case "appX": EditarLista(Rutas.Apps, Listas.App, valor, "del"); break;
                case "skip+": EditarLista(Rutas.AutoSkip, Listas.App, valor, "on"); break;
                case "skip-": EditarLista(Rutas.AutoSkip, Listas.App, valor, "del"); break;
            }
        }

        // Las listas solo se pueden editar sin ninguna sesión activa.
        void EditarLista(string ruta, System.Text.RegularExpressions.Regex valido, string valor, string modo)
        {
            if (fase != "idle" || !valido.IsMatch(valor)) return;
            var salida = new List<string>();
            bool encontrado = false;
            string nuevo = modo == "on" ? valor : "#" + valor;
            foreach (var e in Listas.Leer(ruta))
            {
                if (e.Nombre == valor)
                {
                    encontrado = true;
                    if (modo != "del") salida.Add(nuevo);
                }
                else salida.Add((e.Activo ? "" : "#") + e.Nombre);
            }
            if (!encontrado && modo != "del") salida.Add(nuevo);
            try { Archivo.Escribir(ruta, string.Join("\n", salida) + (salida.Count > 0 ? "\n" : "")); } catch { }
        }

        List<string> SitiosABloquear() { return Listas.Activos(Rutas.Sitios, Listas.Sitio); }

        // En la sesión automática no se bloquean las apps de auto-skip.
        List<string> AppsABloquear(bool esAuto)
        {
            var apps = Listas.Activos(Rutas.Apps, Listas.App);
            if (!esAuto) return apps;
            var libres = new HashSet<string>(Listas.Activos(Rutas.AutoSkip, Listas.App), StringComparer.OrdinalIgnoreCase);
            return apps.Where(a => !libres.Contains(a)).ToList();
        }

        bool HayQueBloquear(bool esAuto) { return SitiosABloquear().Count > 0 || AppsABloquear(esAuto).Count > 0; }

        void IniciarTrabajo()
        {
            if (HayQueBloquear(false)) { fase = "work"; fin = Reloj.Ahora() + TrabajoS; }
            else IrAIdle();
        }

        void IrAIdle() { fase = "idle"; fin = 0; ronda = 0; rondas = 0; auto = false; }

        bool Bloqueado() { return (fase == "focus" || fase == "work") && Reloj.Ahora() < fin; }

        void Aplicar()
        {
            bool b = Bloqueado();
            EscribirHosts(b ? SitiosABloquear() : new List<string>());
            if (!b) return;
            uint consola = WTSGetActiveConsoleSessionId();
            foreach (var a in AppsABloquear(auto))
            {
                foreach (var p in Process.GetProcessesByName(a))
                {
                    try { if (p.SessionId == consola) p.Kill(); } catch { }
                    finally { p.Dispose(); }
                }
            }
        }

        // Reescribe el bloque marcado de hosts. Solo toca el archivo si cambia algo.
        void EscribirHosts(List<string> sitios)
        {
            try
            {
                // Encoding.Default lee y escribe los mismos bytes: no se alteran los comentarios del archivo.
                string actual = File.Exists(Rutas.Hosts) ? File.ReadAllText(Rutas.Hosts, Encoding.Default) : "";
                var sb = new StringBuilder();
                bool dentro = false, habiaBloque = false;
                foreach (var linea in actual.Replace("\r\n", "\n").Split('\n'))
                {
                    if (linea.TrimEnd() == MarcaInicio) { dentro = true; habiaBloque = true; continue; }
                    if (linea.TrimEnd() == MarcaFin) { dentro = false; continue; }
                    if (!dentro) sb.Append(linea).Append("\r\n");
                }
                if (!habiaBloque && sitios.Count == 0) return;
                var texto = sb.ToString().TrimEnd('\r', '\n') + "\r\n";
                if (sitios.Count > 0)
                {
                    texto += MarcaInicio + "\r\n";
                    foreach (var s in sitios)
                        texto += "127.0.0.1 " + s + "\r\n127.0.0.1 www." + s + "\r\n::1 " + s + "\r\n::1 www." + s + "\r\n";
                    texto += MarcaFin + "\r\n";
                }
                if (texto == actual) return;
                var attrs = File.Exists(Rutas.Hosts) ? File.GetAttributes(Rutas.Hosts) : FileAttributes.Normal;
                if ((attrs & FileAttributes.ReadOnly) != 0) File.SetAttributes(Rutas.Hosts, attrs & ~FileAttributes.ReadOnly);
                File.WriteAllText(Rutas.Hosts, texto, Encoding.Default);
                if ((attrs & FileAttributes.ReadOnly) != 0) File.SetAttributes(Rutas.Hosts, attrs);
                try { DnsFlushResolverCache(); } catch { }
            }
            catch { }
        }

        void CargarEstado()
        {
            string[] lineas;
            try { lineas = File.ReadAllLines(Rutas.Estado); } catch { return; }
            foreach (var l in lineas)
            {
                var p = l.Split(new[] { '=' }, 2);
                if (p.Length != 2) continue;
                long n;
                bool num = long.TryParse(p[1], out n) && n >= 0;
                switch (p[0])
                {
                    case "phase": if (p[1] == "idle" || p[1] == "focus" || p[1] == "work" || p[1] == "break") fase = p[1]; break;
                    case "end": if (num) fin = n; break;
                    case "round": if (num) ronda = (int)n; break;
                    case "rounds": if (num) rondas = (int)n; break;
                    case "auto": auto = num && n == 1; break;
                }
            }
        }

        void Guardar()
        {
            try
            {
                Archivo.Escribir(Rutas.Estado, string.Format("phase={0}\nend={1}\nround={2}\nrounds={3}\nauto={4}\n",
                    fase, fin, ronda, rondas, auto ? 1 : 0));
            }
            catch { }
        }

        void EscribirStatus()
        {
            try
            {
                Archivo.Escribir(Rutas.Status, string.Format("phase={0}\nend={1}\nround={2}\nrounds={3}\nupdated={4}\n",
                    fase, fin, ronda, rondas, Reloj.Ahora()));
            }
            catch { }
        }

        [DllImport("kernel32.dll")] static extern uint WTSGetActiveConsoleSessionId();
        [DllImport("dnsapi.dll")] static extern bool DnsFlushResolverCache();
    }
}
