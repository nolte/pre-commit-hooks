---
title: Governance und Specs
audience:
  - portfolio-conventions
  - renovate-governance
content_mode: explanation
track: developer-docs
last_updated: 2026-06-26
source_language: en
---

# Governance und Specs

Diese Seite ist der Einstiegspunkt für alle, die prüfen müssen, ob das
Repository die Portfolio-Konventionen weiterhin erfüllt. Sie dupliziert die
Upstream-Specs nicht, sondern listet die Einstiegspunkte und den aktuellen
Pin-Stand.

## Portfolio-Konventionen

Das Repository folgt den projektweiten Specs aus
[`nolte/claude-shared`](https://github.com/nolte/claude-shared):

- `project-structure`: Verzeichnislayout, Pflichtdateien, README-Anatomie.
- `branching-model`: Branch-Benennung und -Schutz.
- `parallel-working-copies`: das Modell, das der
  `guard-primary-checkout`-Hook erzwingt — der primäre Checkout bleibt auf
  seinem Integration-Branch, Feature-Arbeit passiert in dedizierten
  Worktrees.
- `pull-request-workflow`: squash-only-Merges, Automerge nach grünen Checks.
- `release-automation`: release-drafter- und release-publish-Ablauf.

Der repository-lokale Ordner
[`spec/`](https://github.com/nolte/pre-commit-hooks/blob/main/spec/README.md)
verweist auf diese Portfolio-Specs, statt sie zu wiederholen.

## Wiederverwendbare Workflows

Jeder Workflow unter `.github/workflows/` delegiert an einen
wiederverwendbaren Workflow in
[`nolte/gh-plumbing`](https://github.com/nolte/gh-plumbing). Der aktuelle Pin
ist **`v1.1.18`**. Hebe alle Workflow-Referenzen gemeinsam an, denn das
Mischen von Tags zwischen Workflows ist eine bekannte Drift-Quelle.

| Workflow | Wiederverwendbares Ziel |
|----------|-------------------------|
| `automerge.yaml` | `reusable-automerge.yaml` |
| `build-static-tests.yaml` | `reusable-pre-commit.yaml`, `reusable-chain-bench.yaml`, `reusable-trivy.yaml` (plus ein repo-lokaler `tests`-Job) |
| `release-cd-deliver-docs.yml` | `reusable-mkdocs.yaml` |
| `release-cd-refresh-master.yml` | `reusable-release-cd-refresh-master.yml` |
| `release-drafter.yml` | `reusable-release-drafter.yml` |
| `release-publish.yml` | `reusable-release-publish.yml` |
| `spelling.yaml` | `reusable-spelling-vale.yaml` |

## Dependency-Governance

Renovate läuft auf diesem Repository über
[`renovate.json5`](https://github.com/nolte/pre-commit-hooks/blob/main/renovate.json5),
das `nolte/gh-plumbing//renovate-configs/common` an einem gepinnten Tag
erweitert. Konkrete Erwartungen:

- Alle Pins nutzen released Tags. Keine beweglichen `@develop`- oder
  `@main`-Referenzen in `uses:`-Zeilen von Workflows.
- Renovate gruppiert Dependency-Bumps in einen einzigen Pull Request.
- Pull Requests landen über den Standard-Automerge-Pfad, sobald die Checks
  grün sind.

## Vale und Fließtext

Vale lintet Fließtext mit den Paketen Microsoft und RedHat plus dem
[`nolte/vale-style`](https://github.com/nolte/vale-style)-Release-Pin aus
`.vale.ini`. Das lokale Vokabular unter
`.github/styles/config/vocabularies/pre-commit-hooks/accept.txt` deckt
hook-spezifische Begriffe ab (`worktree`, `checkout`, `develop`,
`pre-commit`). Ergänze dort neue Hook-Namen und Fachbegriffe, wenn du einen
Hook einführst.

Zwei Microsoft-Regeln bleiben in `.vale.ini` bewusst aus:
`Microsoft.Ranges` und `Microsoft.RangeFormat`. Die Zahlenbereich-Alerts
feuern auf YAML-Frontmatter-Daten wie `last_updated: 2026-06-26` und auf
Versions-Pins wie `mkdocs==1.6.1` oder `v1.1.18`, die im erzählerischen Sinn
keine Bereiche sind.

## Probot-Settings

`.github/settings.yml` liefert die Repository-Einstellungen (Branch-Schutz,
Labels, Automerge-Konfiguration) über die Probot-Settings-App. Behandle sie
als Source of Truth. Manuelle Änderungen in der GitHub-UI driften von der
Spec weg.
