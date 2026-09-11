# Spec: Zielgerichtete pre-commit-Hooks entwickeln

> Kanonische Sprache: **Englisch**. Diese deutsche Datei (`de.md`) ist eine
> Übersetzung, die strikt synchron gehalten wird; zuerst `en.md` ändern, dann
> übertragen.

## Zweck

Domänenwissen für das Entwerfen, Bauen, Verteilen und Absichern wiederverwendbarer
[pre-commit](https://pre-commit.com)-Hooks. Diese Spec ist die
**Referenz-Wissensbasis**, die ein Skill konsultiert, wenn er einen *zielgerichteten*
Hook entwickeln muss — einen, der auf genau eine klar abgegrenzte Prüfung
zugeschnitten ist, nicht auf ein Sammelsurium-Skript. Sie ist beschreibendes
Referenzmaterial, kein Schritt-für-Schritt-Workflow.

Jede normative Aussage hier wurde gegen die offizielle pre-commit-Dokumentation,
die Manifeste von `pre-commit/pre-commit` und `pre-commit/pre-commit-hooks`, die
`identify`-Bibliothek und die git-`githooks`-Referenz verifiziert. Siehe
[Quellen](#quellen). Wo eine Aussage umstritten oder versionsabhängig ist, ist sie
inline gekennzeichnet.

## 0. Warum ein Hook überhaupt existiert — die Defect-Class-Guard-Methode

Ein Hook in diesem Repository ist keine Stilfrage. Er ist der mechanische
Rückstand einer Defektklasse, die einmal geschlossen wurde und nicht
zurückkommen darf. Die Methode ist in
**[nolte/claude-shared#573](https://github.com/nolte/claude-shared/issues/573)**
spezifiziert, *„the portfolio has no rule for what a closed defect class leaves
behind (defect-class guards)"*, und die Hooks dieser Spec setzen sie um. Ihre
sechs Regeln, in der Form, die für das Authoring zählt:

1. Eine geschlossene Defektklasse hinterlässt einen mechanischen Guard — oder
   eine schriftliche Notiz, warum keiner möglich ist.
2. Der Guard läuft in einer **erzwungenen** Lane. Ein Guard in einer beratenden
   Lane ist ein Kommentar.
3. Der Guard **zählt die Klasse auf**; er prüft nicht die eine Stelle, an der der
   Defekt gefunden wurde. Das Prädikat gehört in den Header der Datei, nicht in
   die Commit-Message.
4. Ausnahmen stehen in einer Allowlist mit je einer Begründung, und ein Eintrag,
   der auf nichts mehr passt, lässt den Guard fehlschlagen.
5. Der Guard trägt die Issue-Nummer im Namen, damit Befund und Regel gemeinsam
   auffindbar bleiben.
6. Der Selektor darf kein Dateiname sein, wenn die Eigenschaft eine Eigenschaft
   der zusammengesetzten Anwendung ist.

Regel 5 braucht für dieses Repository eine Lesart. Die Hooks hier gelten
portfolioweit: sie schließen eine Klasse für jeden Konsumenten, nicht einen
Defekt dieses Repositories, also gibt es keine einzelne Issue-Nummer für die
Hook-ID. Die Herkunft steht stattdessen im Header des Hooks und benennt die
Issues, aus deren Defekten er gebaut wurde. `workflow-gate-integrity` ist das
ausgearbeitete Beispiel — sein Modul-Docstring nennt die ursprünglichen
kamerplanter-Issues, und seine Fixtures unter
`tests/fixtures/workflow-gate-integrity/` tragen den Commit, aus dem sie jeweils
extrahiert wurden.

Regel 3 wird am häufigsten von einem Hook verletzt, der fertig aussieht. Ein
Guard, der die Fundstelle statt der Klasse prüft, besteht am Tag seiner
Einführung und feuert danach nie wieder. §9 ist die Stelle, an der das auffällt:
Ein Hook ist verifiziert, wenn er auf dem Defekt, aus dem er gebaut wurde,
**rot war** — nicht, wenn er auf dem aktuellen Stand grün ist.

## 1. Mentales Modell — wie pre-commit einen Hook ausführt

- pre-commit ist ein **mehrsprachiges Framework** zur Verwaltung von git-Hooks
  (~260k Projekte; das Framework selbst ist zu ~97 % Python). Es existiert, weil
  gits clientseitige Hooks unter `.git/hooks` liegen, beim `clone` nicht
  mitkopiert werden und pro Checkout installiert werden müssen — ein Framework
  installiert und verwaltet sie.
- Zwei YAML-Dateien definieren den Vertrag:
  - **`.pre-commit-config.yaml`** — die *Konsumenten*-Seite. Listet `repos:`,
    jedes an ein `rev` gepinnt, jedes wählt Hooks per `id` und überschreibt
    optional das Verhalten (`args`, `files`, `stages`, …).
  - **`.pre-commit-hooks.yaml`** — das *Hook-Repository-Manifest*. Das Produkt
    eines Hook-Repos. Ein Eintrag pro Hook-`id`. **Das schreibt ein Hook-Autor.**
- **Ausführung auf Staged-Inhalten ist die zentrale Invariante.** pre-commit führt
  Hooks nur gegen die *gestagten* Inhalte aus. Es stasht ungestagte Änderungen
  vorübergehend (inklusive des ungestagten Rests, wenn eine Datei via `git add -p`
  teilweise gestaged wurde) für die Dauer des Laufs, sodass der Hook exakt das
  sieht, was committet würde. Ein Hook muss daher auf dem operieren, was pre-commit
  ihm übergibt — und **nicht** den Working Tree direkt lesen, siehe
  [Anti-Patterns](#10-anti-patterns).
- **Fehlersignal:** ein Hook schlägt fehl, wenn er **mit Nonzero endet ODER Dateien
  modifiziert.** Beides gilt als fehlgeschlagener Lauf. (Wörtlich von pre-commit.com
  „Creating new hooks": *„The hook must exit nonzero on failure or modify files."*)
  Das Anlegen einer neuen *untracked* Datei ist eine kleine Ausnahme, die den Lauf
  allein nicht zum Scheitern bringt.
- Ein Fehlschlag in der `pre-commit`-Stage bricht `git commit` ab. Entwickler
  können jeden Hook mit `git commit --no-verify` (`-n`) umgehen — Hooks sind auf
  der lokalen Ebene also beratend; die Durchsetzung gehört weiterhin in CI.

## 2. Das Manifest (`.pre-commit-hooks.yaml`)

Ein Listeneintrag pro Hook. **Pflichtfelder:** `id`, `name`, `entry`, `language`.
Alles andere ist optional mit einem Default. (`description` ist *optional*, Default
`''` — kein Pflichtfeld, auch wenn es oft neben den vier Pflichtfeldern auftaucht.)

| Feld | Default | Bedeutung |
|---|---|---|
| `id` | — (Pflicht) | Stabiler Bezeichner, den Konsumenten in `.pre-commit-config.yaml` referenzieren. |
| `name` | — (Pflicht) | Menschenlesbares Label in der Lauf-Ausgabe von pre-commit. |
| `entry` | — (Pflicht) | Das ausführbare Kommando, das pre-commit startet. Ein Skriptpfad (`hooks/foo.sh`), ein vom Hook-Paket mitgelieferter Console-Script-Entry-Point oder — bei `language: fail`/`pygrep` — eine Meldung/ein Muster. pre-commit hängt die Ziel-Dateinamen an, außer bei `pass_filenames: false`. |
| `language` | — (Pflicht) | Wie pre-commit den Hook installiert/ausführt. Siehe [§4](#4-language-backends). |
| `description` | `''` | Längere menschenlesbare Beschreibung. |
| `files` | `''` (alle) | Python-Regex (per `re.search` geprüft, **nicht** verankert), der einschränkt, gegen welche Pfade der Hook läuft. Bei Bedarf explizit mit `^…$` verankern. |
| `exclude` | `^$` (keine) | Python-Regex der Pfade, die aus der `files`-Menge entfernt werden. |
| `types` | `[file]` | `identify`-Tags, die eine Datei **alle** erfüllen muss (AND). |
| `types_or` | `[]` | `identify`-Tags, bei denen **eines** zum Treffer reicht (OR). |
| `exclude_types` | `[]` | `identify`-Tags, die ausgeschlossen werden. |
| `always_run` | `false` | Auch laufen, wenn keine Datei die Filter erfüllt. |
| `pass_filenames` | `true` | Die getroffenen Dateinamen an `entry` anhängen. `false` für Hooks, die auf dem Repo als Ganzes arbeiten. |
| `require_serial` | `false` | Einen einzelnen Prozess erzwingen (kein paralleles File-Batching). Siehe [§7](#7-performance). |
| `stages` | alle Stages | Welche git-Stages der Hook betrifft. Siehe [§3](#3-stages--git-hook-typen). |
| `args` | `[]` | Default-Argumente, die an `entry` angehängt werden. Konsumenten können überschreiben. |
| `additional_dependencies` | `[]` | Zusätzliche Pakete, die in die verwaltete Umgebung des Hooks installiert werden. |
| `minimum_pre_commit_version` | `'0'` | Mindestens erforderliche Framework-Version. |
| `alias` | — | Optionale zweite id, über die Konsumenten den Hook wählen können. |
| `verbose` | `false` | Ausgabe immer drucken, auch bei Erfolg. |
| `language_version` | `default` | Die Backend-Toolchain-Version pinnen (z. B. `python3.11`). |

**Validierung:** pre-commit liefert `pre-commit validate-manifest` (CLI) und einen
konsumierbaren `validate_manifest`-Hook, um die Form eines Manifests zu prüfen. In
der eigenen CI des Hook-Repos ausführen.

## 3. Stages / git-Hook-Typen

Ein Hook deklariert über `stages`, für welche git-Stages er gilt. Die volle Menge:

`commit-msg`, `post-checkout`, `post-commit`, `post-merge`, `post-rewrite`,
`pre-commit`, `pre-merge-commit`, `pre-push`, `pre-rebase`, `prepare-commit-msg`
und die spezielle **`manual`**-Stage.

- **Stage-Namen entsprechen ab pre-commit v3.2.0+ den git-Hook-Namen.** Frühere
  Versionen nutzten `commit`, `push`, `merge-commit`; diese wurden auf
  `pre-commit`, `pre-push`, `pre-merge-commit` abgebildet. `minimum_pre_commit_version:
  3.2.0` zu deklarieren ist angemessen, wenn man sich auf die neuen Namen verlässt.
- **`pre-commit`** — läuft, bevor die Commit-Message eingegeben wird; Nonzero bricht
  den Commit ab. Die Default- und häufigste Stage. Mit `--no-verify` umgehbar.
- **`commit-msg`** — git ruft den Hook mit einem Parameter auf: dem Pfad zu einer
  Temp-Datei mit der Commit-Message. Für Message-Format-Durchsetzung; Nonzero bricht ab.
- **`prepare-commit-msg`** — läuft, bevor der Editor öffnet; kann die Message
  vorbefüllen.
- **`pre-push`** — läuft während `git push`, bevor der Push stattfindet, und kann
  ihn vollständig verhindern; erhält Name/Ort des Remotes als Parameter und die zu
  aktualisierenden Refs über stdin. Der richtige Ort für langsamere Prüfungen, die
  das Teilen gaten sollen, ohne jeden Commit zu verlangsamen. *(Das Pro-Git-Buch
  formuliert das Timing als „after the remote refs have been updated but before
  objects are transferred"; die kanonische `githooks(5)`-Manpage sagt nur, dass er
  vor dem Push läuft und ihn verhindern kann — die vorsichtige Formulierung
  bevorzugen.)*
- **`post-*`** (`post-checkout`, `post-commit`, `post-merge`, `post-rewrite`) —
  informativ; laufen im Nachhinein und können die Operation nicht abbrechen.
- **`manual`** — wird nie automatisch durch einen git-Hook ausgelöst. Nur via
  `pre-commit run --hook-stage manual <id>` aufgerufen. Für Prüfungen, die im Repo
  existieren, aber nicht bei jedem Commit laufen sollen (teures oder Opt-in-Tooling).

**Die Wahl der Stage ist die erste Targeting-Entscheidung:** die Stage auf das
git-Ereignis abstimmen, dessen Inhalt die Prüfung braucht (Message → `commit-msg`;
gestagter Diff → `pre-commit`; zu pushende Refs → `pre-push`; Opt-in → `manual`).

## 4. Language-Backends

`language` sagt pre-commit, wie der Hook installiert und ausgeführt wird. Das
**leichteste Backend wählen, das die Abhängigkeiten erfüllt.**

| `language` | Verwenden, wenn… | Hinweise |
|---|---|---|
| `script` | Der Hook ein in sich geschlossenes Skript ist, das im Hook-Repo eincheckt ist. | Kein Umgebungsmanagement; `entry` ist der Skriptpfad. Konvention dieses Repos für Shell-Hooks. |
| `system` | Das benötigte Kommando bereits auf dem `PATH` angenommen wird. | Kein Install-Schritt; am schnellsten, aber Konsument muss das Tool bereitstellen. |
| `fail` | Der Hook bei jeder getroffenen Datei **bedingungslos fehlschlagen** soll. | `entry` ist die Fehler*meldung*, kein Kommando. Mit `files`/`types` koppeln, um Pfade zu verbieten (z. B. eingecheckte Submodules blocken). |
| `pygrep` | Die Prüfung „keine Datei darf Muster X enthalten" ist. | Eingebaut; `entry` ist ein Python-Regex. Kein externer Prozess. Ideal für einfache Forbidden-Content-Guards. |
| `python` | Der Hook als Python-Paket verteilt wird. | Verwaltetes isoliertes venv; `entry` ist ein `console_scripts`-Entry-Point; Zusatz-Deps via `additional_dependencies`. |
| `node` / `ruby` / `rust` / `golang` / weitere | Der Hook in diesem Ökosystem ausgeliefert wird. | Verwaltete isolierte Umgebung pro Ökosystem; `language_version` pinnt die Toolchain. |
| `docker` / `docker_image` | Die Prüfung einen Container braucht. | Höchste Startkosten; aus dem kuratierten Listing auf pre-commit.com ausgeschlossen. Für Hooks, die bei jedem Commit laufen sollen, möglichst vermeiden. |

Für einen *zielgerichteten* Hook ohne Laufzeitabhängigkeit jenseits von git und
einer POSIX-Shell sind `script` (ein eingecheckter `hooks/<id>.sh`) oder
`pygrep`/`fail` (gar kein Skript) die richtigen Defaults. Zu `python`/`node`/etc.
nur greifen, wenn die Prüfung diese Laufzeit wirklich braucht.

## 5. File-Targeting (welche Dateien ein Hook sieht)

Die Kandidaten-Dateimenge wird aus fünf Filtern berechnet, **alle mit AND
kombiniert**:

- `files` und `exclude` — Python-Regexes über den Pfad (`re.search`).
- `types`, `types_or`, `exclude_types` — Tags aus der **`identify`**-Bibliothek.
  Innerhalb von `types` müssen alle Tags matchen (AND); innerhalb von `types_or`
  reicht ein beliebiges Tag (OR); `exclude_types` entfernt Treffer.

`identify` liefert für jede Datei eine **Menge orthogonaler Tags** gleichzeitig —
Dateiart, Text/Binär, Ausführbarkeit und Sprache — sodass eine Datei mehrere
zugleich erfüllt (eine Python-Datei → `file, text, python, non-executable`).
Auflösungs-Pipeline: Dateityp → Ausführbarkeit → Erweiterung (stopp, wenn erkannt)
→ sonst führende Bytes Binär-vs-Text → bei Text die Shebang. So wird ein
erweiterungsloses Skript, das mit `#!/usr/bin/env python3` beginnt, als `python`
getaggt. Die Tags einer Datei direkt mit `identify-cli` inspizieren
(`--filename-only` für reinen Pfadmodus), um die richtigen `types` zu wählen.

Fallstricke:

- **Jupyter-`.ipynb`-Dateien werden als `json` getaggt** (ihr zugrunde liegendes
  Format). Ein JSON-Hook verarbeitet auch Notebooks, außer man ergänzt
  `exclude_types: [jupyter]`.
- `default types` ist `[file]` — d. h. ohne Eingrenzung läuft ein Hook auf jeder
  (nicht-binär-ausgeschlossenen) Datei.
- **`--all-files` umgeht die Per-Hook-Filter NICHT.** Es verbreitert nur die
  *Kandidaten*-Menge auf das ganze Repo; `files`/`types`/`exclude`/`exclude_types`
  werden weiterhin obendrauf angewandt. (Vom Maintainer bestätigt; eine
  wiederkehrende Fehlmeldung.)

Für Hooks, die auf dem Repo als Ganzes statt pro Datei arbeiten,
`pass_filenames: false` und meist `always_run: true` setzen (das Muster von
`no-commit-to-branch`).

## 6. Der Hook-Vertrag (Verhaltensdesign)

- **Exit-Codes:** `0` = Erfolg (Commit läuft weiter). Jedes Nonzero = Fehlschlag
  (Commit bricht ab). Eine Python-Check-Funktion akzeptiert konventionell einen
  einzelnen Dateinamen oder eine Sequenz von Dateinamen und gibt einen bool oder
  int-Exit-Status zurück.
- **Datei-Modifikation gilt als Fehlschlag.** Formatter-artige Hooks, die Dateien
  umschreiben, melden Fehlschlag in dem Lauf, der etwas geändert hat, sodass der
  Entwickler neu staged und neu committet. Bewusst entwerfen: ein *Checker* lässt
  Dateien unangetastet und meldet nur; ein *Fixer* mutiert und lässt den Lauf
  scheitern.
- **stdout/stderr:** umsetzbare Diagnostik ausgeben. pre-commit zeigt Hook-Ausgabe
  bei Fehlschlag (und immer bei `verbose: true`). Ein guter Guard druckt, *warum*
  er fehlschlug und *wie man es behebt* (die Hooks dieses Repos geben ein
  Reparatur-Rezept auf stderr aus).
- **Determinismus & Idempotenz:** dieselbe gestagte Eingabe muss dasselbe Ergebnis
  liefern; einen Fixer zweimal laufen zu lassen muss beim zweiten Mal ein No-op
  sein. Nicht-deterministische Hooks untergraben Vertrauen und erzeugen
  Geister-Diffs.
- **Konfigurierbarkeit:** Verhalten über `args` exponieren, defensiv mit
  vernünftigem Default geparst, nie ein hartkodierter org-spezifischer Wert, den
  ein Konsument nicht überschreiben kann (z. B. `--maxkb`, `--branch`). Konsumenten
  setzen `args:` in ihrer Config.
- **fail-open vs. fail-closed:** bewusst entscheiden. Ein Guard, der auf den lokalen
  `git commit` eines Entwicklers zielt, sollte **in Automatisierung fail-open sein**
  (kurzschließen zu Exit 0, wenn `CI` gesetzt ist), weil CI den Branch in einem
  Detached HEAD innerhalb eines normalen Clones auscheckt, wo die Prämisse des
  Guards nicht mehr gilt — sonst blockiert er jeden Lint-Job. Korrektheits-/
  Sicherheitsprüfungen, die überall gaten sollen, sollten fail-closed sein. (Der
  Vertrag dieses Repos: Hooks sind unter `CI` fail-open.)

## 7. Performance

- **Parallelität:** seit pre-commit 1.13.0 splittet pre-commit die Dateiliste
  *eines Hooks* über mehrere Prozesse und führt sie parallel aus. Das ist Per-Hook-
  File-Batching — **nicht** das nebenläufige Ausführen verschiedener Hooks.
- **`require_serial: true`** erzwingt einen einzelnen Prozess. Nötig für jeden Hook,
  der **geteilte Ressourcen außerhalb der übergebenen Dateien** berührt (geteilte
  Config liest, ein geteiltes Log schreibt, eine einzelne Ausgabedatei mutiert), um
  Races/Deadlocks über die parallelen Worker zu vermeiden. Der Default (parallel)
  tauscht diese Sicherheit gegen Geschwindigkeit.
- **File-Filtering ist der primäre Performance-Hebel:** `types`/`files` so eng
  fassen, dass der Hook auf so wenigen Dateien wie möglich aufgerufen wird.
- **Latenz-Budget:** die gesamte lokale pre-commit-Laufzeit **unter ~5 Sekunden**
  halten; darüber hinaus greifen Entwickler zu `--no-verify` und hebeln die Hooks
  aus. Faustregel aus der Praxis: eine Prüfung, die >5s dauert **und** bei <~10 %
  der Commits fehlschlägt, gehört **nur in CI**, nicht in lokale Hooks. Schnelle
  Formatter (z. B. `black`, `ruff`) laufen gut lokal; langsame Validatoren (volles
  `mypy`, vollständige Test-Suites) gehören in CI. Auf geänderte Dateien
  beschränkte Test-Hooks können die lokale Zeit drastisch senken (berichtet 47s →
  3–8s), während die volle Suite eine CI-Angelegenheit bleibt.

## 8. Ein wiederverwendbares Hook-Repository bauen und verteilen

- **Die Hook-Skripte + `.pre-commit-hooks.yaml` sind das Produkt.** Für
  `script`/`pygrep`/`fail`-Hooks gibt es kein Build-Artefakt.
- Für einen **Python**-Hook ist das Rezept: (1) eine Check-Funktion (akzeptiert
  Dateiname(n), gibt bool/int zurück, `0` = ok); (2) ein CLI-Wrapper (z. B.
  `argparse`); (3) installierbar machen via `pyproject.toml`-Entry-Point
  `scripts`/`console_scripts`; (4) das `.pre-commit-hooks.yaml`-Manifest, dessen
  `entry` dieses Console-Script ist.
- **Konsum:** Konsumenten fügen einen `repos:`-Eintrag mit der Repo-URL hinzu, an
  ein `rev` gepinnt, und wählen Hooks per `id`:

  ```yaml
  repos:
    - repo: https://github.com/<org>/<repo>
      rev: v1.0.0
      hooks:
        - id: <hook-id>
          args: [--branch=main]
  ```

- **Versionierung / `rev`:**
  - An eine **unveränderliche** Ref pinnen. Ein git-**Tag mit einem Punkt** (z. B.
    `v1.2.0`) ist das, was `pre-commit autoupdate` beim Bump bevorzugt.
  - **Ein Branch-Name oder `HEAD` ist als `rev` nicht unterstützt** — es erfasst nur
    den Zustand zur Install-Zeit und wird nicht auto-aktualisiert.
  - `pre-commit autoupdate` schreibt jedes `rev` auf das neueste Tag um; mit
    `--freeze` schreibt es einen Commit-**SHA** (annotiert mit dem Tag). Hinweis:
    `--freeze` löst weiterhin auf die *neueste* Revision auf — es bewahrt keinen
    bereits gepinnten SHA. Es gibt **keine eingebaute Möglichkeit, ein `rev` gegen
    autoupdate zu sperren**; der einzige Mechanismus ist operativ (autoupdate nicht
    ausführen oder bewusst ausführen und den Diff prüfen).
- **Validierung vor dem Publish:** den Hook gegen ein Beispiel-Repo mit
  `pre-commit try-repo <pfad-oder-url> <hook-id>` testen, bevor man ein Release
  taggt; das Release-Tag mit `git tag -a <version>` erstellen.

## 9. Test-Strategie

- **Wegwerf-Repo-Integrationstests** (das Muster dieses Repos): ein Sandbox-git-Repo
  bauen, `HEAD`/den Index in einen bekannten Zustand treiben, den Hook ausführen,
  auf den **Exit-Code** asserten. Pass-Fall, Fail-Fall, jeden `args`-Zweig, den
  Fail-Open-Pfad (`CI`) und Randzustände (Detached HEAD, Worktrees) abdecken. Kein
  Netzwerk, keine globalen git-config-Seiteneffekte.
- **`pre-commit try-repo`** für einen echten End-to-End-Lauf durch das Framework.
- Für Python-Hooks die Check-Funktion direkt mit `pytest` unit-testen.
- `pre-commit validate-manifest` in CI ausführen, um Manifest-Regressionen zu fangen.

**Falsifikation — das Gate, auf das §0 Regel 3 angewiesen ist.** Ein Hook ist
verifiziert, wenn er auf dem Defekt, aus dem er gebaut wurde, **rot war** — nicht,
wenn er auf dem aktuellen Stand grün ist. Ein Hook, der in seinem
Ursprungs-Repository grün ist und im konsumierenden nie rot war, ist nicht
verifiziert, er ist installiert.

- Ein Fixture des **Vor-Fix-Zustands eines echten geschlossenen Defekts**
  vorhalten, wörtlich aus dem Commit extrahiert, der ihn behoben hat
  (`git show <fix>^:<pfad>`), zusammen mit dem Nach-Fix-Zustand. Den
  Extraktionsbefehl und den Fix-Commit neben dem Fixture festhalten; den Defekt
  nicht von Hand nachbauen, und dem Fixture selbst keinen Herkunfts-Header
  voranstellen, weil das die Zeilennummern verschiebt, auf die die Assertion
  greift.
- **Auf den Befund asserten, nicht auf den Exit-Code.** Über einem echten
  Vor-Fix-Baum ist der Hook meist aus mehreren unabhängigen Gründen gleichzeitig
  rot, sodass eine Exit-Code-Assertion besteht, ohne etwas über den benannten
  Defekt zu beweisen — und weiter besteht, nachdem der Hook die Fähigkeit
  verloren hat, ihn zu erkennen. Die Assertion auf Datei, Zeile und Befundart
  keyen.
- **Ein leeres Ergebnis darf kein Bestehen sein können.** Wo „keine Funde"
  selbst ein erwarteter Wert ist, lässt ein Helper, der bei einem Absturz leer
  zurückkommt, genau diese Fälle bestehen, ohne dass der Hook lief. Stattdessen
  eine eindeutige Fehlermarkierung ausgeben. Das ist die Defektklasse des Hooks
  selbst, reproduziert in seinem Test.
- **Die Falsifikationsfälle mutationsprüfen**: die Form abschalten, die der
  jeweilige Fall abdeckt, und bestätigen, dass genau dieser Fall fällt — und nur
  er. Eine Assertion, die das Entfernen des geprüften Codes überlebt, ist keine.
- Stellt sich ein benannter Defekt als **außerhalb der Reichweite** des Hooks
  heraus, gehört das in den Fixture-Nachweis, und ein echter Defekt derselben
  Klasse tritt an seine Stelle. Kein Fixture erfinden, das einen unerreichbaren
  Defekt als abgedeckt erscheinen lässt.

## 10. Anti-Patterns

- **Den Working Tree statt des gestagten Index lesen.** Ein Fix, der nur im Working
  Tree vorhanden ist (ungestaged), lässt den Hook passieren, während der
  committete/Index-Inhalt weiterhin kaputt ist — ein echter Korrektheitsbug. Auf
  dem operieren, was pre-commit bereitstellt.
- **Den Commit während des Laufs automatisch modifizieren**, sodass das gepushte
  Ergebnis von dem abweicht, was reviewt wurde. Mutierende Fixer sind akzeptabel,
  *weil sie den Lauf scheitern lassen und ein erneutes Stagen erzwingen*; den
  Commit-Inhalt still umzuschreiben ist es nicht.
- **Langsame Hooks bei jedem Commit.** Sie stören Rebase-/Amend-Workflows und
  drängen Entwickler zu `--no-verify`. In `pre-push`, `manual` oder CI verschieben.
- **Hooks mit geteiltem veränderlichem Zustand ohne `require_serial`** → Races unter
  der Default-Parallelität.
- **Org-spezifische Werte hartkodieren**, die ein konsumierendes Repo nicht
  überschreiben kann; stattdessen über `args` mit Defaults exponieren.
- **Lokale Hooks als Durchsetzung behandeln.** `--no-verify` umgeht sie; dieselbe
  Prüfung muss in CI existieren, um wirklich zu gaten.

## 11. Sicherheit und Supply Chain

Hooks führen **bei jedem Commit beliebigen Code aus**, sobald ein Entwickler
`pre-commit install` ausführt. Das macht Hook-Repositories zu einer
Supply-Chain-Oberfläche:

- **Ein einziger vergifteter Commit in einem geteilten Repo kompromittiert jeden
  Entwickler, der es klont und die Hooks installiert** — z. B. liefert ein
  Hook-Eintrag, der ein Reverse-Shell-Payload ausführt, Code-Ausführung auf der
  Maschine des Entwicklers. Rückdatierte Commit-Timestamps können die Änderung
  tarnen.
- **Mutable-Tag-Risiko:** ein Drittanbieter-Repo an ein `rev`-*Tag* zu pinnen, ist
  gegen einen entschlossenen Angreifer nicht ausreichend, weil ein Tag
  force-repusht werden kann, sodass es ohne jede Config-Änderung auf bösartigen Code
  zeigt. **Härtung:** Drittanbieter-Hooks an einen **unveränderlichen vollen
  Commit-SHA** pinnen, annotiert mit der menschenlesbaren Version, z. B.
  `rev: ce40a160603ab0e7d9c627ae33d7ef3906e2d2b2 # frozen: v3.19.1`. Solche Pins mit
  `pre-commit autoupdate --freeze` erzeugen. *(Der pre-commit-Maintainer bestreitet,
  `--freeze` als Sicherheitsfeature zu framen; SHA-Pinning als Defense-in-Depth
  behandeln, die der Konsument wählt, nicht als Garantie des Frameworks.)*
- **CVE-2025-62726** (CVSS 8.8, High): pre-commit-Hooks, die über ein geklontes
  Remote-Repository ausgeliefert werden, sind ein realer Remote-Code-Execution-
  Vektor — eingecheckter Hook-Code, der bei der nächsten git-Operation automatisch
  läuft. Mitigationen: keine Hooks aus nicht vertrauenswürdigen Repositories
  ausführen; Hooks nie als **root** ausführen (Root-Ausführung gibt dem Angreifer
  die ganze Maschine).

**Was ein Hook nicht tun sollte:** nicht vertrauenswürdige Eingaben ungequotet durch
eine Shell laufen lassen; `args`/Dateinamen als sicher annehmen (Pfade können
Leerzeichen/Newlines enthalten — alles quoten; `set -euo pipefail` für Shell-Hooks);
Netzwerkzugriff oder erhöhte Rechte verlangen; oder Seiteneffekte jenseits der
beworbenen Prüfung ausführen.

## 12. Targeting-Checkliste (Referenz)

Wenn das Ziel *ein* zielgerichteter Hook ist, die Designentscheidungen der Reihe nach:

1. **Welches git-Ereignis liefert den Inhalt, den die Prüfung braucht?** → den
   `stages`-Wert wählen (`pre-commit` / `commit-msg` / `pre-push` / `manual`).
2. **Pro Datei oder ganzes Repo?** → `pass_filenames` setzen (und `always_run` fürs
   ganze Repo).
3. **Welche Dateien?** → mit `types`/`types_or`/`files`/`exclude` eingrenzen (mit
   `identify-cli` verifizieren).
4. **Welche Laufzeit braucht es?** → die leichteste `language` wählen
   (`pygrep`/`fail` → `script`/`system` → verwaltetes `python`/`node`/… → `docker`).
5. **Checker oder Fixer?** → Checker meldet nur; Fixer mutiert und lässt den Lauf
   scheitern.
6. **Was ist konfigurierbar?** → über `args` mit sicheren Defaults exponieren.
7. **Wo muss es tatsächlich gaten?** → lokal fail-open / in CI durchsetzen, je nach
   Bedarf; fail-open vs. fail-closed bewusst entscheiden.
8. **Geteilter Zustand?** → `require_serial` setzen, wenn es Ressourcen außerhalb der
   übergebenen Dateien berührt.
9. **Tests:** Sandbox-Repo, das Exit-Codes für jeden Zweig assertet, plus
   `validate-manifest` und `try-repo`.

## Quellen

Primär (offiziell / kanonisch):

- pre-commit.com — Hauptdoku, „Creating new hooks", Filtering, `rev`-Semantik:
  <https://pre-commit.com/>
- Supported-Hooks-Listing: <https://pre-commit.com/hooks.html>
- `pre-commit/pre-commit-hooks`-Manifest (kanonische Hook-Beispiele):
  <https://github.com/pre-commit/pre-commit-hooks/blob/main/.pre-commit-hooks.yaml>
- Eigenes Manifest von `pre-commit/pre-commit` (`validate_manifest`):
  <https://github.com/pre-commit/pre-commit/blob/main/.pre-commit-hooks.yaml>
- `identify`-Bibliothek (File-Type-Tags): <https://github.com/pre-commit/identify>
- pre-commit Advanced-Doku (Stages/Filtering):
  <https://github.com/pre-commit/pre-commit.com/blob/main/sections/advanced.md>
- git-`githooks`-Referenz / Pro Git „Git Hooks":
  <https://git-scm.com/book/en/v2/Customizing-Git-Git-Hooks>
- `--all-files` umgeht Filter nicht (Maintainer):
  <https://github.com/pre-commit/pre-commit/issues/3309>
- `rev`-Freezing / kein eingebauter Lock (Maintainer):
  <https://github.com/pre-commit/pre-commit/issues/3066>

Sekundär (Praxis / Sicherheit):

- Stefanie Molin, „Creating a Custom pre-commit Hook":
  <https://stefaniemolin.com/articles/devx/pre-commit/hook-creation-guide/>
- „pre-commit hooks vs CI — when to skip local checks":
  <https://tildalice.io/pre-commit-hooks-vs-ci-when-to-skip-local-checks/>
- Working-Tree-vs-Index / Auto-Modify-Diskussion (lobste.rs):
  <https://lobste.rs/s/pjysyq/pre_commit_hooks_are_fundamentally>
- Supply-Chain-Demonstration:
  <https://medium.com/@3wisesiren/exploiting-pre-commit-hooks-a-practical-demonstration-4c4bcefe32c8>
- CVE-2025-62726-Advisory (RCE über Cloned-Repo-Hooks, CVSS 8.8):
  <https://github.com/n8n-io/n8n/security/advisories/GHSA-xgp7-7qjq-vg47>

> Recherche-Provenienz: 6 Such-Winkel, 19 Quellen gefetcht, 87 Claims extrahiert,
> 25 adversarial verifiziert (24 bestätigt, 1 widerlegt). Der widerlegte Claim
> behauptete, `description` sei ein *Pflicht*-Manifestfeld; es ist optional (Default
> `''`) — korrigiert in [§2](#2-das-manifest-pre-commit-hooksyaml).
