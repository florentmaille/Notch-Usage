#!/usr/bin/env python3
"""Budgets du principe II de la constitution, à vérifier avant chaque release.

  scripts/measure-budgets.py            # 10 minutes sur l'app en cours
  scripts/measure-budgets.py 3          # fenêtre plus courte, pour un essai

Mesure équivalente à Instruments : temps CPU cumulé de `ps` et empreinte de `footprint`, relevés chaque minute sur
l'app NotchUsage déjà lancée (de préférence une build Release). Budgets : CPU moyen < 1 %, empreinte < 60 Mo.
Code de sortie 1 si un budget est dépassé, 2 si la mesure n'a pas pu se faire.

Laisser l'écran allumé et la session ouverte : écran éteint ou verrouillé, l'app suspend ses relevés et la mesure
ne dit plus rien de l'usage normal. Le script compte les relevés de la fenêtre pour le signaler.
"""
import re
import subprocess
import sys
import time

CPU_BUDGET, FOOTPRINT_BUDGET_MB = 1.0, 60.0
WARMUP, STEP = 60, 60


def run(*command):
    return subprocess.run(command, capture_output=True, text=True).stdout


def pid():
    found = run("pgrep", "-x", "NotchUsage").split()
    return found[0] if found else None


def cpu_seconds(p):
    out = run("ps", "-o", "time=", "-p", p).strip()
    if not out:
        return None
    parts = [float(x) for x in out.split(":")]
    return sum(value * 60 ** i for i, value in enumerate(reversed(parts)))


def footprint_mb(p):
    match = re.search(r"Footprint:\s*([\d.]+)\s*(KB|MB|GB)", run("/usr/bin/footprint", p))
    if not match:
        return None
    value, unit = float(match.group(1)), match.group(2)
    return value / 1024 if unit == "KB" else value * 1024 if unit == "GB" else value


def readings_since(start):
    stamp = time.strftime("%Y-%m-%d %H:%M:%S", time.localtime(start))
    out = run("/usr/bin/log", "show", "--start", stamp, "--style", "compact", "--predicate",
              'subsystem == "com.notchusage" AND eventMessage CONTAINS "reading ok"')
    return sum(1 for line in out.splitlines() if "reading ok" in line)


def main():
    minutes = int(sys.argv[1]) if len(sys.argv) > 1 else 10
    p = pid()
    if not p:
        print("NotchUsage ne tourne pas : lancer l'app (build Release), puis relancer la mesure.")
        return 2
    print(f"pid {p} ; échauffement de {WARMUP} s, puis {minutes} min de mesure", flush=True)
    time.sleep(WARMUP)
    start_cpu, start = cpu_seconds(p), time.time()
    footprints = []
    for minute in range(1, minutes + 1):
        time.sleep(STEP)
        if pid() != p:
            print("l'app a été quittée ou relancée pendant la mesure : à refaire")
            return 2
        cpu, footprint = cpu_seconds(p), footprint_mb(p)
        footprints.append(footprint)
        print(f"minute {minute:2d} : CPU cumulé {cpu - start_cpu:5.2f} s, empreinte {footprint:.1f} Mo", flush=True)
    elapsed = time.time() - start
    used = cpu_seconds(p) - start_cpu
    percent, peak = used / elapsed * 100, max(footprints)
    readings = readings_since(start)
    print(f"CPU moyen : {percent:.2f} % ({used:.2f} s sur {elapsed:.0f} s) ; budget < {CPU_BUDGET:.0f} %")
    print(f"empreinte : {min(footprints):.1f} à {peak:.1f} Mo ; budget < {FOOTPRINT_BUDGET_MB:.0f} Mo")
    print(f"relevés pendant la fenêtre : {readings}")
    if readings * 5 < minutes:
        print("  peu ou pas de relevés : écran éteint, session verrouillée ou économie d'énergie ? La mesure couvre alors l'app en pause.")
    ok = percent < CPU_BUDGET and peak < FOOTPRINT_BUDGET_MB
    print("budgets tenus" if ok else "BUDGET DÉPASSÉ")
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
