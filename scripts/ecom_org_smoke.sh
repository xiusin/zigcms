#!/usr/bin/env bash
set -euo pipefail

API_BASE="${API_BASE:-http://127.0.0.1:3000}"
USERNAME="${USERNAME:-admin}"
PASSWORD="${PASSWORD:-123456}"
FAIL_DUMP_FILE="${FAIL_DUMP_FILE:-/tmp/ecom_org_smoke_last_failed.json}"
STRICT_MODE="${STRICT_MODE:-0}"

post_json() {
  local path="$1"
  local body="$2"
  local token="${3:-}"

  if [[ -n "$token" ]]; then
    curl -sS -X POST "${API_BASE}${path}" \
      -H 'Content-Type: application/json' \
      -H "Authorization: Bearer ${token}" \
      -d "$body"
  else
    curl -sS -X POST "${API_BASE}${path}" \
      -H 'Content-Type: application/json' \
      -d "$body"
  fi
}

assert_not_empty() {
  local value="$1"
  local field_name="$2"
  local step="$3"
  if [[ -z "$value" || "$value" == "null" ]]; then
    echo "[FAIL] ${step} 缺少关键字段: ${field_name}"
    exit 1
  fi
}

extract_field() {
  local json="$1"
  local field="$2"
  python3 - "$json" "$field" <<'PY'
import json
import sys
obj = json.loads(sys.argv[1])
path = sys.argv[2].split('.')
cur = obj
for p in path:
    if isinstance(cur, dict):
        cur = cur.get(p)
    else:
        cur = None
        break
if cur is None:
    print("")
elif isinstance(cur, (dict, list)):
    print(json.dumps(cur, ensure_ascii=False))
else:
    print(cur)
PY
}

assert_code_ok() {
  local json="$1"
  local step="$2"
  local code
  code="$(extract_field "$json" "code")"
  if [[ "$code" != "200" ]]; then
    printf '%s\n' "$json" > "$FAIL_DUMP_FILE"
    echo "[FAIL] ${step} 响应 code 非 200，已写入: $FAIL_DUMP_FILE"
    exit 1
  fi
}

echo "[1/5] 登录接口 smoke..."
LOGIN_RESP="$(post_json "/api/member/login" "{\"username\":\"${USERNAME}\",\"password\":\"${PASSWORD}\"}")"
assert_code_ok "$LOGIN_RESP" "member/login"
TOKEN="$(extract_field "$LOGIN_RESP" "data.token")"
if [[ -z "$TOKEN" ]]; then
  printf '%s\n' "$LOGIN_RESP" > "$FAIL_DUMP_FILE"
  echo "[FAIL] 登录成功但未返回 token: $LOGIN_RESP"
  exit 1
fi
echo "[OK] 登录成功"
if [[ "$STRICT_MODE" == "1" ]]; then
  LOGIN_EXPIRES_IN="$(extract_field "$LOGIN_RESP" "data.expires_in")"
  assert_not_empty "$LOGIN_EXPIRES_IN" "data.expires_in" "member/login"
fi

echo "[2/5] 刷新用户信息 smoke..."
REFRESH_INFO_RESP="$(post_json "/api/member/refreshInfo" "{}" "$TOKEN")"
assert_code_ok "$REFRESH_INFO_RESP" "member/refreshInfo"
echo "[OK] refreshInfo 成功"
if [[ "$STRICT_MODE" == "1" ]]; then
  REFRESH_SERVER_TIME="$(extract_field "$REFRESH_INFO_RESP" "data.server_time")"
  assert_not_empty "$REFRESH_SERVER_TIME" "data.server_time" "member/refreshInfo"
fi

echo "[3/5] 刷新权限 smoke..."
REFRESH_PERM_RESP="$(post_json "/api/member/refreshPermissions" "{}" "$TOKEN")"
assert_code_ok "$REFRESH_PERM_RESP" "member/refreshPermissions"
echo "[OK] refreshPermissions 成功"
if [[ "$STRICT_MODE" == "1" ]]; then
  REFRESH_ROLE_IDS="$(extract_field "$REFRESH_PERM_RESP" "data.role_ids")"
  assert_not_empty "$REFRESH_ROLE_IDS" "data.role_ids" "member/refreshPermissions"
fi

echo "[4/5] 部门树接口 smoke..."
DEPT_TREE_RESP="$(post_json "/api/system/dept/tree" "{\"keyword\":\"\"}" "$TOKEN")"
assert_code_ok "$DEPT_TREE_RESP" "system/dept/tree"
echo "[OK] dept/tree 成功"

echo "[5/5] 管理员列表接口 smoke..."
ADMIN_LIST_RESP="$(post_json "/api/system/admin/list" "{\"page\":1,\"limit\":10}" "$TOKEN")"
assert_code_ok "$ADMIN_LIST_RESP" "system/admin/list"
ROLE_NAME="$(extract_field "$ADMIN_LIST_RESP" "data.list.0.role_name")"
ROLE_TEXT="$(extract_field "$ADMIN_LIST_RESP" "data.list.0.role_text")"

echo "[OK] admin/list 成功"
echo "首行角色名: ${ROLE_NAME}"
echo "首行角色串: ${ROLE_TEXT}"
if [[ "$STRICT_MODE" == "1" ]]; then
  ROLE_IDS="$(extract_field "$ADMIN_LIST_RESP" "data.list.0.role_ids")"
  ROLE_NAMES="$(extract_field "$ADMIN_LIST_RESP" "data.list.0.role_names")"
  assert_not_empty "$ROLE_IDS" "data.list.0.role_ids" "system/admin/list"
  assert_not_empty "$ROLE_NAMES" "data.list.0.role_names" "system/admin/list"
fi
echo "✅ ecom 组织架构联调最小冒烟通过"
