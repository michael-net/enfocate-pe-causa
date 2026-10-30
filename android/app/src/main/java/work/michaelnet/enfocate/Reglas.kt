package work.michaelnet.enfocate

import java.time.Duration
import java.time.LocalDate
import java.time.LocalDateTime
import java.time.LocalTime

// Reglas de Enfócate pe causa en el celular. No dependen de Android, para poder probarlas.
// Las mismas reglas valen en iPhone: ver docs/plan-movil.md.

data class Config(
    val nocheInicio: LocalTime = LocalTime.of(22, 0),
    val nocheFin: LocalTime = LocalTime.of(6, 0),
    val manana: Duration = Duration.ofMinutes(45),
    val pasesPorDia: Int = 2,
    val pase: Duration = Duration.ofMinutes(5),
    val limiteDiario: Duration = Duration.ofMinutes(15),
)

/** Un pase abre una app por 5 minutos de uso. [usoBase] es su uso de hoy al empezar el pase. */
data class Pase(val app: String, val usoBase: Duration)

data class Estado(
    val dia: LocalDate,
    val mananaInicio: LocalDateTime? = null,
    val pasesUsados: Int = 0,
    val pase: Pase? = null,
    val focoFin: LocalDateTime? = null,
)

enum class Motivo { FOCO, NOCHE, MANANA, LIMITE }

sealed class Decision {
    /** La app no está en ninguna lista. */
    data object Libre : Decision()

    /** Se puede usar, pero hay que volver a revisar después de [revisarEn] de uso. */
    data class LibrePor(val revisarEn: Duration) : Decision()

    data class Bloqueada(val motivo: Motivo, val hasta: LocalDateTime, val puedeUsarPase: Boolean) : Decision()
}

class Reglas(private val c: Config = Config()) {

    /** Los pases y la mañana son de cada día: a medianoche vuelven a empezar. */
    fun alDia(e: Estado, ahora: LocalDateTime): Estado =
        if (e.dia == ahora.toLocalDate()) e
        else Estado(dia = ahora.toLocalDate(), focoFin = e.focoFin)

    fun enNoche(t: LocalTime): Boolean =
        if (c.nocheInicio > c.nocheFin) t >= c.nocheInicio || t < c.nocheFin
        else t >= c.nocheInicio && t < c.nocheFin

    /** La mañana empieza con el primer uso después de que termina la noche. */
    fun alUsar(e0: Estado, ahora: LocalDateTime): Estado {
        val e = alDia(e0, ahora)
        if (e.mananaInicio != null || enNoche(ahora.toLocalTime()) || ahora.toLocalTime() < c.nocheFin) return e
        return e.copy(mananaInicio = ahora)
    }

    fun pasesRestantes(e: Estado): Int = (c.pasesPorDia - e.pasesUsados).coerceAtLeast(0)

    fun focoActivo(e: Estado, ahora: LocalDateTime): Boolean = e.focoFin?.isAfter(ahora) == true

    /** Fin de la noche o de la mañana en curso, o null si no hay ninguna. */
    fun finDeFranja(e: Estado, ahora: LocalDateTime): Pair<Motivo, LocalDateTime>? {
        val t = ahora.toLocalTime()
        if (enNoche(t)) {
            var fin = ahora.toLocalDate().atTime(c.nocheFin)
            if (!fin.isAfter(ahora)) fin = fin.plusDays(1)
            return Motivo.NOCHE to fin
        }
        val m = e.mananaInicio ?: return null
        val fin = m.plus(c.manana)
        return if (fin.isAfter(ahora) && !m.isAfter(ahora)) Motivo.MANANA to fin else null
    }

    /**
     * Qué hacer cuando [app] pasa a primer plano. [usoHoy] es su uso de hoy, que mide Android.
     * Las redes sociales tienen mañana, noche, pases y límite; la sesión de enfoque bloquea las dos listas.
     */
    fun decidir(
        e0: Estado,
        ahora: LocalDateTime,
        app: String,
        usoHoy: Duration,
        esSocial: Boolean,
        esFoco: Boolean,
    ): Decision {
        val e = alDia(e0, ahora)
        if ((esSocial || esFoco) && focoActivo(e, ahora)) {
            return Decision.Bloqueada(Motivo.FOCO, e.focoFin!!, puedeUsarPase = false)
        }
        if (!esSocial) return Decision.Libre

        val medianoche = ahora.toLocalDate().plusDays(1).atStartOfDay()
        val quedaHoy = c.limiteDiario.minus(usoHoy)
        if (quedaHoy <= Duration.ZERO) return Decision.Bloqueada(Motivo.LIMITE, medianoche, puedeUsarPase = false)

        val franja = finDeFranja(e, ahora) ?: return Decision.LibrePor(minOf(quedaHoy, hastaLaNoche(ahora)))
        val pase = e.pase
        if (pase != null && pase.app == app) {
            val quedaPase = c.pase.minus(usoHoy.minus(pase.usoBase))
            if (quedaPase > Duration.ZERO) return Decision.LibrePor(minOf(quedaPase, quedaHoy))
        }
        return Decision.Bloqueada(franja.first, franja.second, puedeUsarPase = pasesRestantes(e) > 0)
    }

    /** Tiempo de reloj hasta que empieza la noche, para revisar a esa hora una app abierta. */
    fun hastaLaNoche(ahora: LocalDateTime): Duration {
        var inicio = ahora.toLocalDate().atTime(c.nocheInicio)
        if (!inicio.isAfter(ahora)) inicio = inicio.plusDays(1)
        return Duration.between(ahora, inicio)
    }

    /** Usa un pase para [app]. Devuelve null si ya no quedan pases hoy. */
    fun usarPase(e0: Estado, ahora: LocalDateTime, app: String, usoHoy: Duration): Estado? {
        val e = alDia(e0, ahora)
        if (pasesRestantes(e) <= 0) return null
        return e.copy(pasesUsados = e.pasesUsados + 1, pase = Pase(app, usoHoy))
    }

    /** Una sesión de enfoque no se cancela ni se acorta: solo empieza o se extiende. */
    fun iniciarFoco(e: Estado, ahora: LocalDateTime, duracion: Duration): Estado =
        if (focoActivo(e, ahora)) e else e.copy(focoFin = ahora.plus(duracion))

    fun extenderFoco(e: Estado, ahora: LocalDateTime): Estado {
        val fin = e.focoFin ?: return e
        if (!fin.isAfter(ahora)) return e
        val nuevo = fin.plusMinutes(30)
        return if (Duration.between(ahora, nuevo) <= Duration.ofHours(12)) e.copy(focoFin = nuevo) else e
    }
}
