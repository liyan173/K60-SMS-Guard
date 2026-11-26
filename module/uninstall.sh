#!/system/bin/sh
set -u

state=/data/adb/k60-sms-guard
legacy=/data/adb/service.d/90-k60-sms-manual.sh
saved="$state/legacy-service-hook.sh"
legacy_sha=cd97f7034fcc5be20f322e604fd6569709e7c52342e453c578e3905817f99293

[ "$(getprop ro.product.device)" = socrates ] && [ "$(id -u)" = 0 ] || exit 1
if [ -f "$saved" ] && [ ! -L "$saved" ] && [ ! -e "$legacy" ] && [ ! -L "$legacy" ] &&
    [ "$(sha256sum "$saved" | awk '{print $1}')" = "$legacy_sha" ]; then
    mv -- "$saved" "$legacy" || exit 1
fi
