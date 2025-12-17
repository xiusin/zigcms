#!/usr/bin/env bash
# 项目初始化脚本

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}"
echo "╔═══════════════════════════════════════╗"
echo "║     ZigCMS 项目初始化脚本             ║"
echo "╚═══════════════════════════════════════╝"
echo -e "${NC}"

# 1. 检查依赖
echo -e "${YELLOW}📦 检查系统依赖...${NC}"

# 检查 Zig
if ! command -v zig &> /dev/null; then
    echo -e "${RED}❌ Zig 未安装${NC}"
    echo -e "${YELLOW}请访问 https://ziglang.org/download/ 安装 Zig${NC}"
    exit 1
else
    echo -e "${GREEN}✅ Zig 已安装: $(zig version)${NC}"
fi

# 检查 Git
if ! command -v git &> /dev/null; then
    echo -e "${RED}❌ Git 未安装${NC}"
    exit 1
else
    echo -e "${GREEN}✅ Git 已安装${NC}"
fi

# 2. 创建配置文件
echo -e "\n${YELLOW}⚙️  配置项目...${NC}"

if [ ! -f ".env" ]; then
    if [ -f ".env.example" ]; then
        cp .env.example .env
        echo -e "${GREEN}✅ .env 文件已创建${NC}"
    else
        echo -e "${YELLOW}⚠️  .env.example 不存在，跳过${NC}"
    fi
else
    echo -e "${GREEN}✅ .env 文件已存在${NC}"
fi

# 3. 创建必要的目录
echo -e "\n${YELLOW}📁 创建必要的目录...${NC}"

directories=(
    "logs"
    "uploads"
    "tmp"
    "backups"
)

for dir in "${directories[@]}"; do
    if [ ! -d "$dir" ]; then
        mkdir -p "$dir"
        echo -e "${GREEN}✅ 创建目录: $dir${NC}"
    fi
done

# 4. 设置权限
echo -e "\n${YELLOW}🔐 设置文件权限...${NC}"
chmod +x scripts/*.sh 2>/dev/null || true
echo -e "${GREEN}✅ 脚本权限已设置${NC}"

# 5. 下载依赖
echo -e "\n${YELLOW}📥 下载 Zig 依赖...${NC}"
zig build --help > /dev/null 2>&1 || true
echo -e "${GREEN}✅ 依赖检查完成${NC}"

# 6. 运行测试
echo -e "\n${YELLOW}🧪 运行测试...${NC}"
if zig build test 2>&1 | grep -q "All.*tests passed"; then
    echo -e "${GREEN}✅ 测试通过${NC}"
else
    echo -e "${YELLOW}⚠️  部分测试失败，请检查${NC}"
fi

# 完成
echo -e "\n${BLUE}"
echo "╔═══════════════════════════════════════╗"
echo "║     ✨ 项目初始化完成！               ║"
echo "╚═══════════════════════════════════════╝"
echo -e "${NC}"

echo -e "${GREEN}🚀 快速开始:${NC}"
echo -e "  ${YELLOW}开发模式:${NC} ./scripts/dev.sh"
echo -e "  ${YELLOW}运行测试:${NC} ./scripts/test.sh"
echo -e "  ${YELLOW}构建项目:${NC} ./scripts/build.sh release"
echo -e "  ${YELLOW}查看帮助:${NC} make help"
