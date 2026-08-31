#!/usr/bin/env bash
# Kurrent — install widget + Akonadi QML plugin to the user's ~/.local
#
# Downloads the prebuilt plugin tarball from GitHub Releases (same layout as
# cmake --install PREFIX=~/.local). Compiles from source only with --from-source
# or if no binary exists for this architecture.
#
#   curl -fsSL https://github.com/shrippen/Kurrent/releases/latest/download/install-linux.sh | sudo bash
#
set -Eeuo pipefail

REPO="${KURRENT_REPO:-shrippen/Kurrent}"
DEFAULT_GIT_REF="${KURRENT_GIT_REF:-1.0}"
INSTALLER_URL="https://github.com/${REPO}/releases/latest/download/install-linux.sh"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

FROM_SOURCE=false
FROM_GIT=false
GIT_REF="$DEFAULT_GIT_REF"
TAG=""
SKIP_DEPS=false
SKIP_RESTART=false
WORKDIR=""
SRC=""
LOCAL_SRC=""

trap 'echo -e "${RED}Installation failed at line $LINENO${NC}" >&2' ERR

info() { echo -e "${GREEN}[INFO]${NC} $*" >&2; }
warn() { echo -e "${YELLOW}[WARN]${NC} $*" >&2; }
error() { echo -e "${RED}[ERROR]${NC} $*" >&2; }

cleanup() {
    if [[ -n "$WORKDIR" && -d "$WORKDIR" && "${KURRENT_KEEP_SRC:-0}" != "1" ]]; then
        rm -rf "$WORKDIR"
    fi
}

usage() {
    cat <<EOF >&2
Usage: $0 [OPTIONS]

Install Kurrent (Plasma 6 widget + Akonadi plugin) to ~/.local.

Options:
  --from-source      Compile from the GitHub source tarball instead of the binary
  --from-git         Clone git and compile (implies --from-source)
  --branch NAME      Git branch or tag to clone (implies --from-git; default: ${DEFAULT_GIT_REF})
  --tag TAG          Use a specific release (binary or source), e.g. v0.3
  --no-deps          Do not install distro packages
  --no-restart       Do not restart plasmashell
  -h, --help         Show this help

Examples:
  curl -fsSL ${INSTALLER_URL} | sudo bash
  curl -fsSL ${INSTALLER_URL} | bash -s -- --tag v0.3
  curl -fsSL ${INSTALLER_URL} | bash -s -- --from-source
EOF
}

parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --from-source)
                FROM_SOURCE=true
                shift
                ;;
            --from-git)
                FROM_GIT=true
                FROM_SOURCE=true
                shift
                ;;
            --branch)
                FROM_GIT=true
                FROM_SOURCE=true
                GIT_REF="${2:?--branch needs a name}"
                shift 2
                ;;
            --tag)
                TAG="${2:?--tag needs a name}"
                shift 2
                ;;
            --no-deps)
                SKIP_DEPS=true
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

asset_url() {
    local name="$1"
    if [[ -n "$TAG" ]]; then
        printf 'https://github.com/%s/releases/download/%s/%s\n' "$REPO" "$TAG" "$name"
    else
        printf 'https://github.com/%s/releases/latest/download/%s\n' "$REPO" "$name"
    fi
}

host_arch() {
    local m
    m="$(uname -m)"
    case "$m" in
        x86_64|amd64) echo x86_64 ;;
        aarch64|arm64) echo aarch64 ;;
        *) echo "$m" ;;
    esac
}

is_interactive() {
    if [[ "${CI:-}" == "true" || "${CI:-}" == "1" ]]; then
        return 1
    fi
    if [[ -t 0 || -r /dev/tty ]]; then
        return 0
    fi
    return 1
}

check_plasma6_env() {
    local ver major="" hint=""

    if command -v plasmashell >/dev/null 2>&1; then
        ver="$(plasmashell --version 2>&1 || true)"
        if [[ "$ver" =~ (^|[^0-9])6\. ]] || [[ "$ver" =~ [Pp]lasma[^0-9]*6 ]]; then
            info "Plasma environment: ${ver}"
            return 0
        fi
        if [[ "$ver" =~ (^|[^0-9])([0-9]+)\. ]]; then
            major="${BASH_REMATCH[2]}"
            if [[ "$major" -ge 6 ]]; then
                info "Plasma environment: ${ver}"
                return 0
            fi
        fi
        hint="plasmashell reports: ${ver}"
    fi

    if command -v kpackagetool6 >/dev/null 2>&1; then
        info "Plasma 6 tooling found (kpackagetool6)."
        return 0
    fi
    local qml_dir
    for qml_dir in /usr/lib/qt6/qml /usr/lib64/qt6/qml; do
        if [[ -d "$qml_dir" ]]; then
            info "Qt 6 QML path found: ${qml_dir}"
            return 0
        fi
    done
    if compgen -G '/usr/lib/libKF6*.so' >/dev/null \
        || compgen -G '/usr/lib64/libKF6*.so' >/dev/null \
        || compgen -G '/usr/lib/x86_64-linux-gnu/libKF6*.so' >/dev/null; then
        info "KF6 libraries found."
        return 0
    fi

    error "Kurrent requires KDE Plasma 6 with Qt 6 and KDE Frameworks 6 (KF6)."
    if [[ -n "$hint" ]]; then
        error "${hint}"
    else
        error "plasmashell was not found on PATH."
    fi
    error "Debian stable and Ubuntu LTS may need Plasma 6 backports or a newer release."
    error "Fedora/RHEL/CentOS users may need packages from COPR or EPEL."
    error "See build-from-source instructions: https://github.com/${REPO}#development"
    exit 1
}

UNKNOWN_DISTRO_CONFIRMED=false

confirm_unknown_distro() {
    if [[ "$UNKNOWN_DISTRO_CONFIRMED" == true ]]; then
        return 0
    fi

    warn "Unsupported or unrecognized Linux distribution."
    warn "The installer has explicit package lists only for:"
    warn "  Arch Linux (and derivatives)"
    warn "  Fedora / RHEL / Rocky / Alma"
    warn "  Debian / Ubuntu / Mint"
    warn "  openSUSE"
    warn "Install Plasma 6, Qt 6, KF6, and Akonadi packages yourself if you continue."

    if ! is_interactive; then
        warn "Non-interactive session (no TTY or CI=true): continuing without confirmation."
        UNKNOWN_DISTRO_CONFIRMED=true
        return 0
    fi

    local reply=""
    if [[ -r /dev/tty ]]; then
        read -r -p "Continue anyway? [y/N] " reply </dev/tty
    else
        read -r -p "Continue anyway? [y/N] " reply
    fi
    if [[ "$reply" =~ ^[yY]([eE][sS])?$ ]]; then
        UNKNOWN_DISTRO_CONFIRMED=true
        return 0
    fi
    error "Installation cancelled."
    exit 1
}

IMMUTABLE_KIND=""
IMMUTABLE_LABEL=""
IMMUTABLE_CONFIRMED=false

detect_immutable_distro() {
    IMMUTABLE_KIND=""
    IMMUTABLE_LABEL=""
    local id="" variant="" variant_id="" pretty=""

    if [[ -f /etc/os-release ]]; then
        # shellcheck disable=SC1091
        . /etc/os-release
        id="${ID:-}"
        variant="${VARIANT:-}"
        variant_id="${VARIANT_ID:-}"
        pretty="${PRETTY_NAME:-$id}"
    fi
    IMMUTABLE_LABEL="${pretty:-Linux}"

    local blob
    blob="$(printf '%s %s %s' "$id" "$variant" "$variant_id" | tr '[:upper:]' '[:lower:]')"

    if [[ -f /run/ostree-booted ]] \
        || [[ "$blob" =~ silverblue|kinoite|sericea|fedora-coreos|coreos|bazzite|bluefin|aurora|u-blue|ublue ]]; then
        IMMUTABLE_KIND="ostree"
        return 0
    fi
    if [[ "$blob" =~ microos|aeon|kalpa|transactional ]] \
        || command -v transactional-update >/dev/null 2>&1; then
        IMMUTABLE_KIND="transactional"
        return 0
    fi
    if [[ "$blob" =~ immutable|vanilla ]]; then
        IMMUTABLE_KIND="immutable"
    fi
}

warn_immutable_distro() {
    detect_immutable_distro
    if [[ -z "$IMMUTABLE_KIND" ]]; then
        return 0
    fi
    if [[ "$IMMUTABLE_CONFIRMED" == true ]]; then
        return 0
    fi

    warn "Immutable / atomic system detected: ${IMMUTABLE_LABEL}"
    warn "This installer normally runs dnf/apt/pacman/zypper on the live root — that often fails or is ignored on immutable distros."

    case "$IMMUTABLE_KIND" in
        ostree)
            warn "Fedora Atomic / rpm-ostree — suggested approaches:"
            warn "  A) Layer packages on the host, reboot, then re-run with --no-deps:"
            warn "       rpm-ostree install plasma-workspace kf6-kcalendarcore kf6-ki18n kf6-kconfig \\"
            warn "         kf6-knotifications kf6-kglobalaccel kf6-kirigami akonadi-server akonadi-calendar"
            warn "     For a source build, also layer: cmake extra-cmake-modules gcc-c++ git gettext \\"
            warn "       qt6-qtbase-devel qt6-qtdeclarative-devel kf6-*-devel akonadi-devel"
            warn "     Then: curl … | bash -s -- --no-deps --from-source"
            warn "  B) Run the normal installer inside Toolbx/Distrobox (mutable container)."
            warn "     Kurrent still installs to ~/.local on your user account."
            warn "  C) Wait for COPR packages (see ROADMAP.md)."
            ;;
        transactional)
            warn "openSUSE transactional / MicroOS — suggested approaches:"
            warn "  A) Layer packages, reboot, then re-run with --no-deps:"
            warn "       transactional-update pkg install plasma6-workspace libKF6CalendarCore6 \\"
            warn "         libKF6I18n6 libKF6ConfigCore6 akonadi-server akonadi-calendar"
            warn "     For source builds add -devel packages, cmake, and gcc-c++."
            warn "     Then: curl … | bash -s -- --no-deps --from-source"
            warn "  B) Use Distrobox/Podman with a mutable image and run the installer inside."
            warn "  C) Install build deps in a toolbox, compile there; ~/.local persists on the host."
            ;;
        immutable)
            warn "Generic immutable root — install Plasma 6 + Akonadi via your distro's layering tool,"
            warn "or use a mutable container (Toolbx, Distrobox, nix-shell, …), then re-run with --no-deps."
            ;;
    esac

    warn "Tip: pass --no-deps when runtime/build packages are already installed."
    warn "Docs: https://github.com/${REPO}#install"

    if ! is_interactive; then
        warn "Non-interactive session (no TTY or CI=true): continuing; package steps may fail — use --no-deps if deps are pre-installed."
        IMMUTABLE_CONFIRMED=true
        return 0
    fi

    local reply=""
    if [[ -r /dev/tty ]]; then
        read -r -p "Continue on this immutable system anyway? [y/N] " reply </dev/tty
    else
        read -r -p "Continue on this immutable system anyway? [y/N] " reply
    fi
    if [[ "$reply" =~ ^[yY]([eE][sS])?$ ]]; then
        IMMUTABLE_CONFIRMED=true
        return 0
    fi
    error "Installation cancelled."
    exit 1
}

resolve_install_user() {
    if [[ "${EUID}" -eq 0 ]]; then
        if [[ -n "${SUDO_USER:-}" && "${SUDO_USER}" != "root" ]]; then
            INSTALL_USER="$SUDO_USER"
        else
            error "Do not install Kurrent as root into /root."
            error "Use:  curl -fsSL ${INSTALLER_URL} | sudo bash"
            exit 1
        fi
    else
        INSTALL_USER="${USER:-$(id -un)}"
    fi

    INSTALL_HOME="$(getent passwd "$INSTALL_USER" | cut -d: -f6)"
    if [[ -z "$INSTALL_HOME" || ! -d "$INSTALL_HOME" ]]; then
        error "Could not resolve home directory for ${INSTALL_USER}"
        exit 1
    fi
    INSTALL_PREFIX="${PREFIX:-${INSTALL_HOME}/.local}"
    info "Installing as ${INSTALL_USER} into ${INSTALL_PREFIX}"
}

warn_if_not_sudo() {
    if [[ "${EUID}" -eq 0 ]]; then
        return 0
    fi
    warn "Not running as root."
    warn "Distro packages need elevated privileges. Preferred:"
    warn "  curl -fsSL ${INSTALLER_URL} | sudo bash"
    warn "Without sudo, package install may fail and you must fix root-owned files yourself."
    check_install_prefix_writable || true
}

check_install_prefix_writable() {
    local plasmoids_dir="${INSTALL_PREFIX}/share/plasma/plasmoids"
    if [[ -e "$plasmoids_dir" && ! -w "$plasmoids_dir" ]]; then
        error "${plasmoids_dir} is not writable as ${INSTALL_USER}."
        error "A previous install via sudo left root-owned files under ${INSTALL_PREFIX}."
        error "Fix ownership, then re-run:"
        error "  sudo chown -R ${INSTALL_USER}:${INSTALL_USER} ${INSTALL_PREFIX}/lib ${INSTALL_PREFIX}/share"
        exit 1
    fi
}

as_user() {
    if [[ "${EUID}" -eq 0 ]]; then
        sudo -u "$INSTALL_USER" -H -- "$@"
    else
        "$@"
    fi
}

run_root() {
    if [[ "${EUID}" -eq 0 ]]; then
        "$@"
    elif command -v sudo >/dev/null 2>&1; then
        if [[ -r /dev/tty ]]; then
            sudo "$@" </dev/tty
        else
            sudo "$@"
        fi
    else
        error "Need root to install packages. Re-run with: curl … | sudo bash"
        exit 1
    fi
}

detect_local_src() {
    local self="${BASH_SOURCE[0]:-}"
    LOCAL_SRC=""
    if [[ -z "$self" || "$self" == "-" || "$self" == "bash" || "$self" == "/dev/stdin" ]]; then
        return 0
    fi
    if [[ ! -f "$self" ]]; then
        return 0
    fi
    local dir
    dir="$(cd "$(dirname "$self")" && pwd)"
    if [[ -f "${dir}/CMakeLists.txt" && -f "${dir}/install.sh" ]]; then
        LOCAL_SRC="$dir"
    fi
}

os_family() {
    local id="" like=""
    if [[ -f /etc/os-release ]]; then
        # shellcheck disable=SC1091
        . /etc/os-release
        id="${ID:-}"
        like="${ID_LIKE:-}"
    fi
    local blob
    blob="$(printf '%s %s' "$id" "$like" | tr '[:upper:]' '[:lower:]')"
    case "$blob" in
        *arch*|*manjaro*|*endeavouros*|*cachyos*|*garuda*) echo arch ;;
        *fedora*|*rhel*|*centos*|*rocky*|*alma*) echo fedora ;;
        *debian*|*ubuntu*|*linuxmint*|*pop*|*elementary*|*neon*) echo debian ;;
        *suse*) echo suse ;;
        *) echo unknown ;;
    esac
}

install_runtime_deps() {
    if [[ "$SKIP_DEPS" == true ]]; then
        return 0
    fi
    local family
    family="$(os_family)"
    info "Installing runtime packages (${family})"
    case "$family" in
        arch)
            run_root pacman -Sy --needed --noconfirm \
                curl tar plasma-workspace \
                kcalendarcore ki18n kconfig knotifications kglobalaccel kirigami \
                akonadi akonadi-calendar
            ;;
        fedora)
            run_root dnf install -y \
                curl tar plasma-workspace kf6-kpackage \
                kf6-kcalendarcore kf6-ki18n kf6-kconfig \
                kf6-knotifications kf6-kglobalaccel kf6-kirigami \
                akonadi-server akonadi-calendar
            ;;
        debian)
            run_root apt-get update
            local deb_pkgs=(
                curl tar plasma-workspace kpackagetool6
                libkf6calendarcore6 libkf6i18n6 libkf6configcore6
                libkf6notifications6 libkf6globalaccel6
            )
            local extra
            for extra in libkpim6akonadicore6 libkpim6akonadi6 libakonadicore1; do
                if apt-cache show "$extra" >/dev/null 2>&1; then
                    deb_pkgs+=("$extra")
                    break
                fi
            done
            for extra in akonadi-server; do
                if apt-cache show "$extra" >/dev/null 2>&1; then
                    deb_pkgs+=("$extra")
                fi
            done
            for extra in akonadi-calendar libkpim6akonadicalendar6 libkpim6akonadicalendarcore6; do
                if apt-cache show "$extra" >/dev/null 2>&1; then
                    deb_pkgs+=("$extra")
                    break
                fi
            done
            run_root env DEBIAN_FRONTEND=noninteractive apt-get install -y "${deb_pkgs[@]}"
            ;;
        suse)
            run_root zypper --non-interactive install \
                curl tar plasma6-workspace kpackage-tools \
                libKF6CalendarCore6 libKF6I18n6 libKF6ConfigCore6
            ;;
        *)
            confirm_unknown_distro
            warn "Unknown distro; hoping curl, tar, and kpackagetool6 are already installed."
            ;;
    esac
}

install_build_deps() {
    if [[ "$SKIP_DEPS" == true ]]; then
        info "Skipping distro packages (--no-deps)"
        return 0
    fi
    local family
    family="$(os_family)"
    info "Installing build dependencies (${family})"
    case "$family" in
        arch)
            run_root pacman -Sy --needed --noconfirm \
                base-devel cmake extra-cmake-modules gettext git curl tar \
                qt6-base qt6-declarative \
                kcalendarcore ki18n kconfig knotifications kglobalaccel kirigami \
                plasma-workspace \
                akonadi akonadi-calendar
            ;;
        fedora)
            run_root dnf install -y \
                cmake extra-cmake-modules gcc-c++ git curl tar gettext \
                qt6-qtbase-devel qt6-qtdeclarative-devel \
                kf6-kcalendarcore-devel kf6-ki18n-devel kf6-kconfig-devel \
                kf6-knotifications-devel kf6-kglobalaccel-devel kf6-kirigami-devel \
                kf6-kpackage plasma-workspace
            if ! run_root dnf install -y kf6-akonadi-devel; then
                run_root dnf install -y akonadi-devel
            fi
            run_root dnf install -y akonadi-calendar-devel || true
            ;;
        debian)
            run_root apt-get update
            local deb_pkgs=(
                build-essential cmake extra-cmake-modules gettext git curl tar
                qt6-base-dev qt6-declarative-dev
                libkf6calendarcore-dev libkf6i18n-dev libkf6config-dev
                libkf6notifications-dev libkf6globalaccel-dev libkirigami-dev
                libkf6package-dev kpackagetool6 plasma-workspace
            )
            local extra
            for extra in libkpim6akonadi-dev kpim6-akonadi-dev libakonadi-dev; do
                if apt-cache show "$extra" >/dev/null 2>&1; then
                    deb_pkgs+=("$extra")
                    break
                fi
            done
            run_root env DEBIAN_FRONTEND=noninteractive apt-get install -y "${deb_pkgs[@]}"
            ;;
        suse)
            run_root zypper --non-interactive install \
                cmake extra-cmake-modules gcc-c++ git curl tar gettext-tools \
                qt6-base-devel qt6-declarative-devel \
                kf6-kcalendarcore-devel kf6-ki18n-devel kf6-kconfig-devel \
                kf6-knotifications-devel kf6-kglobalaccel-devel kf6-kirigami-devel \
                kpackage-tools plasma6-workspace \
                libKPim6Akonadi-devel akonadi-calendar-devel
            ;;
        *)
            confirm_unknown_distro
            warn "Unknown distro. Install Plasma 6, Akonadi, extra-cmake-modules, Qt6/KF6 devel, cmake, and g++ yourself."
            ;;
    esac
}

need_cmd() {
    local missing=()
    local cmd
    for cmd in "$@"; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            missing+=("$cmd")
        fi
    done
    if [[ ${#missing[@]} -gt 0 ]]; then
        error "Missing commands: ${missing[*]}"
        exit 1
    fi
}

plugin_ok() {
    local so="$1"
    if [[ ! -f "$so" ]]; then
        warn "Prebuilt plugin missing from tarball (no libkurrentplugin.so)."
        return 1
    fi
    if command -v ldd >/dev/null 2>&1 && ldd "$so" 2>/dev/null | grep -q 'not found'; then
        warn "Prebuilt plugin was built on another distro (missing libraries on this system)."
        ldd "$so" | grep 'not found' >&2 || true
        warn "Will compile from source instead (--from-source)."
        return 1
    fi
    return 0
}

prepare_workdir() {
    if [[ -n "$WORKDIR" && -d "$WORKDIR" ]]; then
        return 0
    fi
    WORKDIR="$(mktemp -d /tmp/kurrent-install.XXXXXX)"
    trap cleanup EXIT
    if [[ "${EUID}" -eq 0 ]]; then
        chown "$INSTALL_USER:$INSTALL_USER" "$WORKDIR"
    fi
}

write_qml_env() {
    local env_dir="${INSTALL_HOME}/.config/plasma-workspace/env"
    local tmp
    prepare_workdir
    tmp="${WORKDIR}/kurrent-qml.sh"
    as_user mkdir -p "$env_dir"
    cat > "$tmp" <<EOF
export QML_IMPORT_PATH="${INSTALL_PREFIX}/lib64/qml:${INSTALL_PREFIX}/lib/qml:${INSTALL_PREFIX}/share/qt6/qml\${QML_IMPORT_PATH:+:\$QML_IMPORT_PATH}"
export QML2_IMPORT_PATH="${INSTALL_PREFIX}/lib64/qml:${INSTALL_PREFIX}/lib/qml:${INSTALL_PREFIX}/share/qt6/qml\${QML2_IMPORT_PATH:+:\$QML2_IMPORT_PATH}"
EOF
    if [[ "${EUID}" -eq 0 ]]; then
        chown "$INSTALL_USER:$INSTALL_USER" "$tmp"
    fi
    as_user cp "$tmp" "${env_dir}/kurrent-qml.sh"
    info "Wrote QML import path helper: ${env_dir}/kurrent-qml.sh"
}

restart_plasmashell() {
    if [[ "$SKIP_RESTART" == true ]]; then
        info "Skipping plasmashell restart (--no-restart)"
        return 0
    fi
    as_user env \
        PREFIX="$INSTALL_PREFIX" \
        HOME="$INSTALL_HOME" \
        SKIP_PLASMA_RESTART=0 \
        bash -c '
            if ! command -v plasmashell >/dev/null 2>&1; then
                echo "plasmashell not found; skipping restart."
                exit 0
            fi
            if ! pgrep -x plasmashell >/dev/null 2>&1; then
                echo "plasmashell is not running; skipping restart."
                exit 0
            fi
            export QML_IMPORT_PATH="${PREFIX}/lib64/qml:${PREFIX}/lib/qml:${PREFIX}/share/qt6/qml${QML_IMPORT_PATH:+:${QML_IMPORT_PATH}}"
            export QML2_IMPORT_PATH="${PREFIX}/lib64/qml:${PREFIX}/lib/qml:${PREFIX}/share/qt6/qml${QML2_IMPORT_PATH:+:${QML2_IMPORT_PATH}}"
            echo "Restarting plasmashell..."
            kquitapp6 plasmashell 2>/dev/null || true
            sleep 1
            env -u KCURRENT_SMOKE nohup plasmashell --replace >/dev/null 2>&1 &
            disown >/dev/null 2>&1 || true
            echo "plasmashell restarted."
        '
}

fix_install_ownership() {
    if [[ "${EUID}" -eq 0 ]]; then
        chown -R "${INSTALL_USER}:${INSTALL_USER}" \
            "${INSTALL_PREFIX}/lib" "${INSTALL_PREFIX}/share"
    fi
}

prepare_install_prefix() {
    as_user mkdir -p "${INSTALL_PREFIX}/lib" "${INSTALL_PREFIX}/share"
    fix_install_ownership
}

remove_legacy_install() {
    as_user rm -rf \
        "${INSTALL_PREFIX}/lib/qml/org/planify" \
        "${INSTALL_PREFIX}/share/qt6/qml/org/planify" \
        "${INSTALL_PREFIX}/share/plasma/plasmoids/org.planify.plasmoid" \
        "${INSTALL_PREFIX}/lib/qml/org/kde/kurrent" \
        "${INSTALL_PREFIX}/share/qt6/qml/org/kde/kurrent" \
        "${INSTALL_PREFIX}/share/plasma/plasmoids/org.kde.kurrent" \
        "${INSTALL_HOME}/.config/plasma-workspace/env/planify-qml.sh" 2>/dev/null || true
}

copy_overlay_tree() {
    local src="$1" dest="$2"
    if [[ ! -d "$src" ]]; then
        return 0
    fi
    as_user mkdir -p "$dest"
    # cp -a keeps root-owned files from a root workdir; drop ownership when installing via sudo.
    if as_user cp -a --no-preserve=ownership "$src/." "$dest/" 2>/dev/null; then
        :
    else
        as_user cp -a "$src/." "$dest/"
    fi
}

verify_install_ownership() {
    local plasmoid="${INSTALL_PREFIX}/share/plasma/plasmoids/com.github.shrippen.kurrent"
    local meta="${plasmoid}/metadata.json"
    local owner
    if [[ ! -f "$meta" ]]; then
        error "Plasmoid metadata missing after install: ${meta}"
        exit 1
    fi
    owner="$(stat -c '%U' "$meta" 2>/dev/null || echo "")"
    if [[ "$owner" != "$INSTALL_USER" ]]; then
        error "Kurrent files are owned by ${owner:-?}, expected ${INSTALL_USER}."
        if [[ "$owner" == "root" || "${EUID}" -ne 0 ]]; then
            error "Fix ownership, then re-run:"
            error "  sudo chown -R ${INSTALL_USER}:${INSTALL_USER} ${INSTALL_PREFIX}/lib ${INSTALL_PREFIX}/share"
            if [[ "${EUID}" -ne 0 ]]; then
                error "Or re-run the installer with sudo:"
                error "  curl -fsSL ${INSTALLER_URL} | sudo bash"
            fi
        fi
        exit 1
    fi
}

register_plasmoid() {
    local plasmoid="$1"
    remove_legacy_install
    # Files are copied into ~/.local/share/plasma/plasmoids/; Plasma loads them directly.
    if [[ ! -f "${plasmoid}/metadata.json" ]]; then
        error "Plasmoid metadata missing: ${plasmoid}/metadata.json"
        exit 1
    fi
    info "Plasmoid com.github.shrippen.kurrent installed"
}

install_from_overlay() {
    local overlay="$1"
    prepare_install_prefix
    remove_legacy_install
    copy_overlay_tree "${overlay}/lib" "${INSTALL_PREFIX}/lib"
    copy_overlay_tree "${overlay}/share" "${INSTALL_PREFIX}/share"
    fix_install_ownership
    verify_install_ownership
    local plasmoid="${INSTALL_PREFIX}/share/plasma/plasmoids/com.github.shrippen.kurrent"
    if [[ ! -d "$plasmoid" ]]; then
        error "Plasmoid missing after extract: ${plasmoid}"
        exit 1
    fi
    register_plasmoid "$plasmoid"
    write_qml_env
    restart_plasmashell
}

try_install_binary() {
    local arch tarball url overlay so
    arch="$(host_arch)"
    case "$arch" in
        x86_64|aarch64) ;;
        *)
            warn "No prebuilt plugin for ${arch}; compiling from source."
            return 1
            ;;
    esac

    need_cmd curl tar
    prepare_workdir
    tarball="${WORKDIR}/kurrent-linux-${arch}.tar.gz"
    url="$(asset_url "kurrent-linux-${arch}.tar.gz")"
    info "Downloading ${url}"
    if ! as_user curl -fL --retry 3 -o "$tarball" "$url"; then
        warn "Could not download prebuilt plugin (${url})."
        warn "Will compile from source instead."
        return 1
    fi

    overlay="${WORKDIR}/overlay"
    as_user mkdir -p "$overlay"
    if ! as_user tar -xzf "$tarball" -C "$overlay"; then
        warn "Failed to extract plugin tarball; will compile from source."
        return 1
    fi

    so="$(find "$overlay" -name 'libkurrentplugin.so' -print -quit || true)"
    if ! plugin_ok "$so"; then
        return 1
    fi

    info "Installing prebuilt plugin (${arch})"
    install_from_overlay "$overlay"
    return 0
}

latest_release_tag() {
    local json tag
    json="$(curl -fsSL "https://api.github.com/repos/${REPO}/releases/latest")"
    tag="$(printf '%s\n' "$json" | awk -F'"' '/"tag_name"/ { print $4; exit }')"
    if [[ -z "$tag" ]]; then
        error "Could not read the latest GitHub release tag"
        exit 1
    fi
    printf '%s\n' "$tag"
}

fetch_source() {
    if [[ -n "$LOCAL_SRC" ]]; then
        SRC="$LOCAL_SRC"
        info "Using local checkout: ${SRC}"
        return 0
    fi

    prepare_workdir
    SRC="${WORKDIR}/src"

    if [[ "$FROM_GIT" == true ]]; then
        need_cmd git
        info "Cloning ${REPO} (${GIT_REF})…"
        as_user git clone --depth 1 --branch "$GIT_REF" \
            "https://github.com/${REPO}.git" "$SRC"
        return 0
    fi

    need_cmd curl tar
    local archive="${WORKDIR}/src.tar.gz"
    local tag="${TAG}"
    if [[ -z "$tag" ]]; then
        tag="$(latest_release_tag)"
    fi
    info "Downloading source ${tag}…"
    if ! as_user curl -fsSL -o "$archive" \
        "https://github.com/${REPO}/archive/refs/tags/${tag}.tar.gz"; then
        error "Failed to download https://github.com/${REPO}/archive/refs/tags/${tag}.tar.gz"
        exit 1
    fi
    as_user mkdir -p "$SRC"
    as_user tar -xzf "$archive" -C "$SRC" --strip-components=1
}

build_and_install() {
    if [[ ! -f "${SRC}/install.sh" ]]; then
        error "install.sh missing in ${SRC}"
        exit 1
    fi
    info "Building from source (this takes a few minutes)…"
    local extra_env=(
        "PREFIX=${INSTALL_PREFIX}"
        "HOME=${INSTALL_HOME}"
        "SKIP_TESTS=1"
        "SKIP_PLASMOIDVIEWER=1"
        "KURRENT_DEV_BUILD=OFF"
    )
    if [[ "$SKIP_RESTART" == true ]]; then
        extra_env+=("SKIP_PLASMA_RESTART=1")
    fi
    as_user env "${extra_env[@]}" bash "${SRC}/install.sh"
}

print_success() {
    echo "" >&2
    echo -e "${GREEN}Installation complete.${NC}" >&2
    echo "" >&2
    echo "Add the Kurrent widget to your panel or desktop if it is not there yet." >&2
    echo "If the widget still shows an error, remove it from the panel and add it again." >&2
    echo "CalDAV: configure tasks in Merkuro or KOrganizer, then check: akonadictl status" >&2
    echo "" >&2
    echo "Update with:" >&2
    echo "  curl -fsSL ${INSTALLER_URL} | sudo bash" >&2
    echo "" >&2
}

main() {
    parse_args "$@"
    info "Kurrent installer"
    resolve_install_user
    check_plasma6_env
    warn_immutable_distro
    warn_if_not_sudo
    check_install_prefix_writable
    detect_local_src

    if [[ -n "$LOCAL_SRC" ]]; then
        install_build_deps
        need_cmd cmake
        fetch_source
        build_and_install
        print_success
        return 0
    fi

    if [[ "$FROM_SOURCE" != true ]]; then
        install_runtime_deps
        need_cmd curl tar
        if try_install_binary; then
            print_success
            return 0
        fi
        warn "Prebuilt install unavailable; compiling from source (several minutes)."
    fi
    install_build_deps
    need_cmd cmake
    fetch_source
    build_and_install
    print_success
}

main "$@"
