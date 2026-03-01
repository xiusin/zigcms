#!/bin/bash

# 全局内存泄漏修复验证脚本

echo "=========================================="
echo "  ZigCMS 内存泄漏修复验证脚本"
echo "=========================================="
echo ""

# 配置
API_BASE="http://localhost:3000/api"
TOKEN="${ZIGCMS_TOKEN:-your_token_here}"

# 颜色输出
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 测试计数
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0

# 测试函数
test_api() {
    local name="$1"
    local method="$2"
    local endpoint="$3"
    local data="$4"
    
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    echo -n "测试 ${TOTAL_TESTS}: ${name} ... "
    
    if [ "$method" = "GET" ]; then
        response=$(curl -s -w "\n%{http_code}" -X GET "${API_BASE}${endpoint}" \
            -H "Authorization: Bearer ${TOKEN}")
    else
        response=$(curl -s -w "\n%{http_code}" -X POST "${API_BASE}${endpoint}" \
            -H "Content-Type: application/json" \
            -H "Authorization: Bearer ${TOKEN}" \
            -d "${data}")
    fi
    
    http_code=$(echo "$response" | tail -n1)
    body=$(echo "$response" | head -n-1)
    
    if [ "$http_code" = "200" ] || [ "$http_code" = "201" ]; then
        echo -e "${GREEN}✓ 通过${NC}"
        PASSED_TESTS=$((PASSED_TESTS + 1))
        return 0
    else
        echo -e "${RED}✗ 失败 (HTTP $http_code)${NC}"
        echo "  响应: $body"
        FAILED_TESTS=$((FAILED_TESTS + 1))
        return 1
    fi
}

echo "开始测试..."
echo ""

# 1. 角色权限管理
echo "=== 1. 角色权限管理 ==="
test_api "创建角色并分配菜单权限" "POST" "/system/role/save" '{
    "role_name": "测试角色_'$(date +%s)'",
    "role_key": "test_role_'$(date +%s)'",
    "sort": 10,
    "remark": "内存泄漏修复测试",
    "status": 1,
    "menu_ids": [1, 2, 3]
}'

test_api "查询角色权限" "GET" "/system/role/permissions/info?role_id=2" ""

echo ""

# 2. 管理员管理
echo "=== 2. 管理员管理 ==="
test_api "分配管理员角色" "POST" "/system/admin/assign-roles" '{
    "admin_id": 2,
    "role_ids": [1, 2]
}'

echo ""

# 3. 会员管理
echo "=== 3. 会员管理 ==="
test_api "批量打标签" "POST" "/business/member/batch-tag" '{
    "member_ids": [1, 2],
    "tag_id": 1
}'

test_api "会员积分充值" "POST" "/business/member/point-recharge" '{
    "member_id": 1,
    "points": 100,
    "change_type": "add",
    "remark": "测试充值",
    "operator_id": 1
}'

test_api "会员余额充值" "POST" "/business/member/balance-recharge" '{
    "member_id": 1,
    "amount": 50.00,
    "change_type": "add",
    "payment_method": "alipay",
    "remark": "测试充值",
    "operator_id": 1
}'

echo ""

# 4. 系统配置
echo "=== 4. 系统配置 ==="
test_api "导入配置" "POST" "/system/config/import" '{
    "configs": [
        {
            "config_name": "测试配置",
            "config_key": "test_key_'$(date +%s)'",
            "config_value": "test_value",
            "config_group": "test",
            "config_type": "text"
        }
    ]
}'

echo ""

# 5. 版本管理
echo "=== 5. 版本管理 ==="
test_api "保存版本配置" "POST" "/system/version/save" '{
    "title": "测试版本_'$(date +%s)'",
    "version": "1.0.0",
    "remark": "测试版本",
    "status": 1
}'

echo ""

# 6. 支付配置
echo "=== 6. 支付配置 ==="
test_api "保存支付配置" "POST" "/system/payment/save" '{
    "channel_name": "测试支付_'$(date +%s)'",
    "channel_code": "test_pay",
    "sort": 10,
    "remark": "测试支付",
    "status": 1
}'

echo ""

# 7. 任务管理
echo "=== 7. 任务管理 ==="
test_api "手动执行任务" "POST" "/operation/task/execute" '{
    "id": 1
}'

echo ""
echo "=========================================="
echo "  测试结果统计"
echo "=========================================="
echo -e "总测试数: ${TOTAL_TESTS}"
echo -e "${GREEN}通过: ${PASSED_TESTS}${NC}"
echo -e "${RED}失败: ${FAILED_TESTS}${NC}"

if [ $FAILED_TESTS -eq 0 ]; then
    echo -e "\n${GREEN}✓ 所有测试通过！${NC}"
    exit 0
else
    echo -e "\n${RED}✗ 部分测试失败，请检查日志${NC}"
    exit 1
fi
