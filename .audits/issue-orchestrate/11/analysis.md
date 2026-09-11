---
artifact-type: issue-orchestration-analysis
repo: "nolte/pre-commit-hooks"
issue: "11"
classification: "feature-request"
secondary-classes: ["spec-change"]
route: "direct"
status: draft
created: "2026-09-11"
---

# Issue Orchestration — Pre-analysis

## Issue metadata

- **Repository**: nolte/pre-commit-hooks
- **Issue**: #11 — adopt the defect-class guard method: generalize kamerplanter's workflow-gate-integrity hook
- **URL**: https://github.com/nolte/pre-commit-hooks/issues/11
- **Labels**: enhancement, cicd
- **Autor**: nolte (Repo-Owner, trusted-author set). Keine Kommentare. Keine
  eingebetteten Instruktionen aus untrusted Quellen.
- **Linked items**: hängt an nolte/claude-shared#573 (OPEN). Keine schließenden PRs.
- **Prior art checked**: `project/features/` und `project/roadmap.md` existieren in
  diesem Repo nicht (established: `ls` im Repo-Root). Einziger offener PR ist #10
  (Renovate, `renovate/all`), berührt das Thema nicht (established:
  `gh pr list --state open`).

## Classification

- **Primary class**: feature-request
- **Secondary class(es)**: spec-change
- **Rationale**: Das Issue fordert eine neue, bisher nicht vorhandene Fähigkeit
  dieses Repos (einen dritten Hook); die Spec-Berührung ist eine Folge davon,
  nicht ihr Zweck.

## Scope

- **In scope**: Portierung des `workflow-gate-integrity`-Checkers aus kamerplanter
  in ein repo-unabhängiges, konfigurierbares Hook dieses Repos, mit
  Manifest-Eintrag, Falsifikations-Self-Test, zweisprachiger Referenz-Doku und der
  von Akzeptanzkriterium 3 verlangten Spec-Referenz auf claude-shared#573. Dazu
  die Präzisierung zweier Repo-Konventionen, die der Hook sonst verletzen müsste.
- **Out of scope**:
  - Die Spec `spec/project/defect-class-guards/` selbst. Sie gehört zu
    claude-shared#573 und wird dort geschrieben, nicht hier.
  - Der zweite, schwächere Kandidat (generische Form von `layer-imports`). Das
    Issue verschiebt ihn ausdrücklich: „Assess it after the first lands, or not at
    all."
  - Aufnahme des Hooks in die `.pre-commit-config.yaml` konsumierender Repos. Das
    ist ein Vorgang in jenen Repos.

## Route

- **Decision**: direct
- **Rationale**: Ein kohärentes Ergebnis (ein Hook wird adoptiert), ein
  PR-Strang, kein neuer oder umgelenkter Roadmap-Eintrag. Dieses Repo führt keine
  Roadmap-Artefakte.

## Requirements gate

Kein Artefakt unter `project/requirements/` (established: Verzeichnis existiert
nicht). **Operator-Override erteilt** am 2026-09-11: das Issue nennt Ziel,
Adoptionsbedingung, Abbruchklausel und einen prüfbaren Falsifikationstest, damit
liegt das Verständnis über der Schwelle, die `requirements-elicit` schließen
soll. `requirements-elicit` wurde bewusst nicht vorgeschaltet.

## Vorbedingungs-Abweichungen

1. `spec/project/issue-orchestration/` liegt nicht in diesem Projekt, sondern in
   `nolte/claude-shared` (established: `ls` an beiden Orten). Die Spec ist lesbar
   und kein Portfolio-Mitglied vendort sie. Als erfüllt behandelt, Abweichung hier
   protokolliert.
2. `task worktree:add` existiert im `Taskfile.yml` dieses Repos nicht (established:
   `grep worktree Taskfile.yml`, leer). Der Worktree wurde spec-konform von Hand
   angelegt: `git worktree add -b feat/workflow-gate-integrity-hook
   ~/repos/.worktrees/pre-commit-hooks/gate-integrity origin/develop`.

## Adoptionsbedingung des Issues — Befund

Das Issue macht die Adoption davon abhängig, dass der Hook ohne kamerplanters
Pfadannahmen konfigurierbar ist, und verlangt sonst den Abbruch.

**Befund: die Bedingung ist erfüllt.** Established: `grep -niE
"kamerplanter|src/backend|src/frontend|scripts/ci/"` über
`kamerplanter/scripts/check_workflow_gate_integrity.py` trifft ausschließlich
Docstring- und Kommentarzeilen (77–79, 467, 474, 544–547, 697, 787–788), keine
Auswertungslogik. Die einzige strukturelle Kopplung ist `REPO_ROOT =
Path(__file__).resolve().parents[1]` in Zeile 145, die ein `scripts/`-Layout
annimmt. Der Scan-Root ist bereits eine Konstante (`DEFAULT_SCAN_ROOT =
".github/workflows"`, Zeile 148) und damit trivial in ein `args:`-Flag zu heben.

## Zwei aufgelöste Konventionskonflikte

Beide vom Operator am 2026-09-11 entschieden:

1. **Sprache.** `CLAUDE.md` fordert „No runtime dependencies beyond `git` and a
   POSIX-ish shell". Die Formen 3 und 5 des Checkers lesen geparstes YAML
   (established: `yaml.safe_load`, Zeile 918). `spec/hook-authoring/en.md` §4
   erlaubt `language: python` ausdrücklich, wenn die Prüfung die Laufzeit braucht.
   **Entscheidung: Python mit `additional_dependencies: [pyyaml]`**, und
   `CLAUDE.md` wird präzisiert (Shell als Default, nicht als Absolutregel).
2. **Fail-Verhalten unter CI.** `CLAUDE.md` fordert Kurzschluss auf Exit 0 bei
   gesetztem `CI`. Für ein Hook, das CI-Gates prüft, hebelt das den Zweck aus.
   `spec/hook-authoring/en.md` §6 unterscheidet bereits lokale Workflow-Guards von
   Korrektheitsprüfungen, die überall greifen sollen. **Entscheidung:
   fail-closed**, und `CLAUDE.md` wird auf Workflow-Guards eingegrenzt.

## Work packages

### P1 — Checker portieren und generalisieren

- **Problem statement**: Der Checker existiert nur in kamerplanter, an ein
  `scripts/`-Layout gebunden, mit einem fest verdrahteten Scan-Root und
  repo-spezifischer Prosa im Docstring. Er muss ein Hook dieses Repos werden, das
  in jedem Repository mit GitHub Actions ohne Zusatzkonfiguration läuft.
- **Acceptance criteria**:
  - `hooks/workflow-gate-integrity.py` existiert; `python3
    hooks/workflow-gate-integrity.py` aus einem beliebigen Repo-Root heraus
    beendet sich mit 0 (sauber), 1 (Defekte gefunden) oder 2 (Nutzungsfehler).
  - Der Scan-Root ist über `args: [--scan-root=...]` übersteuerbar, Default
    `.github/workflows`; kein kamerplanter-Pfad verbleibt in der Logik.
  - Die Repo-Wurzel wird aus git abgeleitet, nicht aus der Skript-Position.
  - Der Hook läuft unter gesetztem `CI` durch (fail-closed), gegenteilig zur
    bisherigen Repo-Regel.
  - `.pre-commit-hooks.yaml` trägt den Eintrag mit `id`, `name`, `description`,
    `language: python`, `additional_dependencies: [pyyaml]`,
    `always_run: true`, `pass_filenames: false`, `stages: [pre-commit]`.
  - `pre-commit validate-manifest` ist grün.
  - Alle fünf Defekt-Formen sind portiert, inklusive der
    Justification-Escape-Hatch `# gate-integrity-ok:` mit Mindestbegründung.
- **Touched files / artifacts**: `hooks/workflow-gate-integrity.py`,
  `.pre-commit-hooks.yaml`
- **Specialist**: `develop-pre-commit-hook` (projektlokales Skill,
  `.claude/skills/develop-pre-commit-hook/`) — direkter Zuständigkeitstreffer:
  „produces a hook that conforms to this repo's contract: a self-contained hook, a
  manifest entry, a self-test, docs, and the supporting wiring".
- **Depends on**: P5

### P2 — Falsifikations-Self-Test

- **Problem statement**: Akzeptanzkriterium 2 verlangt ausdrücklich, dass der Hook
  gegen die Vor-Fix-Zustände zweier realer kamerplanter-Defekte rot meldet. Ein
  Hook, der in seinem Ursprungs-Repo grün ist und hier nie rot war, gilt laut
  Issue als installiert, nicht als verifiziert.
- **Acceptance criteria**:
  - `tests/test_workflow-gate-integrity.sh` existiert, ist ausführbar und in
    `Taskfile.yml` unter `test` eingehängt.
  - Fixture A ist der Vor-Fix-Zustand von kamerplanter#1235, extrahiert aus
    `e0ac3980c^`; der Hook meldet darauf Exit 1.
  - Fixture B ist der Vor-Fix-Zustand von kamerplanter#1302, extrahiert aus
    `421de1d2d^`; der Hook meldet darauf Exit 1.
  - Beide Nach-Fix-Zustände melden Exit 0, sonst prüft der Test nur „meldet
    immer rot".
  - Der Test prüft zusätzlich die Escape-Hatch (mit Begründung grün, ohne
    Begründung rot) und den `--scan-root`-Override.
- **Touched files / artifacts**: `tests/test_workflow-gate-integrity.sh`,
  `tests/fixtures/workflow-gate-integrity/`, `Taskfile.yml`
- **Specialist**: `develop-pre-commit-hook`
- **Depends on**: P1

### P3 — Spec-Referenz auf claude-shared#573

- **Problem statement**: Akzeptanzkriterium 3 verlangt, dass
  `spec/hook-authoring` nolte/claude-shared#573 als die Methode benennt, die der
  Hook umsetzt. Die Spec kennt die Defect-Class-Guard-Methode bisher nicht.
- **Acceptance criteria**:
  - `spec/hook-authoring/en.md` benennt claude-shared#573 als Methodenquelle und
    ordnet den neuen Hook ihr zu.
  - `spec/hook-authoring/de.md` trägt dieselbe Aussage als Übersetzung; beide
    Dateien sind im selben Commit gestaged, sonst schlägt der repo-eigene
    `guard-spec-translation-sync` fehl.
  - Der Verweis nennt die Issue-Nummer, nicht nur die Prosa, damit Befund und
    Regel auffindbar bleiben.
- **Touched files / artifacts**: `spec/hook-authoring/en.md`,
  `spec/hook-authoring/de.md`
- **Specialist**: `nolte-shared:spec` (Skill) — zuständig für mehrsprachige Specs
  unter `spec/` inklusive Übersetzungs-Synchronität.
- **Depends on**: none

### P4 — Referenz-Dokumentation

- **Problem statement**: Jeder bestehende Hook hat eine zweisprachige
  Referenzseite und einen README-Eintrag. Ohne sie ist der neue Hook für
  konsumierende Repos nicht auffindbar.
- **Acceptance criteria**:
  - `docs/en/references/hooks/workflow-gate-integrity.md` und die deutsche
    Entsprechung existieren und folgen der Struktur der beiden bestehenden Seiten.
  - Beide Seiten dokumentieren die fünf Defekt-Formen, die Escape-Hatch und
    `--scan-root`.
  - `README.md` listet den Hook unter `## Hooks` und dokumentiert ihn unter
    `### Configuration` und `### Behaviour`, inklusive der abweichenden
    fail-closed-Semantik.
  - `mkdocs build --strict` ist grün.
- **Touched files / artifacts**: `docs/en/references/hooks/…`,
  `docs/de/references/hooks/…`, `README.md`, ggf. `mkdocs.yml`
- **Specialist**: `nolte-shared:audience-doc-author` (Agent) — arbeitet gegen das
  vorhandene `AUDIENCES.md`-Artefakt dieses Repos.
- **Depends on**: P1

### P5 — Konventionen in CLAUDE.md präzisieren

- **Problem statement**: Zwei Regeln in `CLAUDE.md` sind als Absolutregeln
  formuliert, meinen aber Defaults: Shell-only und fail-open unter `CI`. So wie
  sie stehen, verbieten sie den Hook, den dieses Issue fordert.
- **Acceptance criteria**:
  - Die Sprachregel benennt Shell als Default und verweist für begründete
    Ausnahmen auf `spec/hook-authoring/` §4.
  - Die fail-open-Regel ist auf Workflow-Guards eingegrenzt; Korrektheits- und
    Sicherheitsprüfungen sind ausdrücklich fail-closed, konsistent mit
    `spec/hook-authoring/` §6.
  - Keine bestehende Aussage über die beiden vorhandenen Hooks wird ungültig.
- **Touched files / artifacts**: `CLAUDE.md`
- **Specialist**: no matching specialised agent — generalist remediation.
  `claude-plugin-developer` gilt dem Plugin-Monorepo, nicht der `CLAUDE.md` eines
  Konsumenten; `lektorat-apply` schließt LLM-Instruktions-Artefakte ausdrücklich
  aus. Erste protokollierte Nicht-Übereinstimmung dieser Klasse (Schwelle für
  Gap-Closure ist drei).
- **Depends on**: none

## Dependency ordering

P5 → P1 → P2 ; P1 → P4 ; P3 (unabhängig)

## Risks

- **Der Falsifikations-Test wird zur Attrappe.** Wenn die Fixtures von Hand
  nachgebaut statt aus den echten Vor-Fix-Commits gezogen werden, prüft der Test
  die eigene Erwartung. Mitigation: Fixtures per `git show <sha>^:<pfad>` aus dem
  lokalen kamerplanter-Klon extrahieren, Herkunfts-SHA im Fixture-Header
  vermerken.
- **Die Abhängigkeit claude-shared#573 ist offen.** Die Methoden-Spec existiert
  noch nicht. Mitigation: P3 verweist auf die Issue-Nummer, nicht auf einen
  Spec-Pfad, der noch nicht existiert. Established: `gh issue view 573 --repo
  nolte/claude-shared` meldet `"state":"OPEN"`.
- **PyYAML als neue Abhängigkeit dieses Hook-Repos.** Erste Laufzeit-Abhängigkeit
  überhaupt. Mitigation: über `additional_dependencies` in pre-commits eigener
  verwalteter venv isoliert; kein Einfluss auf die beiden Shell-Hooks.
- **Best-effort-Erkennung.** Die Formen 1, 2, 4 und 5 sind textuell; `|| :` oder
  `; true` entkommen. Das ist im Ursprung bewusst so. Mitigation: die Grenze in
  der Referenz-Doku (P4) benennen, statt Vollständigkeit zu suggerieren.
- **Sicherheitsrelevanz**: keine. Der Hook liest Workflow-Dateien und schreibt
  nichts. Kein Pfad in diesem Change berührt Authentifizierung, Secrets oder
  Netzwerkzugriff, daher kein `code-security-reviewer`-Lauf vor dem PR.

## Open questions

- **Hook-Benennung.** Regel 5 aus claude-shared#573 fordert die Issue-Nummer im
  Namen des Guards. Für einen portfolio-weiten Hook ist keine Nummer sinnvoll,
  weil er keinen Defekt dieses Repos schließt. Vorschlag: der generische Name
  `workflow-gate-integrity` bleibt, die Herkunftsnummern (kamerplanter#1313 und
  die vier Quelldefekte) stehen im Docstring. **Unestablished** bis
  claude-shared#573 geschrieben ist; die Beobachtung, die das klären würde, ist
  der Wortlaut von Regel 5 in der fertigen Spec.

## Dispatch log

2026-09-11 P5 generalist — done. `CLAUDE.md`: Shell als Default statt Absolutregel,
fail-open auf Workflow-Guards eingegrenzt, Self-Test-Regel um „Shell unabhängig vom
Backend des Hooks" ergänzt.

2026-09-11 P1 `develop-pre-commit-hook` — **teilweise Refutation der Hypothese, plus
ein architektonischer Befund.**

- *Refutiert:* Der Auftrag nannte „`--scan-root` ergänzen". Das Flag existiert
  bereits, ebenso `--tree-root`, `--list` und `--json` (established:
  `scripts/check_workflow_gate_integrity.py:1067–1089`). Der Scan-Root war nie
  hartkodiert. Die einzige echte Portabilitätsänderung ist `REPO_ROOT`, jetzt aus
  `git rev-parse --show-toplevel` abgeleitet mit cwd-Fallback.
- *Neuer Befund, nicht im Auftrag:* `language: python` verlangt, dass das
  Hook-Repository ein **installierbares Python-Paket** ist. pre-commit legt eine
  isolierte venv an und löst `entry:` gegen deren Console-Scripts auf.
  Established: `pre-commit try-repo` bricht ab mit „Directory '.' is not
  installable. Neither 'setup.py' nor 'pyproject.toml' found." `spec/hook-authoring/`
  §8 beschreibt genau dieses Rezept. `additional_dependencies` allein genügt nicht.
- *Umgesetzt:* `pyproject.toml` mit Console-Script `workflow-gate-integrity`,
  `package-dir = {"" = "hooks"}`, Modul `hooks/workflow_gate_integrity.py`
  (Unterstriche, weil ein Bindestrich nicht importierbar ist).
- *Verifiziert durch den echten Installationspfad:* `pre-commit try-repo` in einem
  fremden Wegwerf-Repo ohne jede Konfiguration — grün auf sauberem Stand, rot auf
  einem injizierten `|| true`, mit repo-relativem Pfad im Report. Damit ist
  Akzeptanzkriterium 1 des Issues belegt. Shapes 1 und 2 sowie die Escape-Hatch
  (mit Begründung grün, ohne rot) einzeln geprüft. Shapes 3, 4, 5 bleiben P2.
- *Bereinigt:* kamerplanter-Prosa aus der Nutzerausgabe (`NFR-018 §2`,
  `check_workflow_gate_integrity:`), Herkunftsnummern in internen Kommentaren als
  `kamerplanter#NNNN` qualifiziert, repo-spezifische Pfadbeispiele generisch.
- *Regression:* beide bestehenden Self-Tests grün, `validate-manifest` grün.
- **Offen für den Operator:** `CLAUDE.md:9` und `AUDIENCES.md:13` behaupten „there
  is no build artifact". Mit `pyproject.toml` stimmt das nicht mehr wörtlich.

2026-09-11 P1 Nachtrag — Operator wechselte auf den unmanaged Pfad. Umgesetzt als
`language: script`, **nicht** `language: system`: letzteres löst den relativen
Skriptpfad nicht auf. Established: `pre-commit try-repo` mit `language: system`
bricht ab mit „Executable `hooks/workflow-gate-integrity.py` not found"; mit
`language: script` läuft derselbe Hook im fremden Repo durch. `pyproject.toml`
wieder entfernt, Datei zurück auf den Bindestrich-Namen der Hook-ID. Fehlendes
PyYAML meldet jetzt Exit 2 mit Remediation statt eines rohen Tracebacks, damit
„Scan lief nicht" von „Scan war sauber" (0) und „Defekt gefunden" (1) unterscheidbar
bleibt.

2026-09-11 P2 **BEFUND: Akzeptanzkriterium 2 ist zur Hälfte nicht einlösbar.**

Das Issue verlangt, den Vor-Fix-Zustand von kamerplanter#1235 **und** #1302
wiederherzustellen und beide Male Rot zu sehen.

- **#1302 — echt detektiert, belegt.** Vor-Fix `421de1d2d^`:
  `security-nuclei-templates.yml:74`, Kind `uncovered_path_reference`, Detail
  „reads '.github/renovate-pins.yaml', which no paths: entry of this workflow
  covers". Das ist wörtlich der Defekt, den das Issue beschreibt. Nach-Fix
  `421de1d2d`: 0 Funde in derselben Datei. Sauberes Rot-Grün-Paar.
- **#1235 — strukturell unsichtbar für diesen Hook.** Vor-Fix `e0ac3980c^`:
  **0 Funde** in `chart-image-digest-freshness.yml`. Der Defekt lag in
  `scripts/ci/check_digest_freshness.py`, also in Python-Logik außerhalb von
  `.github/workflows`, dem einzigen Scan-Bereich des Hooks. Keine der fünf Formen
  hat ein Prädikat für „Karenzfenster am falschen Anker". Established:
  `--scan-root … --tree-root …  --json`, gefiltert auf die Datei.
- **Die Falle, die das fast verdeckt hätte.** Der Gesamtlauf über den
  #1235-Vor-Fix-Zustand ist **rot** (10 unjustified). Ein Test, der nur auf Exit 1
  prüft, wäre grün geworden — aber wegen sieben unabhängiger Altfunde in
  `docker-publish.yml`, nicht wegen #1235. Genau die Verwechslung, die das Issue
  „installiert, nicht verifiziert" nennt, eine Ebene tiefer. Deshalb werden die
  Assertions auf Datei **und** Kind gekeyt, nie auf den Exit-Code allein.
