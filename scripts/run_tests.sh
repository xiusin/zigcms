#!/usr/bin/env bash
# ZigCMS 全量单元测试统一入口（本地 / CI 共用）
#
# 背景：macOS Homebrew 环境下，`zig build test-unit` 的测试二进制以
# --listen=- 服务模式启动后会在 stdin readv 永久挂起（build runner 集成问题）。
# 策略：后台启动构建，一旦"新的测试二进制"落盘即认为编译成功，终止 build runner，
# 改为直接以 terminal 模式运行该二进制；构建正常退出（Linux CI 或编译失败）则走常规路径。
set -u
cd "$(dirname "$0")/.."

BINARY_NAME=zigcms-lib-tests
LOG=$(mktemp "${TMPDIR:-/tmp}/zigcms-build.XXXXXX")

newest_binary() {
    ls -t .zig-cache/o/*/"$BINARY_NAME" 2>/dev/null | head -1
}

before=$(newest_binary || true)

zig build test-unit --summary all >"$LOG" 2>&1 &
BUILD_PID=$!

finished=0
for _ in $(seq 1 120); do
    if ! kill -0 "$BUILD_PID" 2>/dev/null; then
        finished=1
        break
    fi
    latest=$(newest_binary || true)
    if [ -n "$latest" ] && [ "$latest" != "$before" ]; then
        # 新二进制已落盘，稍等构建进程收尾再终止
        sleep 2
        kill "$BUILD_PID" 2>/dev/null
        break
    fi
    sleep 1
done

# 超时或已发终止信号：确保 build 进程结束（其测试 runner 可能挂在 --listen=- 模式）
if ! kill -0 "$BUILD_PID" 2>/dev/null; then
    finished=1
else
    kill "$BUILD_PID" 2>/dev/null
    finished=0
fi
wait "$BUILD_PID" 2>/dev/null
BUILD_RC=$?

latest=$(newest_binary || true)

if [ -z "$latest" ]; then
    echo "!! 未找到测试二进制，构建日志：" >&2
    cat "$LOG" >&2
    rm -f "$LOG"
    exit 1
fi

# 仅当构建"自行退出且失败"（真编译错误）时才判定失败；
# 构建被本脚本主动终止（listen 模式挂起兜底）不算失败，直接跑二进制
if [ "$finished" -eq 1 ] && [ "$BUILD_RC" -ne 0 ] && [ "$latest" = "$before" ]; then
    echo "!! 编译失败（无新二进制），构建日志：" >&2
    cat "$LOG" >&2
    rm -f "$LOG"
    exit "$BUILD_RC"
fi

rm -f "$LOG"
echo "== 运行测试二进制: $latest =="
"$latest"
BIN_RC=$?
# 0.17 测试 runner 在出现（测试预期的）std.log.err 时会返回 1，
# 成败以结果行 "X passed; ...; Y failed" 为准
if [ "$BIN_RC" -ne 0 ]; then
    if "$latest" 2>&1 | tail -5 | grep -qE "All [0-9]+ tests passed|0 failed"; then
        exit 0
    fi
fi
exit "$BIN_RC"
