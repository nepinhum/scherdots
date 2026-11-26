#!/usr/bin/env bash

set -o pipefail

pidfile="${XDG_RUNTIME_DIR}/scherdots-keybinds-${HYPRLAND_INSTANCE_SIGNATURE}.pid"

if [[ -f "$pidfile" ]]; then
    pid=$(cat "$pidfile")

    if [[ "$pid" =~ ^[0-9]+$ ]] &&
       [[ -r "/proc/$pid/cmdline" ]] &&
       grep -zFxq "scherdots-keybinds" "/proc/$pid/cmdline"; then
        kill "$pid"
        exit 0
    fi

    rm -f "$pidfile"
fi

config="${XDG_CONFIG_HOME:-$HOME/.config}"

entries=$(hyprctl binds -j | jq -r '
    def modifiers($m):
        [
            if ($m / 64 | floor % 2) == 1 then "SUPER" else empty end,
            if ($m / 4  | floor % 2) == 1 then "CTRL" else empty end,
            if ($m / 8  | floor % 2) == 1 then "ALT" else empty end,
            if ($m % 2) == 1 then "SHIFT" else empty end
        ];

    def keyname:
        {
            "mouse:272": "LMB",
            "mouse:273": "RMB",
            "mouse_down": "Scroll Down",
            "mouse_up": "Scroll Up",
            "XF86AudioRaiseVolume": "Volume Up",
            "XF86AudioLowerVolume": "Volume Down",
            "XF86AudioMute": "Mute",
            "XF86AudioMicMute": "Mic Mute",
            "XF86MonBrightnessUp": "Brightness Up",
            "XF86MonBrightnessDown": "Brightness Down",
            "XF86AudioNext": "Next Track",
            "XF86AudioPrev": "Prev Track",
            "XF86AudioPlay": "Play",
            "XF86AudioPause": "Pause"
        }[.] // ascii_upcase;

    def pad($n):
        . + (" " * ([0, $n - length] | max));

    def categories:
        [
            "Applications",
            "Windows",
            "Focus",
            "Workspaces",
            "Mouse",
            "Audio",
            "Brightness",
            "Media",
            "Utilities",
            "Session",
            "Other"
        ];

    [
        .[] |
        select((.description // "") != "") |
        . as $b |
        ($b.description | split(": ")) as $d |
        {
            category: (if ($d | length) > 1 then $d[0] else "Other" end),
            description: (if ($d | length) > 1 then $d[1:] | join(": ") else $d[0] end),
            key: (
                modifiers($b.modmask) +
                [
                    if ($b.key // "") != ""
                    then ($b.key | keyname)
                    else ("KEYCODE " + ($b.keycode | tostring))
                    end
                ] | join(" + ")
            )
        }
    ]
    | group_by(.category)
    | sort_by(.[0].category as $c | categories | index($c) // 99)
    | .[]
    | (
        ("<span foreground=\"#957fb8\"><b>" +
            (.[0].category | ascii_upcase | @html) +
        "</b></span>"),
        (
            .[] |
            "<span foreground=\"#7e9cd8\">" +
            (.key | pad(32) | @html) +
            "</span>" +
            "<span foreground=\"#dcd7ba\">" +
            (.description | @html) +
            "</span>"
        )
    )
') || exit 1

[[ -n "$entries" ]] || exit 0

rofi -dmenu \
    -i \
    -p "Keybindings" \
    -markup-rows \
    -theme "$config/rofi/keybinds.rasi" \
    -window-title "scherdots-keybinds" \
    <<< "$entries" >/dev/null &

pid=$!
echo "$pid" > "$pidfile"

wait "$pid"

if [[ "$(cat "$pidfile" 2>/dev/null)" == "$pid" ]]; then
    rm -f "$pidfile"
fi
