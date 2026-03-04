#!/bin/bash

# 测试数据准备脚本
# 使用方法: ./prepare_test_data.sh [BASE_URL]

BASE_URL="${1:-http://localhost:3000}"
API_PREFIX="/api/quality"

# 颜色定义
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "=========================================="
echo "准备测试数据"
echo "Base URL: $BASE_URL"
echo "=========================================="
echo ""

# 创建项目
echo "创建测试项目..."
project_response=$(curl -s -X POST "${BASE_URL}${API_PREFIX}/projects" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "自动化测试项目",
    "description": "用于 API 测试的项目",
    "owner": "admin"
  }')

project_id=$(echo "$project_response" | grep -o '"id":[0-9]*' | head -1 | grep -o '[0-9]*')

if [ -n "$project_id" ]; then
    echo -e "${GREEN}✓ 项目创建成功 (ID: $project_id)${NC}"
else
    echo -e "${RED}✗ 项目创建失败${NC}"
    echo "响应: $project_response"
    exit 1
fi

# 创建模块
echo "创建测试模块..."
module_response=$(curl -s -X POST "${BASE_URL}${API_PREFIX}/modules" \
  -H "Content-Type: application/json" \
  -d "{
    \"project_id\": $project_id,
    \"name\": \"登录模块\",
    \"description\": \"用户登录相关功能\"
  }")

module_id=$(echo "$module_response" | grep -o '"id":[0-9]*' | head -1 | grep -o '[0-9]*')

if [ -n "$module_id" ]; then
    echo -e "${GREEN}✓ 模块创建成功 (ID: $module_id)${NC}"
else
    echo -e "${RED}✗ 模块创建失败${NC}"
    echo "响应: $module_response"
fi

# 创建子模块
echo "创建子模块..."
submodule_response=$(curl -s -X POST "${BASE_URL}${API_PREFIX}/modules" \
  -H "Content-Type: application/json" \
  -d "{
    \"project_id\": $project_id,
    \"parent_id\": $module_id,
    \"name\": \"用户名密码登录\",
    \"description\": \"传统用户名密码登录方式\"
  }")

submodule_id=$(echo "$submodule_response" | grep -o '"id":[0-9]*' | head -1 | grep -o '[0-9]*')

if [ -n "$submodule_id" ]; then
    echo -e "${GREEN}✓ 子模块创建成功 (ID: $submodule_id)${NC}"
fi

# 创建需求
echo "创建测试需求..."
requirement_response=$(curl -s -X POST "${BASE_URL}${API_PREFIX}/requirements" \
  -H "Content-Type: application/json" \
  -d "{
    \"project_id\": $project_id,
    \"title\": \"用户登录功能\",
    \"description\": \"用户可以使用用户名和密码登录系统\",
    \"priority\": \"high\"
  }")

requirement_id=$(echo "$requirement_response" | grep -o '"id":[0-9]*' | head -1 | grep -o '[0-9]*')

if [ -n "$requirement_id" ]; then
    echo -e "${GREEN}✓ 需求创建成功 (ID: $requirement_id)${NC}"
fi

# 创建测试用例
echo "创建测试用例..."
for i in {1..5}; do
    testcase_response=$(curl -s -X POST "${BASE_URL}${API_PREFIX}/test-cases" \
      -H "Content-Type: application/json" \
      -d "{
        \"title\": \"测试用例 $i\",
        \"project_id\": $project_id,
        \"module_id\": $module_id,
        \"requirement_id\": $requirement_id,
        \"priority\": \"medium\",
        \"precondition\": \"用户已注册\",
        \"steps\": \"1. 打开登录页面\\n2. 输入用户名和密码\\n3. 点击登录按钮\",
        \"expected_result\": \"登录成功，跳转到首页\"
      }")
    
    testcase_id=$(echo "$testcase_response" | grep -o '"id":[0-9]*' | head -1 | grep -o '[0-9]*')
    
    if [ -n "$testcase_id" ]; then
        echo -e "${GREEN}✓ 测试用例 $i 创建成功 (ID: $testcase_id)${NC}"
    fi
done

# 创建反馈
echo "创建测试反馈..."
feedback_response=$(curl -s -X POST "${BASE_URL}${API_PREFIX}/feedbacks" \
  -H "Content-Type: application/json" \
  -d '{
    "title": "登录页面加载慢",
    "content": "登录页面加载时间超过 5 秒",
    "type": "bug",
    "severity": "medium",
    "submitter": "user1"
  }')

feedback_id=$(echo "$feedback_response" | grep -o '"id":[0-9]*' | head -1 | grep -o '[0-9]*')

if [ -n "$feedback_id" ]; then
    echo -e "${GREEN}✓ 反馈创建成功 (ID: $feedback_id)${NC}"
fi

echo ""
echo "=========================================="
echo "测试数据准备完成"
echo "=========================================="
echo ""
echo "创建的资源："
echo "  项目 ID: $project_id"
echo "  模块 ID: $module_id"
echo "  子模块 ID: $submodule_id"
echo "  需求 ID: $requirement_id"
echo "  反馈 ID: $feedback_id"
echo ""
echo "现在可以运行 API 测试："
echo "  ./test_quality_center_api.sh $BASE_URL"
echo ""
