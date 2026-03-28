#!/usr/bin/env bash
# ci.sh - Run CI pipeline (ShellCheck + Bats + Kcov)
#
# Usage:
#   ./ci.sh              # Run full CI via docker compose (default)
#   ./ci.sh --ci         # Run inside CI container (called by compose)
#   ./ci.sh --lint-only  # Run ShellCheck only (via docker compose)
#   ./ci.sh --coverage   # Run tests + coverage (via docker compose)
#   ./ci.sh -h, --help   # Show this help

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"

# ── Help ─────────────────────────────────────────────────────────────────────

usage() {
    cat >&2 <<'EOF'
Usage: ./ci.sh [OPTIONS]

Run CI pipeline: ShellCheck + Bats unit tests + Kcov coverage.

Options:
  --ci          Run directly inside CI container (called by compose)
  --lint-only   Run ShellCheck only
  --coverage    Run tests with Kcov coverage
  -h, --help    Show this help

Without options, runs the full CI via docker compose.

Examples:
  ./ci.sh                # Full CI (docker compose)
  make test              # Same as above (via Makefile)
  make lint              # ShellCheck only
EOF
    exit 0
}

# ── CI container setup ───────────────────────────────────────────────────────

_install_deps() {
    if ! command -v bats >/dev/null 2>&1; then
        apt-get update -qq
        apt-get install -y --no-install-recommends \
            bats bats-support bats-assert \
            shellcheck git ca-certificates
        git clone --depth 1 -b v1.2.5 \
            https://github.com/jasonkarns/bats-mock /usr/lib/bats/bats-mock
    fi
}

# ── ShellCheck ───────────────────────────────────────────────────────────────

_run_shellcheck() {
    echo "--- Running ShellCheck ---"
    find "${SCRIPT_DIR}" -maxdepth 1 -name "*.sh" -print0 | xargs -0 shellcheck -x
    shellcheck -x "${SCRIPT_DIR}/config/pip/setup.sh"
    shellcheck -x "${SCRIPT_DIR}/config/shell/terminator/setup.sh"
    shellcheck -x "${SCRIPT_DIR}/config/shell/tmux/setup.sh"
}

# ── Bats tests ───────────────────────────────────────────────────────────────

_run_tests() {
    echo "--- Running Bats Unit Tests ---"
    bats "${SCRIPT_DIR}/test/unit/"
}

# ── Kcov coverage ────────────────────────────────────────────────────────────

_run_coverage() {
    echo "--- Running Tests with Kcov Coverage ---"
    kcov \
        --include-path="${SCRIPT_DIR}" \
        --exclude-path="${SCRIPT_DIR}/test/,${SCRIPT_DIR}/config/shell/bashrc,${SCRIPT_DIR}/config/shell/terminator/config,${SCRIPT_DIR}/config/shell/tmux/tmux.conf,${SCRIPT_DIR}/.github/" \
        "${SCRIPT_DIR}/coverage" \
        bats "${SCRIPT_DIR}/test/unit/"
}

# ── Fix coverage permissions ─────────────────────────────────────────────────

_fix_permissions() {
    local uid="${HOST_UID:-}"
    local gid="${HOST_GID:-}"
    if [[ -n "${uid}" && -n "${gid}" && -d "${SCRIPT_DIR}/coverage" ]]; then
        chown -R "${uid}:${gid}" "${SCRIPT_DIR}/coverage"
    fi
}

# ── Docker compose wrapper ───────────────────────────────────────────────────

_run_via_compose() {
    docker compose -f "${SCRIPT_DIR}/compose.yaml" run --rm \
        -e HOST_UID="$(id -u)" \
        -e HOST_GID="$(id -g)" \
        ci
}

# ── Main ─────────────────────────────────────────────────────────────────────

main() {
    local mode="compose"

    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help) usage ;;
            --ci) mode="ci"; shift ;;
            --lint-only) mode="lint"; shift ;;
            --coverage) mode="coverage"; shift ;;
            *) echo "Unknown option: $1" >&2; exit 1 ;;
        esac
    done

    case "${mode}" in
        ci)
            # Running inside container
            _install_deps
            _run_shellcheck
            _run_coverage
            _fix_permissions
            echo "Coverage report: ${SCRIPT_DIR}/coverage/index.html"
            ;;
        lint)
            # ShellCheck only — requires shellcheck installed locally
            _run_shellcheck
            ;;
        coverage)
            # Full CI via docker compose (same as default)
            _run_via_compose
            ;;
        compose)
            # Default: full CI via docker compose
            _run_via_compose
            ;;
    esac
}

main "$@"
