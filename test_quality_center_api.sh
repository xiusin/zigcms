#!/bin/bash

# 质量中心 API 测试脚本
# 使用方法: ./test_quality_center_api.sh [BASE_URL]
# 示例: ./test_quality_center_api.sh http://localhost:3000

BASE_URL="${1:-http://localhost:3000}"
API_PREFIX="/api/quality"

# 颜色定义
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 测试计数器
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0

# 测试结果记录
declare -a FAILED_ENDPOINTS

# 打印测试标题
print_header() {
    echo ""
    echo "=========================================="
    echo "$1"
    echo "=========================================="
}

# 打印测试结果
print_result() {
    local endpoint=$1
    local status=$2
    local expected=$3
    local response=$4
    
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    
    if [ "$status" -eq "$expected" ]; then
        echo -e "${GREEN}✓ PASS${NC} $endpoint (HTTP $status)"
        PASSED_TESTS=$((PASSED_TESTS + 1))
    else
        echo -e "${RED}✗ FAIL${NC} $endpoint (Expected: $expected, Got: $status)"
        echo "  Response: $response"
        FAILED_TESTS=$((FAILED_TESTS + 1))
        FAILED_ENDPOINTS+=("$endpoint")
    fi
}

# 测试 GET 请求
test_get() {
    local endpoint=$1
    local expected_status=${2:-200}
    
    response=$(curl -s -w "\n%{http_code}" -X GET "${BASE_URL}${API_PREFIX}${endpoint}")
    status=$(echo "$response" | tail -n1)
    body=$(echo "$response" | sed '$d')
    
    print_result "GET $endpoint" "$status" "$expected_status" "$body"
}

# 测试 POST 请求
test_post() {
    local endpoint=$1
    local data=$2
    local expected_status=${3:-200}
    
    response=$(curl -s -w "\n%{http_code}" -X POST \
        -H "Content-Type: application/json" \
        -d "$data" \
        "${BASE_URL}${API_PREFIX}${endpoint}")
    status=$(echo "$response" | tail -n1)
    body=$(echo "$response" | sed '$d')
    
    print_result "POST $endpoint" "$status" "$expected_status" "$body"
}

# 测试 PUT 请求
test_put() {
    local endpoint=$1
    local data=$2
    local expected_status=${3:-200}
    
    response=$(curl -s -w "\n%{http_code}" -X PUT \
        -H "Content-Type: application/json" \
        -d "$data" \
        "${BASE_URL}${API_PREFIX}${endpoint}")
    status=$(echo "$response" | tail -n1)
    body=$(echo "$response" | sed '$d')
    
    print_result "PUT $endpoint" "$status" "$expected_status" "$body"
}

# 测试 DELETE 请求
test_delete() {
    local endpoint=$1
    local expected_status=${2:-200}
    
    response=$(curl -s -w "\n%{http_code}" -X DELETE "${BASE_URL}${API_PREFIX}${endpoint}")
    status=$(echo "$response" | tail -n1)
    body=$(echo "$response" | sed '$d')
    
    print_result "DELETE $endpoint" "$status" "$expected_status" "$body"
}

# 开始测试
echo "=========================================="
echo "质量中心 API 测试"
echo "Base URL: $BASE_URL"
echo "=========================================="

# ==========================================
# 1. 项目管理 API 测试
# ==========================================
print_header "1. 项目管理 API"

# 创建项目
test_post "/projects" '{
  "name": "测试项目",
  "description": "这是一个测试项目",
  "owner": "admin"
}' 200

# 查询项目列表
test_get "/projects?page=1&page_size=20" 200

# 查询项目详情（假设 ID=1）
test_get "/projects/1" 200

# 更新项目
test_put "/projects/1" '{
  "name": "更新后的项目",
  "description": "更新后的描述"
}' 200

# 获取项目统计
test_get "/projects/1/statistics" 200

# 归档项目
test_post "/projects/1/archive" '{}' 200

# 恢复项目
test_post "/projects/1/restore" '{}' 200

# ==========================================
# 2. 模块管理 API 测试
# ==========================================
print_header "2. 模块管理 API"

# 创建模块
test_post "/modules" '{
  "project_id": 1,
  "name": "测试模块",
  "description": "这是一个测试模块"
}' 200

# 查询模块列表
test_get "/modules?project_id=1" 200

# 查询模块树
test_get "/modules/tree?project_id=1" 200

# 查询模块详情
test_get "/modules/1" 200

# 更新模块
test_put "/modules/1" '{
  "name": "更新后的模块",
  "description": "更新后的描述"
}' 200

# 移动模块
test_post "/modules/1/move" '{
  "parent_id": null,
  "sort_order": 1
}' 200

# 获取模块统计
test_get "/modules/1/statistics" 200

# ==========================================
# 3. 需求管理 API 测试
# ==========================================
print_header "3. 需求管理 API"

# 创建需求
test_post "/requirements" '{
  "project_id": 1,
  "title": "测试需求",
  "description": "这是一个测试需求",
  "priority": "high"
}' 200

# 查询需求列表
test_get "/requirements?project_id=1&page=1&page_size=20" 200

# 查询需求详情
test_get "/requirements/1" 200

# 更新需求
test_put "/requirements/1" '{
  "title": "更新后的需求",
  "description": "更新后的描述",
  "priority": "medium"
}' 200

# 关联测试用例
test_post "/requirements/1/test-cases" '{
  "test_case_id": 1
}' 200

# 取消关联测试用例
test_delete "/requirements/1/test-cases/1" 200

# 导出需求
test_get "/requirements/export?project_id=1" 200

# ==========================================
# 4. 测试用例管理 API 测试
# ==========================================
print_header "4. 测试用例管理 API"

# 创建测试用例
test_post "/test-cases" '{
  "title": "测试用例1",
  "project_id": 1,
  "module_id": 1,
  "priority": "high",
  "precondition": "前置条件",
  "steps": "测试步骤",
  "expected_result": "预期结果"
}' 200

# 搜索测试用例
test_get "/test-cases?project_id=1&page=1&page_size=20" 200

# 查询测试用例详情
test_get "/test-cases/1" 200

# 更新测试用例
test_put "/test-cases/1" '{
  "title": "更新后的测试用例",
  "priority": "medium"
}' 200

# 执行测试用例
test_post "/test-cases/1/execute" '{
  "status": "passed",
  "actual_result": "实际结果",
  "executor": "admin"
}' 200

# 查询执行历史
test_get "/test-cases/1/executions" 200

# 批量删除测试用例
test_post "/test-cases/batch-delete" '{
  "ids": [999, 1000]
}' 200

# 批量更新状态
test_post "/test-cases/batch-update-status" '{
  "ids": [1],
  "status": "in_progress"
}' 200

# 批量分配负责人
test_post "/test-cases/batch-update-assignee" '{
  "ids": [1],
  "assignee": "admin"
}' 200

# ==========================================
# 5. AI 生成 API 测试
# ==========================================
print_header "5. AI 生成 API"

# AI 生成测试用例
test_post "/ai/generate-test-cases" '{
  "requirement_id": 1,
  "max_cases": 5
}' 200

# AI 生成需求
test_post "/ai/generate-requirement" '{
  "description": "用户登录功能"
}' 200

# AI 分析反馈
test_post "/ai/analyze-feedback" '{
  "content": "系统登录时出现500错误"
}' 200

# ==========================================
# 6. 反馈管理 API 测试
# ==========================================
print_header "6. 反馈管理 API"

# 创建反馈
test_post "/feedbacks" '{
  "title": "测试反馈",
  "content": "这是一个测试反馈",
  "type": "bug",
  "severity": "high",
  "submitter": "user1"
}' 200

# 查询反馈列表
test_get "/feedbacks?page=1&page_size=20" 200

# 查询反馈详情
test_get "/feedbacks/1" 200

# 更新反馈
test_put "/feedbacks/1" '{
  "title": "更新后的反馈",
  "status": "in_progress"
}' 200

# 添加跟进记录
test_post "/feedbacks/1/follow-ups" '{
  "content": "已开始处理",
  "follower": "admin"
}' 200

# 批量指派
test_post "/feedbacks/batch-assign" '{
  "ids": [1],
  "assignee": "admin"
}' 200

# 批量更新状态
test_post "/feedbacks/batch-update-status" '{
  "ids": [1],
  "status": "resolved"
}' 200

# 导出反馈
test_get "/feedbacks/export" 200

# ==========================================
# 7. 统计分析 API 测试
# ==========================================
print_header "7. 统计分析 API"

# 模块质量分布
test_get "/statistics/module-distribution?project_id=1" 200

# Bug 质量分布
test_get "/statistics/bug-distribution?project_id=1" 200

# 反馈状态分布
test_get "/statistics/feedback-distribution" 200

# 质量趋势
test_get "/statistics/quality-trend?project_id=1&days=30" 200

# 导出图表
test_get "/statistics/export-chart?type=module-distribution&project_id=1&format=png" 200

# ==========================================
# 8. 错误处理测试
# ==========================================
print_header "8. 错误处理测试"

# 测试 404 错误
test_get "/not-found" 404

# 测试无效 ID
test_get "/projects/99999" 404

# 测试缺少必填字段
test_post "/projects" '{}' 400

# 测试无效的 JSON
test_post "/projects" 'invalid json' 400

# 测试批量操作超限（假设限制 1000 条）
test_post "/test-cases/batch-delete" "{\"ids\": $(seq -s, 1 1001 | sed 's/^/[/;s/$/]/')}" 400

# ==========================================
# 测试总结
# ==========================================
echo ""
echo "=========================================="
echo "测试总结"
echo "=========================================="
echo -e "总测试数: $TOTAL_TESTS"
echo -e "${GREEN}通过: $PASSED_TESTS${NC}"
echo -e "${RED}失败: $FAILED_TESTS${NC}"

if [ $FAILED_TESTS -gt 0 ]; then
    echo ""
    echo "失败的端点:"
    for endpoint in "${FAILED_ENDPOINTS[@]}"; do
        echo -e "  ${RED}✗${NC} $endpoint"
    done
    echo ""
    exit 1
else
    echo ""
    echo -e "${GREEN}所有测试通过！${NC}"
    echo ""
    exit 0
fi
