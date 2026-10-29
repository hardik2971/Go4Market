#!/bin/bash
# Drive the Android emulator: ./a.sh tap X Y | type TEXT | key CODE | swipe X1 Y1 X2 Y2 [ms] | wait S | shot NAME
# Coordinates use the 900x2000 preview space of a 1080x2400 screen (scaled x1.2). Shots go to tools/qa/out/.
export MSYS_NO_PATHCONV=1
ADB="$LOCALAPPDATA/Android/Sdk/platform-tools/adb.exe"
OUT="$(cd "$(dirname "$0")" && pwd)/out"
s() { echo $(( $1 * 12 / 10 )); }
while [ $# -gt 0 ]; do
  case "$1" in
    tap) "$ADB" shell input tap $(s $2) $(s $3); shift 3; sleep 0.8;;
    type) "$ADB" shell input text "$(echo "$2" | sed 's/ /%s/g')"; shift 2; sleep 0.5;;
    key) "$ADB" shell input keyevent $2; shift 2; sleep 0.6;;
    swipe) "$ADB" shell input swipe $(s $2) $(s $3) $(s $4) $(s $5) ${6:-350}; shift 6; sleep 0.8;;
    wait) sleep $2; shift 2;;
    shot) "$ADB" exec-out screencap -p > "$OUT/$2.png"; echo "shot $2"; shift 2;;
    *) echo "bad cmd $1"; exit 1;;
  esac
done
