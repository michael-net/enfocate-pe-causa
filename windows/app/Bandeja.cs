// Icono de bandeja de "Enfócate pe causa" (Windows). Muestra el estado y envía órdenes.
// Las reglas se cumplen en el servicio: aquí nada puede saltarse una sesión.
using System;
using System.Collections.Generic;
using System.Drawing;
using System.Drawing.Drawing2D;
using System.Drawing.Text;
using System.IO;
using System.Linq;
using System.Reflection;
using System.Runtime.InteropServices;
using System.Text;
using System.Threading;
using System.Windows.Forms;
using Microsoft.Win32;

namespace Enfocate
{
    static class Programa
    {
        [STAThread]
        static void Main(string[] args)
        {
            bool nueva;
            using (var unica = new Mutex(true, @"Local\EnfocatePeCausa", out nueva))
            {
                if (!nueva) return;
                try { SetProcessDPIAware(); } catch { }
                Application.EnableVisualStyles();
                Application.SetCompatibleTextRenderingDefault(false);
                Application.Run(new Bandeja(args.Contains("--sin-auto")));
            }
        }

        [DllImport("user32.dll")] static extern bool SetProcessDPIAware();
    }

    static class Ui
    {
        public static readonly string Titulo = "Enfócate pe causa";
        public static Font Fuente(float puntos, FontStyle estilo)
        {
            foreach (var nombre in new[] { "Segoe UI Variable Text", "Segoe UI" })
            {
                var f = new Font(nombre, puntos, estilo);
                if (f.Name == nombre) return f;
                f.Dispose();
            }
            return new Font(FontFamily.GenericSansSerif, puntos, estilo);
        }

        static readonly Random azar = new Random();

        public static void Enviar(string orden)
        {
            var nombre = string.Format("cmd-{0:D13}-{1:x8}", (DateTime.UtcNow - new DateTime(1970, 1, 1)).Ticks / 10000, azar.Next());
            try { File.WriteAllText(Path.Combine(Rutas.Ordenes, nombre), orden + "\n", new UTF8Encoding(false)); } catch { }
        }

        public static string Formato(long segundos)
        {
            long t = Math.Max(segundos, 0);
            if (t >= 3600) return string.Format("{0}:{1:D2}:{2:D2}", t / 3600, (t % 3600) / 60, t % 60);
            return string.Format("{0:D2}:{1:D2}", t / 60, t % 60);
        }
    }

    // Iconos monocromos dibujados en tiempo real: se adaptan a la barra clara u oscura.
    static class Iconos
    {
        static readonly Dictionary<string, Icon> cache = new Dictionary<string, Icon>();

        static bool BarraClara()
        {
            try
            {
                var v = Registry.GetValue(@"HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize",
                    "SystemUsesLightTheme", 0);
                return v is int && (int)v == 1;
            }
            catch { return false; }
        }

        // tipo: enfoque, trabajo, descanso, alerta. texto: minutos restantes, o null.
        public static Icon Obtener(string tipo, string texto)
        {
            bool clara = BarraClara();
            string clave = tipo + "|" + texto + "|" + clara;
            Icon icono;
            if (cache.TryGetValue(clave, out icono)) return icono;
            if (cache.Count > 64) Limpiar();
            int n = SystemInformation.SmallIconSize.Width;
            using (var bmp = new Bitmap(n, n))
            using (var g = Graphics.FromImage(bmp))
            {
                g.SmoothingMode = SmoothingMode.AntiAlias;
                g.TextRenderingHint = TextRenderingHint.AntiAliasGridFit;
                var color = clara ? Color.FromArgb(28, 28, 28) : Color.White;
                float w = Math.Max(1.2f, n / 12f);
                using (var lapiz = new Pen(color, w))
                using (var pincel = new SolidBrush(color))
                {
                    if (texto != null) Texto(g, pincel, texto, n);
                    else Dibujar(g, lapiz, pincel, tipo, n, w);
                }
                IntPtr h = bmp.GetHicon();
                icono = (Icon)Icon.FromHandle(h).Clone();
                DestroyIcon(h);
            }
            cache[clave] = icono;
            return icono;
        }

        static void Texto(Graphics g, Brush pincel, string texto, int n)
        {
            float tam = n * (texto.Length > 2 ? 0.5f : 0.66f);
            using (var f = new Font("Segoe UI", tam, FontStyle.Bold, GraphicsUnit.Pixel))
            using (var formato = new StringFormat { Alignment = StringAlignment.Center, LineAlignment = StringAlignment.Center })
                g.DrawString(texto, f, pincel, new RectangleF(-2, 0, n + 4, n), formato);
        }

        static void Dibujar(Graphics g, Pen lapiz, Brush pincel, string tipo, int n, float w)
        {
            float m = w / 2 + n / 16f;
            float d = n - 2 * m;
            switch (tipo)
            {
                case "trabajo":
                    g.DrawEllipse(lapiz, m, m + n / 10f, d - n / 10f, d - n / 10f);
                    float cx = m + (d - n / 10f) / 2, cy = m + n / 10f + (d - n / 10f) / 2;
                    g.DrawLine(lapiz, cx, cy, cx, cy - d / 3.2f);
                    g.DrawLine(lapiz, cx - n / 8f, m, cx + n / 8f, m);
                    break;
                case "descanso":
                    g.DrawRectangle(lapiz, m, n * 0.35f, d * 0.68f, d * 0.55f);
                    g.DrawArc(lapiz, m + d * 0.6f, n * 0.42f, d * 0.32f, d * 0.3f, -90, 180);
                    g.DrawLine(lapiz, m + d * 0.2f, n * 0.12f, m + d * 0.2f, n * 0.25f);
                    g.DrawLine(lapiz, m + d * 0.45f, n * 0.12f, m + d * 0.45f, n * 0.25f);
                    break;
                case "alerta":
                    g.DrawPolygon(lapiz, new[] { new PointF(n / 2f, m), new PointF(n - m, n - m), new PointF(m, n - m) });
                    g.DrawLine(lapiz, n / 2f, n * 0.38f, n / 2f, n * 0.62f);
                    g.FillEllipse(pincel, n / 2f - w * 0.7f, n * 0.72f, w * 1.4f, w * 1.4f);
                    break;
                default: // enfoque: una diana
                    g.DrawEllipse(lapiz, m, m, d, d);
                    g.DrawEllipse(lapiz, n / 2f - d / 4.5f, n / 2f - d / 4.5f, d / 2.25f, d / 2.25f);
                    g.FillEllipse(pincel, n / 2f - w, n / 2f - w, 2 * w, 2 * w);
                    break;
            }
        }

        static void Limpiar()
        {
            foreach (var i in cache.Values) i.Dispose();
            cache.Clear();
        }

        [DllImport("user32.dll")] static extern bool DestroyIcon(IntPtr h);
    }

    class Bandeja : ApplicationContext
    {
        readonly NotifyIcon icono = new NotifyIcon();
        readonly ContextMenuStrip menu = new ContextMenuStrip();
        readonly ToolStripLabel info = new ToolStripLabel();
        readonly ToolStripLabel tarjetaTitulo = new ToolStripLabel();
        readonly ToolStripLabel tarjetaTiempo = new ToolStripLabel();
        readonly ToolStripLabel tarjetaDetalle = new ToolStripLabel();
        readonly ToolStripSeparator separador = new ToolStripSeparator();
        readonly ToolStripMenuItem enfoque = new ToolStripMenuItem("Sesión de enfoque");
        readonly ToolStripMenuItem pomodoro = new ToolStripMenuItem("Pomodoro");
        readonly ToolStripMenuItem extender = new ToolStripMenuItem("Extender 30 min");
        readonly ToolStripMenuItem agregar = new ToolStripMenuItem("Agregar ronda");
        readonly ToolStripMenuItem quitar = new ToolStripMenuItem("Quitar ronda");
        readonly ToolStripMenuItem terminar = new ToolStripMenuItem("Terminar pomodoro");
        readonly ToolStripSeparator separadorListas = new ToolStripSeparator();
        readonly ToolStripMenuItem elegir = new ToolStripMenuItem("Qué bloquear…");
        readonly System.Windows.Forms.Timer reloj = new System.Windows.Forms.Timer();
        readonly ModeloListas listas = new ModeloListas();
        VentanaListas ventana;
        Aviso aviso;
        Estado anterior;
        long ultimoTick = Reloj.Ahora();

        public Bandeja(bool sinAuto)
        {
            menu.Font = Ui.Fuente(9, FontStyle.Regular);
            menu.ShowImageMargin = false;
            info.ForeColor = SystemColors.GrayText;
            tarjetaTitulo.Font = Ui.Fuente(9.5f, FontStyle.Bold);
            tarjetaTiempo.Font = Ui.Fuente(20, FontStyle.Regular);
            tarjetaDetalle.ForeColor = SystemColors.GrayText;
            foreach (var t in new[] { Tuple.Create("1 hora", 60), Tuple.Create("1 h 30 min", 90), Tuple.Create("2 horas", 120), Tuple.Create("3 horas", 180) })
            {
                int minutos = t.Item2;
                enfoque.DropDownItems.Add(t.Item1, null, delegate { Ui.Enviar("focus" + minutos); });
            }
            pomodoro.Click += delegate { Ui.Enviar("pomodoro"); };
            extender.Click += delegate { Ui.Enviar("extend"); };
            agregar.Click += delegate { Ui.Enviar("add"); };
            quitar.Click += delegate { Ui.Enviar("remove"); };
            terminar.Click += delegate { Ui.Enviar("stop"); };
            elegir.Click += delegate { AbrirListas(); };
            menu.Items.AddRange(new ToolStripItem[] {
                info, tarjetaTitulo, tarjetaTiempo, tarjetaDetalle, separador,
                enfoque, pomodoro, extender, agregar, quitar, terminar, separadorListas, elegir });

            icono.ContextMenuStrip = menu;
            // En Windows el menú se abre con clic izquierdo o derecho.
            icono.MouseUp += (s, e) =>
            {
                if (e.Button != MouseButtons.Left) return;
                var m = typeof(NotifyIcon).GetMethod("ShowContextMenu", BindingFlags.Instance | BindingFlags.NonPublic);
                if (m != null) m.Invoke(icono, null);
            };
            icono.Icon = Iconos.Obtener("enfoque", null);
            icono.Text = Ui.Titulo;
            icono.Visible = true;

            reloj.Interval = 1000;
            reloj.Tick += delegate { Tick(); };
            reloj.Start();
            Tick();

            // Al iniciar sesión o despertar la PC, arranca la sesión automática (al abrir la app, salvo con --sin-auto).
            if (!sinAuto) AutoInicio(30);
            SystemEvents.PowerModeChanged += (s, e) => { if (e.Mode == PowerModes.Resume) AlDespertar(); };
        }

        // Da tiempo al servicio para cerrar una sesión que venció durante la suspensión.
        void AlDespertar() { Despues(3000, () => AutoInicio(30)); }

        // El servicio puede tardar en responder justo después de encender la PC.
        void AutoInicio(int intentos)
        {
            var st = Estado.Leer();
            if (st.Vivo)
            {
                if (st.Fase == "idle") Ui.Enviar("auto"); else MostrarAviso();
            }
            else if (intentos > 0) Despues(2000, () => AutoInicio(intentos - 1));
        }

        static void Despues(int ms, Action accion)
        {
            var t = new System.Windows.Forms.Timer { Interval = ms };
            t.Tick += delegate { t.Stop(); t.Dispose(); accion(); };
            t.Start();
        }

        void MostrarAviso()
        {
            if (aviso == null || aviso.IsDisposed) aviso = new Aviso();
            aviso.Mostrar(tarjetaTitulo.Text, tarjetaTiempo.Text, tarjetaDetalle.Text);
        }

        void Notificar(string mensaje) { icono.ShowBalloonTip(5000, Ui.Titulo, mensaje, ToolTipIcon.None); }

        void Mostrar(string tipo, string texto, string tooltip)
        {
            icono.Icon = Iconos.Obtener(tipo, texto);
            icono.Text = tooltip.Length > 63 ? tooltip.Substring(0, 63) : tooltip;
        }

        // En la bandeja solo cabe un número: los minutos que faltan, o las horas si son muchos.
        static string Minutos(long falta)
        {
            long min = (Math.Max(falta, 0) + 59) / 60;
            return min >= 100 ? (min + 59) / 60 + "h" : min.ToString();
        }

        void Tick()
        {
            // Si el reloj saltó, la PC estuvo dormida aunque Windows no lo haya avisado.
            long ahora = Reloj.Ahora();
            if (ahora - ultimoTick > 120) AlDespertar();
            ultimoTick = ahora;

            var s = Estado.Leer();
            long falta = s.Fin - ahora;
            bool idle = s.Fase == "idle";
            bool enPomodoro = s.Fase == "work" || s.Fase == "break";
            if (ventana == null || !ventana.Visible) listas.Recargar();
            bool nadaActivo = idle && !listas.AlgoActivo;
            bool hayInfo = !s.Vivo || nadaActivo;
            info.Visible = hayInfo;
            foreach (var t in new[] { tarjetaTitulo, tarjetaTiempo, tarjetaDetalle }) t.Visible = !idle && s.Vivo;
            separador.Visible = hayInfo || !idle;
            if (idle && aviso != null) aviso.Hide();
            enfoque.Visible = idle;
            pomodoro.Visible = idle;
            extender.Visible = s.Fase == "focus";
            agregar.Visible = enPomodoro;
            quitar.Visible = enPomodoro;
            terminar.Visible = s.Fase == "break";
            separadorListas.Visible = idle;
            elegir.Visible = idle;
            // Durante una sesión no se puede cambiar lo que se bloquea.
            if (!idle && ventana != null) ventana.Close();
            if (!s.Vivo)
            {
                Mostrar("alerta", null, "El servicio no responde");
                info.Text = "El servicio no responde";
                foreach (var m in new[] { enfoque, pomodoro, extender, agregar, quitar, terminar, elegir }) m.Enabled = false;
                return;
            }
            foreach (var m in new[] { extender, terminar, elegir }) m.Enabled = true;
            enfoque.Enabled = !nadaActivo;
            pomodoro.Enabled = !nadaActivo;
            agregar.Enabled = s.Rondas < 20;
            quitar.Enabled = s.Rondas > s.Ronda;
            switch (s.Fase)
            {
                case "focus":
                    Mostrar("enfoque", Minutos(falta), "Sesión de enfoque · " + Ui.Formato(falta));
                    tarjetaTitulo.Text = "Sesión de enfoque activa";
                    tarjetaDetalle.Text = "Termina a las " + Reloj.ALocal(s.Fin).ToShortTimeString();
                    break;
                case "work":
                    Mostrar("trabajo", Minutos(falta), "Pomodoro · " + Ui.Formato(falta));
                    tarjetaTitulo.Text = "Pomodoro activo";
                    tarjetaDetalle.Text = string.Format("Ronda {0} de {1}", s.Ronda, s.Rondas);
                    break;
                case "break":
                    Mostrar("descanso", Minutos(falta), "Descanso · " + Ui.Formato(falta));
                    tarjetaTitulo.Text = "Descanso";
                    tarjetaDetalle.Text = string.Format("Ronda {0} de {1}", s.Ronda, s.Rondas);
                    break;
                default:
                    Mostrar("enfoque", null, Ui.Titulo);
                    info.Text = "Activa al menos un bloqueo";
                    break;
            }
            tarjetaTiempo.Text = Ui.Formato(falta);
            if (aviso != null && aviso.Visible) aviso.Actualizar(tarjetaTitulo.Text, tarjetaTiempo.Text, tarjetaDetalle.Text);
            if (anterior != null && anterior.Fase != s.Fase)
            {
                if (s.Fase == "focus" || s.Fase == "work") MostrarAviso();
                else if (s.Fase == "break") Notificar("Descanso de 5 minutos. Sitios y apps libres.");
                else if (anterior.Fase == "focus" && idle) Notificar("Sesión de enfoque terminada.");
                else if (anterior.Fase == "work" && idle) Notificar("Pomodoro terminado.");
            }
            anterior = s;
        }

        void AbrirListas()
        {
            listas.Recargar();
            if (ventana == null || ventana.IsDisposed) ventana = new VentanaListas(listas);
            ventana.Reconstruir();
            ventana.Show();
            ventana.WindowState = FormWindowState.Normal;
            ventana.Activate();
        }
    }

    // Aviso flotante abajo a la derecha, junto a la bandeja. No quita el foco y se cierra con un clic.
    class Aviso : Form
    {
        readonly Label titulo = new Label(), tiempo = new Label(), detalle = new Label();
        readonly System.Windows.Forms.Timer ocultar = new System.Windows.Forms.Timer { Interval = 10000 };

        public Aviso()
        {
            FormBorderStyle = FormBorderStyle.None;
            ShowInTaskbar = false;
            TopMost = true;
            StartPosition = FormStartPosition.Manual;
            BackColor = SystemColors.Window;
            AutoSize = true;
            AutoSizeMode = AutoSizeMode.GrowAndShrink;
            Padding = new Padding(16, 10, 16, 12);
            var panel = new FlowLayoutPanel { FlowDirection = FlowDirection.TopDown, AutoSize = true, WrapContents = false };
            titulo.Font = Ui.Fuente(9.5f, FontStyle.Bold);
            tiempo.Font = Ui.Fuente(22, FontStyle.Regular);
            detalle.Font = Ui.Fuente(9, FontStyle.Regular);
            detalle.ForeColor = SystemColors.GrayText;
            foreach (var l in new[] { titulo, tiempo, detalle })
            {
                l.AutoSize = true;
                l.Click += delegate { Hide(); };
                panel.Controls.Add(l);
            }
            panel.MinimumSize = new Size(240, 0);
            panel.Click += delegate { Hide(); };
            Controls.Add(panel);
            Click += delegate { Hide(); };
            ocultar.Tick += delegate { ocultar.Stop(); Hide(); };
        }

        protected override bool ShowWithoutActivation { get { return true; } }

        protected override CreateParams CreateParams
        {
            get
            {
                var cp = base.CreateParams;
                cp.ExStyle |= 0x08000000 | 0x80 | 0x8; // WS_EX_NOACTIVATE | WS_EX_TOOLWINDOW | WS_EX_TOPMOST
                return cp;
            }
        }

        protected override void OnPaint(PaintEventArgs e)
        {
            base.OnPaint(e);
            e.Graphics.DrawRectangle(SystemPens.ControlDark, 0, 0, Width - 1, Height - 1);
        }

        public void Actualizar(string t, string h, string d) { titulo.Text = t; tiempo.Text = h; detalle.Text = d; }

        public void Mostrar(string t, string h, string d)
        {
            Actualizar(t, h, d);
            // Calcula el tamaño antes de mostrarlo, para que no aparezca en otro lugar.
            if (!IsHandleCreated) CreateHandle();
            PerformLayout();
            var area = Screen.PrimaryScreen.WorkingArea;
            Location = new Point(area.Right - Width - 12, area.Bottom - Height - 12);
            Show();
            ocultar.Stop();
            ocultar.Start();
        }
    }

    // Los cambios los aplica el servicio, que los rechaza si hay una sesión activa.
    class ModeloListas
    {
        public List<Elemento> Sitios = new List<Elemento>();
        public List<Elemento> Apps = new List<Elemento>();
        public HashSet<string> AutoSkip = new HashSet<string>(StringComparer.OrdinalIgnoreCase);

        public bool AlgoActivo { get { return Sitios.Any(e => e.Activo) || Apps.Any(e => e.Activo); } }

        public void Recargar()
        {
            Sitios = Listas.Leer(Rutas.Sitios);
            Apps = Listas.Leer(Rutas.Apps);
            AutoSkip = new HashSet<string>(Listas.Activos(Rutas.AutoSkip, Listas.App), StringComparer.OrdinalIgnoreCase);
        }

        static void Poner(List<Elemento> lista, string nombre, bool activo)
        {
            var e = lista.FirstOrDefault(x => x.Nombre == nombre);
            if (e != null) e.Activo = activo; else lista.Add(new Elemento(nombre, activo));
        }

        public void PonerSitio(string n, bool on) { Poner(Sitios, n, on); Ui.Enviar((on ? "site+ " : "site- ") + n); }
        public void PonerApp(string n, bool on) { Poner(Apps, n, on); Ui.Enviar((on ? "app+ " : "app- ") + n); }
        public void QuitarSitio(string n) { Sitios.RemoveAll(x => x.Nombre == n); Ui.Enviar("siteX " + n); }
        public void QuitarApp(string n) { Apps.RemoveAll(x => x.Nombre == n); Ui.Enviar("appX " + n); }

        public void BloquearEnAuto(string n, bool bloquear)
        {
            if (bloquear) AutoSkip.Remove(n); else AutoSkip.Add(n);
            Ui.Enviar((bloquear ? "skip- " : "skip+ ") + n);
        }
    }

    class VentanaListas : Form
    {
        readonly ModeloListas listas;
        readonly FlowLayoutPanel cuerpo = new FlowLayoutPanel();
        readonly TextBox nuevoSitio = new TextBox();
        readonly TextBox nuevaApp = new TextBox();
        readonly Label errorSitio = new Label();
        readonly Label errorApp = new Label();

        public VentanaListas(ModeloListas listas)
        {
            this.listas = listas;
            Text = "Qué bloquear";
            Font = Ui.Fuente(9, FontStyle.Regular);
            float escala;
            using (var g = CreateGraphics()) escala = g.DpiX / 96f;
            ClientSize = new Size((int)(440 * escala), (int)(560 * escala));
            MinimumSize = new Size((int)(380 * escala), (int)(360 * escala));
            StartPosition = FormStartPosition.CenterScreen;
            ShowIcon = false;
            MaximizeBox = false;
            cuerpo.Dock = DockStyle.Fill;
            cuerpo.FlowDirection = FlowDirection.TopDown;
            cuerpo.WrapContents = false;
            cuerpo.AutoScroll = true;
            cuerpo.Padding = new Padding(16, 8, 16, 16);
            Controls.Add(cuerpo);
            foreach (var e in new[] { errorSitio, errorApp })
            {
                e.AutoSize = true;
                e.ForeColor = SystemColors.GrayText;
                e.Visible = false;
            }
            errorSitio.Text = "Escribe un sitio válido, como instagram.com.";
            errorApp.Text = "Escribe el nombre del programa, como WhatsApp.";
            nuevoSitio.Width = 240;
            nuevaApp.Width = 160;
            nuevoSitio.KeyDown += (s, e) => { if (e.KeyCode == Keys.Enter) { e.SuppressKeyPress = true; AgregarSitio(); } };
            nuevaApp.KeyDown += (s, e) => { if (e.KeyCode == Keys.Enter) { e.SuppressKeyPress = true; AgregarApp(nuevaApp.Text); } };
            nuevoSitio.TextChanged += delegate { errorSitio.Visible = false; };
            nuevaApp.TextChanged += delegate { errorApp.Visible = false; };
            cuerpo.Resize += delegate { Anchos(); };
        }

        protected override void OnFormClosing(FormClosingEventArgs e)
        {
            // Se oculta en lugar de destruirse, para conservar lo escrito.
            if (e.CloseReason == CloseReason.UserClosing) { e.Cancel = true; Hide(); }
            base.OnFormClosing(e);
        }

        public new void Close() { Hide(); }

        int AnchoUtil { get { return cuerpo.ClientSize.Width - cuerpo.Padding.Horizontal - SystemInformation.VerticalScrollBarWidth; } }

        // Las filas ocupan todo el ancho, para que "Quitar" quede a la derecha y los textos largos bajen de línea.
        void Anchos()
        {
            int w = Math.Max(AnchoUtil, 200);
            foreach (Control c in cuerpo.Controls)
            {
                c.MaximumSize = new Size(w, 0);
                if (c is TableLayoutPanel) c.MinimumSize = new Size(w, 0);
            }
        }

        public void Reconstruir()
        {
            cuerpo.SuspendLayout();
            // Los cuadros de texto y los avisos se conservan, para no perder lo escrito.
            nuevoSitio.Parent = null;
            nuevaApp.Parent = null;
            foreach (Control c in cuerpo.Controls.Cast<Control>().ToList())
            {
                cuerpo.Controls.Remove(c);
                if (c != errorSitio && c != errorApp) c.Dispose();
            }

            Encabezado("Sitios");
            foreach (var e in listas.Sitios.ToList())
            {
                var nombre = e.Nombre;
                Fila(nombre, e.Activo, on => listas.PonerSitio(nombre, on), () => listas.QuitarSitio(nombre));
            }
            var agregarSitio = new Button { Text = "Agregar", AutoSize = true };
            agregarSitio.Click += delegate { AgregarSitio(); };
            Linea(nuevoSitio, agregarSitio);
            cuerpo.Controls.Add(errorSitio);

            Encabezado("Apps");
            foreach (var e in listas.Apps.ToList())
            {
                var nombre = e.Nombre;
                Fila(nombre, e.Activo, on => listas.PonerApp(nombre, on), () => listas.QuitarApp(nombre));
            }
            var agregarApp = new Button { Text = "Agregar", AutoSize = true };
            agregarApp.Click += delegate { AgregarApp(nuevaApp.Text); };
            var buscar = new Button { Text = "Buscar programa…", AutoSize = true };
            buscar.Click += delegate { BuscarPrograma(); };
            Linea(nuevaApp, agregarApp, buscar);
            cuerpo.Controls.Add(errorApp);

            var activas = listas.Apps.Where(x => x.Activo).ToList();
            if (activas.Count > 0)
            {
                Encabezado("Al encender o abrir la PC");
                foreach (var e in activas)
                {
                    var nombre = e.Nombre;
                    var c = new CheckBox { Text = nombre, Checked = !listas.AutoSkip.Contains(nombre), AutoSize = true, Margin = new Padding(0, 2, 0, 2) };
                    c.CheckedChanged += delegate { listas.BloquearEnAuto(nombre, c.Checked); };
                    cuerpo.Controls.Add(c);
                }
                cuerpo.Controls.Add(new Label
                {
                    Text = "Empieza una sesión de enfoque de 45 minutos. Elige qué apps bloquea.",
                    AutoSize = true, ForeColor = SystemColors.GrayText
                });
            }
            Anchos();
            cuerpo.ResumeLayout();
        }

        void Encabezado(string texto)
        {
            cuerpo.Controls.Add(new Label { Text = texto, AutoSize = true, Font = Ui.Fuente(10, FontStyle.Bold), Margin = new Padding(0, 14, 0, 4) });
        }

        void Fila(string nombre, bool activo, Action<bool> poner, Action quitar)
        {
            var fila = new TableLayoutPanel { ColumnCount = 2, RowCount = 1, AutoSize = true, Margin = new Padding(0, 1, 0, 1) };
            fila.ColumnStyles.Add(new ColumnStyle(SizeType.Percent, 100));
            fila.ColumnStyles.Add(new ColumnStyle(SizeType.AutoSize));
            var c = new CheckBox { Text = nombre, Checked = activo, AutoSize = true, Anchor = AnchorStyles.Left };
            // Reconstruye después del evento, porque la lista de "Al encender" depende de las apps activas.
            c.CheckedChanged += delegate { poner(c.Checked); BeginInvoke(new Action(Reconstruir)); };
            var q = new LinkLabel { Text = "Quitar", AutoSize = true, Anchor = AnchorStyles.Right, AccessibleName = "Quitar " + nombre };
            q.LinkClicked += delegate { quitar(); BeginInvoke(new Action(Reconstruir)); };
            fila.Controls.Add(c, 0, 0);
            fila.Controls.Add(q, 1, 0);
            cuerpo.Controls.Add(fila);
        }

        void Linea(params Control[] controles)
        {
            var l = new FlowLayoutPanel { AutoSize = true, WrapContents = true, Margin = new Padding(0, 6, 0, 0) };
            l.Controls.AddRange(controles);
            cuerpo.Controls.Add(l);
        }

        void AgregarSitio()
        {
            var s = Listas.NormalizarSitio(nuevoSitio.Text);
            if (s == null) { errorSitio.Visible = true; return; }
            listas.PonerSitio(s, true);
            nuevoSitio.Text = "";
            Reconstruir();
            nuevoSitio.Focus();
        }

        void AgregarApp(string texto)
        {
            var a = Listas.NormalizarApp(texto);
            if (a == null) { errorApp.Visible = true; return; }
            listas.PonerApp(a, true);
            nuevaApp.Text = "";
            Reconstruir();
            nuevaApp.Focus();
        }

        // El servicio cierra la app por el nombre de su proceso: el nombre del .exe.
        void BuscarPrograma()
        {
            using (var d = new OpenFileDialog
            {
                Filter = "Programas (*.exe)|*.exe",
                InitialDirectory = Environment.GetFolderPath(Environment.SpecialFolder.ProgramFiles),
                Multiselect = true,
                Title = "Agregar app"
            })
            {
                if (d.ShowDialog(this) != DialogResult.OK) return;
                foreach (var f in d.FileNames)
                {
                    var a = Listas.NormalizarApp(f);
                    if (a != null) listas.PonerApp(a, true);
                }
                Reconstruir();
            }
        }
    }
}
