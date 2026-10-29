#!/bin/bash
# Boots the QA emulator (if needed), waits for it, then installs both release APKs. Logs to out/boot_install.log.
export MSYS_NO_PATHCONV=1
ADB="$LOCALAPPDATA/Android/Sdk/platform-tools/adb.exe"
ROOT="F:/DI_Local_Project/Go4Market"
log() { echo "$(date +%T) $*"; }
for i in $(seq 1 120); do
  [ "$("$ADB" shell getprop sys.boot_completed 2>/dev/null | tr -d '\r')" = 1 ] && break; sleep 5
done
log "boot_completed after ~$((i*5))s"; sleep 20
for app in customer_app partner_app; do
  for t in 1 2 3; do
    r=$("$ADB" install -r "$ROOT/apps/$app/build/app/outputs/flutter-apk/app-release.apk" 2>&1 | tail -1)
    log "$app try $t: $r"; [ "$r" = "Success" ] && break; sleep 15
  done
done
"$ADB" shell settings put secure stylus_handwriting_enabled 0
"$ADB" emu geo fix 72.5714 23.0225 >/dev/null
log DONE
