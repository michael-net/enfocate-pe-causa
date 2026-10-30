import FamilyControls
import SwiftUI

struct Inicio: View {
    private let motor = Motor()
    @ObservedObject private var autorizacion = AuthorizationCenter.shared
    @State private var seleccion = Motor().seleccion
    @State private var config = Motor().config
    @State private var eligiendo = false
    @State private var ahora = Date()
    private let reloj = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        let estado = motor.estado
        let enFoco = Reglas.focoActivo(estado, ahora)
        // Como en escritorio: durante un bloqueo no se cambia lo que se bloquea.
        let editable = !enFoco && !Reglas.horarioActivo(config, estado, ahora)

        NavigationStack {
            Form {
                if autorizacion.authorizationStatus != .approved {
                    Section {
                        Text("Enfócate pe causa usa Tiempo de uso para bloquear. iOS nunca le dice qué apps eliges ni cuánto las usas, y la app no tiene acceso a internet.")
                        Button("Dar permiso de Tiempo de uso") {
                            Task { try? await AuthorizationCenter.shared.requestAuthorization(for: .individual) }
                        }
                    } header: { Text("Para empezar") }
                }

                Section {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(titulo(estado)).font(.headline)
                        if enFoco, let fin = estado.focoFin {
                            Text(fin, style: .timer).font(.largeTitle).monospacedDigit()
                        }
                        Text("Pases de hoy: \(estado.pasesRestantes) de \(Config.pasesPorDia)")
                            .foregroundStyle(.secondary)
                    }
                }

                Section {
                    if enFoco, let fin = estado.focoFin {
                        Text("Termina a las \(fin.formatted(date: .omitted, time: .shortened))")
                        Button("Extender 30 min") { motor.extenderFoco(); ahora = Date() }
                    } else {
                        ForEach([("1 hora", 60), ("1 h 30 min", 90), ("2 horas", 120), ("3 horas", 180)], id: \.1) { op in
                            Button(op.0) { motor.iniciarFoco(minutos: op.1); ahora = Date() }
                        }
                        .disabled(vacia)
                    }
                } header: { Text("Sesión de enfoque") } footer: { Text("Bloquea tu lista. No se puede cancelar.") }

                Section {
                    Button("Elegir redes sociales (\(cantidad))") { eligiendo = true }
                        .disabled(!editable)
                } header: { Text("Qué bloquear") } footer: {
                    Text("Elige cada app por separado para que tenga su límite de \(Config.limiteDiarioMinutos) minutos al día.")
                }

                Section {
                    DatePicker("Empieza", selection: hora(\.nocheInicio), displayedComponents: .hourAndMinute)
                    DatePicker("Termina", selection: hora(\.nocheFin), displayedComponents: .hourAndMinute)
                    Toggle("La mañana empieza con Atajos", isOn: $config.mananaConAtajos)
                } header: { Text("Noche y mañana") } footer: {
                    Text(config.mananaConAtajos
                         ? "Crea en Atajos una automatización \"Al despertar\" o \"Al detener la alarma\" con la acción \"Empezar la mañana sin redes\"."
                         : "La mañana bloquea \(Config.mananaMinutos) minutos al terminar la noche.")
                }
                .disabled(!editable)
            }
            .navigationTitle("Enfócate pe causa")
        }
        .familyActivityPicker(isPresented: $eligiendo, selection: $seleccion)
        .onChange(of: seleccion) { nueva in motor.seleccion = nueva; motor.programar() }
        .onChange(of: config) { nueva in motor.config = nueva; motor.programar() }
        .onReceive(reloj) { ahora = $0 }
    }

    private var cantidad: Int {
        seleccion.applicationTokens.count + seleccion.categoryTokens.count + seleccion.webDomainTokens.count
    }

    private var vacia: Bool { cantidad == 0 }

    private func titulo(_ e: Estado) -> String {
        if Reglas.focoActivo(e, ahora) { return "Sesión de enfoque activa" }
        if Reglas.enNoche(config, ahora) { return "Las redes descansan de noche" }
        if Reglas.enManana(e, ahora) { return "Empieza tu mañana sin redes" }
        return "Sin bloqueo"
    }

    private func hora(_ campo: WritableKeyPath<Config, HoraDelDia>) -> Binding<Date> {
        Binding(
            get: { Calendar.current.date(from: config[keyPath: campo].componentes) ?? Date() },
            set: {
                let c = Calendar.current.dateComponents([.hour, .minute], from: $0)
                config[keyPath: campo] = HoraDelDia(hora: c.hour ?? 0, minuto: c.minute ?? 0)
            }
        )
    }
}
