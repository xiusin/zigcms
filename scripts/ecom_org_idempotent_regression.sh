#!/usr/bin/env bash
set -euo pipefail

API_BASE="${API_BASE:-http://127.0.0.1:3000}"
USERNAME="${USERNAME:-admin}"
PASSWORD="${PASSWORD:-123456}"
ROLE_ID="${ROLE_ID:-2}"
FAIL_DUMP_FILE="${FAIL_DUMP_FILE:-/tmp/ecom_org_idempotent_failed.json}"

# 函数说明：执行一次完整链路冒烟，并为每轮设置独立失败落盘文件
run_once() {
  local round="$1"
  local round_dump="${FAIL_DUMP_FILE%.json}_round${round}.json"

  echo "[回归] 第 ${round} 轮 full smoke 开始..."
  API_BASE="$API_BASE" \
  USERNAME="$USERNAME" \
  PASSWORD="$PASSWORD" \
  ROLE_ID="$ROLE_ID" \
  FAIL_DUMP_FILE="$round_dump" \
  bash "$(dirname "$0")/ecom_org_full_smoke.sh"
  echo "[回归] 第 ${round} 轮通过"
}

run_once 1
run_once 2

echo "✅ 幂等回归通过：连续两轮 full smoke 均成功，未出现脏数据污染"
