#!/system/bin/sh

[ "$(getprop ro.product.device)" = socrates ] &&
[ "$(getprop ro.product.model)" = 22127RK46C ] &&
[ "$(getprop ro.build.version.sdk)" = 36 ] ||
    abort "此模块适用于型号 22127RK46C、Android 16 的 Redmi K60 Pro。"

set_perm "$MODPATH/boot-completed.sh" 0 0 0755
set_perm "$MODPATH/apply.sh" 0 0 0755
set_perm "$MODPATH/uninstall.sh" 0 0 0755
ui_print "模块将在 Android 开机完成后应用规则。"
