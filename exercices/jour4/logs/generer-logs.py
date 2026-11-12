#!/usr/bin/env python3
"""Génère api.log, le jeu de données de l'exercice 4.5 (formateur uniquement).

Une ligne JSON par évènement, au format du logger de l'API TaskFlow
(api/src/logger.js) : {"time","level","method","path","status","ms"}.
Scénario : 2 h de trafic normal, puis 12 minutes où la base sature
(latence en hausse, 500 et 503), plus un robot qui teste des URL connues.
Graine fixe : le fichier est identique à chaque génération.

    python3 generer-logs.py > api.log
"""
import json
import random
from datetime import datetime, timedelta, timezone

random.seed(42)
START = datetime(2026, 10, 22, 8, 0, 0, tzinfo=timezone.utc)
INCIDENT = (START + timedelta(minutes=72), START + timedelta(minutes=84))
BOT = (START + timedelta(minutes=31), START + timedelta(minutes=33))
BOT_PATHS = ["/.env", "/wp-login.php", "/phpmyadmin/", "/.git/config", "/admin", "/api/v1/users", "/server-status"]
lines = []


def emit(t, **fields):
    entry = {"time": t.strftime("%Y-%m-%dT%H:%M:%S.") + f"{t.microsecond // 1000:03d}Z"}
    entry.update(fields)
    lines.append((t, json.dumps(entry, ensure_ascii=False, separators=(",", ":"))))


def request(t, method, path, status, ms):
    emit(t, level="info", method=method, path=path, status=status, ms=round(ms, 1))


in_incident = lambda t: INCIDENT[0] <= t < INCIDENT[1]
next_id = 120

# Sonde /health toutes les 15 s (blackbox)
t = START
while t < START + timedelta(minutes=120):
    if in_incident(t) and random.random() < 0.6:
        request(t, "GET", "/health", 503, random.uniform(2000, 5000))
    else:
        request(t, "GET", "/health", 200, random.uniform(1.5, 4))
    t += timedelta(seconds=15)

# Trafic utilisateur
t = START
while t < START + timedelta(minutes=120):
    t += timedelta(seconds=random.expovariate(1 / 6.5))
    slow = in_incident(t)
    r = random.random()
    if r < 0.55:
        method, path, ok, base = "GET", "/api/tasks", 200, (4, 18)
    elif r < 0.75:
        method, path, ok, base = "POST", "/api/tasks", 201, (8, 25)
    elif r < 0.92:
        method, path, ok, base = "PATCH", f"/api/tasks/{random.randint(1, next_id)}/toggle", 200, (6, 20)
    else:
        method, path, ok, base = "DELETE", f"/api/tasks/{random.randint(1, next_id)}", 204, (6, 20)
    if method == "POST":
        next_id += 1
    status = ok
    ms = random.uniform(*base)
    if random.random() < 0.01:  # rares appels mal formés
        status, ms = 400, random.uniform(1, 3)
    if method in ("PATCH", "DELETE") and random.random() < 0.04:
        status = 404
    if slow:
        ms = random.uniform(400, 4800)
        if random.random() < 0.45:
            status = 500
            emit(t, level="error", message="timeout exceeded when trying to connect")
    request(t, method, path, status, ms)

# Robot qui teste des URL classiques
t = BOT[0]
while t < BOT[1]:
    request(t, "GET", random.choice(BOT_PATHS), 404, random.uniform(0.5, 2))
    t += timedelta(seconds=random.uniform(0.2, 1.5))

# Démarrage de l'API
emit(START - timedelta(seconds=5), level="info", message="API démarrée sur le port 3000", env="production", version="4e7a1c2")

for _, line in sorted(lines, key=lambda x: x[0]):
    print(line)
