package work.michaelnet.enfocate

import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import java.time.Duration
import java.time.LocalDateTime
import java.time.LocalTime
import java.time.format.DateTimeFormatter
import java.time.format.FormatStyle

// Textos de la app, con el mismo tono que en escritorio: calma, sin alertas.
object Texto {
    private val formato = DateTimeFormatter.ofLocalizedTime(FormatStyle.SHORT)

    fun hora(t: LocalDateTime): String = t.format(formato)
    fun hora(t: LocalTime): String = t.format(formato)

    fun cuenta(d: Duration): String {
        val s = d.seconds.coerceAtLeast(0)
        return if (s >= 3600) "%d:%02d:%02d".format(s / 3600, (s % 3600) / 60, s % 60)
        else "%02d:%02d".format(s / 60, s % 60)
    }

    fun titulo(m: Motivo, app: String): String = when (m) {
        Motivo.FOCO -> "Sesión de enfoque"
        Motivo.NOCHE -> "Las redes descansan de noche"
        Motivo.MANANA -> "Empieza tu mañana sin redes"
        Motivo.LIMITE -> "Ya usaste tus 15 minutos de $app hoy"
    }

    fun detalle(m: Motivo, hasta: LocalDateTime): String = when (m) {
        Motivo.FOCO -> "Termina a las ${hora(hasta)}."
        Motivo.NOCHE, Motivo.MANANA -> "Libre a las ${hora(hasta)}."
        Motivo.LIMITE -> "Vuelve a estar libre mañana."
    }
}

@Composable
fun Tema(contenido: @Composable () -> Unit) {
    MaterialTheme(colorScheme = if (isSystemInDarkTheme()) darkColorScheme() else lightColorScheme()) { contenido() }
}
