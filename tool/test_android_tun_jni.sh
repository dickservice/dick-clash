#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
java_home="${JAVA_HOME:-/usr/lib/jvm/java-17-openjdk-amd64}"
header_dir="${1:-android/core/src/main/cpp/includes/arm64-v8a}"
test -f "$header_dir/libclash.h"
out="$(mktemp -d)"
trap 'rm -rf "$out"' EXIT
"${CXX:-g++}" -std=c++17 -ffunction-sections -fdata-sections -Wl,--gc-sections \
  -I"$java_home/include" -I"$java_home/include/linux" \
  -Iandroid/core/src/main/cpp -I"$header_dir" \
  android/tests/native/tun_start_failure_test.cpp -o "$out/tun_start_failure_test"
"$out/tun_start_failure_test"
echo 'JNI TUN startup success/failure injection passed'
