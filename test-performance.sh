#!/bin/bash

# 质量中心性能测试脚本
# 用于验证性能优化效果

set -e

echo "=========================================="
echo "质量中心性能测试"
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
test_performance() {
    local test_name=$1
    local endpoint=$2
    local expected_time=$3
    
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    
    echo -n "测试: $test_name ... "
    
    # 执行 3 次取平均值
    local total_time=0
    for i in {1..3}; do
        local response_time=$(curl -o /dev/null -s -w '%{time_total}' "$endpoint")
        total_time=$(echo "$total_time + $response_time" | bc)
    done
    
    local avg_time=$(echo "scale=3; $total_time / 3" | bc)
    local avg_time_ms=$(echo "$avg_time * 1000" | bc | cut -d'.' -f1)
    
    if [ "$avg_time_ms" -lt "$expected_time" ]; then
        echo -e "${GREEN}✓ 通过${NC} (${avg_time_ms}ms < ${expected_time}ms)"
        PASSED_TESTS=$((PASSED_TESTS + 1))
    else
        echo -e "${RED}✗ 失败${NC} (${avg_time_ms}ms >= ${expected_time}ms)"
        FAILED_TESTS=$((FAILED_TESTS + 1))
    fi
}

# 检查依赖
if ! command -v curl &> /dev/null; then
    echo -e "${RED}错误: 需要安装 curl${NC}"
    exit 1
fi

if ! command -v bc &> /dev/null; then
    echo -e "${RED}错误: 需要安装 bc${NC}"
    exit 1
fi

# 设置 API 基础 URL
API_BASE="${API_BASE:-http://localhost:3000}"

echo "API 基础 URL: $API_BASE"
echo ""

# 1. 测试用例列表查询性能
echo "=========================================="
echo "1. 测试用例列表查询性能"
echo "=========================================="
test_performance "测试用例列表查询" \
    "$API_BASE/api/quality/test-cases?page=1&page_size=20" \
    500

echo ""

# 2. 项目统计查询性能
echo "=========================================="
echo "2. 项目统计查询性能"
echo "=========================================="
test_performance "项目统计查询" \
    "$API_BASE/api/quality/projects/1/statistics" \
    1000

echo ""

# 3. 模块树查询性能
echo "=========================================="
echo "3. 模块树查询性能"
echo "=========================================="
test_performance "模块树查询" \
    "$API_BASE/api/quality/modules/tree?project_id=1" \
    500

echo ""

# 4. 批量操作性能
echo "=========================================="
echo "4. 批量操作性能"
echo "=========================================="
echo "注意: 批量操作需要手动测试"
echo "- 批量删除: POST /api/quality/test-cases/batch-delete"
echo "- 批量更新状态: POST /api/quality/test-cases/batch-update-status"
echo ""

# 5. 缓存命中率测试
echo "=========================================="
echo "5. 缓存命中率测试"
echo "=========================================="
echo "执行 100 次相同查询测试缓存命中率..."

cache_test_endpoint="$API_BASE/api/quality/test-cases/1"
total_time=0
cache_hits=0

for i in {1..100}; do
    response_time=$(curl -o /dev/null -s -w '%{time_total}' "$cache_test_endpoint")
    total_time=$(echo "$total_time + $response_time" | bc)
    
    # 如果响应时间 < 50ms，认为是缓存命中
    response_time_ms=$(echo "$response_time * 1000" | bc | cut -d'.' -f1)
    if [ "$response_time_ms" -lt 50 ]; then
        cache_hits=$((cache_hits + 1))
    fi
    
    # 显示进度
    if [ $((i % 10)) -eq 0 ]; then
        echo -n "."
    fi
done

echo ""
cache_hit_rate=$((cache_hits * 100 / 100))
avg_time=$(echo "scale=3; $total_time / 100" | bc)
avg_time_ms=$(echo "$avg_time * 1000" | bc | cut -d'.' -f1)

echo "缓存命中率: $cache_hit_rate%"
echo "平均响应时间: ${avg_time_ms}ms"

TOTAL_TESTS=$((TOTAL_TESTS + 1))
if [ "$cache_hit_rate" -ge 80 ]; then
    echo -e "${GREEN}✓ 缓存命中率测试通过${NC} ($cache_hit_rate% >= 80%)"
    PASSED_TESTS=$((PASSED_TESTS + 1))
else
    echo -e "${RED}✗ 缓存命中率测试失败${NC} ($cache_hit_rate% < 80%)"
    FAILED_TESTS=$((FAILED_TESTS + 1))
fi

echo ""

# 6. 并发性能测试
echo "=========================================="
echo "6. 并发性能测试"
echo "=========================================="
echo "执行 100 并发请求测试..."

if command -v ab &> /dev/null; then
    ab -n 1000 -c 100 -q "$API_BASE/api/quality/test-cases?page=1&page_size=20" > /tmp/ab_result.txt 2>&1
    
    # 提取关键指标
    avg_time=$(grep "Time per request" /tmp/ab_result.txt | head -1 | awk '{print $4}')
    qps=$(grep "Requests per second" /tmp/ab_result.txt | awk '{print $4}')
    
    echo "平均响应时间: ${avg_time}ms"
    echo "QPS: $qps"
    
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    avg_time_int=$(echo "$avg_time" | cut -d'.' -f1)
    if [ "$avg_time_int" -lt 500 ]; then
        echo -e "${GREEN}✓ 并发性能测试通过${NC} (${avg_time}ms < 500ms)"
        PASSED_TESTS=$((PASSED_TESTS + 1))
    else
        echo -e "${RED}✗ 并发性能测试失败${NC} (${avg_time}ms >= 500ms)"
        FAILED_TESTS=$((FAILED_TESTS + 1))
    fi
else
    echo -e "${YELLOW}⚠ 跳过并发测试 (需要安装 apache2-utils)${NC}"
fi

echo ""

# 测试总结
echo "=========================================="
echo "测试总结"
echo "=========================================="
echo "总测试数: $TOTAL_TESTS"
echo -e "通过: ${GREEN}$PASSED_TESTS${NC}"
echo -e "失败: ${RED}$FAILED_TESTS${NC}"
echo ""

if [ "$FAILED_TESTS" -eq 0 ]; then
    echo -e "${GREEN}✓ 所有性能测试通过！${NC}"
    exit 0
else
    echo -e "${RED}✗ 部分性能测试失败${NC}"
    exit 1
fi
