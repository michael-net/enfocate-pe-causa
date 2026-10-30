// Rutas y reglas que comparten el servicio y la bandeja de "Enfócate pe causa" (Windows).
// Se compila con el csc.exe de .NET Framework que trae Windows: solo C# 5.
using System;
using System.Collections.Generic;
using System.IO;
using System.Text;
using System.Text.RegularExpressions;

namespace Enfocate
{
    public static class Rutas
    {
        // Carpeta de SYSTEM: cualquier usuario la lee, solo el servicio y los administradores la escriben.
        public static readonly string Base = Path.Combine(
            Environment.GetFolderPath(Environment.SpecialFolder.CommonApplicationData), "Enfocate");
        // Carpeta de órdenes: cualquier usuario puede crear archivos. El servicio solo lee y borra.
        public static readonly string Ordenes = Path.Combine(Base, "ordenes");
        public static readonly string Status = Path.Combine(Base, "status");
        public static readonly string Estado = Path.Combine(Base, "sesion.state");
        public static readonly string Sitios = Path.Combine(Base, "sites");
        public static readonly string Apps = Path.Combine(Base, "apps");
        public static readonly string AutoSkip = Path.Combine(Base, "auto-skip");
        public static readonly string Dueno = Path.Combine(Base, "owner");
        public static readonly string Hosts = Path.Combine(Environment.SystemDirectory, @"drivers\etc\hosts");
    }

    public class Estado
    {
        public string Fase = "idle";   // idle, focus, work, break
        public long Fin, Actualizado;
        public int Ronda, Rondas;

        public bool Vivo { get { return Reloj.Ahora() - Actualizado <= 5; } }

        public static Estado Leer()
        {
            var s = new Estado();
            string texto;
            try { texto = File.ReadAllText(Rutas.Status); } catch { return s; }
            foreach (var linea in texto.Split('\n'))
            {
                var p = linea.Trim().Split(new[] { '=' }, 2);
                if (p.Length != 2) continue;
                long n;
                long.TryParse(p[1], out n);
                switch (p[0])
                {
                    case "phase": s.Fase = p[1]; break;
                    case "end": s.Fin = n; break;
                    case "round": s.Ronda = (int)n; break;
                    case "rounds": s.Rondas = (int)n; break;
                    case "updated": s.Actualizado = n; break;
                }
            }
            return s;
        }
    }

    public class Elemento
    {
        public string Nombre;
        public bool Activo;
        public Elemento(string nombre, bool activo) { Nombre = nombre; Activo = activo; }
    }

    public static class Listas
    {
        public static readonly Regex Sitio = new Regex("^[a-z0-9][a-z0-9.-]*$");
        public static readonly Regex App = new Regex("^[A-Za-z0-9][A-Za-z0-9 ._-]*$");

        // Una línea que empieza con # es un elemento desactivado.
        public static List<Elemento> Leer(string ruta)
        {
            var r = new List<Elemento>();
            string[] lineas;
            try { lineas = File.ReadAllLines(ruta); } catch { return r; }
            foreach (var l in lineas)
            {
                var t = l.Trim();
                if (t.Length == 0) continue;
                if (t.StartsWith("#")) r.Add(new Elemento(t.Substring(1), false));
                else r.Add(new Elemento(t, true));
            }
            return r;
        }

        public static List<string> Activos(string ruta, Regex valido)
        {
            var r = new List<string>();
            foreach (var e in Leer(ruta))
                if (e.Activo && valido.IsMatch(e.Nombre)) r.Add(e.Nombre);
            return r;
        }

        // instagram.com, https://www.instagram.com/usuario -> instagram.com. null si no es válido.
        public static string NormalizarSitio(string crudo)
        {
            var s = (crudo ?? "").Trim().ToLowerInvariant();
            foreach (var prefijo in new[] { "https://", "http://", "www." })
                if (s.StartsWith(prefijo)) s = s.Substring(prefijo.Length);
            s = s.Split('/')[0];
            return Regex.IsMatch(s, @"^[a-z0-9][a-z0-9-]*(\.[a-z0-9-]+)+$") ? s : null;
        }

        // WhatsApp, WhatsApp.exe, C:\...\WhatsApp.exe -> WhatsApp. null si no es válido.
        public static string NormalizarApp(string crudo)
        {
            var s = Path.GetFileName((crudo ?? "").Trim());
            if (s.EndsWith(".exe", StringComparison.OrdinalIgnoreCase)) s = s.Substring(0, s.Length - 4);
            return App.IsMatch(s) ? s : null;
        }
    }

    public static class Reloj
    {
        static readonly DateTime Epoca = new DateTime(1970, 1, 1, 0, 0, 0, DateTimeKind.Utc);
        public static long Ahora() { return (long)(DateTime.UtcNow - Epoca).TotalSeconds; }
        public static DateTime ALocal(long epoch) { return Epoca.AddSeconds(epoch).ToLocalTime(); }
    }

    public static class Archivo
    {
        // Escribe en un temporal y lo reemplaza, para que nadie lea un archivo a medias.
        public static void Escribir(string ruta, string texto)
        {
            var tmp = ruta + ".tmp";
            File.WriteAllText(tmp, texto, new UTF8Encoding(false));
            if (File.Exists(ruta)) File.Replace(tmp, ruta, null);
            else File.Move(tmp, ruta);
        }
    }
}
