#!/usr/bin/env bash
set -euo pipefail

FRONTEND_BASE="${FRONTEND_BASE:-http://127.0.0.1:3201}"
FAIL_DUMP_FILE="${FAIL_DUMP_FILE:-/tmp/ecom_admin_proxy_check_failed.json}"

# 函数说明：校验 HTTP 状态码与业务 code，快速识别代理是否命中后端
check_proxy_endpoint() {
  local path="$1"
  local expected_http="$2"
  local expected_code="$3"

  local raw_response
  raw_response="$(curl -sS -X POST "${FRONTEND_BASE}${path}" -H 'Content-Type: application/json' -d '{}' -w $'\n%{http_code}')"

  python3 - "$raw_response" "$expected_http" "$expected_code" "$path" "$FAIL_DUMP_FILE" <<'PY'
import json
import sys

raw = sys.argv[1]
expected_http = int(sys.argv[2])
expected_code = int(sys.argv[3])
path = sys.argv[4]
fail_dump = sys.argv[5]

if '\n' not in raw:
    with open(fail_dump, 'w', encoding='utf-8') as f:
        f.write(raw)
    print(f"[FAIL] {path} 响应格式异常，已写入: {fail_dump}")
    sys.exit(1)

body, http_line = raw.rsplit('\n', 1)
try:
    http_status = int(http_line)
except Exception:
    with open(fail_dump, 'w', encoding='utf-8') as f:
        f.write(raw)
    print(f"[FAIL] {path} HTTP 状态码解析失败，已写入: {fail_dump}")
    sys.exit(1)

try:
    obj = json.loads(body)
except Exception:
    with open(fail_dump, 'w', encoding='utf-8') as f:
        f.write(body)
    print(f"[FAIL] {path} 响应不是有效 JSON，已写入: {fail_dump}")
    sys.exit(1)

biz_code = obj.get('code')
if http_status != expected_http or biz_code != expected_code:
    with open(fail_dump, 'w', encoding='utf-8') as f:
        f.write(body)
    print(f"[FAIL] {path} 期望 HTTP={expected_http}, code={expected_code}，实际 HTTP={http_status}, code={biz_code}")
    print(f"[FAIL] 失败响应已写入: {fail_dump}")
    sys.exit(1)

print(f"[OK] {path} -> HTTP={http_status}, code={biz_code}")
PY
}

# 函数说明：执行开发代理最小可用检查，确认不会返回前端 404
run_proxy_smoke() {
  echo "[1/2] 校验 refreshInfo 走后端（未登录应返回 401 业务码）..."
  check_proxy_endpoint "/api/member/refreshInfo" "200" "401"

  echo "[2/2] 校验 refreshPermissions 走后端（未登录应返回 401 业务码）..."
  check_proxy_endpoint "/api/member/refreshPermissions" "200" "401"

  echo "✅ ecom-admin 开发代理检查通过"
}

run_proxy_smoke
