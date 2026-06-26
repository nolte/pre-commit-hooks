---
title: Mitwirken
audience:
  - hook-maintainer
  - documentation-author
content_mode: how-to
track: developer-docs
last_updated: 2026-06-26
source_language: en
---

# Mitwirken

Der kanonische Einstiegspunkt zum Hinzufügen eines Hooks, zum Ändern eines
bestehenden oder zum Aktualisieren der gerenderten Doku.
[`CLAUDE.md`](https://github.com/nolte/pre-commit-hooks/blob/main/CLAUDE.md)
hält dieselben Konventionen für KI-gestützte Edits fest. Halte beide
Dokumente synchron, wenn sich der Vertrag ändert.

## Hook-Konventionen

Jeder Hook folgt demselben Vertrag. Halte ihn intakt, wenn du Hooks änderst
oder hinzufügst.

- **Ein Script pro Hook.** Jeder Hook ist ein in sich geschlossenes Script
  unter `hooks/`, benannt nach seiner Hook-ID (`hooks/<id>.sh`). Keine
  Laufzeitabhängigkeiten außer `git` und einer POSIX-nahen Shell;
  `set -euo pipefail` am Anfang.
- **Im Manifest registriert.** Jeder Hook hat eine stabile `id`, einen
  lesbaren `name`, eine `description` und `language: script` in
  `.pre-commit-hooks.yaml`.
- **Fail-open in der Automatisierung.** Hooks brechen mit Exit 0 ab, wenn
  `CI` gesetzt ist, sodass derselbe lokal installierte Hook nie einen
  CI-Lint-Job blockiert.
- **Konfigurierbar über `args:`.** Stelle veränderbare Eingaben über
  pre-commit-`args:` bereit (etwa `--branch <name>`), defensiv geparst mit
  einem sinnvollen Default. Keine portfolio-spezifischen Werte hart
  verdrahten, die ein auf `main` integrierendes Repository nicht
  überschreiben kann.

## Selbsttest-Vertrag

Jeder Hook hat einen passenden Selbsttest unter `tests/test_<id>.sh`. Der
Test baut Wegwerf-git-Repositories unter `tests/.sandbox/`, treibt `HEAD` in
einen bekannten Zustand, führt den Hook aus und prüft seinen Exit-Code —
ohne Netzwerk, ohne globale git-Seiteneffekte.

```bash
task test       # die Hook-Selbsttests ausführen
tests/test_guard-primary-checkout.sh   # eine Suite direkt ausführen
```

Führe die gesamte Suite aus, bevor du einen Hook änderst, und ergänze Fälle
für jedes neue Verhalten oder Argument.

## Lokale Checks

```bash
task            # verfügbare Tasks auflisten
task lint       # jeden pre-commit-Hook ausführen (shellcheck, Hygiene, Guard)
task test       # die Hook-Selbsttests ausführen
task docs       # die mkdocs-Site lokal servieren
```

`task lint` und `task docs` delegieren an die remote eingebundenen
[`nolte/taskfiles`](https://github.com/nolte/taskfiles)-Module und hängen
von den vorbereiteten virtuellen Umgebungen unter `~/.venvs/development` und
`~/.venvs/docs` ab. Fehlt eine venv, scheitert der Task beim ersten Lauf;
die Lösung ist, die venv bereitzustellen, nicht `pip install` einzubetten.

## Doku-Konventionen

- `mkdocs-include-markdown-plugin` zieht den Intro-Block aus der README über
  die Marker `<!--intro-start-->` und `<!--intro-end-->` in die gerenderte
  Startseite. Lass diese Marker an Ort und Stelle.
- Jeder Hook bekommt eine Seite unter `docs/en/references/hooks/` (und die
  passende Übersetzung unter `docs/de/references/hooks/`) mit demselben
  Schema: kurzes Intro, **Voraussetzungen**, **Argumente**, **Verhalten**,
  **Beispiel**, **Fehlerbehebung**.
- Neue Hook-Namen und Fachbegriffe kommen in das lokale Vale-Vokabular unter
  `.github/styles/config/vocabularies/pre-commit-hooks/accept.txt`; sonst
  scheitert der spelling-vale-Workflow bei der ersten Erwähnung im Fließtext.

## Pull-Request-Ablauf

- Verzweige von `develop` in einem dedizierten Worktree — genau das
  parallele Working-Copies-Modell, das der `guard-primary-checkout`-Hook
  erzwingt. Der primäre Checkout bleibt auf `develop`.
- Pull Requests führen die wiederverwendbaren Workflows aus
  [`nolte/gh-plumbing`](https://github.com/nolte/gh-plumbing) an einem
  gepinnten Tag aus (aktuell `v1.1.18`). Hebe alle Workflow-Referenzen
  gemeinsam an, wenn du den Pin aktualisierst.
- Merges sind squash-only und automergen, sobald die Checks grün sind. Von
  Renovate getriebene Dependency-Bumps folgen demselben Pfad.
- Fließtext-Änderungen müssen Vale bestehen (Microsoft + RedHat plus das
  [`nolte/vale-style`](https://github.com/nolte/vale-style)-Paket und das
  lokale `pre-commit-hooks`-Vokabular).
