import AppIntents

// iOS no avisa a las apps del desbloqueo. Con una automatización de Atajos
// ("Al despertar" o "Al detener la alarma") la mañana empieza cuando te levantas.
struct EmpezarManana: AppIntent {
    static var title: LocalizedStringResource = "Empezar la mañana sin redes"
    static var description = IntentDescription("Bloquea las redes sociales 45 minutos. Solo funciona una vez al día y fuera de la noche.")
    static var openAppWhenRun = false

    func perform() async throws -> some IntentResult {
        Motor().empezarManana()
        return .result()
    }
}

struct AtajosDeEnfocate: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(intent: EmpezarManana(), phrases: ["Empezar la mañana con \(.applicationName)"])
    }
}
