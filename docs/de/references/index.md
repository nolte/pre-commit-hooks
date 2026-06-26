---
title: Referenzen
audience:
  - hook-consumer-project
  - consumer-developer
  - consumer-ci
content_mode: reference
track: developer-docs
last_updated: 2026-06-26
source_language: en
---

# Referenzen

Informationsorientierte Dokumentation. Nutze diesen Abschnitt, um den
Vertrag jedes Hooks und die Portfolio-Konventionen des Repositories
nachzuschlagen.

## Hook-Referenzen

Eine Seite pro Hook unter `hooks/`. Jede Seite folgt demselben Schema
(kurzes Intro, **Voraussetzungen**, **Argumente**, **Verhalten**,
**Beispiel**, **Fehlerbehebung**).

- [guard-primary-checkout](hooks/guard-primary-checkout.md): blockiert
  Commits im primären Checkout, während dieser auf einem Feature-Branch
  sitzt.

## Gemeinsamer Vertrag

Diese Regeln gelten für jeden Hook der Sammlung. Die Hook-Seiten wiederholen
sie nicht, sondern verweisen auf diesen Abschnitt.

### Remote eingebunden, per Tag gepinnt

Hooks werden über den Standard-`repos:`-Mechanismus von pre-commit
eingebunden. Das `rev`-Feld ist der einzige Pin-Punkt:

```yaml
repos:
  - repo: https://github.com/nolte/pre-commit-hooks
    rev: v1.0.0
    hooks:
      - id: guard-primary-checkout
```

Pinne auf einen released Tag für deterministisches Verhalten. Renovate hebt
das `rev` in der Config des Konsumenten wie jede andere Abhängigkeit an.

### Fail-open in der Automatisierung

Jeder Hook bricht mit *erlauben* ab, wenn die Umgebungsvariable `CI` gesetzt
ist. CI checkt den Branch als detached HEAD in einem einfachen Clone aus,
was von einem primären Checkout auf einem Feature-Branch nicht zu
unterscheiden ist; die Hooks zielen auf den lokalen Commit einer
Entwicklerin, nicht auf den CI-Lint-Job.

### Primärer Checkout versus linked Worktree

Hooks, die das parallele Working-Copies-Modell erzwingen, greifen nur im
primären Checkout — erkennbar daran, dass das pro-Worktree-git-dir gleich
dem geteilten git-common-dir ist. In einem linked Worktree ist
Feature-Branch-Arbeit korrekt, also bleiben die Hooks still.

### Konfiguration über `args:`

Veränderbare Eingaben werden über pre-commit-`args:` mit einem sinnvollen
Default bereitgestellt. Jede Hook-Seite listet ihre Argumente in der
**Argumente**-Tabelle.

## Repository-Governance

- [Governance und Specs](governance.md): Portfolio-Konventionen,
  wiederverwendbare Workflows, Dependency-Governance, Vale-Stack,
  Probot-Settings.

## Quellen

- `.pre-commit-hooks.yaml` (kanonisches Hook-Manifest)
- `hooks/<id>.sh` (kanonische Hook-Scripts)
- [`CLAUDE.md`](https://github.com/nolte/pre-commit-hooks/blob/main/CLAUDE.md)
