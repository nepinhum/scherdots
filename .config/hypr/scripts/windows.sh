#!/usr/bin/env bash

set -o pipefail

config="${XDG_CONFIG_HOME:-$HOME/.config}"
pidfile="${XDG_RUNTIME_DIR}/scherdots-windows-${HYPRLAND_INSTANCE_SIGNATURE}.pid"

if [[ -f "$pidfile" ]]; then
    pid=$(cat "$pidfile")

    if [[ "$pid" =~ ^[0-9]+$ ]] &&
       [[ -r "/proc/$pid/cmdline" ]] &&
       grep -zFxq "scherdots-windows" "/proc/$pid/cmdline"; then
        kill "$pid"
        exit 0
    fi

    rm -f "$pidfile"
fi

active=$(hyprctl activewindow -j | jq -r '.address // ""') || exit 1

clients=$(hyprctl clients -j | jq -c --arg active "$active" '
    [
        .[] |
        select(.mapped == true) |
        select(.hidden != true) |
        select(.address != $active)
    ]
    | sort_by(
        if (.focusHistoryID // -1) < 0
        then 999999
        else .focusHistoryID
        end
    )
') || exit 1

[[ "$clients" != "[]" ]] || exit 0

entries=$(jq -r '
    def clean:
        gsub("[[:cntrl:]]"; " ");

    def pad($n):
        . + (" " * ([0, $n - length] | max));

    .[] |
    (
        "<span foreground=\"#957fb8\">" +
        (.workspace.name | tostring | clean | pad(12) | @html) +
        "</span>" +
        "<span foreground=\"#7e9cd8\">" +
        (.class | clean | pad(24) | @html) +
        "</span>" +
        "<span foreground=\"#dcd7ba\">" +
        (.title | clean | @html) +
        "</span>"
    )
' <<< "$clients") || exit 1

result=$(mktemp "${XDG_RUNTIME_DIR}/scherdots-windows.XXXXXX") || exit 1

rofi -dmenu \
    -i \
    -p "Windows" \
    -markup-rows \
    -no-custom \
    -format i \
    -theme "$config/rofi/windows.rasi" \
    -window-title "scherdots-windows" \
    <<< "$entries" > "$result" &

pid=$!
echo "$pid" > "$pidfile"

cleanup() {
    if [[ "$(cat "$pidfile" 2>/dev/null)" == "$pid" ]]; then
        rm -f "$pidfile"
    fi

    rm -f "$result"
}

trap cleanup EXIT

wait "$pid" || exit 0

index=$(cat "$result")

[[ "$index" =~ ^[0-9]+$ ]] || exit 0

address=$(jq -r --argjson i "$index" \
    '.[$i].address // empty' <<< "$clients")

[[ "$address" =~ ^0x[0-9a-fA-F]+$ ]] || exit 1

hyprctl dispatch "hl.dsp.focus({ window = \"address:$address\" })"
