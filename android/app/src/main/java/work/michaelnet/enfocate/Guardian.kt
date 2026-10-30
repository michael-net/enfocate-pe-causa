package work.michaelnet.enfocate

import android.accessibilityservice.AccessibilityService
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.view.accessibility.AccessibilityEvent
import java.time.Duration
import java.time.LocalDateTime

/**
 * Servicio de accesibilidad: Android lo despierta solo cuando pasa a primer plano una de las
 * apps elegidas. No lee la pantalla, no corre en segundo plano y no tiene acceso a internet.
 */
class Guardian : AccessibilityService() {
    private lateinit var almacen: Almacen
    private lateinit var uso: Uso
    private val handler = Handler(Looper.getMainLooper())
    private var revision: Runnable? = null

    // El primer desbloqueo después de la noche empieza la mañana.
    private val desbloqueo = object : BroadcastReceiver() {
        override fun onReceive(context: Context, intent: Intent) {
            almacen.estado = Reglas(almacen.config).alUsar(almacen.estado, LocalDateTime.now())
        }
    }

    override fun onServiceConnected() {
        almacen = Almacen(this)
        uso = Uso(this)
        actualizarFiltro()
        val filtro = IntentFilter(Intent.ACTION_USER_PRESENT)
        if (Build.VERSION.SDK_INT >= 33) registerReceiver(desbloqueo, filtro, RECEIVER_NOT_EXPORTED)
        else registerReceiver(desbloqueo, filtro)
        instancia = this
    }

    override fun onDestroy() {
        instancia = null
        handler.removeCallbacksAndMessages(null)
        runCatching { unregisterReceiver(desbloqueo) }
        super.onDestroy()
    }

    override fun onInterrupt() {}

    /** Android solo avisa de las apps de la lista. Sin lista, solo de esta app, nunca de todas. */
    fun actualizarFiltro() {
        val apps = almacen.sociales
        serviceInfo = serviceInfo.apply {
            packageNames = if (apps.isEmpty()) arrayOf(packageName) else apps.toTypedArray()
        }
    }

    override fun onAccessibilityEvent(evento: AccessibilityEvent) {
        if (evento.eventType != AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED) return
        val app = evento.packageName?.toString() ?: return
        if (app in almacen.sociales) revisar(app)
    }

    private fun revisar(app: String) {
        val ahora = LocalDateTime.now()
        val reglas = Reglas(almacen.config)
        val e = reglas.alUsar(almacen.estado, ahora)
        almacen.estado = e
        revision?.let(handler::removeCallbacks)
        // Las sesiones de enfoque bloquean la misma lista.
        when (val d = reglas.decidir(e, ahora, app, uso.hoy(app), esSocial = true, esFoco = true)) {
            is Decision.Bloqueada -> bloquear(app, d)
            is Decision.LibrePor -> programar(app, d.revisarEn)
            Decision.Libre -> {}
        }
    }

    // Revisa de nuevo cuando se acabe el pase, el límite o empiece la noche, si la app sigue abierta.
    private fun programar(app: String, en: Duration) {
        val r = Runnable { if (uso.enPrimerPlano() == app) revisar(app) }
        revision = r
        handler.postDelayed(r, en.toMillis() + 1000)
    }

    private fun bloquear(app: String, d: Decision.Bloqueada) {
        performGlobalAction(GLOBAL_ACTION_HOME)
        startActivity(
            Intent(this, BloqueoActivity::class.java)
                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
                .putExtra(BloqueoActivity.APP, app)
                .putExtra(BloqueoActivity.MOTIVO, d.motivo.name)
                .putExtra(BloqueoActivity.HASTA, d.hasta.toString())
                .putExtra(BloqueoActivity.PASE, d.puedeUsarPase)
        )
    }

    companion object {
        private var instancia: Guardian? = null

        val activo: Boolean get() = instancia != null

        /** Después de cambiar la lista, para que Android avise de las apps nuevas. */
        fun listaCambiada() {
            instancia?.actualizarFiltro()
        }
    }
}
