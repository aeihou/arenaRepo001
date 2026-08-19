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
#
# Environment (overridable; CLI wins):
#   SELF_DIR SELF_NAME SELF_FILENAME SELF_README SELF_MARKER SELF_LOG
#   SELF_PROVENANCE SELF_AUTO_NAME SELF_NAME_SEP
# ==============================================================================

set -eu

# ---- Defaults (environment-overridable) -------------------------------------
SELF_DIR="${SELF_DIR:-}"
SELF_NAME="${SELF_NAME:-}"
SELF_FILENAME="${SELF_FILENAME:-}"
SELF_README="${SELF_README:-README.md}"
SELF_MARKER="${SELF_MARKER:-.selfconstructor.rc}"
SELF_LOG="${SELF_LOG:-.selfconstructor.log}"
SELF_PROVENANCE="${SELF_PROVENANCE:-1}"
SELF_AUTO_NAME="${SELF_AUTO_NAME:-0}"
SELF_MKNAME="${SELF_MKNAME:-0}"
SELF_SYNC="${SELF_SYNC:-0}"
SELF_VERIFY="${SELF_VERIFY:-0}"
SELF_CHKDOCS="${SELF_CHKDOCS:-0}"
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
        "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
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
    printf -- '- Timestamp: %s\n' "$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
}

# autoNameIfNeeded()
#   if (Not) nameOfFolder -> mkdir("nameOfFolder: ddmmaaaaHHMMSS")
#   When --auto-name is set and no name was supplied, generate a timestamped
#   folder name "<nameOfFolder><sep><ddmmaaaaHHMMSS>", create that directory,
#   and self-construct it under the generated name ($Name_Folder).
autoNameIfNeeded() {
    [ "$SELF_AUTO_NAME" -eq 1 ] || return 0
    [ -z "$SELF_NAME" ] || return 0
    SELF_NAME="$(nameOfFolder)${SELF_NAME_SEP}$(date +%d%m%Y%H%M%S)"
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
    stamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

    initWorkspace

    # newFile("[nameOfFolder.md]") — the self-description, linked markdown-style
    newFile "$SELF_DIR/$filename" <<EOF
# $name

Self-constructed description of the **$name** workspace.

## Metadata

- Folder: $SELF_DIR
- File: $filename
- Generator: SelfConstructor.sh
- Created: $stamp

## Link

[$name.md]($name.md)

## Rebuild

    ./SelfConstructor.sh --dir "$SELF_DIR" --name "$name"
EOF

    # initSession(README) — written after the self-description so the README's
    # Contents section lists it.
    initSession "$name"
}

# writeReadme(dir, name)
#   (Re)generates the README.md for a single self-described workspace.
writeReadme() {
    d="$1"; name="$2"
    stamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    tmp="$d/.README.tmp.$$"
    {
        printf '# %s\n\n' "$name"
        printf 'Self-described workspace, initialized by `SelfConstructor.sh`.\n\n'
        printf -- '- Folder: %s\n' "$d"
        printf -- '- Self description: [%s.md](%s.md)\n\n' "$name" "$name"
        printf '## Contents\n\n'
        for e in "$d"/*; do
            [ -e "$e" ] || continue
            b=$(basename "$e")
            case "$b" in
                "$SELF_README") continue ;;
            esac
            if [ -d "$e" ]; then
                printf -- '- %s/\n' "$b"
            else
                printf -- '- %s\n' "$b"
            fi
        done
        printf '\n## Last updated\n\n- %s\n\n' "$stamp"
        printf '## Usage\n\n    ./SelfConstructor.sh --help\n'
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
    find "$root" -name .git -prune -o -type d -print | sort \
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
    : > "$dup"; : > "$outd"; : > "$red"; : > "$mis"

    # ---- DUPED: exact content duplicates (identical size + crc) ---------------
    # Runtime artifacts (audit log + first-run marker) are intentionally similar
    # across workspaces and are gitignored, so they are excluded from this scan.
    find "$root" -path '*/.git' -prune -o -path "$out" -prune -o -type f -print \
    | sort \
    | grep -vE '/(\.selfconstructor\.rc|\.selfconstructor\.log)$' \
    | while IFS= read -r f; do cksum "$f"; done \
    | sort -k1,1 -k2,2 \
    | awk '{
        name = $0; sub(/^[^ ]+ [^ ]+ /, "", name)
        key = $1 " " $2
        if (key == prev) { if (!grp) { print prevname; grp = 1 } print name }
        else { prev = key; prevname = name; grp = 0 }
      }' > "$dup"

    # ---- OUTDATED -------------------------------------------------------------
    canon="$root/SelfConstructor.sh"
    if [ -f "$canon" ]; then
        find "$root" -path '*/.git' -prune -o -path "$out" -prune -o \
            -type f -name 'SelfConstructor.sh' -print \
        | while IFS= read -r f; do
            [ "$f" = "$canon" ] && continue
            cmp -s "$f" "$canon" || echo "$f" >> "$outd"
        done
    fi
    find "$root" -path '*/.git' -prune -o -path "$out" -prune -o \
        -type f -name 'README.md' -print \
    | while IFS= read -r f; do
        grep -q '## Contents' "$f" || echo "$f (old template)" >> "$outd"
    done

    # ---- REDUNDANT: generated-only workspaces ---------------------------------
    find "$root" -path '*/.git' -prune -o -path "$out" -prune -o -type d -print \
    | sort \
    | while IFS= read -r d; do
        [ "$d" = "$root" ] && continue
        base=$(basename "$d")
        [ -f "$d/$base.md" ] || continue
        extra=0
        for e in "$d"/* "$d"/.[!.]*; do
            [ -e "$e" ] || continue
            b=$(basename "$e")
            case "$b" in
                "$base.md"|README.md|.selfconstructor.rc|.selfconstructor.log) ;;
                *) extra=1 ;;
            esac
        done
        [ "$extra" -eq 0 ] && echo "$d" >> "$red"
    done

    # ---- MISPLACED: "<folder>.md" convention ----------------------------------
    rootname=$(basename "$root")
    find "$root" -path '*/.git' -prune -o -path "$out" -prune -o \
        -type f -name '*.md' -print \
    | while IFS= read -r f; do
        d=$(dirname "$f"); b=$(basename "$f")
        folder=$(basename "$d")
        case "$b" in
            README.md|agents.md) continue ;;
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
    agents="$root/AGENTS/agents.md"
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
        | grep -vE '^(SELF_MKNAME|SELF_SYNC|SELF_VERIFY|SELF_CHKDOCS|SELF_FORCE|SELF_QUIET|SELF_NO_RELOAD|SELF_RELOADED|SELF_SCRIPT|SELF_ARGV)$' \
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
            esac
            grep -qE "^$fn\(\)" "$script" || echo "  - $fn()"
        done
    else
        say "  (AGENTS/agents.md not found)"
    fi
    say ""
    say "done."
    rm -rf "$tmp"
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
            "created=$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
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
