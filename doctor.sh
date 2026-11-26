#!/usr/bin/env bash

root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
config="${XDG_CONFIG_HOME:-$HOME/.config}"

passed=0
warnings=0
failed=0

if [[ -t 1 && -z "${NO_COLOR:-}" ]]; then
    green=$'\033[38;2;152;187;108m'
    yellow=$'\033[38;2;230;195;132m'
    red=$'\033[38;2;195;64;67m'
    purple=$'\033[38;2;149;127;184m'
    reset=$'\033[0m'
else
    green=""
    yellow=""
    red=""
    purple=""
    reset=""
fi

ok() {
    printf '%s[ OK ]%s %s\n' "$green" "$reset" "$*"
    ((passed += 1))
}

warn() {
    printf '%s[WARN]%s %s\n' "$yellow" "$reset" "$*"
    ((warnings += 1))
}

fail() {
    printf '%s[FAIL]%s %s\n' "$red" "$reset" "$*"
    ((failed += 1))
}

section() {
    printf '\n%s%s%s\n' "$purple" "$1" "$reset"
}

printf 'scherdots doctor\n'
printf 'Repository: %s\n' "$root"

section "DEPENDENCIES"

required=(
    Hyprland hyprctl kitty waybar rofi
    mako hyprpaper jq cliphist flock
    wl-copy wl-paste grim slurp
)

optional=(
    uwsm zsh dolphin librewolf firefox
    wpctl pactl brightnessctl playerctl
    nmcli nmtui cal
)

for cmd in "${required[@]}"; do
    if command -v "$cmd" >/dev/null 2>&1; then
        ok "$cmd"
    else
        fail "$cmd not installed"
    fi
done

for cmd in "${optional[@]}"; do
    if command -v "$cmd" >/dev/null 2>&1; then
        ok "$cmd"
    else
        warn "$cmd not installed (feature unavailable)"
    fi
done

section "CONFIGURATION"

files=(
    hypr/hyprland.lua
    hypr/hyprpaper.conf
    kitty/kitty.conf
    kitty/current-theme.conf
    waybar/config.jsonc
    waybar/style.css
    rofi/config.rasi
    rofi/keybinds.rasi
    rofi/windows.rasi
    mako/config
)

for file in "${files[@]}"; do
    if [[ -r "$root/.config/$file" ]]; then
        ok "$file"
    else
        fail "$file missing or unreadable"
    fi
done

if command -v jq >/dev/null 2>&1; then
    if jq -e 'type == "object"' "$root/.config/waybar/config.jsonc" >/dev/null 2>&1; then
        ok "Waybar JSON syntax"
    else
        fail "Waybar configuration is not a valid JSON object"
    fi
fi

section "SCRIPTS"

scripts=(
    hypr/scripts/keybinds.sh
    hypr/scripts/windows.sh
    waybar/scripts/actions.sh
)

for script in "${scripts[@]}"; do
    path="$root/.config/$script"

    if [[ ! -f "$path" ]]; then
        fail "$script missing"
    elif [[ ! -x "$path" ]]; then
        fail "$script is not executable"
    elif ! bash -n "$path"; then
        fail "$script has syntax errors"
    else
        ok "$script"
    fi
done

section "SYMLINKS"

for app in hypr kitty waybar rofi mako; do
    target="$config/$app"
    expected="$root/.config/$app"

    if [[ -L "$target" && ! -e "$target" ]]; then
        fail "$app: broken symlink"
    elif [[ -L "$target" ]]; then
        if [[ "$(realpath "$target")" == "$(realpath "$expected")" ]]; then
            ok "$app -> $expected"
        else
            warn "$app points outside this repository"
        fi
    elif [[ -d "$target" ]]; then
        warn "$app: installed as a regular directory"
    else
        fail "$app: configuration not installed"
    fi
done

section "ASSETS"

if [[ -r "$root/wallpapers/dotfiles_bg.jpg" ]]; then
    ok "Repository wallpaper"
else
    fail "Repository wallpaper missing"
fi

paper="$config/hypr/hyprpaper.conf"

if [[ -r "$paper" ]]; then
    while IFS= read -r wallpaper; do
        wallpaper="${wallpaper/#\~/$HOME}"

        if [[ -r "$wallpaper" ]]; then
            ok "Wallpaper: $wallpaper"
        else
            fail "Wallpaper not found: $wallpaper"
        fi
    done < <(sed -n 's/^[[:space:]]*path[[:space:]]*=[[:space:]]*//p' "$paper")
else
    warn "Active hyprpaper configuration unavailable"
fi

section "SESSION"

if [[ "${XDG_SESSION_TYPE:-}" == "wayland" ]]; then
    ok "Wayland session"
else
    warn "Not running in a Wayland session"
fi

if command -v hyprctl >/dev/null 2>&1 &&
   hyprctl monitors -j >/dev/null 2>&1; then
    ok "Hyprland IPC"

    if errors=$(hyprctl configerrors 2>&1); then
        if [[ -z "${errors//[[:space:]]/}" ]]; then
            ok "Hyprland configuration has no errors"
        else
            fail "Hyprland configuration errors"
            printf '%s\n' "$errors"
        fi
    else
        warn "Could not query Hyprland configuration errors"
    fi

    for process in waybar mako hyprpaper; do
        if pgrep -u "$UID" -x "$process" >/dev/null; then
            ok "$process running"
        else
            warn "$process not running"
        fi
    done

    if pgrep -u "$UID" -f '(^|/)wl-paste .*--watch[[:space:]]+([^[:space:]]*/)?cliphist[[:space:]]+store([[:space:]]|$)' >/dev/null; then
        ok "Clipboard watcher running"
    else
        warn "Clipboard watcher not detected"
    fi
else
    warn "Hyprland IPC unavailable; runtime checks skipped"
fi

section "SUMMARY"

printf '%s%d passed%s, ' "$green" "$passed" "$reset"
printf '%s%d warnings%s, ' "$yellow" "$warnings" "$reset"
printf '%s%d failed%s\n' "$red" "$failed" "$reset"

if ((failed > 0)); then
    exit 1
fi

exit 0
