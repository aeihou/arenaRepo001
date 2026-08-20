# AGENTS/SessionHand-off.md

The essential data and procedures for another agent to continue this
session/context.

- **Generated:** 2026-08-20T01:16:45Z (UTC)
- **Repo:** `aeihou/arenaRepo001`
- **Remote:** `https://github.com/aeihou/arenaRepo001.git`
- **Branch (fixed):** `arena/01a01c09-arenarepo001`

| Item | Value |
|---|---|
| Last pushed commit (at export) | a1e9891 |

Deep-dive companion: [`AGENTS/PortableSessionAI.md`](PortableSessionAI.md).

---

## 1. EBT — before touching anything

**1.1 `Synch(Repo)` (mandatory)** — the working tree sometimes resets to
`main`/`2f643c1` between turns. Always re-sync against the *true* remote tip
(never a stale `origin/<branch>` ref):

```sh
cd /home/user/arenaRepo001
git fetch origin refs/heads/arena/01a01c09-arenarepo001:refs/remotes/origin/arena/01a01c09-arenarepo001
local=$(git rev-parse HEAD)
remote=$(git ls-remote origin refs/heads/arena/01a01c09-arenarepo001 | cut -f1)
[ "$local" = "$remote" ] || git reset --hard "$remote"
```

**1.2 `DescribeMe(auto)`** — self-describe before acting (who / what / how).

---

## 2. The owner's pseudocode → engine (essential mapping)

| Pseudocode | Implementation in `SelfConstructor.sh` |
|---|---|
| `selfConstructor(name)` | `initWorkspace` + `<name>.md` + `README.md` |
| `initSession(README)` / `.SelfDescribe("README.md")` | `writeReadme()` |
| `newSession.Reload()` | `reloadSession()` (guarded re-exec, exported state) |
| `.newFile("X")` | `newFile()` (provenance footer + log) |
| `--NameOfFolder:X` / `mkdir().SelfConstructor("$Name_Folder='X'")` | `mkdir(X)` + self-construct |
| `--auto-name` | `if (Not)nameOfFolder → mkdir("name: ddmmaaaaHHMMSS")` |
| `Actualizar(para todo [nameOfFolder.md] OF README.md)` | `--sync-readmes` |
| `For EveryNewFileConstructor()` | provenance: `## Created by` + `.selfconstructor.log` |
| `Repo.Verify(consistency…dup/outdated/redundant/misplaced)` | `--verify` |
| `self.Consistency.new(verify documentation to scripts)` | `--check-docs` |
| `Repo.Optimize(performance, hand-off timing)` | `--verify` (1 pass) + `--handoff` |
| `Repo.SearchForHardodedVariables().ReplaceFixedHarcodedVariables()` | `--search-hardcoded` + `SELF_*` |
| `Repo.Update(ForEveryFile)` | `--update` |
| `BeforeThinking.MyPrompts.md().Add(new Prompt)` | `--add-prompt TEXT` → `AGENTS/.user/MyPrompts.md` |
| `SelfDescriberRepo().Update({$thisRepo})` | edit `arenaRepo001.md` |
| `AGENTS/agents.md().Update($)` | edit `AGENTS/agents.md` |
| `arena_AI.commitAndPush()` / `Arena_AI.pushAndCommit()` | commit + push |

---

## 3. `SelfConstructor.sh` quick reference

**Flags:** `--dir` · `--name` · `--NameOfFolder` (`:`, `=`, space) ·
`--auto-name` · `--name-sep` · `--sync-readmes` · `--verify` · `--check-docs` ·
`--handoff` · `--search-hardcoded` · `--update` · `--add-prompt` · `--provenance` /
`--no-provenance` · `--filename` · `--readme` · `--force` · `--no-reload` ·
`--quiet` · `--help`.

**Modes:** self-construct (default) · `--sync-readmes` · `--verify` ·
`--check-docs` · `--handoff` · `--search-hardcoded` · `--update` ·
`--add-prompt`.

**Invariants:** POSIX `#!/bin/sh` (`set -eu`), no bash arrays / GNU `grep -o` /
`local` / `[[ ]]`; magic values only in the `SELF_*` Defaults block; idempotent
via `.selfconstructor.rc` (`--force` rebuilds); provenance ON by default.

---

## 4. EAT — after the work

```sh
# keep the repo self-describing:
./SelfConstructor.sh --update          # READMEs + file inventory
./SelfConstructor.sh --handoff         # refresh handoff docs (both)
# then:
git add -A
git commit -m "<message naming the pseudocode directive>"
git push origin arena/01a01c09-arenarepo001
# plus append to AGENTS/session.log  (ExportSession("userPrompt, log.init()"))
```

---

## 5. Current state + gates

- `--verify` → 0 DUPED, 0 OUTDATED, 0 MISPLACED; 4 REDUNDANT (demo workspaces,
  intentionally kept).
- `--check-docs` → green (docs ↔ script consistent).
- `--search-hardcoded` → clean (no literals outside the Defaults block).
- `--update` → file inventory == `git ls-files` count.

---

## 6. Data export (machine-friendly)

```txt
repo=arenaRepo001
remote=https://github.com/aeihou/arenaRepo001.git
branch=arena/01a01c09-arenarepo001
base=main
last_commit=a1e9891
engine=SelfConstructor.sh
self_description=arenaRepo001.md
prompts=AGENTS/.user/MyPrompts.md
agent_registry=AGENTS/agents.md
session_log=AGENTS/session.log
handoff=AGENTS/PortableSessionAI.md
session_handoff=AGENTS/SessionHand-off.md
verify=./SelfConstructor.sh --verify
check_docs=./SelfConstructor.sh --check-docs
search_hardcoded=./SelfConstructor.sh --search-hardcoded
update=./SelfConstructor.sh --update
add_prompt=./SelfConstructor.sh --add-prompt
handoff_refresh=./SelfConstructor.sh --handoff
timestamp_format=ddmmaaaaHHMMSS
```

---

## 7. Top gotchas

1. Sync against `git ls-remote` (fresh refspec), never a stale `origin/<branch>`.
2. Don't let copied `SelfConstructor.sh` drift (run root script with `--dir`).
3. Stay POSIX (no bashisms); keep `--search-hardcoded` clean.
4. `ddmmaaaaHHMMSS` uses a **4-digit year**.
5. Commit messages name the pseudocode directive they implement.
