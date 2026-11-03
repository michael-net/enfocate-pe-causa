"""Prueba el bloqueo en navegadores reales.

1. Abre cada navegador y carga los sitios, como quien ya los tenía abiertos.
2. Empieza una sesión de enfoque que bloquea esos sitios.
3. Vuelve a cargarlos varias veces durante unos minutos y anota si abren.
4. Abre cada navegador de nuevo, ya con la sesión activa, y prueba otra vez.

Uso: python pruebas/navegadores.py "<orden que empieza la sesión>" chrome edge firefox [safari]
"""
import os
import subprocess
import sys
import time

from selenium import webdriver
from selenium.common.exceptions import WebDriverException

# URL y el título que tiene la página de verdad. Las páginas de error no lo tienen.
SITIOS = {
    "wikipedia.org": ("https://www.wikipedia.org/", "Wikipedia"),
    "github.com": ("https://github.com/", "GitHub"),
}
CHEQUEOS = [5, 30, 70, 130, 250]


def abrir(nombre):
    if nombre == "chrome":
        o = webdriver.ChromeOptions()
        o.add_argument("--headless=new")
        o.page_load_strategy = "eager"
        d = webdriver.Chrome(options=o)
    elif nombre == "edge":
        o = webdriver.EdgeOptions()
        o.add_argument("--headless=new")
        o.page_load_strategy = "eager"
        d = webdriver.Edge(options=o)
    elif nombre == "firefox":
        o = webdriver.FirefoxOptions()
        o.add_argument("-headless")
        o.page_load_strategy = "eager"
        d = webdriver.Firefox(options=o)
    elif nombre == "safari":
        d = webdriver.Safari()
    else:
        raise ValueError(nombre)
    d.set_page_load_timeout(30)
    return d


def abre(d, url, n):
    """"abre", "bloqueado" o "copia": se ve una copia guardada, pero el sitio no responde."""
    try:
        d.get(f"{url}?prueba={n}")
        time.sleep(1)
        if SITIOS_POR_URL[url] not in d.title:
            return "bloqueado"
        # Lo que importa es si hay conexión con el sitio: así carga el contenido de una red social.
        d.set_script_timeout(20)
        conecta = d.execute_async_script(
            "const listo = arguments[arguments.length - 1];"
            " fetch('/favicon.ico?r=' + Math.random(), {cache: 'no-store'}).then(() => listo(true), () => listo(false));")
        return "abre" if conecta else "copia"
    except WebDriverException:
        return "bloqueado"


SITIOS_POR_URL = {url: titulo for url, titulo in SITIOS.values()}


def diagnosticar_firefox(d):
    """Diagnóstico temporal: qué dirección y qué conexión usa Firefox."""
    with d.context(d.CONTEXT_CHROME):
        d.set_script_timeout(20)
        print("    firefox por dentro:", d.execute_async_script("""
            const listo = arguments[arguments.length - 1];
            const dash = Cc["@mozilla.org/network/dashboard;1"].getService(Ci.nsIDashboard);
            const sitio = x => /wikipedia|github|wikimedia/.test(JSON.stringify(x));
            dash.requestDNSInfo(dns => dash.requestHttpConnections(http => {
              Services.dns.asyncResolve("www.wikipedia.org", Ci.nsIDNSService.RESOLVE_TYPE_DEFAULT,
                Ci.nsIDNSService.RESOLVE_BYPASS_CACHE, null, {
                  onLookupComplete(req, rec, status) {
                    let ips = [];
                    try { rec.QueryInterface(Ci.nsIDNSAddrRecord); while (rec.hasMore()) ips.push(rec.getNextAddrAsString()); } catch (e) {}
                    listo({ resolver: [status, ips], dns: (dns.entries || []).filter(sitio),
                            conexiones: (http.connections || []).filter(sitio) });
                  }
                }, Services.tm.mainThread, {});
            }));
        """))


def main():
    iniciar, nombres = sys.argv[1], sys.argv[2:]
    filas = []
    abiertos = {}
    for nombre in nombres:
        try:
            abiertos[nombre] = abrir(nombre)
        except WebDriverException as e:
            print(f"{nombre}: no se pudo abrir ({e.msg})")

    if "firefox" in abiertos:
        d = abiertos["firefox"]
        with d.context(d.CONTEXT_CHROME):
            print("Firefox:", d.execute_script(
                "const p = Services.prefs; return {trr: p.getIntPref('network.trr.mode'),"
                " cache: p.getIntPref('network.dnsCacheExpiration'), gracia: p.getIntPref('network.dnsCacheExpirationGracePeriod'),"
                " http3: p.getBoolPref('network.http.http3.enable'), bloqueada: p.prefIsLocked('network.http.http3.enable'),"
                " https: [p.getBoolPref('network.dns.native_https_query', null), p.getBoolPref('network.dns.native_https_query_win10', null), p.getBoolPref('network.dns.upgrade_with_https_rr', null), p.getBoolPref('network.dns.use_https_rr_as_altsvc', null)],"
                " activas: Object.keys(Services.policies.getActivePolicies() || {})}"))

    print("Antes de la sesión:")
    for nombre, d in abiertos.items():
        for sitio, (url, _) in SITIOS.items():
            r = abre(d, url, 0)
            print(f"  {nombre} {sitio}: {r}")
            if r == "bloqueado":
                print(f"    título: {d.title!r}")

    subprocess.run(iniciar, shell=True, check=True)
    t0 = time.time()
    print("Sesión iniciada.")

    for s in CHEQUEOS:
        time.sleep(max(0, t0 + s - time.time()))
        for nombre, d in abiertos.items():
            for sitio, (url, _) in SITIOS.items():
                r = abre(d, url, s)
                if nombre == "firefox" and r == "abre" and s == CHEQUEOS[0]:
                    diagnosticar_firefox(d)
                filas.append((nombre, "ya abierto", s, sitio, r))
                print(f"  {s:>3}s {nombre} {sitio}: {r.upper() if r == 'abre' else r}")

    for d in abiertos.values():
        d.quit()

    # Navegadores abiertos después de empezar la sesión.
    for nombre in abiertos:
        d = abrir(nombre)
        for sitio, (url, _) in SITIOS.items():
            r = abre(d, url, "nuevo")
            filas.append((nombre, "abierto en la sesión", None, sitio, r))
            print(f"  nuevo {nombre} {sitio}: {r.upper() if r == 'abre' else r}")
        d.quit()

    resumen = ["| Navegador | Caso | Segundos | Sitio | Resultado |", "|---|---|---|---|---|"]
    nombres_r = {"abre": "**abre**", "bloqueado": "bloqueado", "copia": "solo la copia guardada, sin internet"}
    for nombre, caso, s, sitio, r in filas:
        resumen.append(f"| {nombre} | {caso} | {s if s is not None else ''} | {sitio} | {nombres_r[r]} |")
    texto = "\n".join(resumen)
    fallas = [f for f in filas if f[4] == "abre"]
    print(texto)
    if os.environ.get("GITHUB_STEP_SUMMARY"):
        with open(os.environ["GITHUB_STEP_SUMMARY"], "a", encoding="utf-8") as f:
            f.write(f"## {sys.platform}\n\n{texto}\n\n")
    if fallas:
        print(f"{len(fallas)} veces un sitio bloqueado abrió.")
        sys.exit(1)


if __name__ == "__main__":
    main()
