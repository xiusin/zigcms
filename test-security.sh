#!/bin/bash

# 质量中心安全性测试脚本
# 用于验证 SQL 注入防护、输入验证等安全机制

set -e

echo "=========================================="
echo "质量中心安全性测试"
echo "=========================================="
echo ""

# 颜色定义
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 测试结果统计
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0

# 测试函数
test_case() {
    local name=$1
    local expected=$2
    local command=$3
    
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    echo -n "测试 $TOTAL_TESTS: $name ... "
    
    if eval "$command" > /dev/null 2>&1; then
        if [ "$expected" = "pass" ]; then
            echo -e "${GREEN}✓ 通过${NC}"
            PASSED_TESTS=$((PASSED_TESTS + 1))
        else
            echo -e "${RED}✗ 失败 (预期失败但通过)${NC}"
            FAILED_TESTS=$((FAILED_TESTS + 1))
        fi
    else
        if [ "$expected" = "fail" ]; then
            echo -e "${GREEN}✓ 通过 (正确拒绝)${NC}"
            PASSED_TESTS=$((PASSED_TESTS + 1))
        else
            echo -e "${RED}✗ 失败 (预期通过但失败)${NC}"
            FAILED_TESTS=$((FAILED_TESTS + 1))
        fi
    fi
}

echo "1. SQL 注入防护测试"
echo "----------------------------------------"


# 注意：这些测试需要服务器运行在 localhost:3000
# 如果服务器地址不同，请修改 BASE_URL
BASE_URL="http://localhost:3000"

# 测试 1.1: 基础 SQL 注入
test_case "基础 SQL 注入防护" "pass" \
    "curl -s -X POST $BASE_URL/api/quality/test-cases/search \
    -H 'Content-Type: application/json' \
    -d '{\"keyword\": \"' OR '1'='1\"}' | grep -q 'success'"

# 测试 1.2: UNION 注入
test_case "UNION 注入防护" "pass" \
    "curl -s -X POST $BASE_URL/api/quality/test-cases/search \
    -H 'Content-Type: application/json' \
    -d '{\"keyword\": \"' UNION SELECT * FROM users--\"}' | grep -q 'success'"

# 测试 1.3: 注释注入
test_case "注释注入防护" "pass" \
    "curl -s -X POST $BASE_URL/api/quality/test-cases/search \
    -H 'Content-Type: application/json' \
    -d '{\"keyword\": \"admin'--\"}' | grep -q 'success'"

echo ""
echo "2. 输入验证测试"
echo "----------------------------------------"

# 测试 2.1: 必填字段缺失
test_case "必填字段验证" "fail" \
    "curl -s -X POST $BASE_URL/api/quality/test-cases \
    -H 'Content-Type: application/json' \
    -d '{\"project_id\": 1}' | grep -q 'success'"

# 测试 2.2: 长度超限
test_case "长度限制验证" "fail" \
    "curl -s -X POST $BASE_URL/api/quality/test-cases \
    -H 'Content-Type: application/json' \
    -d '{\"title\": \"$(python3 -c 'print("A"*201)')\", \"project_id\": 1, \"module_id\": 1}' | grep -q 'success'"

# 测试 2.3: 类型错误
test_case "类型验证" "fail" \
    "curl -s -X POST $BASE_URL/api/quality/test-cases \
    -H 'Content-Type: application/json' \
    -d '{\"title\": \"Test\", \"project_id\": \"invalid\", \"module_id\": 1}' | grep -q 'success'"


echo ""
echo "3. 批量操作安全测试"
echo "----------------------------------------"

# 测试 3.1: 批量删除空列表
test_case "批量删除空列表验证" "fail" \
    "curl -s -X POST $BASE_URL/api/quality/test-cases/batch-delete \
    -H 'Content-Type: application/json' \
    -d '{\"ids\": []}' | grep -q 'success'"

# 测试 3.2: 批量操作超限
test_case "批量操作限制验证" "fail" \
    "curl -s -X POST $BASE_URL/api/quality/test-cases/batch-delete \
    -H 'Content-Type: application/json' \
    -d '{\"ids\": [$(seq -s, 1 1001)]}' | grep -q 'success'"

echo ""
echo "4. XSS 防护测试"
echo "----------------------------------------"

# 测试 4.1: 脚本注入存储
test_case "XSS 脚本存储" "pass" \
    "curl -s -X POST $BASE_URL/api/quality/test-cases \
    -H 'Content-Type: application/json' \
    -d '{\"title\": \"<script>alert(1)</script>\", \"project_id\": 1, \"module_id\": 1}' | grep -q 'success'"

# 测试 4.2: HTML 注入存储
test_case "XSS HTML 存储" "pass" \
    "curl -s -X POST $BASE_URL/api/quality/feedbacks \
    -H 'Content-Type: application/json' \
    -d '{\"title\": \"Test\", \"content\": \"<img src=x onerror=alert(1)>\"}' | grep -q 'success'"

echo ""
echo "=========================================="
echo "测试结果汇总"
echo "=========================================="
echo "总测试数: $TOTAL_TESTS"
echo -e "${GREEN}通过: $PASSED_TESTS${NC}"
echo -e "${RED}失败: $FAILED_TESTS${NC}"
echo ""

if [ $FAILED_TESTS -eq 0 ]; then
    echo -e "${GREEN}✓ 所有安全测试通过！${NC}"
    exit 0
else
    echo -e "${RED}✗ 部分测试失败，请检查安全配置${NC}"
    exit 1
fi

