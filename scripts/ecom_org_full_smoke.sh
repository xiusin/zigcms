#!/usr/bin/env bash
set -euo pipefail

API_BASE="${API_BASE:-http://127.0.0.1:3000}"
USERNAME="${USERNAME:-admin}"
PASSWORD="${PASSWORD:-123456}"
ROLE_ID="${ROLE_ID:-2}"
FAIL_DUMP_FILE="${FAIL_DUMP_FILE:-/tmp/ecom_org_full_smoke_failed.json}"

# 函数说明：统一发送 JSON POST 请求，支持可选 token
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

# 函数说明：提取 JSON 字段，路径格式如 data.id
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

# 函数说明：断言业务 code=200，否则落盘失败响应
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

# 函数说明：断言字段非空
assert_not_empty() {
  local value="$1"
  local field_name="$2"
  local step="$3"
  if [[ -z "$value" || "$value" == "null" ]]; then
    echo "[FAIL] ${step} 缺少字段: ${field_name}"
    exit 1
  fi
}

SUFFIX="$(date +%s)"
NEW_DEPT_NAME="联调部门_${SUFFIX}"
NEW_DEPT_CODE="ITG_${SUFFIX}"
NEW_ADMIN_USERNAME="itg_admin_${SUFFIX}"
NEW_ADMIN_NICKNAME="联调管理员_${SUFFIX}"

echo "[1/9] 登录..."
LOGIN_RESP="$(post_json "/api/member/login" "{\"username\":\"${USERNAME}\",\"password\":\"${PASSWORD}\"}")"
assert_code_ok "$LOGIN_RESP" "member/login"
TOKEN="$(extract_field "$LOGIN_RESP" "data.token")"
assert_not_empty "$TOKEN" "data.token" "member/login"
echo "[OK] 登录成功"

echo "[2/9] 新增部门..."
DEPT_SAVE_RESP="$(post_json "/api/system/dept/save" "{\"id\":0,\"parent_id\":1,\"dept_name\":\"${NEW_DEPT_NAME}\",\"dept_code\":\"${NEW_DEPT_CODE}\",\"leader\":\"联调负责人\",\"phone\":\"13800138000\",\"sort\":99,\"status\":1}" "$TOKEN")"
assert_code_ok "$DEPT_SAVE_RESP" "system/dept/save"
NEW_DEPT_ID="$(extract_field "$DEPT_SAVE_RESP" "data.id")"
assert_not_empty "$NEW_DEPT_ID" "data.id" "system/dept/save"
echo "[OK] 新增部门 id=${NEW_DEPT_ID}"

echo "[3/9] 查询部门树验证新增..."
DEPT_TREE_RESP="$(post_json "/api/system/dept/tree" "{\"keyword\":\"${NEW_DEPT_CODE}\"}" "$TOKEN")"
assert_code_ok "$DEPT_TREE_RESP" "system/dept/tree"
if ! printf '%s' "$DEPT_TREE_RESP" | grep -q "$NEW_DEPT_CODE"; then
  printf '%s\n' "$DEPT_TREE_RESP" > "$FAIL_DUMP_FILE"
  echo "[FAIL] system/dept/tree 未检索到新增部门编码，已写入: $FAIL_DUMP_FILE"
  exit 1
fi
echo "[OK] 部门树检索成功"

echo "[4/9] 新增管理员并绑定角色..."
ADMIN_SAVE_RESP="$(post_json "/api/system/admin/save" "{\"id\":0,\"username\":\"${NEW_ADMIN_USERNAME}\",\"nickname\":\"${NEW_ADMIN_NICKNAME}\",\"password\":\"123456\",\"confirm_password\":\"123456\",\"mobile\":\"13900139000\",\"email\":\"${NEW_ADMIN_USERNAME}@zigcms.local\",\"avatar\":\"\",\"gender\":1,\"dept_id\":${NEW_DEPT_ID},\"role_id\":${ROLE_ID},\"remark\":\"组织架构联调冒烟\"}" "$TOKEN")"
assert_code_ok "$ADMIN_SAVE_RESP" "system/admin/save"
NEW_ADMIN_ID="$(extract_field "$ADMIN_SAVE_RESP" "data.id")"
assert_not_empty "$NEW_ADMIN_ID" "data.id" "system/admin/save"
echo "[OK] 新增管理员 id=${NEW_ADMIN_ID}"

echo "[5/9] 管理员状态切换（禁用）..."
ADMIN_SET_RESP="$(post_json "/api/system/admin/set" "{\"id\":${NEW_ADMIN_ID},\"field\":\"status\",\"value\":0}" "$TOKEN")"
assert_code_ok "$ADMIN_SET_RESP" "system/admin/set(disable)"
echo "[OK] 管理员已禁用"

echo "[6/9] 管理员状态切换（启用）..."
ADMIN_SET_RESP2="$(post_json "/api/system/admin/set" "{\"id\":${NEW_ADMIN_ID},\"field\":\"status\",\"value\":1}" "$TOKEN")"
assert_code_ok "$ADMIN_SET_RESP2" "system/admin/set(enable)"
echo "[OK] 管理员已启用"

echo "[7/9] 分配管理员角色..."
ASSIGN_RESP="$(post_json "/api/system/admin/assignRoles" "{\"id\":${NEW_ADMIN_ID},\"role_ids\":[${ROLE_ID}]}" "$TOKEN")"
assert_code_ok "$ASSIGN_RESP" "system/admin/assignRoles"
echo "[OK] 角色分配成功"

echo "[8/9] 管理员列表检索验证..."
ADMIN_LIST_RESP="$(post_json "/api/system/admin/list" "{\"page\":1,\"limit\":10,\"keyword\":\"${NEW_ADMIN_USERNAME}\"}" "$TOKEN")"
assert_code_ok "$ADMIN_LIST_RESP" "system/admin/list"
if ! printf '%s' "$ADMIN_LIST_RESP" | grep -q "$NEW_ADMIN_USERNAME"; then
  printf '%s\n' "$ADMIN_LIST_RESP" > "$FAIL_DUMP_FILE"
  echo "[FAIL] system/admin/list 未检索到新增管理员，已写入: $FAIL_DUMP_FILE"
  exit 1
fi
echo "[OK] 管理员列表检索成功"

echo "[9/9] 清理管理员与部门..."
DEL_ADMIN_RESP="$(post_json "/api/system/admin/delete" "{\"id\":${NEW_ADMIN_ID}}" "$TOKEN")"
assert_code_ok "$DEL_ADMIN_RESP" "system/admin/delete"
DEL_DEPT_RESP="$(post_json "/api/system/dept/remove" "{\"id\":${NEW_DEPT_ID},\"delete_mode\":\"hard\"}" "$TOKEN")"
assert_code_ok "$DEL_DEPT_RESP" "system/dept/remove"
echo "[OK] 清理完成"

echo "✅ ecom 组织架构完整联调冒烟通过"
