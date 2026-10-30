import DeviceActivity
import FamilyControls
import Foundation
import ManagedSettings

// Aplica las reglas con la API de Tiempo de uso. Lo usan la app y sus extensiones.
// La app nunca sabe qué apps elegiste: solo guarda las fichas opacas que da iOS.

extension DeviceActivityName {
    static let noche = Self("noche")
    static let manana = Self("manana")
    static let diario = Self("diario")
    static let pase = Self("pase")
    static let foco = Self("foco")
}

extension DeviceActivityEvent.Name {
    static let finDePase = Self("pase.fin")
    static func limite(_ i: Int) -> Self { Self("limite.\(i)") }
}

extension ManagedSettingsStore.Name {
    // Cada regla tiene su propio almacén: un pase abre el horario, pero no el límite ni el enfoque.
    static let horario = Self("horario")
    static let limite = Self("limite")
    static let foco = Self("foco")
}

final class Motor {
    static let grupo = "group.work.michaelnet.enfocate"
    private let datos = UserDefaults(suiteName: Motor.grupo) ?? .standard
    private let centro = DeviceActivityCenter()

    // MARK: Datos guardados en el grupo de la app

    private func leer<T: Decodable>(_ clave: String, _ tipo: T.Type) -> T? {
        guard let d = datos.data(forKey: clave) else { return nil }
        return try? JSONDecoder().decode(tipo, from: d)
    }

    private func guardar<T: Encodable>(_ valor: T?, _ clave: String) {
        if let valor, let d = try? JSONEncoder().encode(valor) { datos.set(d, forKey: clave) }
        else { datos.removeObject(forKey: clave) }
    }

    var seleccion: FamilyActivitySelection {
        get { leer("seleccion", FamilyActivitySelection.self) ?? FamilyActivitySelection() }
        set { guardar(newValue, "seleccion") }
    }

    var config: Config {
        get { leer("config", Config.self) ?? Config() }
        set { guardar(newValue, "config") }
    }

    var estado: Estado {
        get { (leer("estado", Estado.self) ?? Estado()).alDia() }
        set { guardar(newValue, "estado") }
    }

    /// App con un pase en curso. Sigue abierta hasta 5 minutos de uso.
    var paseApp: ApplicationToken? {
        get { leer("paseApp", ApplicationToken.self) }
        set { guardar(newValue, "paseApp") }
    }

    /// Apps que ya llegaron a su límite hoy.
    var limitadas: Set<ApplicationToken> {
        get { leer("limitadas", Set<ApplicationToken>.self) ?? [] }
        set { guardar(newValue, "limitadas") }
    }

    /// Orden de las apps para los eventos "limite.N".
    private var ordenLimites: [ApplicationToken] {
        get { leer("ordenLimites", [ApplicationToken].self) ?? [] }
        set { guardar(newValue, "ordenLimites") }
    }

    // MARK: Horarios

    /// Vuelve a programar los horarios. Se llama al cambiar la lista o las horas.
    func programar() {
        let c = config
        centro.stopMonitoring([.noche, .diario])
        try? centro.startMonitoring(.noche, during: DeviceActivitySchedule(
            intervalStart: c.nocheInicio.componentes, intervalEnd: c.nocheFin.componentes, repeats: true))

        // Límite diario: un evento de 15 minutos por app elegida.
        let apps = Array(seleccion.applicationTokens)
        ordenLimites = apps
        var eventos: [DeviceActivityEvent.Name: DeviceActivityEvent] = [:]
        for (i, app) in apps.enumerated() {
            eventos[.limite(i)] = DeviceActivityEvent(
                applications: [app], threshold: DateComponents(minute: Config.limiteDiarioMinutos))
        }
        try? centro.startMonitoring(.diario, during: DeviceActivitySchedule(
            intervalStart: DateComponents(hour: 0, minute: 0),
            intervalEnd: DateComponents(hour: 23, minute: 59), repeats: true), events: eventos)
        aplicarHorario()
    }

    /// Pone o quita el escudo del horario según la hora, dejando libre la app con pase.
    func aplicarHorario() {
        let store = ManagedSettingsStore(named: .horario)
        guard Reglas.horarioActivo(config, estado) else { store.clearAllSettings(); return }
        let s = seleccion
        let libre: Set<ApplicationToken> = paseApp.map { [$0] } ?? []
        store.shield.applications = s.applicationTokens.subtracting(libre)
        store.shield.applicationCategories = .specific(s.categoryTokens, except: libre)
        store.shield.webDomains = s.webDomainTokens
    }

    // MARK: Mañana

    /// Empieza los 45 minutos de la mañana, una vez al día. Lo llama Atajos al despertar,
    /// o el monitor al terminar la noche si no se usa Atajos.
    func empezarManana(_ ahora: Date = Date()) {
        var e = estado
        guard !e.mananaEmpezada, !Reglas.enNoche(config, ahora) else { return }
        let fin = ahora.addingTimeInterval(TimeInterval(Config.mananaMinutos * 60))
        e.mananaEmpezada = true
        e.mananaFin = fin
        estado = e
        try? centro.startMonitoring(.manana, during: Motor.intervalo(desde: ahora, hasta: fin))
        aplicarHorario()
    }

    func terminarManana() {
        var e = estado
        e.mananaFin = nil
        estado = e
        aplicarHorario()
    }

    // MARK: Pases

    /// Usa un pase para [app]. Devuelve false si ya no quedan hoy o no hay horario activo.
    func usarPase(_ app: ApplicationToken, _ ahora: Date = Date()) -> Bool {
        var e = estado
        guard e.pasesRestantes > 0, Reglas.horarioActivo(config, e, ahora), !limitadas.contains(app) else { return false }
        e.pasesUsados += 1
        estado = e
        paseApp = app
        // iOS pide horarios de al menos 15 minutos: el pase termina al llegar a 5 minutos de uso.
        try? centro.startMonitoring(.pase,
            during: Motor.intervalo(desde: ahora, hasta: ahora.addingTimeInterval(3600)),
            events: [.finDePase: DeviceActivityEvent(applications: [app], threshold: DateComponents(minute: Config.paseMinutos))])
        aplicarHorario()
        return true
    }

    func terminarPase() {
        paseApp = nil
        centro.stopMonitoring([.pase])
        aplicarHorario()
    }

    // MARK: Límite diario

    func llegoAlLimite(_ evento: DeviceActivityEvent.Name) {
        guard let n = Int(evento.rawValue.replacingOccurrences(of: "limite.", with: "")),
              n < ordenLimites.count else { return }
        limitadas.insert(ordenLimites[n])
        ManagedSettingsStore(named: .limite).shield.applications = limitadas
    }

    /// A medianoche: límites y pases nuevos.
    func nuevoDia() {
        limitadas = []
        ManagedSettingsStore(named: .limite).clearAllSettings()
        estado = estado.alDia()
        aplicarHorario()
    }

    // MARK: Sesión de enfoque

    /// Una sesión no se cancela ni se acorta: solo empieza o se extiende.
    func iniciarFoco(minutos: Int, _ ahora: Date = Date()) {
        guard !Reglas.focoActivo(estado, ahora) else { return }
        ponerFoco(hasta: ahora.addingTimeInterval(TimeInterval(minutos * 60)), ahora)
    }

    func extenderFoco(_ ahora: Date = Date()) {
        guard let fin = estado.focoFin, fin > ahora else { return }
        let nuevo = fin.addingTimeInterval(1800)
        guard nuevo.timeIntervalSince(ahora) <= 12 * 3600 else { return }
        ponerFoco(hasta: nuevo, ahora)
    }

    private func ponerFoco(hasta fin: Date, _ ahora: Date) {
        var e = estado
        e.focoFin = fin
        estado = e
        let s = seleccion
        let store = ManagedSettingsStore(named: .foco)
        store.shield.applications = s.applicationTokens
        store.shield.applicationCategories = .specific(s.categoryTokens)
        store.shield.webDomains = s.webDomainTokens
        try? centro.startMonitoring(.foco, during: Motor.intervalo(desde: ahora, hasta: fin))
    }

    func terminarFoco() {
        var e = estado
        e.focoFin = nil
        estado = e
        ManagedSettingsStore(named: .foco).clearAllSettings()
    }

    private static func intervalo(desde: Date, hasta: Date) -> DeviceActivitySchedule {
        let campos: Set<Calendar.Component> = [.year, .month, .day, .hour, .minute, .second]
        return DeviceActivitySchedule(
            intervalStart: Calendar.current.dateComponents(campos, from: desde),
            intervalEnd: Calendar.current.dateComponents(campos, from: hasta),
            repeats: false)
    }
}
