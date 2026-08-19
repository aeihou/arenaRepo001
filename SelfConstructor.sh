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
#
# into a parametrizable POSIX sh script. On first run it:
#   1. initWorkspace()   -> ensures the target folder exists
#   2. initSession()     -> writes README.md (the session entry point)
#   3. selfConstructor() -> writes <nameOfFolder>.md (the self-description),
#                           linked markdown-style as [<name>.md](<name>.md)
#   4. reloadSession()   -> newSession.Reload(): re-executes itself so the
#                           freshly built session state is picked up
#
# Parameters (CLI wins over environment):
#   positional arg            target directory        (default: $PWD)
#   -d, --dir DIR             target directory        (env: SELF_DIR)
#   -n, --name NAME           override folder name    (env: SELF_NAME)
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
# ==============================================================================

set -eu

# ---- Defaults (environment-overridable) -------------------------------------
SELF_DIR="${SELF_DIR:-}"
SELF_NAME="${SELF_NAME:-}"
SELF_FILENAME="${SELF_FILENAME:-}"
SELF_README="${SELF_README:-README.md}"
SELF_MARKER="${SELF_MARKER:-.selfconstructor.rc}"
SELF_FORCE=0
SELF_QUIET=0
SELF_NO_RELOAD=0
SELF_RELOADED="${SELF_RELOADED:-0}"

# ---- Logging -----------------------------------------------------------------
say()  { [ "$SELF_QUIET" -eq 1 ] || printf '%s\n' "$*"; }
warn() { printf '%s\n' "warn: $*" >&2; }
die()  { printf '%s\n' "error: $*" >&2; exit 1; }

# ---- Usage -------------------------------------------------------------------
usage() {
    sed -n '2,35p' "$0" | sed 's/^# \{0,1\}//'
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

# newFile(path)
#   Creates a file (and any missing parent directories), writing stdin to it.
newFile() {
    path="$1"
    dir=$(dirname "$path")
    mkdir -p "$dir"
    cat > "$path"
    say "created $path"
}

# initWorkspace()
#   Ensures the workspace directory exists.
initWorkspace() {
    mkdir -p "$SELF_DIR"
    say "workspace: $SELF_DIR"
}

# initSession(name)
#   Creates the session entry point: the README for the folder.
initSession() {
    name="$1"
    newFile "$SELF_DIR/$SELF_README" <<EOF
# $name

Self-described repository, initialized by \`SelfConstructor.sh\`.

- Folder: $SELF_DIR
- Self description: [$name.md]($name.md)

## Usage

    ./SelfConstructor.sh --help
EOF
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
        exec "$0" "$@"
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
    initSession "$name"

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

    [ -n "$SELF_DIR" ] || SELF_DIR="$PWD"
    mkdir -p "$SELF_DIR"
    SELF_DIR=$(cd "$SELF_DIR" && pwd)

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

        reloadSession "$@"
    fi

    if [ "$SELF_NO_RELOAD" -eq 1 ]; then
        say "workspace ready at $SELF_DIR"
    else
        say "session reloaded — workspace ready at $SELF_DIR"
    fi
}

main "$@"
