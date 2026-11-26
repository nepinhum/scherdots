#!/usr/bin/env bash

set -o pipefail

menu() {
    rofi -dmenu -i -no-custom -p "$1"
}

case "$1" in
    audio)
        sinks=$(pactl -f json list sinks) || exit 1

        index=$(jq -r '.[].description' <<< "$sinks" |
            rofi -dmenu -i -no-custom -format i -p "Audio output") || exit 0

        [[ "$index" =~ ^[0-9]+$ ]] || exit 1

        sink=$(jq -r --argjson i "$index" \
            '.[$i].name // empty' <<< "$sinks")

        [[ -n "$sink" ]] || exit 1

        pactl set-default-sink "$sink"
        ;;

    network)
        kitty --class scherdots-network nmtui
        ;;

    network-info)
        nmcli device status |
            menu "Network" >/dev/null
        ;;

    brightness)
        level=$(printf '%s\n' 10% 25% 50% 75% 100% |
            menu "Brightness") || exit 0

        [[ -n "$level" ]] || exit 0

        brightnessctl -c backlight set "$level"
        ;;

    battery)
        for battery in /sys/class/power_supply/BAT*; do
            [[ -d "$battery" ]] || continue

            printf 'Battery: %s\n' "${battery##*/}"

            for field in status capacity cycle_count; do
                [[ -r "$battery/$field" ]] || continue
                printf '%s: %s\n' "$field" "$(cat "$battery/$field")"
            done
        done | menu "Battery" >/dev/null
        ;;

    calendar)
        cal | menu "$(date +%Y-%m-%d)" >/dev/null
        ;;

    *)
        exit 1
        ;;
esac
