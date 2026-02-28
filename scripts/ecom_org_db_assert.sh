#!/usr/bin/env bash
set -euo pipefail

DB_HOST="${DB_HOST:-127.0.0.1}"
DB_PORT="${DB_PORT:-3306}"
DB_USER="${DB_USER:-root}"
DB_PASSWORD="${DB_PASSWORD:-}"
DB_NAME="${DB_NAME:-zigcms}"
ITG_DEPT_PREFIX="${ITG_DEPT_PREFIX:-ITG_}"
ITG_ADMIN_PREFIX="${ITG_ADMIN_PREFIX:-itg_admin_}"

# 函数说明：执行单值 SQL 并返回结果
run_scalar_sql() {
  local sql="$1"
  MYSQL_PWD="$DB_PASSWORD" mysql \
    --host="$DB_HOST" \
    --port="$DB_PORT" \
    --user="$DB_USER" \
    --database="$DB_NAME" \
    --batch --skip-column-names \
    -e "$sql"
}

# 函数说明：断言计数为 0，否则输出失败信息并退出
assert_zero() {
  local count="$1"
  local label="$2"
  if [[ "$count" != "0" ]]; then
    echo "[FAIL] ${label} 残留数量=${count}"
    exit 1
  fi
  echo "[OK] ${label} 无残留"
}

echo "[1/4] 检查 ITG_ 部门残留..."
DEPT_COUNT="$(run_scalar_sql "SELECT COUNT(*) FROM sys_dept WHERE dept_code LIKE '${ITG_DEPT_PREFIX}%';")"
assert_zero "$DEPT_COUNT" "部门"

echo "[2/4] 检查 itg_admin_ 管理员残留..."
ADMIN_COUNT="$(run_scalar_sql "SELECT COUNT(*) FROM sys_admin WHERE username LIKE '${ITG_ADMIN_PREFIX}%';")"
assert_zero "$ADMIN_COUNT" "管理员"

echo "[3/4] 检查管理员角色关联残留..."
ROLE_REL_COUNT="$(run_scalar_sql "SELECT COUNT(*) FROM sys_admin_role r INNER JOIN sys_admin a ON a.id = r.admin_id WHERE a.username LIKE '${ITG_ADMIN_PREFIX}%';")"
assert_zero "$ROLE_REL_COUNT" "管理员角色关联"

echo "[4/4] 检查部门被管理员引用残留..."
DEPT_REF_COUNT="$(run_scalar_sql "SELECT COUNT(*) FROM sys_admin a INNER JOIN sys_dept d ON d.id = a.dept_id WHERE d.dept_code LIKE '${ITG_DEPT_PREFIX}%';")"
assert_zero "$DEPT_REF_COUNT" "部门引用"

echo "✅ DB 无污染断言通过（ITG_ / itg_admin_）"
