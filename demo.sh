#!/bin/zsh
# Build, install and screenshot one demo step: ./demo.sh <device-udid> <step> <out.png>
export DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer
xcrun simctl terminate $1 com.benfriedman.flare 2>/dev/null
xcrun simctl launch $1 com.benfriedman.flare -demo $2 >/dev/null
sleep ${4:-3}
xcrun simctl io $1 screenshot $3 >/dev/null 2>&1 && sips -Z 1000 $3 >/dev/null
