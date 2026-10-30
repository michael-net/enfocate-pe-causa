import ManagedSettings
import ManagedSettingsUI
import UIKit

// La pantalla que cubre una app bloqueada. Calma: el motivo, volver y, si se puede, un pase.
class Escudo: ShieldConfigurationDataSource {
    let motor = Motor()

    override func configuration(shielding application: Application) -> ShieldConfiguration {
        pantalla(application.token)
    }

    override func configuration(shielding application: Application, in category: ActivityCategory) -> ShieldConfiguration {
        pantalla(application.token)
    }

    override func configuration(shielding webDomain: WebDomain) -> ShieldConfiguration {
        pantalla(nil)
    }

    override func configuration(shielding webDomain: WebDomain, in category: ActivityCategory) -> ShieldConfiguration {
        pantalla(nil)
    }

    private func pantalla(_ app: ApplicationToken?) -> ShieldConfiguration {
        let e = motor.estado
        let titulo: String
        var detalle: String
        var pase: String? = nil
        if Reglas.focoActivo(e), let fin = e.focoFin {
            titulo = "Sesión de enfoque"
            detalle = "Termina a las \(fin.formatted(date: .omitted, time: .shortened))."
        } else if let app, motor.limitadas.contains(app) {
            titulo = "Ya usaste tus \(Config.limiteDiarioMinutos) minutos de hoy"
            detalle = "Vuelve a estar libre mañana."
        } else if Reglas.enNoche(motor.config) {
            titulo = "Las redes descansan de noche"
            detalle = "Libre a las \(String(format: "%d:%02d", motor.config.nocheFin.hora, motor.config.nocheFin.minuto))."
        } else {
            titulo = "Empieza tu mañana sin redes"
            detalle = e.mananaFin.map { "Libre a las \($0.formatted(date: .omitted, time: .shortened))." } ?? ""
        }
        let horario = !Reglas.focoActivo(e) && !(app.map { motor.limitadas.contains($0) } ?? true)
        if horario, app != nil, e.pasesRestantes > 0 {
            pase = "Usar un pase de \(Config.paseMinutos) minutos (te quedan \(e.pasesRestantes))"
        }
        if detalle.isEmpty { detalle = " " }
        return ShieldConfiguration(
            backgroundBlurStyle: .systemMaterial,
            title: .init(text: titulo, color: .label),
            subtitle: .init(text: detalle, color: .secondaryLabel),
            primaryButtonLabel: .init(text: "Volver", color: .white),
            primaryButtonBackgroundColor: .systemIndigo,
            secondaryButtonLabel: pase.map { .init(text: $0, color: .systemIndigo) }
        )
    }
}
