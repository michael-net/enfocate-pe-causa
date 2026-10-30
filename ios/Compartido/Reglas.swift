import Foundation

// Reglas de Enfócate pe causa en el iPhone. Las mismas que en Android: ver docs/plan-movil.md.
// En iOS el tiempo de uso lo mide el sistema; aquí solo se decide qué horario está activo.

struct HoraDelDia: Codable, Equatable {
    var hora: Int
    var minuto: Int

    var componentes: DateComponents { DateComponents(hour: hora, minute: minuto) }
    var minutosDelDia: Int { hora * 60 + minuto }
}

struct Config: Codable, Equatable {
    var nocheInicio = HoraDelDia(hora: 22, minuto: 0)
    var nocheFin = HoraDelDia(hora: 6, minuto: 0)
    /// iOS no avisa del desbloqueo. Con Atajos, la mañana empieza al despertar; si no, al terminar la noche.
    var mananaConAtajos = false

    static let mananaMinutos = 45
    static let pasesPorDia = 2
    static let paseMinutos = 5
    static let limiteDiarioMinutos = 15
}

struct Estado: Codable, Equatable {
    var dia = Estado.hoy()
    var pasesUsados = 0
    var mananaEmpezada = false
    var mananaFin: Date?
    var focoFin: Date?

    static func hoy(_ fecha: Date = Date()) -> String {
        let c = Calendar.current.dateComponents([.year, .month, .day], from: fecha)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }

    /// Los pases y la mañana son de cada día: a medianoche vuelven a empezar.
    func alDia(_ ahora: Date = Date()) -> Estado {
        if dia == Estado.hoy(ahora) { return self }
        return Estado(dia: Estado.hoy(ahora), focoFin: focoFin)
    }

    var pasesRestantes: Int { max(Config.pasesPorDia - pasesUsados, 0) }
}

enum Reglas {
    static func enNoche(_ c: Config, _ ahora: Date = Date()) -> Bool {
        let h = Calendar.current.dateComponents([.hour, .minute], from: ahora)
        let t = (h.hour ?? 0) * 60 + (h.minute ?? 0)
        let ini = c.nocheInicio.minutosDelDia, fin = c.nocheFin.minutosDelDia
        return ini > fin ? (t >= ini || t < fin) : (t >= ini && t < fin)
    }

    static func enManana(_ e: Estado, _ ahora: Date = Date()) -> Bool {
        guard let fin = e.mananaFin else { return false }
        return fin > ahora
    }

    /// Hay bloqueo de horario si es de noche o está corriendo la mañana.
    static func horarioActivo(_ c: Config, _ e: Estado, _ ahora: Date = Date()) -> Bool {
        enNoche(c, ahora) || enManana(e, ahora)
    }

    static func focoActivo(_ e: Estado, _ ahora: Date = Date()) -> Bool {
        (e.focoFin ?? .distantPast) > ahora
    }
}
