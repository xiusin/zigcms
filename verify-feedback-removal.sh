#!/bin/bash

# 验证"建议反馈"模块删除脚本
# 用于确认所有相关文件已被正确删除，质量中心功能完整保留

echo "=========================================="
echo "验证建议反馈模块删除情况"
echo "=========================================="
echo ""

# 检查已删除的文件
echo "1. 检查已删除的文件..."
echo ""

files_to_check=(
  "ecom-admin/src/router/routes/modules/feedback.ts"
  "ecom-admin/src/views/feedback"
  "ecom-admin/src/components/feedback/AttachmentManager.vue"
  "ecom-admin/src/components/feedback/MentionInput.vue"
  "ecom-admin/src/components/feedback/SmartClassificationPanel.vue"
  "ecom-admin/src/api/feedback.ts"
  "ecom-admin/src/api/feedback-notification.ts"
  "ecom-admin/src/store/modules/feedback"
  "ecom-admin/src/store/modules/feedback-notification"
  "ecom-admin/src/mock/feedback.ts"
  "ecom-admin/src/mock/feedback-notification.ts"
  "ecom-admin/src/composables/useFeedbackClassification.ts"
)

deleted_count=0
for file in "${files_to_check[@]}"; do
  if [ ! -e "$file" ]; then
    echo "✅ 已删除: $file"
    ((deleted_count++))
  else
    echo "❌ 仍存在: $file"
  fi
done

echo ""
echo "已删除文件数: $deleted_count / ${#files_to_check[@]}"
echo ""

# 检查保留的文件
echo "2. 检查保留的文件（质量中心使用）..."
echo ""

preserved_files=(
  "ecom-admin/src/components/feedback/CommentSection.vue"
  "ecom-admin/src/components/feedback/FeedbackFlowChart.vue"
  "ecom-admin/src/views/quality-center/feedback/index.vue"
  "ecom-admin/src/views/quality-center/feedback/detail.vue"
)

preserved_count=0
for file in "${preserved_files[@]}"; do
  if [ -e "$file" ]; then
    echo "✅ 已保留: $file"
    ((preserved_count++))
  else
    echo "❌ 缺失: $file"
  fi
done

echo ""
echo "已保留文件数: $preserved_count / ${#preserved_files[@]}"
echo ""

# 检查路由配置
echo "3. 检查路由配置..."
echo ""

if grep -q "import feedback from './modules/feedback'" ecom-admin/src/router/routes/index.ts 2>/dev/null; then
  echo "❌ 路由配置中仍有 feedback 导入"
else
  echo "✅ 路由配置中已移除 feedback 导入"
fi

if grep -q "feedback," ecom-admin/src/router/routes/index.ts 2>/dev/null; then
  echo "❌ 路由配置中仍有 feedback 注册"
else
  echo "✅ 路由配置中已移除 feedback 注册"
fi

echo ""

# 检查 Mock 配置
echo "4. 检查 Mock 配置..."
echo ""

if grep -q "import feedbackMock from './feedback'" ecom-admin/src/mock/index.ts 2>/dev/null; then
  echo "❌ Mock 配置中仍有 feedbackMock 导入"
else
  echo "✅ Mock 配置中已移除 feedbackMock 导入"
fi

if grep -q "import feedbackNotificationMock from './feedback-notification'" ecom-admin/src/mock/index.ts 2>/dev/null; then
  echo "❌ Mock 配置中仍有 feedbackNotificationMock 导入"
else
  echo "✅ Mock 配置中已移除 feedbackNotificationMock 导入"
fi

echo ""

# 检查导航栏
echo "5. 检查导航栏组件..."
echo ""

if grep -q "FeedbackNotificationCenter" ecom-admin/src/components/navbar/index.vue 2>/dev/null; then
  echo "❌ 导航栏中仍有 FeedbackNotificationCenter 引用"
else
  echo "✅ 导航栏中已移除 FeedbackNotificationCenter 引用"
fi

echo ""

# 检查质量中心依赖
echo "6. 检查质量中心依赖..."
echo ""

if grep -q "@/components/feedback/FeedbackFlowChart" ecom-admin/src/views/quality-center/feedback/detail.vue 2>/dev/null; then
  echo "✅ 质量中心正确引用 FeedbackFlowChart"
else
  echo "❌ 质量中心缺失 FeedbackFlowChart 引用"
fi

if grep -q "@/components/feedback/CommentSection" ecom-admin/src/views/quality-center/feedback/detail.vue 2>/dev/null; then
  echo "✅ 质量中心正确引用 CommentSection"
else
  echo "❌ 质量中心缺失 CommentSection 引用"
fi

echo ""
echo "=========================================="
echo "验证完成！"
echo "=========================================="
echo ""
echo "建议执行以下命令清除缓存并重启开发服务器："
echo "  rm -rf ecom-admin/node_modules/.vite"
echo "  cd ecom-admin && npm run dev"
echo ""
