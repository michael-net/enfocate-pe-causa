package work.michaelnet.enfocate

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import java.time.Duration
import java.time.LocalDateTime
import java.time.ZoneId

// Aviso con la cuenta regresiva de la sesión de enfoque. Lo cuenta Android: no hay servicio en segundo plano.
object Foco {
    private const val CANAL = "foco"
    private const val ID = 1

    fun mostrar(context: Context, fin: LocalDateTime) {
        val nm = context.getSystemService(NotificationManager::class.java)
        nm.createNotificationChannel(NotificationChannel(CANAL, "Sesión de enfoque", NotificationManager.IMPORTANCE_LOW))
        if (!nm.areNotificationsEnabled()) return
        val finMs = fin.atZone(ZoneId.systemDefault()).toInstant().toEpochMilli()
        val abrir = PendingIntent.getActivity(
            context, 0, Intent(context, MainActivity::class.java), PendingIntent.FLAG_IMMUTABLE
        )
        val n = Notification.Builder(context, CANAL)
            .setSmallIcon(R.drawable.ic_launcher_foreground)
            .setContentTitle("Sesión de enfoque activa")
            .setContentText("Termina a las ${Texto.hora(fin)}")
            .setWhen(finMs)
            .setShowWhen(true)
            .setUsesChronometer(true)
            .setChronometerCountDown(true)
            .setOngoing(true)
            .setContentIntent(abrir)
            .setTimeoutAfter(Duration.between(LocalDateTime.now(), fin).toMillis().coerceAtLeast(0))
            .build()
        nm.notify(ID, n)
    }
}
