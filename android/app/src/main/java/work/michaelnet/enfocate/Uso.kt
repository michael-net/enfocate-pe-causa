package work.michaelnet.enfocate

import android.app.AppOpsManager
import android.app.usage.UsageEvents
import android.app.usage.UsageStatsManager
import android.content.Context
import android.os.Build
import android.os.Process
import java.time.Duration
import java.time.LocalDate
import java.time.ZoneId

// Minutos de uso que ya registra Android. La app no guarda un historial propio.
class Uso(private val context: Context) {
    private val usm = context.getSystemService(UsageStatsManager::class.java)

    fun permitido(): Boolean {
        val ops = context.getSystemService(AppOpsManager::class.java)
        val modo = if (Build.VERSION.SDK_INT >= 29) {
            ops.unsafeCheckOpNoThrow(AppOpsManager.OPSTR_GET_USAGE_STATS, Process.myUid(), context.packageName)
        } else {
            @Suppress("DEPRECATION")
            ops.checkOpNoThrow(AppOpsManager.OPSTR_GET_USAGE_STATS, Process.myUid(), context.packageName)
        }
        return modo == AppOpsManager.MODE_ALLOWED
    }

    /** Tiempo en primer plano de [app] desde la medianoche, contando la sesión abierta. */
    fun hoy(app: String): Duration {
        val inicio = LocalDate.now().atStartOfDay(ZoneId.systemDefault()).toInstant().toEpochMilli()
        val ahora = System.currentTimeMillis()
        val eventos = usm.queryEvents(inicio, ahora)
        val e = UsageEvents.Event()
        var abiertas = 0
        var desde = inicio
        var total = 0L
        while (eventos.hasNextEvent()) {
            eventos.getNextEvent(e)
            if (e.packageName != app) continue
            when (e.eventType) {
                RESUMIDA -> {
                    if (abiertas == 0) desde = e.timeStamp
                    abiertas++
                }
                PAUSADA -> if (abiertas > 0) {
                    abiertas--
                    if (abiertas == 0) total += e.timeStamp - desde
                }
            }
        }
        if (abiertas > 0) total += ahora - desde
        return Duration.ofMillis(total)
    }

    /** La app en primer plano ahora, según los últimos eventos. */
    fun enPrimerPlano(): String? {
        val ahora = System.currentTimeMillis()
        val eventos = usm.queryEvents(ahora - 3_600_000, ahora)
        val e = UsageEvents.Event()
        var ultima: String? = null
        while (eventos.hasNextEvent()) {
            eventos.getNextEvent(e)
            if (e.eventType == RESUMIDA) ultima = e.packageName
            else if (e.eventType == PAUSADA && e.packageName == ultima) ultima = null
        }
        return ultima
    }

    private companion object {
        // MOVE_TO_FOREGROUND y MOVE_TO_BACKGROUND antes de Android 10; mismos valores.
        const val RESUMIDA = 1
        const val PAUSADA = 2
    }
}
