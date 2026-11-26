#!/system/bin/sh
set -u
umask 077

state=/data/adb/k60-sms-guard
legacy=/data/adb/service.d/90-k60-sms-manual.sh
legacy_backup="$state/legacy-service-hook.sh"
legacy_sha=cd97f7034fcc5be20f322e604fd6569709e7c52342e453c578e3905817f99293
activation=com.xiaomi.simactivate.service
cloud_group="com.miui.cloudservice com.miui.micloudsync"
blocked_apps="com.xiaomi.finddevice com.xiaomi.xmsf com.xiaomi.account com.miui.hybrid com.miui.securityadd com.google.android.gms com.android.vending"
rcs_keys="pref_rcs_enable_cm pref_rcs_enable pref_rcs_auto_resend_sms pref_rcs_auto_resend_mms"
failed=0
dirty=0

[ "$(id -u)" = 0 ] &&
[ "$(getprop ro.product.device)" = socrates ] &&
[ "$(getprop ro.product.model)" = 22127RK46C ] &&
[ "$(getprop ro.build.version.sdk)" = 36 ] || { echo "Unsupported device or caller"; exit 1; }

[ "$(getprop sys.boot_completed)" = 1 ] || { echo "Android boot incomplete"; exit 1; }
[ -d "$state" ] && [ ! -L "$state" ] || exit 1
inventory="$(pm list packages --user 0 -U)" || { echo "Package Manager unavailable"; exit 1; }
[ -n "$inventory" ] || { echo "Empty package inventory"; exit 1; }

package_uid() {
    printf '%s\n' "$inventory" | awk -v pkg="package:$1" '
        $1 == pkg && $2 ~ /^uid:[0-9]+$/ { sub(/^uid:/,"",$2); print $2 }
    '
}

uid_mode() {
    local output
    output="$(cmd appops get --user 0 "$1" SEND_SMS)" || return 1
    printf '%s\n' "$output" | sed -n 's/^Uid mode: SEND_SMS: //p'
}

# Capture the starting policy once. Each line contains only a package, operation or setting.
if [ ! -e "$state/before.tsv" ]; then
    snapshot="$(mktemp "$state/before.XXXXXX")" || exit 1
    (
        printf 'kind\tname\tvalue\n'
        for app in "$activation" $cloud_group $blocked_apps; do
            uid="$(package_uid "$app")"
            if [ -z "$uid" ]; then
                printf 'SEND_SMS\t%s\tabsent\n' "$app"
            else
                original="$(uid_mode "$uid")" || exit 1
                [ -n "$original" ] || original=default
                printf 'SEND_SMS\t%s\t%s\n' "$app" "$original"
            fi
        done
        for key in $rcs_keys; do
            original="$(settings --user 0 get system "$key")" || exit 1
            printf 'system\t%s\t%s\n' "$key" "$original"
        done
    ) > "$snapshot" || { rm -f -- "$snapshot"; exit 1; }
    mv -- "$snapshot" "$state/before.tsv" || exit 1
fi

block_sms() {
    local app uid members member allowed current
    app="$1"
    shift
    allowed="$app $*"
    uid="$(package_uid "$app")"
    if [ -z "$uid" ]; then
        printf '%s absent\n' "$app"
        return 0
    fi
    case "$uid" in ''|*[!0-9]*) return 1;; esac
    if [ "$uid" -lt 10000 ] || [ "$uid" -ge 100000 ]; then
        if [ "$app:$uid" != com.xiaomi.finddevice:6110 ]; then
            printf 'Refused protected UID for %s\n' "$app"
            return 1
        fi
    fi
    members="$(pm list packages --user 0 -a --uid "$uid")" || return 1
    members="$(printf '%s\n' "$members" | awk '/^package:/{sub(/^package:/,"",$1); print $1}')"
    printf '%s\n' "$members" | grep -Fxq "$app" || return 1
    for member in $members; do
        case " $allowed " in
            *" $member "*) ;;
            *) printf 'Refused unexpected shared UID for %s\n' "$app"; return 1;;
        esac
    done
    current="$(uid_mode "$uid")" || return 1
    if [ "$current" != ignore ]; then
        cmd appops set --user 0 --uid "$app" SEND_SMS ignore || return 1
        dirty=1
        current="$(uid_mode "$uid")" || return 1
    fi
    printf '%s SEND_SMS=%s\n' "$app" "$current"
    [ "$current" = ignore ]
}

printf 'SMS policy run %s\n' "$(date +%FT%T%z)"
activation_safe=1
block_sms "$activation" || { failed=1; activation_safe=0; }
block_sms com.miui.cloudservice com.miui.micloudsync || failed=1
block_sms com.miui.micloudsync com.miui.cloudservice || failed=1
for app in $blocked_apps; do
    block_sms "$app" || failed=1
done

if [ "$activation_safe" = 1 ] && [ -n "$(package_uid "$activation")" ]; then
    if pm list packages --user 0 -s "$activation" | grep -Fxq "package:$activation"; then
        pm uninstall -k --user 0 "$activation" || :
    else
        echo "Refused to uninstall an unverified system activation package"
    fi
fi
installed="$(pm list packages --user 0 "$activation")" || exit 1
if printf '%s\n' "$installed" | grep -Fxq "package:$activation"; then
    echo "$activation installed=true"
    failed=1
else
    echo "$activation installed=false"
fi

if [ "$dirty" = 1 ]; then
    cmd appops write-settings || failed=1
fi

# rcs_enable_cm is SDK selection. Only the user-facing RCS and fallback preferences are managed.
for key in $rcs_keys; do
    current="$(settings --user 0 get system "$key")" || { failed=1; continue; }
    if [ "$current" != 0 ]; then
        settings --user 0 put system "$key" 0 || { failed=1; continue; }
        current="$(settings --user 0 get system "$key")" || { failed=1; continue; }
    fi
    printf 'system.%s=%s\n' "$key" "$current"
    [ "$current" = 0 ] || failed=1
done

# Retire the exact previous wrapper only after the new policy is verified.
if [ "$failed" = 0 ] && [ -e "$legacy" ]; then
    if [ ! -L "$legacy" ] && [ -f "$legacy" ] &&
        [ "$(sha256sum "$legacy" | awk '{print $1}')" = "$legacy_sha" ] &&
        [ ! -e "$legacy_backup" ] && [ ! -L "$legacy_backup" ]; then
        if mv -- "$legacy" "$legacy_backup"; then
            echo "Previous startup wrapper saved"
        else
            failed=1
        fi
    else
        echo "Previous startup wrapper differs or has a backup"
        failed=1
    fi
fi
exit "$failed"
