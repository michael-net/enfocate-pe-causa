import Cocoa
import SwiftUI
import UniformTypeIdentifiers

let cmdDir = "/Users/Shared/focus-sesion"
let statusPath = "/Library/Application Support/focus/status"
let sitesPath = "/Library/Application Support/focus/sites"
let appsPath = "/Library/Application Support/focus/apps"
let autoSkipPath = "/Library/Application Support/focus/auto-skip"

struct Status {
    var phase = "idle", end = 0, round = 0, rounds = 0, updated = 0
    var alive: Bool { Int(Date().timeIntervalSince1970) - updated <= 5 }
}

func readStatus() -> Status {
    var s = Status()
    guard let text = try? String(contentsOfFile: statusPath, encoding: .utf8) else { return s }
    for line in text.split(separator: "\n") {
        let p = line.split(separator: "=", maxSplits: 1).map(String.init)
        guard p.count == 2 else { continue }
        switch p[0] {
        case "phase": s.phase = p[1]
        case "end": s.end = Int(p[1]) ?? 0
        case "round": s.round = Int(p[1]) ?? 0
        case "rounds": s.rounds = Int(p[1]) ?? 0
        case "updated": s.updated = Int(p[1]) ?? 0
        default: break
        }
    }
    return s
}

func send(_ c: String) {
    let name = String(format: "cmd-%013d-%08x", Int(Date().timeIntervalSince1970 * 1000), UInt32.random(in: 0...UInt32.max))
    try? (c + "\n").write(toFile: cmdDir + "/" + name, atomically: false, encoding: .utf8)
}

func notify(_ msg: String) {
    let p = Process()
    p.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
    p.arguments = ["-e", "display notification \"\(msg)\" with title \"Enfócate pe causa\""]
    try? p.run()
}

struct BlockItem: Identifiable {
    let name: String
    var on: Bool
    var id: String { name }
}

func readItems(_ path: String) -> [BlockItem] {
    guard let text = try? String(contentsOfFile: path, encoding: .utf8) else { return [] }
    return text.split(separator: "\n").map { line in
        line.hasPrefix("#") ? BlockItem(name: String(line.dropFirst()), on: false) : BlockItem(name: String(line), on: true)
    }
}

// Los cambios los aplica el servicio, que los rechaza si hay una sesión activa.
final class BlockLists: ObservableObject {
    @Published var sites: [BlockItem] = []
    @Published var apps: [BlockItem] = []
    @Published var autoSkip: Set<String> = []

    var anyOn: Bool { sites.contains { $0.on } || apps.contains { $0.on } }

    func reload() {
        sites = readItems(sitesPath)
        apps = readItems(appsPath)
        autoSkip = Set(readItems(autoSkipPath).filter { $0.on }.map { $0.name })
    }

    func setBlockedOnAuto(_ name: String, blocked: Bool) {
        if blocked { autoSkip.remove(name) } else { autoSkip.insert(name) }
        send("skip\(blocked ? "-" : "+") \(name)")
    }

    // Con la ventana abierta manda lo que se ve: un cambio tarda hasta 1 s en llegar al servicio.
    func reloadUnlessEditing(window: NSWindow?) {
        if window?.isVisible != true { reload() }
    }

    func setSite(_ name: String, on: Bool) {
        if let i = sites.firstIndex(where: { $0.name == name }) { sites[i].on = on } else { sites.append(BlockItem(name: name, on: on)) }
        send("site\(on ? "+" : "-") \(name)")
    }

    func setApp(_ name: String, on: Bool) {
        if let i = apps.firstIndex(where: { $0.name == name }) { apps[i].on = on } else { apps.append(BlockItem(name: name, on: on)) }
        send("app\(on ? "+" : "-") \(name)")
    }

    func removeSite(_ name: String) {
        sites.removeAll { $0.name == name }
        send("siteX \(name)")
    }

    func removeApp(_ name: String) {
        apps.removeAll { $0.name == name }
        send("appX \(name)")
    }
}

// instagram.com, https://www.instagram.com/usuario -> instagram.com. nil si no es válido.
func normalizeSite(_ raw: String) -> String? {
    var s = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    for prefix in ["https://", "http://", "www."] where s.hasPrefix(prefix) { s.removeFirst(prefix.count) }
    s = String(s.split(separator: "/", omittingEmptySubsequences: false).first ?? "")
    return s.range(of: "^[a-z0-9][a-z0-9-]*(\\.[a-z0-9-]+)+$", options: .regularExpression) != nil ? s : nil
}

func appIcon(_ name: String) -> NSImage? {
    for dir in ["/Applications", NSHomeDirectory() + "/Applications", "/System/Applications"] {
        let path = "\(dir)/\(name).app"
        if FileManager.default.fileExists(atPath: path) { return NSWorkspace.shared.icon(forFile: path) }
    }
    return nil
}

struct BlockRow: View {
    let name: String
    let icon: NSImage?
    let fallback: String
    let on: Binding<Bool>
    let remove: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Group {
                if let icon { Image(nsImage: icon).resizable() } else { Image(systemName: fallback).foregroundStyle(.secondary) }
            }
            .frame(width: 20, height: 20)
            Text(name)
            Spacer()
            Button(action: remove) { Image(systemName: "minus.circle") }
                .buttonStyle(.borderless)
                .foregroundStyle(.secondary)
                .help("Quitar de la lista")
                .accessibilityLabel("Quitar \(name)")
            Toggle(name, isOn: on).labelsHidden().toggleStyle(.switch).controlSize(.small)
        }
    }
}

struct BlockListsView: View {
    @ObservedObject var lists: BlockLists
    @State private var newSite = ""
    @State private var siteError = false

    var body: some View {
        Form {
            Section("Sitios") {
                ForEach(lists.sites) { item in
                    BlockRow(name: item.name, icon: nil, fallback: "globe",
                             on: Binding(get: { item.on }, set: { lists.setSite(item.name, on: $0) }),
                             remove: { lists.removeSite(item.name) })
                }
                HStack {
                    TextField("Agregar sitio", text: $newSite, prompt: Text("Agregar un sitio"))
                        .labelsHidden()
                        .onSubmit(addSite)
                        .onChange(of: newSite) { _ in siteError = false }
                    Button("Agregar", action: addSite).disabled(newSite.isEmpty)
                }
                if siteError {
                    Text("Escribe un sitio válido, como instagram.com.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Section("Apps") {
                ForEach(lists.apps) { item in
                    BlockRow(name: item.name, icon: appIcon(item.name), fallback: "app",
                             on: Binding(get: { item.on }, set: { lists.setApp(item.name, on: $0) }),
                             remove: { lists.removeApp(item.name) })
                }
                Button("Agregar app…", action: addApp)
            }
            if lists.apps.contains(where: { $0.on }) {
                Section {
                    ForEach(lists.apps.filter { $0.on }) { item in
                        Toggle(item.name, isOn: Binding(
                            get: { !lists.autoSkip.contains(item.name) },
                            set: { lists.setBlockedOnAuto(item.name, blocked: $0) }
                        ))
                        .toggleStyle(.switch)
                        .controlSize(.small)
                    }
                } header: {
                    Text("Al encender o abrir la Mac")
                } footer: {
                    Text("Empieza una sesión de enfoque de 45 minutos. Elige qué apps bloquea.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .formStyle(.grouped)
        .frame(minWidth: 380, idealWidth: 400, minHeight: 360, idealHeight: 520)
    }

    func addSite() {
        guard let site = normalizeSite(newSite) else { siteError = true; return }
        lists.setSite(site, on: true)
        newSite = ""
    }

    func addApp() {
        let panel = NSOpenPanel()
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.allowedContentTypes = [.application]
        panel.allowsMultipleSelection = true
        panel.prompt = "Agregar"
        guard panel.runModal() == .OK else { return }
        for url in panel.urls {
            // El servicio cierra la app por el nombre de su proceso.
            if let name = Bundle(url: url)?.executableURL?.lastPathComponent { lists.setApp(name, on: true) }
        }
    }
}

final class SessionModel: ObservableObject {
    @Published var title = ""
    @Published var time = ""
    @Published var detail = ""
}

struct SessionCard: View {
    @ObservedObject var model: SessionModel

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(model.title).font(.system(size: 13, weight: .medium))
            Text(model.time).font(.system(size: 30, weight: .semibold)).monospacedDigit()
            Text(model.detail).font(.system(size: 12)).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
    }
}

// Aviso flotante: no quita el foco a lo que estés haciendo.
struct SessionNotice: View {
    let model: SessionModel
    let dismiss: () -> Void

    var body: some View {
        SessionCard(model: model)
            .padding(.vertical, 4)
            .frame(width: 260)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
            .contentShape(Rectangle())
            .onTapGesture(perform: dismiss)
            .accessibilityAddTraits(.isButton)
            .accessibilityHint("Cierra el aviso")
    }
}

func symbol(_ name: String, _ description: String) -> NSImage? {
    let image = NSImage(systemSymbolName: name, accessibilityDescription: description)
    image?.isTemplate = true  // se adapta solo a barra clara u oscura
    return image
}

class App: NSObject, NSApplicationDelegate {
    let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    let menu = NSMenu()
    let info = NSMenuItem(title: "", action: nil, keyEquivalent: "")
    let sessionItem = NSMenuItem()
    let session = SessionModel()
    var notice: NSPanel? = nil
    var noticeHide: DispatchWorkItem? = nil
    let separator = NSMenuItem.separator()
    let focusMenu = NSMenuItem(title: "Sesión de enfoque", action: nil, keyEquivalent: "")
    let pomodoro = NSMenuItem(title: "Pomodoro", action: #selector(onPomodoro), keyEquivalent: "")
    let extend = NSMenuItem(title: "Extender 30 min", action: #selector(onExtend), keyEquivalent: "")
    let add = NSMenuItem(title: "Agregar ronda", action: #selector(onAdd), keyEquivalent: "")
    let remove = NSMenuItem(title: "Quitar ronda", action: #selector(onRemove), keyEquivalent: "")
    let stop = NSMenuItem(title: "Terminar pomodoro", action: #selector(onStop), keyEquivalent: "")
    let listSeparator = NSMenuItem.separator()
    let chooseItem = NSMenuItem(title: "Qué bloquear…", action: #selector(onChoose), keyEquivalent: "")
    let lists = BlockLists()
    var listWindow: NSWindow? = nil
    let endTime: DateFormatter = {
        let f = DateFormatter()
        f.timeStyle = .short
        f.dateStyle = .none
        return f
    }()
    var last: Status? = nil

    func applicationDidFinishLaunching(_ n: Notification) {
        info.isEnabled = false
        let card = NSHostingView(rootView: SessionCard(model: session))
        card.frame = NSRect(x: 0, y: 0, width: 260, height: card.fittingSize.height)
        sessionItem.view = card
        let sub = NSMenu()
        for (title, mins) in [("1 hora", 60), ("1 h 30 min", 90), ("2 horas", 120), ("3 horas", 180)] {
            let m = NSMenuItem(title: title, action: #selector(onFocus(_:)), keyEquivalent: "")
            m.target = self
            m.tag = mins
            sub.addItem(m)
        }
        focusMenu.submenu = sub
        for m in [pomodoro, extend, add, remove, stop, chooseItem] { m.target = self }
        menu.autoenablesItems = false
        [info, sessionItem, separator, focusMenu, pomodoro, extend, add, remove, stop, listSeparator, chooseItem].forEach { menu.addItem($0) }
        item.menu = menu
        item.button?.imagePosition = .imageLeading
        let timer = Timer(timeInterval: 1, repeats: true) { _ in self.tick() }
        RunLoop.main.add(timer, forMode: .common)
        tick()
        // Al iniciar sesión o abrir la Mac, arranca la sesión automática (al abrir la app, salvo con --sin-auto).
        if !CommandLine.arguments.contains("--sin-auto") { autoStart(attemptsLeft: 30) }
        NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) { _ in
            // Da tiempo al servicio para cerrar una sesión que venció durante la suspensión.
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) { self.autoStart(attemptsLeft: 30) }
        }
    }

    // El servicio puede tardar en responder justo después de encender la Mac.
    func autoStart(attemptsLeft: Int) {
        let st = readStatus()
        if st.alive {
            if st.phase == "idle" { send("auto") } else { showNotice() }
        } else if attemptsLeft > 0 {
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) { self.autoStart(attemptsLeft: attemptsLeft - 1) }
        }
    }

    func showNotice() {
        let panel = notice ?? makeNotice()
        notice = panel
        if let screen = NSScreen.main?.visibleFrame {
            panel.setFrameOrigin(NSPoint(x: screen.maxX - panel.frame.width - 12, y: screen.maxY - panel.frame.height - 12))
        }
        panel.orderFrontRegardless()
        noticeHide?.cancel()
        let hide = DispatchWorkItem { panel.orderOut(nil) }
        noticeHide = hide
        DispatchQueue.main.asyncAfter(deadline: .now() + 10, execute: hide)
    }

    func makeNotice() -> NSPanel {
        let view = NSHostingView(rootView: SessionNotice(model: session) { [weak self] in self?.notice?.orderOut(nil) })
        view.frame.size = view.fittingSize
        let panel = NSPanel(contentRect: view.frame, styleMask: [.nonactivatingPanel, .borderless], backing: .buffered, defer: false)
        panel.contentView = view
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.level = .statusBar
        panel.hidesOnDeactivate = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        return panel
    }

    func fmt(_ secs: Int) -> String {
        let t = max(secs, 0)
        if t >= 3600 { return String(format: "%d:%02d:%02d", t / 3600, (t % 3600) / 60, t % 60) }
        return String(format: "%02d:%02d", t / 60, t % 60)
    }

    // Icono y contador: cifras de ancho fijo para que la barra no salte cada segundo.
    func show(_ image: NSImage?, _ text: String) {
        guard let button = item.button else { return }
        button.image = image
        button.attributedTitle = NSAttributedString(string: text, attributes: [
            .font: NSFont.monospacedDigitSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)
        ])
    }

    func tick() {
        let s = readStatus()
        let left = s.end - Int(Date().timeIntervalSince1970)
        let idle = s.phase == "idle"
        let inPomodoro = s.phase == "work" || s.phase == "break"
        lists.reloadUnlessEditing(window: listWindow)
        let nothingOn = idle && !lists.anyOn
        let hasInfo = !s.alive || nothingOn
        info.isHidden = !hasInfo
        sessionItem.isHidden = idle || !s.alive
        separator.isHidden = !hasInfo && idle
        if idle { notice?.orderOut(nil) }
        focusMenu.isHidden = !idle
        pomodoro.isHidden = !idle
        extend.isHidden = s.phase != "focus"
        add.isHidden = !inPomodoro
        remove.isHidden = !inPomodoro
        stop.isHidden = s.phase != "break"
        listSeparator.isHidden = !idle
        chooseItem.isHidden = !idle
        // Durante una sesión no se puede cambiar lo que se bloquea.
        if !idle { listWindow?.close() }
        guard s.alive else {
            show(symbol("exclamationmark.triangle", "El servicio no responde"), "")
            info.title = "El servicio no responde"
            for m in [focusMenu, pomodoro, extend, add, remove, stop, chooseItem] { m.isEnabled = false }
            return
        }
        for m in [extend, stop, chooseItem] { m.isEnabled = true }
        focusMenu.isEnabled = !nothingOn
        pomodoro.isEnabled = !nothingOn
        add.isEnabled = s.rounds < 20
        remove.isEnabled = s.rounds > s.round
        switch s.phase {
        case "focus":
            show(symbol("scope", "Sesión de enfoque"), " " + fmt(left))
            let until = endTime.string(from: Date(timeIntervalSince1970: TimeInterval(s.end)))
            session.title = "Sesión de enfoque activa"
            session.detail = "Termina a las \(until)"
        case "work":
            show(symbol("timer", "Pomodoro"), " " + fmt(left))
            session.title = "Pomodoro activo"
            session.detail = "Ronda \(s.round) de \(s.rounds)"
        case "break":
            show(symbol("cup.and.saucer", "Descanso"), " " + fmt(left))
            session.title = "Descanso"
            session.detail = "Ronda \(s.round) de \(s.rounds)"
        default:
            show(symbol("scope", "Enfócate pe causa"), "")
            info.title = "Activa al menos un bloqueo"
        }
        session.time = fmt(left)
        if let l = last, l.phase != s.phase {
            switch (l.phase, s.phase) {
            case (_, "focus"), (_, "work"): showNotice()
            case (_, "break"): notify("Descanso de 5 minutos. Sitios y apps libres.")
            case ("focus", "idle"): notify("Sesión de enfoque terminada.")
            case ("work", "idle"): notify("Pomodoro terminado.")
            default: break
            }
        }
        last = s
    }

    @objc func onChoose() {
        lists.reload()
        if listWindow == nil {
            let window = NSWindow(contentViewController: NSHostingController(rootView: BlockListsView(lists: lists)))
            window.title = "Qué bloquear"
            window.styleMask = [.titled, .closable, .resizable]
            window.setContentSize(NSSize(width: 400, height: 520))
            window.isReleasedWhenClosed = false
            window.center()
            listWindow = window
        }
        NSApp.activate(ignoringOtherApps: true)
        listWindow?.makeKeyAndOrderFront(nil)
    }

    @objc func onFocus(_ sender: NSMenuItem) { send("focus\(sender.tag)") }
    @objc func onPomodoro() { send("pomodoro") }
    @objc func onExtend() { send("extend") }
    @objc func onAdd() { send("add") }
    @objc func onRemove() { send("remove") }
    @objc func onStop() { send("stop") }
}

let app = NSApplication.shared
app.setActivationPolicy(.accessory)
let delegate = App()
app.delegate = delegate
app.run()
