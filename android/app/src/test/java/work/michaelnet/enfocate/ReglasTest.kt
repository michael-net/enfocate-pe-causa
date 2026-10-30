package work.michaelnet.enfocate

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import java.time.Duration
import java.time.LocalDate
import java.time.LocalDateTime

class ReglasTest {
    private val r = Reglas()
    private val hoy = LocalDate.of(2026, 10, 30)
    private fun a(h: Int, m: Int = 0) = hoy.atTime(h, m)
    private fun min(n: Long) = Duration.ofMinutes(n)
    private val ig = "com.instagram.android"

    private fun decidir(e: Estado, t: LocalDateTime, uso: Duration = Duration.ZERO, app: String = ig) =
        r.decidir(e, t, app, uso, esSocial = true, esFoco = false)

    @Test fun nocheBloqueaHastaLaHoraFija() {
        val d = decidir(Estado(hoy), a(23)) as Decision.Bloqueada
        assertEquals(Motivo.NOCHE, d.motivo)
        assertEquals(hoy.plusDays(1).atTime(6, 0), d.hasta)
        assertTrue(d.puedeUsarPase)
    }

    @Test fun mananaEmpiezaConElPrimerUsoDespuesDeLaNoche() {
        var e = r.alUsar(Estado(hoy), a(5, 30))
        assertNull("a las 5:30 sigue la noche", e.mananaInicio)
        e = r.alUsar(e, a(7, 10))
        assertEquals(a(7, 10), e.mananaInicio)
        e = r.alUsar(e, a(7, 20))
        assertEquals("solo el primer uso cuenta", a(7, 10), e.mananaInicio)
        val d = decidir(e, a(7, 30)) as Decision.Bloqueada
        assertEquals(Motivo.MANANA, d.motivo)
        assertEquals(a(7, 55), d.hasta)
        assertEquals(Decision.LibrePor(min(15)), decidir(e, a(8)))
    }

    @Test fun dosPasesAlDiaDeCincoMinutos() {
        var e = r.usarPase(Estado(hoy), a(23), ig, min(3))!!
        assertEquals(Decision.LibrePor(min(5)), decidir(e, a(23), min(3)))
        assertEquals(Decision.LibrePor(min(2)), decidir(e, a(23, 10), min(6)))
        assertTrue(decidir(e, a(23, 20), min(8)) is Decision.Bloqueada)
        e = r.usarPase(e, a(23, 30), "com.zhiliaoapp.musically", Duration.ZERO)!!
        assertEquals(0, r.pasesRestantes(e))
        assertNull(r.usarPase(e, a(23, 40), ig, min(8)))
        val d = decidir(e, a(23, 50), min(8)) as Decision.Bloqueada
        assertTrue(!d.puedeUsarPase)
    }

    @Test fun losPasesSeRenuevanAMedianoche() {
        var e = r.usarPase(Estado(hoy), a(22), ig, Duration.ZERO)!!
        e = r.usarPase(e, a(23), ig, Duration.ZERO)!!
        assertEquals(0, r.pasesRestantes(e))
        assertEquals(2, r.pasesRestantes(r.alDia(e, hoy.plusDays(1).atTime(1, 0))))
    }

    @Test fun elPaseNoPasaElLimiteDiario() {
        val e = r.usarPase(Estado(hoy), a(23), ig, min(13))!!
        assertEquals(Decision.LibrePor(min(2)), decidir(e, a(23), min(13)))
        val d = decidir(e, a(23, 5), min(15)) as Decision.Bloqueada
        assertEquals(Motivo.LIMITE, d.motivo)
        assertTrue(!d.puedeUsarPase)
    }

    @Test fun limiteDiarioDeQuinceMinutos() {
        assertEquals(Decision.LibrePor(min(4)), decidir(Estado(hoy), a(12), min(11)))
        val d = decidir(Estado(hoy), a(12), min(15)) as Decision.Bloqueada
        assertEquals(Motivo.LIMITE, d.motivo)
        assertEquals(hoy.plusDays(1).atStartOfDay(), d.hasta)
    }

    @Test fun focoNoSeCancelaYSoloSeExtiende() {
        var e = r.iniciarFoco(Estado(hoy), a(10), Duration.ofHours(1))
        assertEquals(a(11), e.focoFin)
        assertEquals("no se acorta", a(11), r.iniciarFoco(e, a(10, 5), min(15)).focoFin)
        e = r.extenderFoco(e, a(10, 30))
        assertEquals(a(11, 30), e.focoFin)
        val d = r.decidir(e, a(11), "com.whatsapp", Duration.ZERO, esSocial = false, esFoco = true) as Decision.Bloqueada
        assertEquals(Motivo.FOCO, d.motivo)
        assertTrue(!d.puedeUsarPase)
        assertEquals(Decision.Libre, r.decidir(e, a(11, 31), "com.whatsapp", Duration.ZERO, esSocial = false, esFoco = true))
    }

    @Test fun unaAppAbiertaSeRevisaAlEmpezarLaNoche() {
        assertEquals(Decision.LibrePor(min(5)), decidir(Estado(hoy), a(21, 55)))
    }

    @Test fun appsFueraDeLaListaNoSeTocan() {
        assertEquals(Decision.Libre, r.decidir(Estado(hoy), a(23), "com.whatsapp", min(60), esSocial = false, esFoco = false))
    }
}
