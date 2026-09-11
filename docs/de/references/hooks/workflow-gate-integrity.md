---
title: workflow-gate-integrity
audience:
  - hook-consumer-project
  - consumer-developer
  - consumer-ci
content_mode: reference
track: developer-docs
last_updated: 2026-09-11
source_language: en
---

# workflow-gate-integrity

Weist ein GitHub-Actions-Gate zurück, das keinen Fehlschlag melden kann. Eine
Prüfung, die nicht rot werden kann, ist von einer, die gar nicht läuft, nicht zu
unterscheiden — beide sehen stromabwärts gleich aus: grün.

Siehe [Referenzen → Gemeinsamer Vertrag](../index.md#gemeinsamer-vertrag) für
die Pin- und Konfigurationskonventionen, die für jeden Hook gelten. Zwei davon
gelten hier **nicht**; die Ausnahmen stehen unter [Verhalten](#verhalten).

## Voraussetzungen

- [pre-commit](https://pre-commit.com) im `PATH`.
- `python3` und [PyYAML](https://pypi.org/project/PyYAML/) im `PATH`. Zwei der
  fünf Formen lesen geparstes Workflow-YAML, der Parser ist also nicht optional.
  Fehlt er, beendet sich der Hook mit **2** und scannt nichts, statt teilweise
  zu scannen und ein Grün zu melden, das weniger bedeutet, als es aussieht.
- Ein `git`-Repository. Gelesene Pfade werden gegen dessen **getrackte**
  Dateien aufgelöst.

## Argumente

| Argument | Default | Zweck |
|----------|---------|-------|
| `--scan-root <pfad>` | `.github/workflows` | Das Verzeichnis, das rekursiv nach Workflow-Dateien (`.yml`, `.yaml`) durchsucht wird. |
| `--tree-root <pfad>` | der umgebende Checkout | Der Checkout, dessen getrackte Dateien entscheiden, ob ein referenzierter Pfad existiert. |
| `--list` | aus | Nennt beim Bestehen zusätzlich jede begründete Fundstelle. |
| `--json` | aus | Gibt die Funde als JSON statt als Klartextbericht aus. |

Argumente werden über die `args:`-Liste von pre-commit übergeben:

```yaml
hooks:
  - id: workflow-gate-integrity
    args: [--scan-root=.github/workflows]
```

## Verhalten

Der Hook meldet fünf Formen. Alle sind in Produktion aufgetreten.

1. **Ein verworfener Exit-Code** — `|| true` in einem `run:`-Step. Oft korrekt,
   und genau deshalb braucht es eine Begründung statt eines Verbots.
2. **`continue-on-error: true`** — der Step oder Job kann seine Prüfung nicht
   rot färben. Legitim für einen Reporter, nicht für etwas, das misst.
3. **Ein Job, der `needs.<x>.outputs` liest, ohne `needs.<x>.result` zu
   prüfen**, während sein eigenes `if:` GitHubs Dependency-Gating mit
   `always()`, `cancelled()` oder `failure()` übersteuert. Ein
   fehlgeschlagener Produzent hinterlässt dann jeden Output als leeren String
   und jeden Step übersprungen — und ein Job, dessen Steps alle übersprungen
   werden, *meldet Erfolg*.
4. **Ein Kommentar auf einer Zeile, die über ein abschließendes `\` erreicht
   wird** — das `#` beendet die logische Zeile, das Kommando läuft abgeschnitten.
   Der Step wird rot, was nach Selbstauskunft aussieht, aber die Artefakte, auf
   die spätere Steps gaten, werden nie geschrieben, und jene Steps überspringen
   still hinter ihren eigenen Existenzprüfungen.
5. **Ein Pfad, den der Workflow liest, den sein eigener `paths:`-Filter aber
   ausschließt** — die Änderung, die eine Prüfung am ehesten brechen kann, ist
   dann genau die, die sie nie ausführt.

Zwei Konventionen des gemeinsamen Vertrags gelten hier nicht:

- **Dieser Hook schlägt fail-closed fehl.** Er bricht unter `CI` *nicht* ab. Er
  prüft CI-Konfiguration, und ein Gate, das sich selbst von CI ausnimmt, wäre
  genau die Form, die es zurückweisen soll.
- **Er ist kein Shell-Skript.** Die Formen 3 und 5 brauchen einen YAML-Parser.
  Das Manifest deklariert weiterhin `language: script`, damit pre-commit die
  Datei gegen den Klon dieses Repositories auflöst; das verwaltete
  `language: python`-Backend würde stattdessen verlangen, dieses Repository zu
  einem installierbaren Paket zu machen.

Die Exit-Codes sind bewusst dreiwertig, denn ein Scan, der nicht stattfand, darf
nicht wie ein Scan aussehen, der nichts fand:

| Exit | Bedeutung |
|------|-----------|
| `0` | Jedes verworfene Urteil trägt eine Begründung. |
| `1` | Mindestens eine Fundstelle kann nicht fehlschlagen und hat keine Begründung. |
| `2` | Der Scan lief nicht: fehlender Parser, fehlender Scan-Root, Nutzungsfehler. |

Er ist mit `always_run: true` und `pass_filenames: false` registriert und scannt
das Workflow-Verzeichnis daher bei jedem Commit, unabhängig davon, welche
Dateien gestaged sind. Die Erkennung ist für die Formen 1, 2, 4 und 5 textuell,
ein verworfener Exit-Code als `|| :` oder `; true` entkommt also; Form 3 liest
geparstes YAML, kann aber nicht durch eine Composite Action oder einen
wiederverwendbaren Workflow hindurchsehen. Die Zusage ist nicht Vollständigkeit
— sie ist, dass diese Formen nicht *hinzugefügt* werden können, ohne dass jemand
aufschreibt, warum.

### Die Escape-Hatch

Eine Fundstelle darf bestehen bleiben, wenn sie eine Begründung trägt — auf der
eigenen Zeile oder im Kommentarblock direkt darüber:

```yaml
# gate-integrity-ok: grep -c exits 1 on no match; the count is the result
- run: hits=$(grep -c '^kind:' file || true)
```

Die Begründung ist verpflichtend und muss mindestens 12 Zeichen lang sein, damit
die Markierung nicht als bloßer Stummschalter dient. Für Form 3 steht sie im
Kommentarblock über dem Job-Key. Form 5 akzeptiert eine Markierung irgendwo im
selben Workflow, **sofern die Begründung den Pfad nennt** — eine Referenz kann
in einem Shell- oder JavaScript-String stehen, wo `#` ein Syntaxfehler ist, und
der ehrliche Ort für „diese Referenz weitet den Trigger bewusst nicht aus" ist
neben dem `paths:`-Filter, den sie nicht ausweitet. Dass der Pfad genannt wird,
verhindert, dass diese Platzierung zum dateiweiten Stummschalter wird.

## Beispiel

```yaml
# .pre-commit-config.yaml im konsumierenden Repository
repos:
  - repo: https://github.com/nolte/pre-commit-hooks
    rev: v1.0.0
    hooks:
      - id: workflow-gate-integrity
```

Ein Workflow, dessen eigener Filter die Pin-Datei ausschließt, die er liest:

```text
workflow-gate-integrity: 1 site(s) where a check cannot fail

  .github/workflows/security-nuclei-templates.yml:74: this workflow reads a file its own paths: filter excludes
      reads '.github/renovate-pins.yaml', which no paths: entry of this workflow covers

A check that cannot report a failure is indistinguishable from one that is
not running. Either restore the verdict, or say — where it stands, on the
same line or in the comment block directly above it — why the discarded
outcome is not a verdict:

    # gate-integrity-ok: <why this cannot hide a failure>
```

## Fehlerbehebung

- **Exit 2 mit „PyYAML is not installed".** In den Interpreter installieren, den
  pre-commit verwendet: `python3 -m pip install PyYAML`. Der Hook verweigert den
  Teil-Scan, statt ein Grün zu melden, das drei von fünf Formen abdeckt.
- **Ein Fund auf einem `|| true`, das wirklich korrekt ist.** Das ist der
  erwartete Fall, kein falsch-positiver. Markierung mit einer Begründung von
  mindestens 12 Zeichen setzen; der Punkt ist, dass die Begründung in der Datei
  steht, nicht dass das Muster verboten wäre.
- **Ein Pfad-Fund auf einer Referenz, die den Trigger nicht ausweiten soll.**
  Die Begründung schreiben und den Pfad darin nennen. Die Markierung darf dann
  irgendwo in diesem Workflow stehen, auch neben dem `paths:`-Filter.
- **Der Hook feuert in CI und blockiert einen Lint-Job.** Das ist beabsichtigt;
  dieser Hook schlägt fail-closed fehl. Ist der Fund berechtigt, den Workflow
  reparieren oder die Fundstelle begründen. Einen `CI`-Bypass gibt es nicht.
- **Ein Fund verschwindet auf einer Maschine und auf einer anderen nicht.**
  Gelesene Pfade werden gegen **getrackte** Dateien aufgelöst. Eine ungetrackte
  Datei, die zufällig im Arbeitsbaum liegt, zählt nicht — das hält das Urteil
  auf einer Workstation und auf einem Runner identisch.
- **Funde in einem Workflow-Verzeichnis, das nicht `.github/workflows` ist.**
  Den Hook mit `args: [--scan-root=<pfad>]` darauf richten.

## Verwandtes

- [`spec/hook-authoring`](../governance.md) §0 hält die
  Defect-Class-Guard-Methode fest, die dieser Hook umsetzt, spezifiziert in
  [nolte/claude-shared#573](https://github.com/nolte/claude-shared/issues/573),
  und §9 die Falsifikationsregel, die sein Self-Test erfüllt.
