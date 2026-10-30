package work.michaelnet.enfocate

import android.content.Context
import java.time.Duration
import java.time.LocalDate
import java.time.LocalDateTime
import java.time.LocalTime

// Todo se guarda en el almacenamiento privado de la app. Nada sale del celular.
class Almacen(context: Context) {
    private val p = context.getSharedPreferences("enfocate", Context.MODE_PRIVATE)

    // Se sugieren al abrir la app por primera vez, si están instaladas.
    companion object {
        val SUGERIDAS = setOf(
            "com.instagram.android",
            "com.zhiliaoapp.musically",      // TikTok
            "com.ss.android.ugc.trill",      // TikTok en Asia
            "com.facebook.katana",
            "com.facebook.lite",
            "com.twitter.android",           // X
            "com.google.android.youtube",
            "com.snapchat.android",
            "com.instagram.barcelona",       // Threads
            "com.reddit.frontpage",
        )
    }

    var configurada: Boolean
        get() = p.getBoolean("configurada", false)
        set(v) = p.edit().putBoolean("configurada", v).apply()

    var sociales: Set<String>
        get() = p.getStringSet("sociales", emptySet())!!.toSet()
        set(v) = p.edit().putStringSet("sociales", v).apply()

    var config: Config
        get() = Config(
            nocheInicio = LocalTime.ofSecondOfDay(p.getInt("nocheInicio", 22 * 3600).toLong()),
            nocheFin = LocalTime.ofSecondOfDay(p.getInt("nocheFin", 6 * 3600).toLong()),
        )
        set(c) = p.edit()
            .putInt("nocheInicio", c.nocheInicio.toSecondOfDay())
            .putInt("nocheFin", c.nocheFin.toSecondOfDay())
            .apply()

    var estado: Estado
        get() {
            val dia = p.getString("dia", null)?.let(LocalDate::parse) ?: LocalDate.now()
            val paseApp = p.getString("paseApp", null)
            return Estado(
                dia = dia,
                mananaInicio = p.getString("mananaInicio", null)?.let(LocalDateTime::parse),
                pasesUsados = p.getInt("pasesUsados", 0),
                pase = paseApp?.let { Pase(it, Duration.ofMillis(p.getLong("paseBase", 0))) },
                focoFin = p.getString("focoFin", null)?.let(LocalDateTime::parse),
            )
        }
        set(e) {
            p.edit()
                .putString("dia", e.dia.toString())
                .putString("mananaInicio", e.mananaInicio?.toString())
                .putInt("pasesUsados", e.pasesUsados)
                .putString("paseApp", e.pase?.app)
                .putLong("paseBase", e.pase?.usoBase?.toMillis() ?: 0)
                .putString("focoFin", e.focoFin?.toString())
                .apply()
        }
}
