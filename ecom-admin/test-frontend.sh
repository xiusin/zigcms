#!/bin/bash

# 质量中心前端功能自动化测试脚本
# 执行时间: 2026-03-05

echo "========================================="
echo "质量中心前端功能测试"
echo "========================================="
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
test_item() {
    local test_name="$1"
    local test_command="$2"
    
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    
    echo -n "测试: $test_name ... "
    
    if eval "$test_command" > /dev/null 2>&1; then
        echo -e "${GREEN}✓ 通过${NC}"
        PASSED_TESTS=$((PASSED_TESTS + 1))
        return 0
    else
        echo -e "${RED}✗ 失败${NC}"
        FAILED_TESTS=$((FAILED_TESTS + 1))
        return 1
    fi
}

# 检查文件存在
check_file() {
    local file="$1"
    test -f "$file"
}

# 检查目录存在
check_dir() {
    local dir="$1"
    test -d "$dir"
}

# 检查文件包含内容
check_content() {
    local file="$1"
    local pattern="$2"
    grep -q "$pattern" "$file"
}

echo "1. 检查核心页面文件"
echo "-----------------------------------"
test_item "测试用例列表页" "check_file src/views/quality-center/test-case/index.vue"
test_item "测试用例表格组件" "check_file src/views/quality-center/test-case/components/TestCaseTable.vue"
test_item "测试用例表单组件" "check_file src/views/quality-center/test-case/components/TestCaseForm.vue"
test_item "AI 生成对话框" "check_file src/views/quality-center/test-case/components/AIGenerateDialog.vue"
test_item "执行历史组件" "check_file src/views/quality-center/test-case/components/ExecutionHistory.vue"
echo ""

echo "2. 检查项目管理页面"
echo "-----------------------------------"
test_item "项目列表页" "check_file src/views/quality-center/project/index.vue"
test_item "项目详情页" "check_file src/views/quality-center/project/detail.vue"
test_item "项目卡片组件" "check_file src/views/quality-center/project/components/ProjectCard.vue"
test_item "项目统计组件" "check_file src/views/quality-center/project/components/ProjectStatistics.vue"
echo ""

echo "3. 检查模块管理页面"
echo "-----------------------------------"
test_item "模块列表页" "check_file src/views/quality-center/module/index.vue"
test_item "模块树组件" "check_file src/views/quality-center/module/components/ModuleTree.vue"
test_item "模块表单组件" "check_file src/views/quality-center/module/components/ModuleForm.vue"
echo ""

echo "4. 检查需求管理页面"
echo "-----------------------------------"
test_item "需求列表页" "check_file src/views/quality-center/requirement/index.vue"
test_item "需求详情页" "check_file src/views/quality-center/requirement/detail.vue"
test_item "需求表格组件" "check_file src/views/quality-center/requirement/components/RequirementTable.vue"
test_item "关联测试用例组件" "check_file src/views/quality-center/requirement/components/LinkedTestCases.vue"
echo ""

echo "5. 检查反馈管理页面"
echo "-----------------------------------"
test_item "反馈列表页" "check_file src/views/quality-center/feedback/index.vue"
test_item "反馈详情页" "check_file src/views/quality-center/feedback/detail.vue"
test_item "反馈表格组件" "check_file src/views/quality-center/feedback/components/FeedbackTable.vue"
test_item "跟进时间线组件" "check_file src/views/quality-center/feedback/components/FollowUpTimeline.vue"
echo ""

echo "6. 检查数据可视化页面"
echo "-----------------------------------"
test_item "质量中心首页" "check_file src/views/quality-center/dashboard/index.vue"
test_item "模块质量分布图" "check_file src/views/quality-center/dashboard/components/ModuleDistribution.vue"
test_item "Bug 质量分布图" "check_file src/views/quality-center/dashboard/components/BugDistribution.vue"
test_item "反馈状态分布图" "check_file src/views/quality-center/dashboard/components/FeedbackDistribution.vue"
test_item "质量趋势图" "check_file src/views/quality-center/dashboard/components/QualityTrend.vue"
echo ""

echo "7. 检查脑图视图页面"
echo "-----------------------------------"
test_item "脑图页面" "check_file src/views/quality-center/mindmap/index.vue"
echo ""

echo "8. 检查 API 客户端"
echo "-----------------------------------"
test_item "API 客户端文件" "check_file src/api/quality-center.ts"
test_item "类型定义文件" "check_file src/types/quality-center.d.ts"
echo ""

echo "9. 检查工具函数"
echo "-----------------------------------"
test_item "键盘快捷键工具" "check_file src/utils/keyboard.ts"
test_item "操作反馈工具" "check_file src/utils/feedback.ts"
test_item "本地存储工具" "check_file src/utils/storage.ts"
echo ""

echo "10. 检查路由配置"
echo "-----------------------------------"
test_item "质量中心路由" "check_file src/router/routes/modules/quality-center.ts"
echo ""

echo "11. 检查关键功能实现"
echo "-----------------------------------"
test_item "键盘快捷键 - Ctrl+S" "check_content src/utils/keyboard.ts 'Ctrl.*S'"
test_item "键盘快捷键 - Ctrl+F" "check_content src/utils/keyboard.ts 'Ctrl.*F'"
test_item "键盘快捷键 - Esc" "check_content src/utils/keyboard.ts 'Escape'"
test_item "Toast 提示 - 成功" "check_content src/utils/feedback.ts 'showSuccess'"
test_item "Toast 提示 - 错误" "check_content src/utils/feedback.ts 'showError'"
test_item "Toast 提示 - 警告" "check_content src/utils/feedback.ts 'showWarning'"
test_item "确认对话框" "check_content src/utils/feedback.ts 'showConfirm'"
test_item "删除确认" "check_content src/utils/feedback.ts 'showDeleteConfirm'"
test_item "批量操作确认" "check_content src/utils/feedback.ts 'showBatchConfirm'"
test_item "表格状态记忆" "check_content src/utils/storage.ts 'saveTableState'"
test_item "用户偏好设置" "check_content src/utils/storage.ts 'savePreferences'"
echo ""

echo "12. 检查响应式设计"
echo "-----------------------------------"
test_item "响应式栅格系统" "check_content src/views/quality-center/dashboard/index.vue 'a-col'"
test_item "移动端适配" "check_content src/views/quality-center/test-case/index.vue 'xs='"
echo ""

echo "========================================="
echo "测试结果汇总"
echo "========================================="
echo -e "总计测试: ${TOTAL_TESTS}"
echo -e "通过测试: ${GREEN}${PASSED_TESTS}${NC}"
echo -e "失败测试: ${RED}${FAILED_TESTS}${NC}"
echo ""

if [ $FAILED_TESTS -eq 0 ]; then
    echo -e "${GREEN}✓ 所有测试通过！${NC}"
    echo ""
    echo "建议："
    echo "1. 启动开发服务器: npm run dev"
    echo "2. 在浏览器中手动测试各个页面"
    echo "3. 测试不同分辨率下的响应式设计"
    echo "4. 测试键盘快捷键功能"
    echo "5. 测试主题切换功能"
    exit 0
else
    echo -e "${RED}✗ 部分测试失败，请检查缺失的文件${NC}"
    exit 1
fi
