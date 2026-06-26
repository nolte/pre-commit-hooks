---
title: Erste Schritte
audience:
  - hook-consumer-project
  - consumer-developer
content_mode: tutorial
track: developer-docs
last_updated: 2026-06-26
source_language: en
---

# Erste Schritte

Dieses Tutorial führt ein Konsument-Projekt durch das erstmalige Einbinden
des `guard-primary-checkout`-Hooks. Am Ende wird ein `git commit`, der im
primären Checkout auf einem Feature-Branch versucht wird, blockiert — und
derselbe Commit gelingt aus einem Worktree.

## Voraussetzungen

- [pre-commit](https://pre-commit.com) im `PATH`.
- Ein lokal ausgechecktes `git`-Repository mit einer
  `.pre-commit-config.yaml` (eine leere `repos: []`-Datei genügt zum Start).

## 1. Das Repository in die Konsument-Config eintragen

Das Hook-Repository in die `.pre-commit-config.yaml` des Konsumenten
eintragen und einen released Tag pinnen:

```yaml
repos:
  - repo: https://github.com/nolte/pre-commit-hooks
    rev: v1.0.0
    hooks:
      - id: guard-primary-checkout
```

Das `rev`-Feld pinnt auf einen released Tag, sodass das Verhalten über
Maschinen hinweg deterministisch ist. Ersetze `v1.0.0` durch den neuesten
Eintrag der [Releases-Seite](https://github.com/nolte/pre-commit-hooks/releases).

## 2. Den Hook installieren

```bash
pre-commit install
```

Das verdrahtet den Hook in `.git/hooks/pre-commit` des lokalen Clones. Da
der Hook im geteilten Hooks-Verzeichnis installiert wird, feuert er auch in
linked Worktrees — wo er bewusst still bleibt.

## 3. Einen fehlplatzierten Commit blockieren sehen

Mit dem primären Checkout auf einem Feature-Branch wird ein Commit
verweigert:

```bash
git switch -c feat/demo
echo change >> file.txt && git add file.txt
git commit -m "feat: demo"
# ✖ Primary checkout is on branch 'feat/demo', not 'develop' — commit blocked.
```

Der Hook lässt den Branch unangetastet; er verweigert nur den Commit und
zeigt, wie man die Arbeit in einen Worktree verschiebt.

## 4. Stattdessen aus einem Worktree committen

Einen dedizierten Worktree für den Feature-Branch anlegen und dort
committen. Das `worktree`-Modul von
[`nolte/taskfiles`](https://github.com/nolte/taskfiles) macht das zu einem
Befehl:

```bash
task worktree:add -- feat/demo
cd "$(task worktree:root)/<repo>/demo"
git commit -m "feat: demo"   # gelingt — das ist ein linked Worktree
```

## 5. Den Integration-Branch konfigurieren (optional)

Der Hook nutzt standardmäßig `develop`. Ein Repository, das auf `main`
integriert, konfiguriert das über `args`:

```yaml
repos:
  - repo: https://github.com/nolte/pre-commit-hooks
    rev: v1.0.0
    hooks:
      - id: guard-primary-checkout
        args: [--branch=main]
```

## Was als Nächstes lesen

- [Referenzen → Hooks](../references/index.md) dokumentiert jeden Hook,
  seine Argumente und sein genaues Verhalten.
- [Anleitungen → Mitwirken](../guides/contributing.md) behandelt das
  Hinzufügen eines neuen Hooks oder das Ändern eines bestehenden.

## Quellen

- [`README.md`](https://github.com/nolte/pre-commit-hooks/blob/main/README.md)
  (Usage-Abschnitt)
- `hooks/guard-primary-checkout.sh`
