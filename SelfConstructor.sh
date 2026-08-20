#!/bin/sh
# ==============================================================================
# SelfConstructor.sh — self-executing workspace initializer (a.k.a. constructor.sh)
# ------------------------------------------------------------------------------
# Converts the pseudocode:
#
#     selfConstructor(nameOfFolder().newFile("[nameOfFolder.md]"));
#     newSession.Reload();
#     initWorkspace();
#     initSession(nameOfFolder.newFile.README);
#     if (Not)nameOfFolder then
#         mkdir("nameOfFolder: ddmmaaaaHHMMSS").selfConstructor("$Name_Folder");
#     SelfConstructor.sh --NameOfFolder:MyTest
#     Actualizar(para todo [nameOfFolder.md] OF README.md);
#
# into a parametrizable POSIX sh script. On first run it:
#   1. initWorkspace()   -> ensures the target folder exists
#   2. initSession()     -> writes README.md (the session entry point)
#   3. selfConstructor() -> writes <nameOfFolder>.md (the self-description),
#                           linked markdown-style as [<name>.md](<name>.md)
#   4. reloadSession()   -> newSession.Reload(): re-executes itself so the
#                           freshly built session state is picked up
#   5. autoName()        -> if no name is given, mkdir a timestamped folder
#                           "<nameOfFolder><sep><ddmmaaaaHHMMSS>" and
#                           self-construct it under that name
#   6. mkNameOfFolder()  -> --NameOfFolder NAME: mkdir(NAME) and self-construct
#                           the workspace under that folder name
#   7. syncReadmes()     -> Actualizar(para todo [nameOfFolder.md] OF README.md):
#                           for every folder carrying a <nameOfFolder>.md, (re)generate
#                           its README.md from the current workspace state
#   8. provenance        -> For EveryNewFileConstructor(): every file it creates
#                           keeps the command/script that created it, both as a
#                           footer in the file and as an audit-log line
#                           (.selfconstructor.log, gitignored)
#   9. verify            -> Repo.Verify(consistency().Includes(...)): scans for
#                           DUPED / OUTDATED / REDUNDANT / MISPLACED files
#  10. checkDocs         -> self.Consistency.new(verify documentation to scripts):
#                           cross-checks --help/agents.md docs against the flags,
#                           env vars and primitives the script actually implements
#  11. refreshHandoff    -> Repo.Optimize(performance, hand-off timing): refresh the
#                           volatile fields (Generated + last_commit) of
#                           AGENTS/PortableSessionAI.md from live git state, in a
#                           single pass (no tree walk)
#  12. searchHardcoded   -> Repo.SearchForHardodedVariables(): report literal
#                           occurrences of the parameterized constants. After the
#                           ReplaceFixedHarcodedVariables() refactor they may only
#                           live in the Defaults block (or in comments).
#  13. updateEveryFile   -> Repo.Update(ForEveryFile): re-sync every workspace
#                           README and regenerate a complete file inventory into
#                           the root self-description, so every file is described.
#
# Parameters (CLI wins over environment):
#   positional arg            target directory        (default: $PWD)
#   -d, --dir DIR             target directory        (env: SELF_DIR)
#   -n, --name NAME           override folder name    (env: SELF_NAME)
#       --NameOfFolder NAME   mkdir(NAME) + self-construct it (accepts the
#                             --NameOfFolder:NAME and --NameOfFolder=NAME forms)
#       --auto-name           if no --name given, mkdir a timestamped folder
#       --name-sep SEP        auto-name separator (default "-"; ":" matches the
#                             literal "nameOfFolder: ddmmaaaaHHMMSS" template)
#       --sync-readmes        update every README.md from its <name>.md (batch)
#       --verify              consistency report: duped / outdated / redundant /
#                             misplaced (POSIX, read-only)
#       --check-docs          verify documentation <-> script consistency
#                             (flags, env vars, primitives; POSIX, read-only)
#       --handoff             refresh AGENTS/PortableSessionAI.md volatile fields
#                             (Generated + last_commit) from live git state
#       --search-hardcoded    report literal hardcoded variables in *.sh files
#       --update              Repo.Update(ForEveryFile): re-sync every workspace
#                             README + regenerate the file inventory
#       --provenance          annotate every created file with the command that
#                             made it (default ON; set --no-provenance to disable)
#   -f, --filename FILE       self-description file   (env: SELF_FILENAME)
#       --readme FILE         readme file name        (default: README.md)
#       --force               rebuild even if already constructed
#       --no-reload           skip the session reload
#   -q, --quiet               suppress info output
#   -h, --help                show this help
#
# Examples:
#   ./SelfConstructor.sh
#   ./SelfConstructor.sh --dir /path/to/repo
#   ./SelfConstructor.sh --dir . --name myProject --filename "[myProject].md"
#   ./SelfConstructor.sh --dir SRC --auto-name --name-sep ':'
#   ./SelfConstructor.sh --NameOfFolder:MyTest
#   ./SelfConstructor.sh --sync-readmes
#   ./SelfConstructor.sh --verify
#   ./SelfConstructor.sh --check-docs
#   ./SelfConstructor.sh --handoff
#   ./SelfConstructor.sh --search-hardcoded
#   ./SelfConstructor.sh --update
#
# Environment (overridable; CLI wins):
#   SELF_DIR SELF_NAME SELF_FILENAME SELF_README SELF_MARKER SELF_LOG
#   SELF_PROVENANCE SELF_AUTO_NAME SELF_NAME_SEP
#   SELF_AGENTS_DIR SELF_AGENTS_FILE SELF_HANDOFF_FILE SELF_SESSION_HANDOFF
#   SELF_SCRIPT_NAME SELF_GITDIR SELF_TS_FMT SELF_ISO_FMT
# ==============================================================================

set -eu

# ---- Defaults (environment-overridable) -------------------------------------
SELF_DIR="${SELF_DIR:-}"
SELF_NAME="${SELF_NAME:-}"
SELF_FILENAME="${SELF_FILENAME:-}"
SELF_README="${SELF_README:-README.md}"
SELF_MARKER="${SELF_MARKER:-.selfconstructor.rc}"
SELF_LOG="${SELF_LOG:-.selfconstructor.log}"
SELF_AGENTS_DIR="${SELF_AGENTS_DIR:-AGENTS}"
SELF_AGENTS_FILE="${SELF_AGENTS_FILE:-agents.md}"
SELF_HANDOFF_FILE="${SELF_HANDOFF_FILE:-PortableSessionAI.md}"
SELF_SESSION_HANDOFF="${SELF_SESSION_HANDOFF:-SessionHand-off.md}"
SELF_SCRIPT_NAME="${SELF_SCRIPT_NAME:-SelfConstructor.sh}"
SELF_GITDIR="${SELF_GITDIR:-.git}"
SELF_TS_FMT="${SELF_TS_FMT:-%d%m%Y%H%M%S}"
SELF_ISO_FMT="${SELF_ISO_FMT:-%Y-%m-%dT%H:%M:%SZ}"
SELF_PROVENANCE="${SELF_PROVENANCE:-1}"
SELF_AUTO_NAME="${SELF_AUTO_NAME:-0}"
SELF_MKNAME="${SELF_MKNAME:-0}"
SELF_SYNC="${SELF_SYNC:-0}"
SELF_VERIFY="${SELF_VERIFY:-0}"
SELF_CHKDOCS="${SELF_CHKDOCS:-0}"
SELF_HANDOFF="${SELF_HANDOFF:-0}"
SELF_SEARCH="${SELF_SEARCH:-0}"
SELF_UPDATE="${SELF_UPDATE:-0}"
SELF_NAME_SEP="${SELF_NAME_SEP:--}"
SELF_FORCE="${SELF_FORCE:-0}"
SELF_QUIET="${SELF_QUIET:-0}"
SELF_NO_RELOAD="${SELF_NO_RELOAD:-0}"
SELF_RELOADED="${SELF_RELOADED:-0}"

# ---- Logging -----------------------------------------------------------------
say()  { [ "$SELF_QUIET" -eq 1 ] || printf '%s\n' "$*"; }
warn() { printf '%s\n' "warn: $*" >&2; }
die()  { printf '%s\n' "error: $*" >&2; exit 1; }

# ---- Usage -------------------------------------------------------------------
usage() {
    awk 'NR > 2 {
        if ($0 ~ /^# =+$/) exit
        sub(/^# ?/, "")
        print
    }' "$0"
}

# ---- Pseudocode primitives ---------------------------------------------------
#
# nameOfFolder()
#   Returns the name of the target folder (SELF_NAME if provided, otherwise
#   the basename of the target directory).
nameOfFolder() {
    if [ -n "$SELF_NAME" ]; then
        printf '%s\n' "$SELF_NAME"
    else
        basename "$SELF_DIR"
    fi
}

# invocationCommand()
#   The command (or script) that created the current construction run. Reconstructs
#   "$0 $@" (with args shell-quoted), or falls back to the exported state when the
#   session was reloaded via newSession.Reload().
invocationCommand() {
    if [ -n "${SELF_ARGV+x}" ]; then
        printf '%s' "$SELF_ARGV"
    else
        printf '%s' "$SELF_SCRIPT"
    fi
}

# logCreatedFile(dir, relpath)
#   For EveryNewFileConstructor(): append an audit-log line recording the command
#   that created <dir>/<relpath>. Kept POSIX: a single printf append, no external
#   tools. The log lives at <dir>/.selfconstructor.log (gitignored).
logCreatedFile() {
    [ "$SELF_PROVENANCE" -eq 1 ] || return 0
    d="$1"; rel="$2"
    printf '%s %s via: %s\n' \
        "$(date -u +"$SELF_ISO_FMT")" \
        "$rel" \
        "$(invocationCommand)" >> "$d/$SELF_LOG"
}

# provenanceFooter()
#   Renders the "Created by" block embedded in every file this script writes.
provenanceFooter() {
    [ "$SELF_PROVENANCE" -eq 1 ] || return 0
    printf '\n## Created by\n\n'
    printf -- '- Script: %s\n' "$(basename "$SELF_SCRIPT")"
    printf -- '- Command: %s\n' "$(invocationCommand)"
    printf -- '- Timestamp: %s\n' "$(date -u +"$SELF_ISO_FMT")"
}

# autoNameIfNeeded()
#   if (Not) nameOfFolder -> mkdir("nameOfFolder: ddmmaaaaHHMMSS")
#   When --auto-name is set and no name was supplied, generate a timestamped
#   folder name "<nameOfFolder><sep><ddmmaaaaHHMMSS>", create that directory,
#   and self-construct it under the generated name ($Name_Folder).
autoNameIfNeeded() {
    [ "$SELF_AUTO_NAME" -eq 1 ] || return 0
    [ -z "$SELF_NAME" ] || return 0
    SELF_NAME="$(nameOfFolder)${SELF_NAME_SEP}$(date +"$SELF_TS_FMT")"
    SELF_DIR="$SELF_DIR/$SELF_NAME"
    mkdir -p "$SELF_DIR"
    say "mkdir: $SELF_DIR (auto-name $SELF_NAME)"
}

# newFile(path)
#   Creates a file (and any missing parent directories), writing stdin to it,
#   plus the provenance footer and an audit-log entry (For EveryNewFileConstructor).
newFile() {
    path="$1"
    dir=$(dirname "$path")
    mkdir -p "$dir"
    cat > "$path"
    provenanceFooter >> "$path"
    logCreatedFile "$dir" "$(basename "$path")"
    say "created $path"
}

# initWorkspace()
#   Ensures the workspace directory exists.
initWorkspace() {
    mkdir -p "$SELF_DIR"
    say "workspace: $SELF_DIR"
}

# initSession(name)
#   Creates the session entry point: the README for the folder. Delegates to
#   writeReadme() so every construction path produces the SAME README template
#   (title, folder, self-description link, contents, last-updated, provenance).
initSession() {
    name="$1"
    writeReadme "$SELF_DIR" "$name"
}

# reloadSession()
#   newSession.Reload() — re-executes the script so the freshly built session
#   state is picked up. Guarded so it only reloads once per invocation chain.
reloadSession() {
    [ "$SELF_RELOADED" -eq 0 ] || return 0
    if [ "$SELF_NO_RELOAD" -eq 1 ]; then
        say "session reload skipped (--no-reload)"
        return 0
    fi
    if [ -x "$0" ]; then
        SELF_RELOADED=1
        export SELF_RELOADED
        say "reloading session..."
        exec "$0"
    fi
    warn "cannot re-exec $0 (not executable); session reload skipped"
}

# selfConstructor(name)
#   The main builder: workspace + session + self-description file.
selfConstructor() {
    name="$1"
    filename="${SELF_FILENAME:-${name}.md}"
    stamp=$(date -u +"$SELF_ISO_FMT")

    initWorkspace

    # newFile("[nameOfFolder.md]") — the self-description, linked markdown-style
    newFile "$SELF_DIR/$filename" <<EOF
# $name

Self-constructed description of the **$name** workspace.

## Metadata

- Folder: $SELF_DIR
- File: $filename
- Generator: $SELF_SCRIPT_NAME
- Created: $stamp

## Link

[$name.md]($name.md)

## Rebuild

    ./$SELF_SCRIPT_NAME --dir "$SELF_DIR" --name "$name"
EOF

    # initSession(README) — written after the self-description so the README's
    # Contents section lists it.
    initSession "$name"
}

# writeReadme(dir, name)
#   (Re)generates the README.md for a single self-described workspace.
writeReadme() {
    d="$1"; name="$2"
    stamp=$(date -u +"$SELF_ISO_FMT")
    tmp="$d/.README.tmp.$$"
    {
        printf '# %s\n\n' "$name"
        printf 'Self-described workspace, initialized by `%s`.\n\n' "$SELF_SCRIPT_NAME"
        printf -- '- Folder: %s\n' "$d"
        printf -- '- Self description: [%s.md](%s.md)\n\n' "$name" "$name"
        printf '## Contents\n\n'
        for e in "$d"/*; do
            [ -e "$e" ] || continue
            b=$(basename "$e")
            [ "$b" = "$SELF_README" ] && continue
            if [ -d "$e" ]; then
                printf -- '- %s/\n' "$b"
            else
                printf -- '- %s\n' "$b"
            fi
        done
        printf '\n## Last updated\n\n- %s\n\n' "$stamp"
        printf '## Usage\n\n    ./%s --help\n' "$SELF_SCRIPT_NAME"
        provenanceFooter
    } > "$tmp"
    logCreatedFile "$d" "$SELF_README"
    mv "$tmp" "$d/$SELF_README"
    say "updated $d/$SELF_README"
}

# syncReadmes([root])
#   Actualizar(para todo [nameOfFolder.md] OF README.md)
#   Walks the workspace tree (skipping .git) and, for every folder that carries
#   a <nameOfFolder>.md self-description, (re)generates its README.md.
syncReadmes() {
    root="${1:-$SELF_DIR}"
    [ -n "$root" ] || root="$PWD"
    find "$root" -name "$SELF_GITDIR" -prune -o -type d -print | sort \
    | while IFS= read -r d; do
        name=$(basename "$d")
        selfdesc="$d/$name.md"
        if [ -f "$selfdesc" ]; then
            writeReadme "$d" "$name"
        fi
    done
}

# verify([root])
#   Repo.Verify(consistency().Includes("duped OR outdated OR redundant OR misplaced"))
#   Read-only, POSIX-only consistency report:
#     DUPED      files with identical content (cksum size+crc)
#     OUTDATED   stale SelfConstructor.sh copies; READMEs on the old template
#     REDUNDANT  self-constructed-only workspaces (no custom content)
#     MISPLACED  .md files that break the "<folder>.md" convention
verify() {
    root="${1:-$SELF_DIR}"
    [ -n "$root" ] || root="$PWD"
    [ -d "$root" ] || die "verify: not a directory: $root"

    out="$root/.verify.$$"
    mkdir -p "$out"
    trap 'rm -rf "$out"' 0 1 2 3 15
    dup="$out/dup"; outd="$out/outd"; red="$out/red"; mis="$out/mis"
    files="$out/files"; dirs="$out/dirs"
    : > "$dup"; : > "$outd"; : > "$red"; : > "$mis"

    # ---- Single-pass collection (performance) ----------------------------------
    # Walk the tree exactly twice (files once, dirs once) and run every check
    # against the cached listings instead of re-walking per category.
    find "$root" -name "$SELF_GITDIR" -prune -o -path "$out" -prune -o -type f -print \
    | sort > "$files"
    find "$root" -name "$SELF_GITDIR" -prune -o -path "$out" -prune -o -type d -print \
    | sort > "$dirs"

    # ---- DUPED: exact content duplicates (identical size + crc) ---------------
    # Runtime artifacts (audit log + first-run marker) are intentionally similar
    # across workspaces and are gitignored, so they are excluded from this scan.
    while IFS= read -r f; do
        b=$(basename "$f")
        [ "$b" = "$SELF_MARKER" ] || [ "$b" = "$SELF_LOG" ] || cksum "$f"
    done < "$files" \
    | sort -k1,1 -k2,2 \
    | awk '{
        name = $0; sub(/^[^ ]+ [^ ]+ /, "", name)
        key = $1 " " $2
        if (key == prev) { if (!grp) { print prevname; grp = 1 } print name }
        else { prev = key; prevname = name; grp = 0 }
      }' > "$dup"

    # ---- OUTDATED -------------------------------------------------------------
    canon="$root/$SELF_SCRIPT_NAME"
    if [ -f "$canon" ]; then
        grep "/${SELF_SCRIPT_NAME}\$" "$files" \
        | while IFS= read -r f; do
            [ "$f" = "$canon" ] && continue
            cmp -s "$f" "$canon" || echo "$f" >> "$outd"
        done
    fi
    grep "/${SELF_README}\$" "$files" \
    | while IFS= read -r f; do
        grep -q '## Contents' "$f" || echo "$f (old template)" >> "$outd"
    done

    # ---- REDUNDANT: generated-only workspaces ---------------------------------
    while IFS= read -r d; do
        [ "$d" = "$root" ] && continue
        base=$(basename "$d")
        [ -f "$d/$base.md" ] || continue
        extra=0
        for e in "$d"/* "$d"/.[!.]*; do
            [ -e "$e" ] || continue
            b=$(basename "$e")
            if [ "$b" = "$base.md" ] || [ "$b" = "$SELF_README" ] \
               || [ "$b" = "$SELF_MARKER" ] || [ "$b" = "$SELF_LOG" ]; then
                :
            else
                extra=1
            fi
        done
        [ "$extra" -eq 0 ] && echo "$d" >> "$red"
    done < "$dirs"

    # ---- MISPLACED: "<folder>.md" convention ----------------------------------
    rootname=$(basename "$root")
    grep '\.md$' "$files" \
    | while IFS= read -r f; do
        d=$(dirname "$f"); b=$(basename "$f")
        folder=$(basename "$d")
        if [ "$b" = "$SELF_README" ] || [ "$b" = "$SELF_AGENTS_FILE" ] \
           || [ "$b" = "$SELF_HANDOFF_FILE" ] || [ "$b" = "$SELF_SESSION_HANDOFF" ]; then
            continue
        fi
        case "$b" in
            [0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9].md) continue ;;
        esac
        if [ "$folder" = "." ] || [ -z "$folder" ]; then folder="$rootname"; fi
        [ "$b" = "$folder.md" ] || echo "$f (expected $folder/$folder.md)" >> "$mis"
    done

    # ---- Report ----------------------------------------------------------------
    report() {
        title="$1"; file="$2"
        say "== $title =="
        if [ -s "$file" ]; then
            sed 's/^/  - /' "$file"
        else
            say "  (none)"
        fi
        say ""
    }
    say "Repo.Verify — consistency scan of $root"
    say ""
    report "DUPED"      "$dup"
    report "OUTDATED"   "$outd"
    report "REDUNDANT"  "$red"
    report "MISPLACED"  "$mis"

    n=$(( $(wc -l < "$dup") + $(wc -l < "$outd") + $(wc -l < "$red") + $(wc -l < "$mis") ))
    if [ "$n" -eq 0 ]; then
        say "consistency: OK — no duped / outdated / redundant / misplaced items."
    else
        say "consistency: $n finding(s) across categories (see above)."
    fi
    rm -rf "$out"
    trap - 0 1 2 3 15
}

# tokens() — POSIX token extractor: emits every match of a regex found in stdin,
# one per line (awk match()+RSTART/RLENGTH; no GNU grep -o).
tokens() {
    re="$1"
    awk -v re="$re" '{
        while (match($0, re)) { print substr($0, RSTART, RLENGTH); $0 = substr($0, RSTART+RLENGTH) }
    }'
}

# checkDocs([root])
#   self.Consistency.new("verify documentation to scripts")
#   Read-only, POSIX-only cross-check between the documentation and the script:
#     1. FLAGS:      --flags documented in the --help header vs those actually
#                    handled by parse_args()
#     2. ENV:        SELF_* variables used by the script vs documented in the
#                    header (internal state vars are excluded by contract)
#     3. PRIMITIVES: primitives documented in AGENTS/agents.md vs function
#                    definitions in the script (pseudocode aliases mapped)
checkDocs() {
    root="${1:-$SELF_DIR}"
    [ -n "$root" ] || root="$PWD"
    script="$0"
    agents="$root/$SELF_AGENTS_DIR/$SELF_AGENTS_FILE"
    tmp="$root/.checkdocs.$$"
    mkdir -p "$tmp"
    trap 'rm -rf "$tmp"' 0 1 2 3 15
    hdr="$tmp/hdr"; prs="$tmp/prs"

    # header (the --help text) and the parse_args() body
    awk 'NR > 2 { if ($0 ~ /^# =+$/) exit; print }' "$script" > "$hdr"
    sed -n '/^parse_args()/,/^}/p' "$script" > "$prs"

    tokens '--[A-Za-z][A-Za-z-]*' < "$hdr" | sort -u > "$tmp/flags_doc"
    tokens '--[A-Za-z][A-Za-z-]*' < "$prs" | sort -u > "$tmp/flags_impl"

    tokens 'SELF_[A-Z_]+' < "$hdr" | sort -u > "$tmp/env_doc"
    tokens 'SELF_[A-Z_]+' < "$script" \
        | grep -vE '^(SELF_MKNAME|SELF_SYNC|SELF_VERIFY|SELF_CHKDOCS|SELF_HANDOFF|SELF_SEARCH|SELF_UPDATE|SELF_FORCE|SELF_QUIET|SELF_NO_RELOAD|SELF_RELOADED|SELF_SCRIPT|SELF_ARGV)$' \
        | sort -u > "$tmp/env_impl"

    say "Self.Consistency — documentation <-> script ($script)"
    say ""
    say "== FLAGS: documented but not implemented =="
    comm -23 "$tmp/flags_doc" "$tmp/flags_impl" | sed 's/^/  - /'
    say ""
    say "== FLAGS: implemented but not documented =="
    comm -13 "$tmp/flags_doc" "$tmp/flags_impl" | sed 's/^/  - /'
    say ""
    say "== ENV: documented but not used =="
    comm -23 "$tmp/env_doc" "$tmp/env_impl" | sed 's/^/  - /'
    say ""
    say "== ENV: used but not documented =="
    comm -13 "$tmp/env_doc" "$tmp/env_impl" | sed 's/^/  - /'
    say ""
    say "== PRIMITIVES: documented in agents.md but not defined =="
    if [ -f "$agents" ]; then
        awk '/Pseudocode primitives:/{on=1} on{print} on && /Lifecycle:/{exit}' "$agents" \
        | tokens '[A-Za-z_][A-Za-z0-9_]*\(\)' \
        | sed 's/()$//' \
        | sort -u \
        | while IFS= read -r fn; do
            # documented pseudocode -> implemented function alias table
            case "$fn" in
                Reload)                  fn=reloadSession ;; # newSession.Reload()
                EveryNewFileConstructor) fn=newFile ;;       # For EveryNewFileConstructor()
                consistency)             fn=verify ;;        # Repo.Verify(consistency())
                SearchForHardodedVariables)    fn=searchHardcoded ;; # Repo.SearchForHardodedVariables()
                ReplaceFixedHarcodedVariables) fn=searchHardcoded ;; # ...ReplaceFixedHarcodedVariables()
            esac
            grep -qE "^$fn\(\)" "$script" || echo "  - $fn()"
        done
    else
        say "  ($SELF_AGENTS_DIR/$SELF_AGENTS_FILE not found)"
    fi
    say ""
    say "done."
    rm -rf "$tmp"
    trap - 0 1 2 3 15
}

# refreshHandoff([root])
#   Repo.Optimize(performance, hand-off timing)
#   Refreshes the volatile fields of AGENTS/PortableSessionAI.md in a single pass
#   (one git rev-parse + one date + one sed), so the hand-off document always
#   records the baseline tip without re-walking the tree:
#     - "Generated"       -> now (UTC)
#     - "last_commit"     -> current HEAD short hash
#     - "Last pushed commit (at export)" table cell -> current HEAD short hash
refreshHandoff() {
    root="${1:-$SELF_DIR}"
    [ -n "$root" ] || root="$PWD"
    stamp=$(date -u +"$SELF_ISO_FMT")
    short=$( (cd "$root" && git rev-parse --short HEAD) 2>/dev/null || printf '%s' "unknown" )
    for hf in \
        "$root/$SELF_AGENTS_DIR/$SELF_HANDOFF_FILE" \
        "$root/$SELF_AGENTS_DIR/$SELF_SESSION_HANDOFF" ; do
        [ -f "$hf" ] || continue
        tmp="$hf.tmp.$$"
        sed \
            -e "s|^- \\*\\*Generated:\\*\\* .*|- **Generated:** ${stamp} (UTC)|" \
            -e "s|^last_commit=.*|last_commit=${short}|" \
            -e "s#^| Last pushed commit (at export) | .*#| Last pushed commit (at export) | ${short} |#" \
            "$hf" > "$tmp"
        mv "$tmp" "$hf"
        say "handoff refreshed: $hf"
    done
    say "  generated  : $stamp"
    say "  last_commit: $short"
}

# searchHardcoded([root])
#   Repo.SearchForHardodedVariables()
#   Read-only, POSIX-only scan of every *.sh file under root for literal
#   occurrences of the values that must stay parameterized (see the Defaults
#   block). A value may appear literally only as a SELF_* default assignment or
#   inside a comment; anywhere else it is a hardcoded variable to replace.
searchHardcoded() {
    root="${1:-$SELF_DIR}"
    [ -n "$root" ] || root="$PWD"
    script=$(cd "$(dirname "$0")" && pwd)/$(basename "$0")
    s=$(grep -n '^# <<<search-tokens' "$script" | cut -d: -f1 | head -1)
    e=$(grep -n '^# >>>search-tokens' "$script" | cut -d: -f1 | head -1)
    [ -n "$s" ] || s=0
    [ -n "$e" ] || e=0
    report="$root/.search.$$"
    : > "$report"
    say "Repo.SearchForHardodedVariables — literal scan under $root"
    say ""
# <<<search-tokens
    TOKENS='.selfconstructor.rc
.selfconstructor.log
README.md
SelfConstructor.sh
AGENTS/agents.md
AGENTS/PortableSessionAI.md
SessionHand-off.md
%d%m%Y%H%M%S
%Y-%m-%dT%H:%M:%SZ'
# >>>search-tokens
    find "$root" -name "$SELF_GITDIR" -prune -o -type f -name '*.sh' -print \
    | while IFS= read -r f; do
        printf '%s\n' "$TOKENS" | while IFS= read -r tok; do
            [ -n "$tok" ] || continue
            echo "== $tok ==" >> "$report"
            grep -nF "$tok" "$f" \
            | awk -v file="$f" -v me="$script" -v s="$s" -v e="$e" '
                {
                    num = $0; sub(/:.*/, "", num)
                    rest = $0; sub(/^[0-9]+:/, "", rest)
                    if (file == me && num+0 >= s+0 && num+0 <= e+0) next
                    if (rest ~ /^[[:space:]]*#/) next
                    if (rest ~ /^SELF_[A-Z_]*=/) next
                    print "  - " file ":" $0
                }' >> "$report"
        done
    done
    cat "$report"
    n=$(grep -c '^  - ' "$report" 2>/dev/null || true)
    if [ "$n" -eq 0 ]; then
        say "result: no hardcoded literals remain outside the Defaults block."
    else
        say "result: $n hardcoded literal(s) to replace (see above)."
    fi
    rm -f "$report"
}

# classifyFile(basename, dirname, foldername)
#   Maps a file to a short inventory type (kept as a case-less echo).
classifyFile() {
    b="$1"; d="$2"; folder="$3"
    case "$b" in
        *.sh)                          printf 'script' ;;
        "$SELF_README")                printf 'session entry point' ;;
        .gitignore)                    printf 'configuration' ;;
        "$SELF_AGENTS_FILE")           printf 'agent registry' ;;
        "$SELF_HANDOFF_FILE")          printf 'portable session export' ;;
        "$SELF_SESSION_HANDOFF")       printf 'session hand-off' ;;
        session.log)                   printf 'session log' ;;
        [0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9].md)
                                       printf 'timestamped snapshot' ;;
        *.md)
            if [ "$b" = "$folder.md" ]; then printf 'self-description'
            else printf 'documentation'; fi ;;
        *)                             printf 'asset' ;;
    esac
}

# injectInventory(target, inventory)
#   Inserts (or replaces, between markers) the generated file-inventory section
#   into a markdown document. POSIX awk, no GNU extensions.
injectInventory() {
    target="$1"; inv="$2"; itmp="$target.itmp.$$"
    if grep -q '^<!-- file-inventory:start -->' "$target"; then
        awk -v inv="$inv" '
            /^<!-- file-inventory:start -->/ { print; while ((getline line < inv) > 0) print line; close(inv); insection = 1; next }
            /^<!-- file-inventory:end -->/ { insection = 0; print; next }
            insection { next }
            { print }
        ' "$target" > "$itmp"
    elif grep -q '^## Rebuild' "$target"; then
        awk -v inv="$inv" '
            /^## Rebuild/ {
                print "<!-- file-inventory:start -->"
                while ((getline line < inv) > 0) print line
                close(inv)
                print "<!-- file-inventory:end -->"
                print ""
                print
                next
            }
            { print }
        ' "$target" > "$itmp"
    else
        {
            cat "$target"
            printf '\n<!-- file-inventory:start -->\n'
            cat "$inv"
            printf '<!-- file-inventory:end -->\n'
        } > "$itmp"
    fi
    mv "$itmp" "$target"
}

# updateEveryFile([root])
#   Repo.Update(ForEveryFile)
#   1. Re-syncs every workspace README from its <name>.md (current state).
#   2. Builds a complete inventory of every file under root (excluding .git and
#      runtime artifacts), classifying it and attaching the command that created
#      it (from the nearest .selfconstructor.log, else "committed").
#   3. Injects that inventory into the root self-description (<rootname>.md).
updateEveryFile() {
    root="${1:-$SELF_DIR}"
    [ -n "$root" ] || root="$PWD"
    selfdesc="$root/$(basename "$root").md"
    [ -f "$selfdesc" ] || die "update: self-description not found: $selfdesc"

    utmp="$root/.update.$$"
    mkdir -p "$utmp"
    trap 'rm -rf "$utmp"' 0 1 2 3 15
    uinv="$utmp/inventory"

    # 1. every workspace README up to date
    syncReadmes "$root"

    # 2. complete file inventory
    {
        printf '## File inventory (ForEveryFile)\n\n'
        printf 'Every file in the repository, auto-generated by `Repo.Update(ForEveryFile)`.\n\n'
        printf '| File | Type | Created by |\n|---|---|---|\n'
        find "$root" -name "$SELF_GITDIR" -prune -o -path "$utmp" -prune -o -type f -print \
        | sort \
        | while IFS= read -r f; do
            b=$(basename "$f")
            case "$b" in
                "$SELF_MARKER"|"$SELF_LOG") continue ;;
            esac
            rel=${f#"$root"/}
            folder=$(basename "$(dirname "$f")")
            type=$(classifyFile "$b" "$(dirname "$f")" "$folder")
            prov="committed"
            d=$(dirname "$f")
            while : ; do
                if [ -f "$d/$SELF_LOG" ]; then
                    p=$(grep -F "$b via:" "$d/$SELF_LOG" 2>/dev/null | tail -1 | sed 's/^.* via: //')
                    [ -n "$p" ] && prov="$p"
                    break
                fi
                [ "$d" = "$root" ] && break
                [ "$d" = "/" ] && break
                d=$(dirname "$d")
            done
            printf '| `%s` | %s | %s |\n' "$rel" "$type" "$prov"
        done
        printf '\n_Generated %s (%s)._ \n' "$(date -u +"$SELF_ISO_FMT")" "$SELF_SCRIPT_NAME"
    } > "$uinv"

    # 3. inject into the root self-description
    injectInventory "$selfdesc" "$uinv"

    count=$(grep -c '^| `' "$uinv")
    say "updated: $selfdesc"
    say "inventory: $count file(s) described"
    rm -rf "$utmp"
    trap - 0 1 2 3 15
}

# ---- Argument parsing ---------------------------------------------------------
parse_args() {
    while [ "$#" -gt 0 ]; do
        case "$1" in
            -h|--help)       usage; exit 0 ;;
            -d|--dir)        [ "$#" -ge 2 ] || die "missing value for $1"; SELF_DIR="$2"; shift 2 ;;
            --dir=*)         SELF_DIR="${1#*=}"; shift ;;
            -n|--name)       [ "$#" -ge 2 ] || die "missing value for $1"; SELF_NAME="$2"; shift 2 ;;
            --name=*)        SELF_NAME="${1#*=}"; shift ;;
            --NameOfFolder)      [ "$#" -ge 2 ] || die "missing value for $1"; SELF_NAME="$2"; SELF_MKNAME=1; shift 2 ;;
            --NameOfFolder=*)    SELF_NAME="${1#*=}"; SELF_MKNAME=1; shift ;;
            --NameOfFolder:*)    SELF_NAME="${1#*:}"; SELF_MKNAME=1; shift ;;
            --auto-name)     SELF_AUTO_NAME=1; shift ;;
            --sync-readmes)  SELF_SYNC=1; shift ;;
            --verify)        SELF_VERIFY=1; shift ;;
            --check-docs)    SELF_CHKDOCS=1; shift ;;
            --handoff)       SELF_HANDOFF=1; shift ;;
            --search-hardcoded) SELF_SEARCH=1; shift ;;
            --update)        SELF_UPDATE=1; shift ;;
            --provenance)    SELF_PROVENANCE=1; shift ;;
            --no-provenance) SELF_PROVENANCE=0; shift ;;
            --name-sep)      [ "$#" -ge 2 ] || die "missing value for $1"; SELF_NAME_SEP="$2"; shift 2 ;;
            --name-sep=*)    SELF_NAME_SEP="${1#*=}"; shift ;;
            -f|--filename)   [ "$#" -ge 2 ] || die "missing value for $1"; SELF_FILENAME="$2"; shift 2 ;;
            --filename=*)    SELF_FILENAME="${1#*=}"; shift ;;
            --readme)        [ "$#" -ge 2 ] || die "missing value for $1"; SELF_README="$2"; shift 2 ;;
            --force)         SELF_FORCE=1; shift ;;
            --no-reload)     SELF_NO_RELOAD=1; shift ;;
            -q|--quiet)      SELF_QUIET=1; shift ;;
            --)              shift; break ;;
            -*)              die "unknown option: $1 (try --help)" ;;
            *)               break ;;
        esac
    done

    # First positional argument = target directory
    if [ "$#" -gt 0 ]; then
        SELF_DIR="$1"
        shift
    fi
    [ "$#" -eq 0 ] || die "unexpected argument: $1"
}

# ---- Main ----------------------------------------------------------------------
main() {
    parse_args "$@"

    # Capture the command/script that is creating this run (For EveryNewFileConstructor).
    # Defaults are inherited from an exported state on newSession.Reload().
    SELF_SCRIPT="${SELF_SCRIPT:-$0}"
    if [ "$#" -gt 0 ]; then
        q=
        for a in "$@"; do
            case "$a" in
                *' '*|*'"'*|*"'"*) a=$(printf '%s' "$a" | sed "s/'/'\\\\''/g"); q="$q '$a'" ;;
                *) q="$q $a" ;;
            esac
        done
        SELF_ARGV="$SELF_SCRIPT$q"
    else
        SELF_ARGV="${SELF_ARGV:-$SELF_SCRIPT}"
    fi
    export SELF_SCRIPT SELF_ARGV

    [ -n "$SELF_DIR" ] || SELF_DIR="$PWD"
    mkdir -p "$SELF_DIR"
    SELF_DIR=$(cd "$SELF_DIR" && pwd)

    # Repo.Optimize(performance, hand-off timing)
    if [ "$SELF_HANDOFF" -eq 1 ]; then
        refreshHandoff "$SELF_DIR"
        exit 0
    fi

    # Repo.SearchForHardodedVariables()
    if [ "$SELF_SEARCH" -eq 1 ]; then
        searchHardcoded "$SELF_DIR"
        exit 0
    fi

    # Repo.Update(ForEveryFile)
    if [ "$SELF_UPDATE" -eq 1 ]; then
        updateEveryFile "$SELF_DIR"
        exit 0
    fi

    # self.Consistency.new(verify documentation to scripts)
    if [ "$SELF_CHKDOCS" -eq 1 ]; then
        checkDocs "$SELF_DIR"
        exit 0
    fi

    # Repo.Verify(consistency().Includes(...))
    if [ "$SELF_VERIFY" -eq 1 ]; then
        verify "$SELF_DIR"
        exit 0
    fi

    # Actualizar(para todo [nameOfFolder.md] OF README.md)
    if [ "$SELF_SYNC" -eq 1 ]; then
        syncReadmes "$SELF_DIR"
        exit 0
    fi

    # if (Not) nameOfFolder -> mkdir("nameOfFolder: ddmmaaaaHHMMSS")
    autoNameIfNeeded

    # --NameOfFolder NAME -> mkdir(NAME) and self-construct it there
    if [ "$SELF_MKNAME" -eq 1 ]; then
        SELF_DIR="$SELF_DIR/$SELF_NAME"
        mkdir -p "$SELF_DIR"
        SELF_DIR=$(cd "$SELF_DIR" && pwd)
        say "mkdir: $SELF_DIR (NameOfFolder $SELF_NAME)"
    fi

    export SELF_DIR SELF_NAME SELF_QUIET SELF_SCRIPT SELF_ARGV SELF_PROVENANCE SELF_LOG

    if [ "$SELF_RELOADED" -eq 0 ]; then
        if [ -f "$SELF_DIR/$SELF_MARKER" ] && [ "$SELF_FORCE" -eq 0 ]; then
            say "already constructed: $SELF_DIR (use --force to rebuild)"
            exit 0
        fi

        name=$(nameOfFolder)
        selfConstructor "$name"

        printf '%s\n' \
            "name=$name" \
            "dir=$SELF_DIR" \
            "created=$(date -u +"$SELF_ISO_FMT")" \
            > "$SELF_DIR/$SELF_MARKER"

        reloadSession
    fi

    if [ "$SELF_NO_RELOAD" -eq 1 ]; then
        say "workspace ready at $SELF_DIR"
    else
        say "session reloaded — workspace ready at $SELF_DIR"
    fi
}

main "$@"
