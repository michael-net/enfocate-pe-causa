package work.michaelnet.enfocate

import android.content.Intent
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.BackHandler
import androidx.activity.compose.setContent
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.Button
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import java.time.LocalDateTime

/** Pantalla que aparece al abrir una app bloqueada. Calma: solo el motivo, la hora y el pase. */
class BloqueoActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        mostrar(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        mostrar(intent)
    }

    private fun mostrar(intent: Intent) {
        val app = intent.getStringExtra(APP) ?: return finish()
        val motivo = Motivo.valueOf(intent.getStringExtra(MOTIVO) ?: return finish())
        val hasta = LocalDateTime.parse(intent.getStringExtra(HASTA) ?: return finish())
        val almacen = Almacen(this)
        val reglas = Reglas(almacen.config)
        val quedan = reglas.pasesRestantes(reglas.alDia(almacen.estado, LocalDateTime.now()))
        val puedePase = intent.getBooleanExtra(PASE, false) && quedan > 0
        val nombre = runCatching {
            packageManager.getApplicationLabel(packageManager.getApplicationInfo(app, 0)).toString()
        }.getOrDefault(app)

        setContent {
            Tema {
                BackHandler { alInicio() }
                Pantalla(
                    titulo = Texto.titulo(motivo, nombre),
                    detalle = Texto.detalle(motivo, hasta),
                    pase = if (puedePase) "Usar un pase de 5 minutos (te quedan $quedan)" else null,
                    usarPase = { usarPase(app) },
                    salir = { alInicio() },
                )
            }
        }
    }

    private fun usarPase(app: String) {
        val almacen = Almacen(this)
        val nuevo = Reglas(almacen.config).usarPase(almacen.estado, LocalDateTime.now(), app, Uso(this).hoy(app))
        if (nuevo != null) {
            almacen.estado = nuevo
            packageManager.getLaunchIntentForPackage(app)?.let(::startActivity)
        }
        finish()
    }

    private fun alInicio() {
        startActivity(Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_HOME).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
        finish()
    }

    companion object {
        const val APP = "app"
        const val MOTIVO = "motivo"
        const val HASTA = "hasta"
        const val PASE = "pase"
    }
}

@Composable
private fun Pantalla(titulo: String, detalle: String, pase: String?, usarPase: () -> Unit, salir: () -> Unit) {
    Surface(Modifier.fillMaxSize(), color = MaterialTheme.colorScheme.background) {
        Column(
            Modifier.padding(32.dp),
            verticalArrangement = Arrangement.Center,
            horizontalAlignment = Alignment.CenterHorizontally,
        ) {
            Text(titulo, style = MaterialTheme.typography.headlineSmall, textAlign = TextAlign.Center)
            Spacer(Modifier.height(12.dp))
            Text(
                detalle,
                style = MaterialTheme.typography.bodyLarge,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                textAlign = TextAlign.Center,
            )
            Spacer(Modifier.height(40.dp))
            Button(onClick = salir, modifier = Modifier.fillMaxWidth()) { Text("Volver al inicio") }
            if (pase != null) {
                Spacer(Modifier.height(8.dp))
                OutlinedButton(onClick = usarPase, modifier = Modifier.fillMaxWidth()) { Text(pase) }
            }
        }
    }
}
