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
    "youtube.com": ("https://www.youtube.com/", "YouTube"),
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
    """True si la página real cargó."""
    try:
        d.get(f"{url}?prueba={n}")
        time.sleep(1)
        return SITIOS_POR_URL[url] in d.title
    except WebDriverException:
        return False


SITIOS_POR_URL = {url: titulo for url, titulo in SITIOS.values()}


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
                "return {trr: Services.prefs.getIntPref('network.trr.mode'),"
                " politicas: Services.policies.status, activas: Object.keys(Services.policies.getActivePolicies() || {})}"))

    print("Antes de la sesión:")
    for nombre, d in abiertos.items():
        for sitio, (url, _) in SITIOS.items():
            ok = abre(d, url, 0)
            print(f"  {nombre} {sitio}: {'abre' if ok else 'NO ABRE'}")
            if not ok:
                print(f"    título: {d.title!r}")

    subprocess.run(iniciar, shell=True, check=True)
    t0 = time.time()
    print("Sesión iniciada.")

    for s in CHEQUEOS:
        time.sleep(max(0, t0 + s - time.time()))
        for nombre, d in abiertos.items():
            for sitio, (url, _) in SITIOS.items():
                ok = abre(d, url, s)
                filas.append((nombre, "ya abierto", s, sitio, ok))
                print(f"  {s:>3}s {nombre} {sitio}: {'ABRE' if ok else 'bloqueado'}")

    for d in abiertos.values():
        d.quit()

    # Navegadores abiertos después de empezar la sesión.
    for nombre in abiertos:
        d = abrir(nombre)
        for sitio, (url, _) in SITIOS.items():
            ok = abre(d, url, "nuevo")
            filas.append((nombre, "abierto en la sesión", None, sitio, ok))
            print(f"  nuevo {nombre} {sitio}: {'ABRE' if ok else 'bloqueado'}")
        d.quit()

    resumen = ["| Navegador | Caso | Segundos | Sitio | Resultado |", "|---|---|---|---|---|"]
    for nombre, caso, s, sitio, ok in filas:
        resumen.append(f"| {nombre} | {caso} | {s if s is not None else ''} | {sitio} | {'**abre**' if ok else 'bloqueado'} |")
    texto = "\n".join(resumen)
    print(texto)
    if os.environ.get("GITHUB_STEP_SUMMARY"):
        with open(os.environ["GITHUB_STEP_SUMMARY"], "a", encoding="utf-8") as f:
            f.write(f"## {sys.platform}\n\n{texto}\n\n")


if __name__ == "__main__":
    main()
