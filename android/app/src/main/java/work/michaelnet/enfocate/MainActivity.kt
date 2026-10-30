package work.michaelnet.enfocate

import android.Manifest
import android.app.TimePickerDialog
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.os.Bundle
import android.provider.Settings
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.safeDrawingPadding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material3.Card
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Surface
import androidx.compose.material3.Switch
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import kotlinx.coroutines.delay
import java.time.Duration
import java.time.LocalDateTime
import java.time.LocalTime

data class AppInstalada(val paquete: String, val nombre: String)

class MainActivity : ComponentActivity() {
    private lateinit var almacen: Almacen
    private var refrescar by mutableIntStateOf(0)

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        almacen = Almacen(this)
        val apps = appsInstaladas()
        // La primera vez se sugieren las redes sociales instaladas.
        if (!almacen.configurada) {
            almacen.sociales = apps.map { it.paquete }.filter { it in Almacen.SUGERIDAS }.toSet()
            almacen.configurada = true
        }
        setContent {
            Tema {
                // Se vuelve a dibujar cada segundo para la cuenta regresiva.
                var tick by remember { mutableIntStateOf(0) }
                LaunchedEffect(Unit) { while (true) { delay(1000); tick++ } }
                Inicio(apps, tick + refrescar)
            }
        }
    }

    override fun onResume() {
        super.onResume()
        refrescar++
    }

    // Solo las apps con icono en el inicio: no hace falta el permiso de ver todas las apps.
    private fun appsInstaladas(): List<AppInstalada> {
        val intent = Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_LAUNCHER)
        return packageManager.queryIntentActivities(intent, 0)
            .map { AppInstalada(it.activityInfo.packageName, it.loadLabel(packageManager).toString()) }
            .filter { it.paquete != packageName }
            .distinctBy { it.paquete }
            .sortedWith(compareBy({ it.paquete !in Almacen.SUGERIDAS }, { it.nombre.lowercase() }))
    }

    @Composable
    private fun Inicio(apps: List<AppInstalada>, @Suppress("UNUSED_PARAMETER") version: Int) {
        val ahora = LocalDateTime.now()
        val config = almacen.config
        val reglas = Reglas(config)
        val estado = reglas.alDia(almacen.estado, ahora)
        val franja = reglas.finDeFranja(estado, ahora)
        val enFoco = reglas.focoActivo(estado, ahora)
        // Como en escritorio: durante un bloqueo no se cambia lo que se bloquea.
        val editable = franja == null && !enFoco
        var sociales by remember { mutableStateOf(almacen.sociales) }

        Surface(Modifier.fillMaxSize(), color = MaterialTheme.colorScheme.background) {
            LazyColumn(
                Modifier.safeDrawingPadding().padding(horizontal = 20.dp),
                verticalArrangement = Arrangement.spacedBy(12.dp),
            ) {
                item {
                    Spacer(Modifier.height(12.dp))
                    Text("Enfócate pe causa", style = MaterialTheme.typography.headlineSmall)
                }
                item { Permisos() }
                item { EstadoActual(reglas, estado, ahora) }
                item {
                    Seccion("Sesión de enfoque") {
                        if (enFoco) {
                            Text("Termina a las ${Texto.hora(estado.focoFin!!)}")
                            OutlinedButton(onClick = { cambiarEstado(reglas.extenderFoco(almacen.estado, LocalDateTime.now())) }) {
                                Text("Extender 30 min")
                            }
                        } else {
                            Text(
                                "Bloquea tu lista. No se puede cancelar.",
                                color = MaterialTheme.colorScheme.onSurfaceVariant,
                            )
                            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                                listOf("1 h" to 60L, "1 h 30" to 90L, "2 h" to 120L, "3 h" to 180L).forEach { (t, m) ->
                                    OutlinedButton(onClick = { iniciarFoco(m) }, enabled = sociales.isNotEmpty()) { Text(t) }
                                }
                            }
                        }
                    }
                }
                item {
                    Seccion("Noche") {
                        Text(
                            "Las redes se bloquean de noche. La mañana bloquea 45 minutos desde que empiezas a usar el celular.",
                            color = MaterialTheme.colorScheme.onSurfaceVariant,
                        )
                        Hora("Empieza", config.nocheInicio, editable) { almacen.config = config.copy(nocheInicio = it); refrescar++ }
                        Hora("Termina", config.nocheFin, editable) { almacen.config = config.copy(nocheFin = it); refrescar++ }
                    }
                }
                item {
                    Text("Redes sociales", style = MaterialTheme.typography.titleMedium)
                    if (!editable) {
                        Text("Se pueden cambiar cuando no haya un bloqueo.", color = MaterialTheme.colorScheme.onSurfaceVariant)
                    }
                }
                items(apps, key = { it.paquete }) { app ->
                    Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
                        Text(app.nombre, Modifier.weight(1f))
                        Switch(
                            checked = app.paquete in sociales,
                            enabled = editable,
                            onCheckedChange = { on ->
                                sociales = if (on) sociales + app.paquete else sociales - app.paquete
                                almacen.sociales = sociales
                                Guardian.listaCambiada()
                            },
                        )
                    }
                    HorizontalDivider()
                }
                item { Spacer(Modifier.height(24.dp)) }
            }
        }
    }

    @Composable
    private fun Permisos() {
        val uso = Uso(this).permitido()
        val accesibilidad = Guardian.activo
        if (uso && accesibilidad) return
        Seccion("Para empezar") {
            Text("Enfócate pe causa necesita dos permisos. No tiene acceso a internet: nada sale de tu celular.")
            if (!uso) {
                TextButton(onClick = { startActivity(Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS)) }) {
                    Text("1. Activar el acceso a uso (para contar los minutos)")
                }
            }
            if (!accesibilidad) {
                TextButton(onClick = { startActivity(Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS)) }) {
                    Text("2. Activar Enfócate pe causa en Accesibilidad (para bloquear)")
                }
                Text(
                    "Si aparece como no disponible, ve a Ajustes > Apps > Enfócate pe causa, abre el menú ⋮ y elige \"Permitir ajustes restringidos\".",
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
            }
        }
    }

    @Composable
    private fun EstadoActual(reglas: Reglas, estado: Estado, ahora: LocalDateTime) {
        val franja = reglas.finDeFranja(estado, ahora)
        val (titulo, detalle) = when {
            reglas.focoActivo(estado, ahora) ->
                "Sesión de enfoque activa" to Texto.cuenta(Duration.between(ahora, estado.focoFin))
            franja != null ->
                Texto.titulo(franja.first, "") to Texto.detalle(franja.first, franja.second)
            else -> "Sin bloqueo" to "La noche empieza a las ${Texto.hora(almacen.config.nocheInicio)}."
        }
        Card(Modifier.fillMaxWidth()) {
            Column(Modifier.padding(16.dp)) {
                Text(titulo, style = MaterialTheme.typography.titleMedium)
                Text(detalle, style = MaterialTheme.typography.headlineMedium)
                Text(
                    "Pases de hoy: ${reglas.pasesRestantes(estado)} de 2",
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
            }
        }
    }

    @Composable
    private fun Seccion(titulo: String, contenido: @Composable () -> Unit) {
        Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
            Text(titulo, style = MaterialTheme.typography.titleMedium)
            contenido()
        }
    }

    @Composable
    private fun Hora(etiqueta: String, valor: LocalTime, editable: Boolean, cambiar: (LocalTime) -> Unit) {
        Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
            Text(etiqueta, Modifier.weight(1f))
            TextButton(enabled = editable, onClick = {
                TimePickerDialog(this@MainActivity, { _, h, m -> cambiar(LocalTime.of(h, m)) }, valor.hour, valor.minute, true).show()
            }) { Text(Texto.hora(valor)) }
        }
    }

    private fun cambiarEstado(e: Estado) {
        almacen.estado = e
        e.focoFin?.let { Foco.mostrar(this, it) }
        refrescar++
    }

    private fun iniciarFoco(minutos: Long) {
        if (Build.VERSION.SDK_INT >= 33 &&
            checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED
        ) {
            requestPermissions(arrayOf(Manifest.permission.POST_NOTIFICATIONS), 0)
        }
        val reglas = Reglas(almacen.config)
        val ahora = LocalDateTime.now()
        cambiarEstado(reglas.iniciarFoco(reglas.alDia(almacen.estado, ahora), ahora, Duration.ofMinutes(minutos)))
    }
}
