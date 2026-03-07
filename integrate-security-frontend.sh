#!/bin/bash

# 安全告警/通知前端自动集成脚本
# 用途：自动完成安全模块的前端集成
# 使用：chmod +x integrate-security-frontend.sh && ./integrate-security-frontend.sh

set -e

echo "=========================================="
echo "  安全告警/通知前端自动集成脚本"
echo "=========================================="
echo ""

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 检查前端目录
if [ ! -d "ecom-admin" ]; then
    echo -e "${RED}错误: 未找到 ecom-admin 目录${NC}"
    echo "请在项目根目录运行此脚本"
    exit 1
fi

echo -e "${GREEN}✓${NC} 找到前端目录"

# 检查必要文件
echo ""
echo "检查必要文件..."

files=(
    "ecom-admin/src/api/security.ts"
    "ecom-admin/src/types/security.d.ts"
    "ecom-admin/src/store/modules/security/index.ts"
    "ecom-admin/src/components/security/AlertNotification.vue"
    "ecom-admin/src/views/security/events/index.vue"
    "ecom-admin/src/router/modules/security.ts"
)

all_files_exist=true
for file in "${files[@]}"; do
    if [ -f "$file" ]; then
        echo -e "${GREEN}✓${NC} $file"
    else
        echo -e "${RED}✗${NC} $file ${RED}(缺失)${NC}"
        all_files_exist=false
    fi
done

if [ "$all_files_exist" = false ]; then
    echo ""
    echo -e "${RED}错误: 部分必要文件缺失${NC}"
    echo "请确保已完成前端文件创建"
    exit 1
fi

echo ""
echo -e "${GREEN}✓${NC} 所有必要文件已就绪"

# 备份原文件
echo ""
echo "备份原文件..."

backup_dir="backups/security-integration-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$backup_dir"

if [ -f "ecom-admin/src/router/index.ts" ]; then
    cp "ecom-admin/src/router/index.ts" "$backup_dir/"
    echo -e "${GREEN}✓${NC} 已备份 router/index.ts"
fi

if [ -f "ecom-admin/src/main.ts" ]; then
    cp "ecom-admin/src/main.ts" "$backup_dir/"
    echo -e "${GREEN}✓${NC} 已备份 main.ts"
fi

# 查找 Header 组件
header_file=""
if [ -f "ecom-admin/src/layout/components/Header.vue" ]; then
    header_file="ecom-admin/src/layout/components/Header.vue"
elif [ -f "ecom-admin/src/layouts/components/Header.vue" ]; then
    header_file="ecom-admin/src/layouts/components/Header.vue"
elif [ -f "ecom-admin/src/components/layout/Header.vue" ]; then
    header_file="ecom-admin/src/components/layout/Header.vue"
fi

if [ -n "$header_file" ]; then
    cp "$header_file" "$backup_dir/"
    echo -e "${GREEN}✓${NC} 已备份 Header.vue"
else
    echo -e "${YELLOW}⚠${NC} 未找到 Header.vue，跳过备份"
fi

echo ""
echo -e "${GREEN}✓${NC} 备份完成: $backup_dir"

# Step 1: 集成路由
echo ""
echo "=========================================="
echo "Step 1: 集成安全路由"
echo "=========================================="

router_file="ecom-admin/src/router/index.ts"

if [ ! -f "$router_file" ]; then
    echo -e "${RED}错误: 未找到 $router_file${NC}"
    exit 1
fi

# 检查是否已经导入
if grep -q "from './modules/security'" "$router_file"; then
    echo -e "${YELLOW}⚠${NC} 安全路由已导入，跳过"
else
    # 在导入区域添加
    echo ""
    echo "添加安全路由导入..."
    
    # 创建临时文件
    temp_file=$(mktemp)
    
    # 在第一个 import 语句后添加
    awk '
        /^import.*from.*router/ && !done {
            print
            print "import securityRoutes from '\''./modules/security'\'';"
            done=1
            next
        }
        {print}
    ' "$router_file" > "$temp_file"
    
    mv "$temp_file" "$router_file"
    echo -e "${GREEN}✓${NC} 已添加安全路由导入"
fi

# 检查是否已经添加到 routes 数组
if grep -q "securityRoutes" "$router_file"; then
    echo -e "${YELLOW}⚠${NC} 安全路由已添加到 routes 数组，跳过"
else
    echo ""
    echo "添加安全路由到 routes 数组..."
    
    # 这部分需要手动完成，因为 routes 数组结构可能不同
    echo -e "${YELLOW}⚠${NC} 请手动在 routes 数组中添加 securityRoutes"
    echo ""
    echo "在 $router_file 中找到 routes 数组，添加："
    echo "  securityRoutes,"
fi

echo ""
echo -e "${GREEN}✓${NC} Step 1 完成"

# Step 2: 集成通知组件
echo ""
echo "=========================================="
echo "Step 2: 集成通知组件到 Header"
echo "=========================================="

if [ -z "$header_file" ]; then
    echo -e "${YELLOW}⚠${NC} 未找到 Header.vue，请手动添加通知组件"
    echo ""
    echo "在 Header 组件中添加："
    echo "  <AlertNotification />"
    echo ""
    echo "并导入："
    echo "  import AlertNotification from '@/components/security/AlertNotification.vue';"
else
    # 检查是否已经导入
    if grep -q "AlertNotification" "$header_file"; then
        echo -e "${YELLOW}⚠${NC} AlertNotification 已导入，跳过"
    else
        echo ""
        echo "添加 AlertNotification 导入..."
        
        # 这部分需要手动完成，因为 Header 结构可能不同
        echo -e "${YELLOW}⚠${NC} 请手动在 Header.vue 中添加 AlertNotification 组件"
        echo ""
        echo "在 $header_file 中："
        echo "1. 添加导入："
        echo "   import AlertNotification from '@/components/security/AlertNotification.vue';"
        echo ""
        echo "2. 在模板中添加："
        echo "   <AlertNotification />"
    fi
fi

echo ""
echo -e "${GREEN}✓${NC} Step 2 完成"

# Step 3: 初始化 Store
echo ""
echo "=========================================="
echo "Step 3: 初始化安全 Store"
echo "=========================================="

main_file="ecom-admin/src/main.ts"

if [ ! -f "$main_file" ]; then
    echo -e "${RED}错误: 未找到 $main_file${NC}"
    exit 1
fi

# 检查是否已经初始化
if grep -q "useSecurityStore" "$main_file"; then
    echo -e "${YELLOW}⚠${NC} 安全 Store 已初始化，跳过"
else
    echo ""
    echo "添加安全 Store 初始化代码..."
    
    # 添加到文件末尾
    cat >> "$main_file" << 'EOF'

// 初始化安全 Store
import { useSecurityStore } from '@/store/modules/security';

router.isReady().then(() => {
  const securityStore = useSecurityStore();
  securityStore.loadNotificationConfig();
  securityStore.startRealtimePolling(30000);
  console.log('[安全管理] 已启动实时告警轮询');
});
EOF
    
    echo -e "${GREEN}✓${NC} 已添加安全 Store 初始化代码"
fi

echo ""
echo -e "${GREEN}✓${NC} Step 3 完成"

# Step 4: 创建声音目录
echo ""
echo "=========================================="
echo "Step 4: 创建声音文件目录"
echo "=========================================="

sounds_dir="ecom-admin/public/sounds"

if [ ! -d "$sounds_dir" ]; then
    mkdir -p "$sounds_dir"
    echo -e "${GREEN}✓${NC} 已创建 $sounds_dir 目录"
else
    echo -e "${YELLOW}⚠${NC} $sounds_dir 目录已存在"
fi

if [ ! -f "$sounds_dir/alert.mp3" ]; then
    echo ""
    echo -e "${YELLOW}⚠${NC} 未找到告警声音文件"
    echo "请将告警声音文件复制到: $sounds_dir/alert.mp3"
    echo ""
    echo "可选的声音资源："
    echo "  - https://www.zapsplat.com/"
    echo "  - https://freesound.org/"
else
    echo -e "${GREEN}✓${NC} 告警声音文件已存在"
fi

echo ""
echo -e "${GREEN}✓${NC} Step 4 完成"

# 总结
echo ""
echo "=========================================="
echo "  集成完成总结"
echo "=========================================="
echo ""
echo -e "${GREEN}✓${NC} 已完成自动集成步骤"
echo ""
echo "手动步骤（如果需要）："
echo ""
echo "1. 在 router/index.ts 的 routes 数组中添加："
echo "   securityRoutes,"
echo ""
echo "2. 在 Header.vue 中添加："
echo "   <AlertNotification />"
echo ""
echo "3. 添加告警声音文件到："
echo "   $sounds_dir/alert.mp3"
echo ""
echo "验证步骤："
echo ""
echo "1. 启动后端："
echo "   zig build run"
echo ""
echo "2. 启动前端："
echo "   cd ecom-admin && npm run dev"
echo ""
echo "3. 访问页面："
echo "   http://localhost:5173/security/dashboard"
echo ""
echo "备份位置："
echo "   $backup_dir"
echo ""
echo -e "${GREEN}=========================================="
echo "  集成脚本执行完成！"
echo "==========================================${NC}"
echo ""
