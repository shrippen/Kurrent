#!/usr/bin/env bash
# Uninstall Kurrent plasmoid + QML plugin from the user's prefix.
# Removes everything installed by install.sh and install-linux.sh.
set -Eeuo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PREFIX="${PREFIX:-${HOME}/.local}"
DRY_RUN=false
SKIP_RESTART=false

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

info()  { echo -e "${GREEN}[INFO]${NC} $*" >&2; }
warn()  { echo -e "${YELLOW}[WARN]${NC} $*" >&2; }
error() { echo -e "${RED}[ERROR]${NC} $*" >&2; }

usage() {
    cat <<EOF >&2
Usage: $0 [OPTIONS]

Uninstall Kurrent (Plasma 6 widget + Akonadi plugin) from \$PREFIX.

Options:
  --dry-run          Show what would be removed without actually removing anything
  --no-restart       Do not restart plasmashell after uninstall
  -h, --help         Show this help
EOF
}

parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --dry-run)
                DRY_RUN=true
                shift
                ;;
            --no-restart)
                SKIP_RESTART=true
                shift
                ;;
            -h|--help)
                usage
                exit 0
                ;;
            *)
                error "Unknown option: $1"
                usage
                exit 1
                ;;
        esac
    done
}

remove() {
    local target="$1"
    if [[ "$DRY_RUN" == true ]]; then
        if [[ -e "$target" ]]; then
            echo "  [DRY-RUN] would remove: $target"
        else
            echo "  [DRY-RUN] would remove (not found): $target"
        fi
        return 0
    fi
    if [[ -e "$target" ]]; then
        rm -rf "$target"
        info "Removed: $target"
    fi
}

remove_dir_if_empty() {
    local dir="$1"
    if [[ "$DRY_RUN" == true ]]; then
        return 0
    fi
    if [[ -d "$dir" ]] && rmdir "$dir" 2>/dev/null; then
        info "Removed (empty): $dir"
    fi
}

restart_plasmashell() {
    if [[ "$SKIP_RESTART" == true ]] || ! command -v plasmashell >/dev/null 2>&1; then
        return 0
    fi
    if ! pgrep -x plasmashell >/dev/null 2>&1; then
        info "plasmashell is not running; skipping restart."
        return 0
    fi
    info "Restarting plasmashell..."
    kquitapp6 plasmashell 2>/dev/null || true
    sleep 1
    nohup plasmashell --replace >/dev/null 2>&1 &
    disown >/dev/null 2>&1 || true
    info "plasmashell restarted."
}

main() {
    parse_args "$@"

    echo ""
    info "Kurrent uninstaller"
    echo ""
    if [[ "$DRY_RUN" == true ]]; then
        warn "Dry-run mode -- nothing will be removed."
        echo ""
    fi

    # 1. Unregister plasmoid via kpackagetool6
    PLASMOID_ID="com.github.shrippen.kurrent"
    if command -v kpackagetool6 >/dev/null 2>&1; then
        if kpackagetool6 -t Plasma/Applet -r "$PLASMOID_ID" 2>/dev/null; then
            info "Unregistered plasmoid: $PLASMOID_ID"
        else
            info "Plasmoid $PLASMOID_ID was not registered (or kpackagetool6 failed)."
        fi
    else
        warn "kpackagetool6 not found; skipping plasmoid unregistration."
    fi

# Clean up old / alternative plasmoid IDs (exact paths from install.sh)
    for _old_id in org.planify.plasmoid org.kde.kurrent; do
        if command -v kpackagetool6 >/dev/null 2>&1; then
            kpackagetool6 -t Plasma/Applet -r "$_old_id" 2>/dev/null || true
        fi
        remove "${PREFIX}/share/plasma/plasmoids/${_old_id}"
    done
    # QML plugin paths for old IDs (directory names differ from plasmoid IDs)
    remove "${PREFIX}/lib/qml/org/planify"
    remove "${PREFIX}/share/qt6/qml/org/planify"
    remove "${PREFIX}/lib/qml/org/kde/kurrent"
    remove "${PREFIX}/share/qt6/qml/org/kde/kurrent"

    # 3. Remove QML plugin (libkurrentplugin.so + qmldir)
    remove "${PREFIX}/lib/qml/com/github/shrippen/kurrent"
    remove "${PREFIX}/share/qt6/qml/com/github/shrippen/kurrent"
    remove_dir_if_empty "${PREFIX}/lib/qml/com/github/shrippen"
    remove_dir_if_empty "${PREFIX}/lib/qml/com/github"
    remove_dir_if_empty "${PREFIX}/lib/qml/com"
    remove_dir_if_empty "${PREFIX}/share/qt6/qml/com/github/shrippen"
    remove_dir_if_empty "${PREFIX}/share/qt6/qml/com/github"
    remove_dir_if_empty "${PREFIX}/share/qt6/qml/com"

    # 4. Remove plasmoid files
    remove "${PREFIX}/share/plasma/plasmoids/com.github.shrippen.kurrent"
    remove_dir_if_empty "${PREFIX}/share/plasma/plasmoids"

    # 5. Remove icon
    remove "${PREFIX}/share/icons/hicolor/scalable/apps/kurrent.svg"
    remove_dir_if_empty "${PREFIX}/share/icons/hicolor/scalable/apps"
    remove_dir_if_empty "${PREFIX}/share/icons/hicolor/scalable"
    remove_dir_if_empty "${PREFIX}/share/icons/hicolor"

    # 6. Remove notifications
    remove "${PREFIX}/share/knotifications6/kurrent.notifyrc"
    remove_dir_if_empty "${PREFIX}/share/knotifications6"

    # 7. Remove translations
    while IFS= read -r -d '' mo; do
        remove "$mo"
        lc_dir="$(dirname "$mo")"
        remove_dir_if_empty "$lc_dir"
        lang_dir="$(dirname "$lc_dir")"
        remove_dir_if_empty "$lang_dir"
        share_locale="$(dirname "$lang_dir")"
        remove_dir_if_empty "$share_locale"
    done < <(find "${PREFIX}/share/locale" -name 'plasma_applet_com.github.shrippen.kurrent.mo' -print0 2>/dev/null || true)

    # 8. Remove QML import path helper
    remove "${HOME}/.config/plasma-workspace/env/kurrent-qml.sh"
    remove_dir_if_empty "${HOME}/.config/plasma-workspace/env"
    remove_dir_if_empty "${HOME}/.config/plasma-workspace"

    # 9. Remove user configuration (ask before wiping settings)
    CONFIG_DIR="${HOME}/.config/com.github.shrippen.kurrent"
    if [[ -d "$CONFIG_DIR" ]]; then
        echo ""
        warn "User configuration directory found: ${CONFIG_DIR}"
        if [[ "$DRY_RUN" == true ]]; then
            echo "  [DRY-RUN] would prompt to remove: ${CONFIG_DIR}"
        else
            echo "This stores your Kurrent settings (sort mode, sidebar layout, etc.)."
            read -r -p "Remove it? [y/N] " REPLY
            if [[ "$REPLY" =~ ^[yY] ]]; then
                remove "$CONFIG_DIR"
                remove_dir_if_empty "$(dirname "$CONFIG_DIR")"
            else
                info "Keeping: ${CONFIG_DIR}"
            fi
        fi
    fi

    echo ""

    if [[ "$DRY_RUN" == false ]]; then
        info "Uninstall complete."
        restart_plasmashell
    else
        warn "Dry-run complete. Re-run without --dry-run to actually uninstall."
    fi
}

main "$@"
