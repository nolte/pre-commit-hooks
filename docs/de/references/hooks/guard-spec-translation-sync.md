---
title: guard-spec-translation-sync
audience:
  - hook-consumer-project
  - consumer-developer
  - consumer-ci
content_mode: reference
track: developer-docs
last_updated: 2026-06-26
---

# guard-spec-translation-sync

Blockt einen Commit, der eine Sprache eines mehrsprachigen Spezifikations-Topics
staged, eine getrackte Geschwister-Übersetzung aber zurücklässt. Er hält jedes
`spec/<topic>/<lang>.md`-Set im Gleichschritt — eine kanonische Sprache, der Rest
strikte Übersetzungen.

Siehe [Referenzen → Gemeinsamer Vertrag](../index.md#gemeinsamer-vertrag) für die
Pinning-, Fail-open- und Primary-Checkout-versus-Worktree-Konventionen, die für
jeden Hook gelten.

## Voraussetzungen

- [pre-commit](https://pre-commit.com) auf dem `PATH`.
- Ein `git`-Repository, dessen Specs dem Layout `spec/<topic>/<lang>.md` folgen.
  Der Hook ruft nur `git` auf; er hat keine weitere Laufzeitabhängigkeit.

## Argumente

| Argument | Default | Zweck |
|----------|---------|-------|
| `--lang <code>` | `en` `de` | Eine Sprache, die synchron bleiben muss. Das Flag pro Sprache wiederholen (`--lang=en --lang=de --lang=fr`). Ein Topic mit nur einer konfigurierten Sprache wird nie geblockt. |
| `--spec-dir <pfad>` | `spec` | Das Wurzelverzeichnis mit den `<topic>/<lang>.md`-Bäumen. |

Argumente werden über die `args:`-Liste von pre-commit übergeben:

```yaml
hooks:
  - id: guard-spec-translation-sync
    args: [--lang=en, --lang=de, --spec-dir=spec]
```

## Verhalten

- **Inspiziert das Staged-Set, keine Dateiliste.** Mit `pass_filenames: false`
  registriert, liest der Hook die gestagten Pfade selbst via `git diff --cached`.
  Das ist Absicht: pre-commit kann eine Per-Hook-Dateiliste über parallele
  Prozesse aufteilen, was ein `en.md`/`de.md`-Paar trennen und einen Fehlalarm
  auslösen könnte. Das ganze Staged-Set einmal zu lesen vermeidet das.
- **Erzwingt Gleichschritt pro Topic.** Wenn mindestens eine konfigurierte
  `<lang>.md` eines Topics gestaged ist, muss jede konfigurierte Sprache, deren
  Datei in `HEAD` **getrackt** ist, ebenfalls gestaged sein. Eine fehlende,
  getrackte Geschwister-Datei blockt den Commit mit Exit 1 und listet die nicht
  gestagten Dateien.
- **Ignoriert brandneue Topics.** Ein Topic ohne getrackte Geschwister-Datei (zum
  Beispiel eine frisch erstellte `spec/<topic>/en.md` ohne `de.md` in `HEAD`) ist
  erlaubt — das ist ein Vollständigkeits-, kein Synchronitätsthema.
- **Ist in CI fail-open.** Wenn `CI` gesetzt ist, beendet sich der Hook sofort mit
  0; CI führt `pre-commit run --all-files` aus, wo es kein Staged-Set zu bewerten
  gibt.
- **Mutiert nie den Zustand.** Er verweigert nur den Commit; Index und Working
  Tree bleiben unberührt.

## Beispiel

```yaml
# .pre-commit-config.yaml im konsumierenden Repository
repos:
  - repo: https://github.com/nolte/pre-commit-hooks
    rev: v1.0.0
    hooks:
      - id: guard-spec-translation-sync
```

Ein Commit, der nur die kanonische Sprache eines bestehenden Topics staged:

```text
✖ Spec translations out of sync — commit blocked.

  The nolte spec convention keeps every spec/<topic>/<lang>.md in
  lockstep. You staged one language of a topic but left its tracked
  sibling translation(s) unstaged:

    spec/hook-authoring/de.md
```

## Fehlerbehebung

- **Der Hook blockt einen legitimen, bewussten Work-in-Progress.** Den einzelnen
  Commit mit `git commit --no-verify` umgehen und die Übersetzung in einem
  Folge-Commit synchronisieren.
- **Eine neue Sprache soll erzwungen werden.** Sie der `args`-Liste hinzufügen
  (`--lang=fr`). Der Hook verlangt nur Sprachen, von denen er weiß.
- **Specs liegen außerhalb von `spec/`.** Den Hook mit `--spec-dir=<pfad>` auf das
  richtige Wurzelverzeichnis zeigen lassen.
- **CI-Commits werden unerwartet geblockt.** Werden sie nicht: der Hook beendet
  sich mit 0, sobald `CI` gesetzt ist. Um Übersetzungs-Parität in CI zu erzwingen,
  einen eigenen Job statt dieses Commit-Zeit-Guards laufen lassen.

## Verwandt

- [`spec/hook-authoring/`](https://github.com/nolte/pre-commit-hooks/tree/main/spec/hook-authoring)
  — die Referenz-Wissensbasis, gegen die dieser Hook entworfen wurde.
