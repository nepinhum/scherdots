#!/usr/bin/env bash

hyprctl binds -j | jq -r '
    .[] |
    select((.description // "") != "") |
    . as $b |
    [
        if ($b.modmask / 64 | floor % 2) == 1 then "SUPER" else empty end,
        if ($b.modmask / 4 | floor % 2) == 1 then "CTRL" else empty end,
        if ($b.modmask / 8 | floor % 2) == 1 then "ALT" else empty end,
        if ($b.modmask % 2) == 1 then "SHIFT" else empty end,
        $b.key
    ] |
    join(" + ") + "    —    " + $b.description
' | rofi -dmenu -i -p "Keybindings" \
    -theme-str 'window { width: 750px; } listview { lines: 15; }' \
    >/dev/null
