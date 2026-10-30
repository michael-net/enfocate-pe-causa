import DeviceActivity
import Foundation

// iOS despierta esta extensión solo cuando empieza o termina un horario, o se llega a un límite.
// No tiene acceso a la red ni a lo que haces en las apps.
class Monitor: DeviceActivityMonitor {
    let motor = Motor()

    override func intervalDidStart(for activity: DeviceActivityName) {
        super.intervalDidStart(for: activity)
        switch activity {
        case .noche: motor.aplicarHorario()
        case .diario: motor.nuevoDia()
        default: break
        }
    }

    override func intervalDidEnd(for activity: DeviceActivityName) {
        super.intervalDidEnd(for: activity)
        switch activity {
        case .noche:
            motor.aplicarHorario()
            // Sin Atajos, la mañana empieza al terminar la noche.
            if !motor.config.mananaConAtajos { motor.empezarManana() }
        case .manana: motor.terminarManana()
        case .pase: motor.terminarPase()
        case .foco: motor.terminarFoco()
        default: break
        }
    }

    override func eventDidReachThreshold(_ event: DeviceActivityEvent.Name, activity: DeviceActivityName) {
        super.eventDidReachThreshold(event, activity: activity)
        if event == .finDePase { motor.terminarPase() } else { motor.llegoAlLimite(event) }
    }
}
