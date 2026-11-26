#!/system/bin/sh
set -o pipefail
umask 077

module_dir="$(dirname "$0")"
state=/data/adb/k60-sms-guard
[ ! -L "$state" ] && mkdir -p -m 700 "$state" || exit 1

# Keep Android service output on a pipe. system_server cannot write to an adb_data_file directly.
/system/bin/sh "$module_dir/apply.sh" 2>&1 | /system/bin/tee "$state/last-boot.log" >/dev/null
