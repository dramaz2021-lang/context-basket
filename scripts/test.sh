#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
# Some standalone Command Line Tools builds do not auto-load their Testing macro.
developer_dir="$(xcode-select -p)"
testing_plugin="$developer_dir/usr/lib/swift/host/plugins/testing/libTestingMacros.dylib"
if [[ -f "$testing_plugin" ]]; then
    swift test --disable-xctest -Xswiftc -load-plugin-library -Xswiftc "$testing_plugin"
else
    swift test --disable-xctest
fi
