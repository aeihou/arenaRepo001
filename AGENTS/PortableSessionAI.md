# AGENTS/PortableSessionAI.md

Portable session export for `arenaRepo001` — the skill procedures and data
another `agent_AI` needs to continue this conversation / development / context.

- **Exported by:** `arena_AI` (Arena.ai Agent Mode)
- **Generated:** 2026-08-20T01:16:45Z (UTC)
- **Session branch:** `arena/01a01c09-arenarepo001`
- **Remote:** `https://github.com/aeihou/arenaRepo001.git`

> **Companion:** the essential quick-reference hand-off lives at
> [`AGENTS/SessionHand-off.md`](SessionHand-off.md). This file is the full
> deep-dive; both are refreshed together by `./SelfConstructor.sh --handoff`.

---

## 1. Session identity

| Item | Value |
|---|---|
| Repository | `aeihou/arenaRepo001` |
| Working branch (fixed) | `arena/01a01c09-arenarepo001` |
| Base branch | `main` @ `2f643c1` |
| Last pushed commit (at export) | a1e9891 |
| Owner style | pseudocode → parametrizable POSIX `sh` artifacts |

> **Rule:** always work on `arena/01a01c09-arenarepo001`. Never switch, create,
> or push to another branch. Push only with:
> `git push origin arena/01a01c09-arenarepo001`.

---

## 2. EBT — before touching anything

### 2.1 `ExecuteBeforeThinking.Synch(Repo)` (mandatory)

The workspace **resets to the base commit at the start of some turns** (the
local working tree has repeatedly come back at `2f643c1` / `main` while the
remote is ahead). Always re-sync first, and always against the *true* remote
tip — a stale local `origin/<branch>` ref has caused a backward `reset` before:

```sh
cd /home/user/arenaRepo001
git fetch origin refs/heads/arena/01a01c09-arenarepo001:refs/remotes/origin/arena/01a01c09-arenarepo001
local=$(git rev-parse HEAD)
remote=$(git ls-remote origin refs/heads/arena/01a01c09-arenarepo001 | cut -f1)
[ "$local" = "$remote" ] || git reset --hard "$remote"
git status --short   # expect clean
```

**Lesson recorded (must not repeat):** never compare against a stale
`origin/<branch>` remote-tracking ref. Use `git ls-remote` (or a fetch with the
full `refs/heads/...:refs/remotes/origin/...` refspec) before any `reset`.

### 2.1b Hand-off timing (`Repo.Optimize(performance, hand-off timing)`)

This handoff is refreshed at **EBT**, right after `Synch(Repo)`, so its
`Generated` and `last_commit` fields always record the **baseline tip** — the
state a fresh agent builds on. Refresh is a single pass (one `git rev-parse`
+ one `date` + one `sed`; no tree walk):

```sh
./SelfConstructor.sh --handoff
```

Commit the refreshed handoff together with the turn's work. Its `last_commit`
then equals the parent of the commit a new agent clones — an unambiguous,
non-stale hand-off point. `--verify` treats `PortableSessionAI.md` as an
intentional non-`<folder>.md` file (exempt, like `agents.md`).

### 2.2 `ExecuteBeforeThinking.DescribeMe(auto)`

State the self-description before acting: who (`arena_AI`), what it will do
(translate the pseudocode into executable POSIX artifacts and run them), how
(`initWorkspace → initSession → selfConstructor → SelfDescriberRepo().Update →
commit & push`).

---

## 3. The owner's "pseudocode language" (decoded so far)

The owner writes a compact pseudocode. This table is the accumulated
translation into the implemented `SelfConstructor.sh`:

| Owner pseudocode | Meaning / implementation |
|---|---|
| `selfConstructor(name)` | main builder: `initWorkspace` + `<name>.md` + `README.md` |
| `nameOfFolder()` | folder basename, or `--name` if given |
| `.newFile("X.md")` | create file `X.md` (parents auto-created) |
| `.SelfDescribe("README.md")` | write the `README.md` session entry point |
| `newSession.Reload()` | re-exec the script once (guarded, state exported) |
| `initWorkspace()` | `mkdir -p` the workspace |
| `initSession(README)` | write the workspace `README.md` |
| `if (Not)nameOfFolder then mkdir("nameOfFolder: ddmmaaaaHHMMSS").selfConstructor("$Name_Folder")` | `--auto-name`: timestamped folder fallback |
| `mkdir().SelfConstructor("$Name_Folder = 'X'")` | `--NameOfFolder:X` (also `=` and space forms) |
| `ddmmaaaaHHMMSS` | timestamp format: day/month/4-digit-year/HH/MM/SS |
| `Actualizar(para todo [nameOfFolder.md] OF README.md)` | `--sync-readmes` batch re-sync |
| `For EveryNewFileConstructor()` | provenance: keep the command that created each file |
| `Repo.Verify(consistency().Includes("duped OR outdated OR redundant OR misplaced"))` | `--verify` scan |
| `self.Consistency.new(verify documentation to scripts)` | `--check-docs` scan |
| `Repo.SearchForHardodedVariables().ReplaceFixedHarcodedVariables()` | `--search-hardcoded` scan; parameterize magic values into `SELF_*` defaults |
| `Repo.Update(ForEveryFile)` | `--update`: re-sync every README + regenerate the complete file inventory |
| `BeforeThinking.MyPrompts.md().Add(new Prompt)` | `--add-prompt TEXT`: append to `AGENTS/.user/MyPrompts.md` |
| `SelfDescriberRepo().Update({$thisRepo})` | update `arenaRepo001.md` after each change |
| `AGENTS/agents.md().Update($)` | update the agent registry |
| `arena_AI.commitAndPush()` / `Arena_AI.pushAndCommit()` | commit + push to the session branch |

---

## 4. `SelfConstructor.sh` — the engine

Self-executing, POSIX `#!/bin/sh` (dash-safe, `set -eu`), parametrizable.

### 4.1 Primitives (functions)

`nameOfFolder` · `autoNameIfNeeded` · `newFile` · `initWorkspace` ·
`initSession` (delegates to `writeReadme`) · `writeReadme` · `reloadSession` ·
`selfConstructor` · `syncReadmes` · `verify` · `checkDocs` · `refreshHandoff` ·
`searchHardcoded` · `updateEveryFile` · `addPrompt` · `classifyFile` ·
`injectInventory` · `invocationCommand` · `logCreatedFile` ·
`provenanceFooter` · `tokens`.

### 4.2 CLI flags (CLI wins over env)

`--dir` · `--name` · `--NameOfFolder` (`:`, `=`, space forms) · `--auto-name` ·
`--name-sep` · `--sync-readmes` · `--verify` · `--check-docs` · `--handoff` ·
`--search-hardcoded` · `--update` · `--add-prompt` · `--provenance` /
`--no-provenance` · `--filename` · `--readme` · `--force` · `--no-reload` ·
`--quiet` · `--help`.

### 4.3 Environment (overridable)

`SELF_DIR` · `SELF_NAME` · `SELF_FILENAME` · `SELF_README` · `SELF_MARKER` ·
`SELF_LOG` · `SELF_PROVENANCE` · `SELF_AUTO_NAME` · `SELF_NAME_SEP` ·
`SELF_AGENTS_DIR` · `SELF_AGENTS_FILE` · `SELF_HANDOFF_FILE` ·
`SELF_SESSION_HANDOFF` · `SELF_USER_DIR` · `SELF_PROMPTS_FILE` ·
`SELF_SCRIPT_NAME` · `SELF_GITDIR` · `SELF_TS_FMT` · `SELF_ISO_FMT`.

### 4.4 Guarantees

- **Provenance ON by default:** every generated file ends with a
  `## Created by` block (script, full command, UTC timestamp) and appends a
  line to `.selfconstructor.log` (gitignored) in the same folder.
- **Idempotency:** skips already-constructed workspaces (`.selfconstructor.rc`
  marker, gitignored); `--force` rebuilds.
- **POSIX-only:** `printf`/`basename`/`date`/`find`/`awk`/`sed`/`cksum`/`cmp`;
  a custom `awk match()/RSTART/RLENGTH` tokenizer replaces GNU `grep -o`.
- **`newSession.Reload()` state safety:** on re-exec, the original invocation
  command and dir/name are exported so no second timestamped folder is created
  and provenance is preserved.

---

## 5. Lifecycle hooks (kept, applied every turn)

- **EBT** = `ExecuteBeforeThinking`: `Synch(Repo)` → `DescribeMe(auto)`.
- **EAT** = `ExecuteAfterThinking`: `Commit&&Push()` —
  `git add -A && git commit -m "<msg>" && git push origin arena/01a01c09-arenarepo001`.
- **ExportSession("userPrompt, log.init()")**: append the user prompt + a
  `log.init()` entry to `AGENTS/session.log` (tracked).

---

## 6. Self-description model (how the repo is organized)

Every self-constructed workspace folder carries:

1. `<nameOfFolder>.md` — self-description (metadata + link + rebuild command).
2. `README.md` — session entry point (title, folder, `[<name>.md](<name>.md)`,
   `## Contents`, `## Last updated`, `## Usage`, `## Created by`).
3. `.selfconstructor.rc` — first-run marker (gitignored).
4. `.selfconstructor.log` — audit log (gitignored).

Root-level documents:

| Path | Purpose |
|---|---|
| `SelfConstructor.sh` | the engine (single source of truth) |
| `arenaRepo001.md` | repo self-description + workspace table + verification report |
| `README.md` | root session entry point |
| `AGENTS/agents.md` | agent registry (identity, lifecycle, repo map, primitives, quick ref) |
| `AGENTS/README.md` | AGENTS workspace entry point |
| `AGENTS/session.log` | session export (`userPrompt` + `log.init()`) |
| `AGENTS/PortableSessionAI.md` | this handoff document |
| `AGENTS/<ddmmaaaaHHMMSS>.md` | timestamped snapshot |

Demo workspaces (kept, flagged REDUNDANT by `--verify`): `MyTest/`,
`SRC/Tools/`, `TEST/`, `TEST/19082026223433/`,
`arenaRepo001-19082026222314/`.

---

## 7. Consistency tooling + current state

- `./SelfConstructor.sh --verify` → DUPED / OUTDATED / REDUNDANT / MISPLACED.
  Current: **0 DUPED, 0 OUTDATED, 0 MISPLACED**; 4 REDUNDANT (the demo
  workspaces above — intentionally kept; candidate for `archive/`).
- `./SelfConstructor.sh --check-docs` → documentation ↔ script. Current:
  **green** (flags, env, primitives all consistent). Drift-tested: an
  undocumented-but-implemented flag is reported correctly.
- `./SelfConstructor.sh --verify` → performance: collects the tree once
  (files + dirs) and runs all four checks against the cached listings
  (2 `find` passes instead of 5).
- `./SelfConstructor.sh --handoff` → refreshes this file's volatile fields.
- `./SelfConstructor.sh --search-hardcoded` → reports literal hardcoded
  variables; after the `ReplaceFixedHarcodedVariables()` refactor it must
  report **none** (magic values live only in the `SELF_*` Defaults block).
- `./SelfConstructor.sh --update` → `Repo.Update(ForEveryFile)`: re-syncs every
  workspace README and regenerates the complete **File inventory** (every file,
  classified, with the command that created it) into `arenaRepo001.md`.
- All checks are **read-only**; always re-run them before committing changes.

---

## 8. Procedure to continue the work (step-by-step)

```sh
cd /home/user/arenaRepo001

# 1. EBT.Synch(Repo) — see section 2.1 (never skip)

# 2. Orient
./SelfConstructor.sh --help
./SelfConstructor.sh --verify
./SelfConstructor.sh --check-docs

# 3. Do the work
#    - decode the owner's pseudocode using section 3
#    - prefer extending SelfConstructor.sh (POSIX) rather than one-off shell
#    - after any code change:  sh -n SelfConstructor.sh  (syntax gate)

# 4. Keep the repo self-describing
#    - update arenaRepo001.md (SelfDescriberRepo().Update)
#    - update AGENTS/agents.md if primitives/flags/lifecycle changed
#    - append the prompt + outcome to AGENTS/session.log (ExportSession)

# 5. EAT.Commit&&Push()
git add -A
git commit -m "<concise message naming the pseudocode directive>"
git push origin arena/01a01c09-arenarepo001
```

---

## 9. Data export (machine-friendly)

```txt
repo=arenaRepo001
remote=https://github.com/aeihou/arenaRepo001.git
branch=arena/01a01c09-arenarepo001
base=main
last_commit=a1e9891
self_description=arenaRepo001.md
agent_registry=AGENTS/agents.md
session_log=AGENTS/session.log
handoff=AGENTS/PortableSessionAI.md
prompts=AGENTS/.user/MyPrompts.md
engine=SelfConstructor.sh
verify=./SelfConstructor.sh --verify
check_docs=./SelfConstructor.sh --check-docs
search_hardcoded=./SelfConstructor.sh --search-hardcoded
sync_readmes=./SelfConstructor.sh --sync-readmes
handoff=./SelfConstructor.sh --handoff
update=./SelfConstructor.sh --update
add_prompt=./SelfConstructor.sh --add-prompt
timestamp_format=ddmmaaaaHHMMSS
```

---

## 10. Gotchas checklist (do not regress)

1. Always `git fetch <full refspec>` + `git ls-remote` before `reset` (section 2.1).
2. Never let a *copied* `SelfConstructor.sh` drift from the root one — copies go
   stale and `--verify` flags them as OUTDATED; prefer running the root script
   with `--dir` over copying it.
3. Keep POSIX: no bash arrays, no `grep -o`, no `[[ ]]`, no `local` keyword
   (use plain variables), no `mapfile`.
4. `ddmmaaaaHHMMSS` uses a **4-digit year**; the earlier `ddmmaahhmmss`
   (2-digit) form was corrected once — do not reintroduce it.
5. No hardcoded magic values in code — reference the `SELF_*` defaults
   (names, markers, paths, date formats). `--search-hardcoded` must stay clean.
6. Commit message should name the pseudocode directive it implements (keeps the
   history traceable to the owner's intent).
