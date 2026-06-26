---
title: guard-primary-checkout
audience:
  - hook-consumer-project
  - consumer-developer
  - consumer-ci
content_mode: reference
track: developer-docs
last_updated: 2026-06-26
source_language: en
---

# guard-primary-checkout

Blockiert Commits, die direkt im primären Checkout gemacht werden, während
dieser auf einem Feature-Branch sitzt. Feature-Arbeit gehört in einen
dedizierten [git worktree](https://git-scm.com/docs/git-worktree), der vom
Integration-Branch abzweigt.

Siehe [Referenzen → Gemeinsamer Vertrag](../index.md#gemeinsamer-vertrag) für
die Konventionen zu Pinning, Fail-open und primärer-Checkout-versus-Worktree,
die für jeden Hook gelten.

## Voraussetzungen

- [pre-commit](https://pre-commit.com) im `PATH`.
- Ein `git`-Repository. Der Hook ruft ausschließlich `git` auf; er hat keine
  weitere Laufzeitabhängigkeit.

## Argumente

| Argument | Default | Zweck |
|----------|---------|-------|
| `--branch <name>` | `develop` | Der Integration-Branch, auf dem der primäre Checkout bleiben muss. `--branch=main` für Repositories, die auf `main` integrieren. |

Argumente werden über die `args:`-Liste von pre-commit übergeben:

```yaml
hooks:
  - id: guard-primary-checkout
    args: [--branch=main]
```

## Verhalten

- **Greift nur im primären Checkout.** Der Hook vergleicht das
  pro-Worktree-git-dir mit dem geteilten git-common-dir; sie sind nur im
  primären Checkout gleich. In einem linked Worktree unterscheiden sie sich,
  also endet der Hook mit Exit 0 — Feature-Branch-Commits gehören dorthin.
- **Erlaubt den Integration-Branch.** Wenn der primäre Checkout auf dem
  konfigurierten Branch ist (Default `develop`), läuft der Commit durch.
- **Blockiert alles andere.** Auf jedem anderen Branch — oder einem detached
  HEAD — im primären Checkout wird der Commit mit Exit 1 verweigert, samt
  einer Meldung, die zeigt, wie man die Arbeit in einen Worktree verschiebt.
- **Fail-open in CI.** Wenn `CI` gesetzt ist, endet der Hook sofort mit
  Exit 0.
- **Verändert nie den Zustand.** Er verweigert nur den Commit; Branch, Index
  und Arbeitsbaum bleiben unangetastet.

Er ist mit `always_run: true` und `pass_filenames: false` registriert, feuert
also bei jedem Commit, unabhängig davon, welche Dateien gestaged sind.

## Beispiel

```yaml
# .pre-commit-config.yaml im Konsument-Repository
repos:
  - repo: https://github.com/nolte/pre-commit-hooks
    rev: v1.0.0
    hooks:
      - id: guard-primary-checkout
```

Ein Commit, der auf einem Feature-Branch im primären Checkout versucht wird:

```text
✖ Primary checkout is on branch 'feat/x', not 'develop' — commit blocked.

  The primary checkout (…) is for integration only and MUST stay
  on 'develop' at all times. Feature work happens on a feature
  branch in a dedicated worktree that branches off 'develop'.
```

## Fehlerbehebung

- **Der Hook blockiert einen legitimen Commit auf `main`.** Das Repository
  integriert auf `main`, nicht auf `develop`. Konfiguriere es mit
  `args: [--branch=main]`.
- **Der Hook feuert gar nicht.** Bestätige, dass `pre-commit install` im
  Clone gelaufen ist und dass der Commit im primären Checkout passiert. In
  einem linked Worktree ist der Hook absichtlich still.
- **CI-Commits werden unerwartet blockiert.** Werden sie nicht: Der Hook
  endet mit Exit 0, sobald `CI` gesetzt ist. Braucht ein lokaler
  Automatisierungskontext denselben Bypass, setze `CI=1` für diesen Aufruf.
- **Ein Commit muss zur Drift-Reparatur im primären Checkout landen.** Führe
  den git-Befehl aus einem Worktree aus oder lege den Hook vorübergehend
  beiseite; der Hook gibt beim Blockieren die worktree-basierten
  Reparaturschritte aus.

## Verwandt

- Das `worktree`-Modul von
  [`nolte/taskfiles`](https://github.com/nolte/taskfiles) (`task
  worktree:add`) erstellt die dedizierten Worktrees, zu denen dieser Hook
  hinleitet.
