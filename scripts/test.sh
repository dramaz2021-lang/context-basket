#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
developer_dir="$(xcode-select -p)"
test_args=(--disable-xctest)

# Standalone Command Line Tools may not expose their bundled Testing frameworks
# to SwiftPM. Supply both the compile-time search path and runtime dependencies.
testing_frameworks="$developer_dir/Library/Developer/Frameworks"
if [[ -d "$testing_frameworks/Testing.framework" ]]; then
    test_args+=(
        -Xswiftc -F -Xswiftc "$testing_frameworks"
        -Xlinker -rpath -Xlinker "$testing_frameworks"
        -Xlinker -rpath -Xlinker "$developer_dir/Library/Developer/usr/lib"
    )
fi

# Some standalone Command Line Tools builds do not auto-load their Testing macro.
testing_plugin="$developer_dir/usr/lib/swift/host/plugins/testing/libTestingMacros.dylib"
if [[ -f "$testing_plugin" ]]; then
    test_args+=(-Xswiftc -load-plugin-library -Xswiftc "$testing_plugin")
fi

swift test "${test_args[@]}" "$@"
