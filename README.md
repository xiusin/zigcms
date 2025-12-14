# ZigCMS

基于 Zig 语言开发的现代化 CMS 系统，具备高性能、内存安全和易扩展的特性。

## 📚 文档导航

- **[开发规范](DEVELOPMENT_SPEC.md)** - 详细的开发标准和规范
- **[使用指南](USAGE_GUIDE.md)** - 完整的使用说明和教程
- **[项目结构](STRUCTURE.md)** - 代码组织和架构说明
- **[技术文档](DOCS.md)** - 技术实现细节和API文档
- **[API文档](docs/api/)** - 交互式API文档

## 🚀 快速开始

### 环境要求

- Zig 0.12.0+
- SQLite 3.8+ (内置支持)
- MySQL/PostgreSQL (可选)

### 安装和运行

```bash
# 克隆项目
git clone <repository-url>
cd zigcms

# 构建项目
zig build

# 运行开发服务器
zig build run

# 生产环境构建
zig build -Doptimize=ReleaseSafe run
```

### 访问系统

- 管理后台: http://localhost:8080/admin
- API文档: http://localhost:8080/docs/api/

## 📖 详细文档

### 开发者指南

请参考 [开发规范](DEVELOPMENT_SPEC.md) 了解：
- 代码风格和命名规范
- 架构设计原则
- API设计标准
- 数据库设计规范

### 使用指南

请参考 [使用指南](USAGE_GUIDE.md) 了解：
- 系统安装配置
- 功能模块使用
- 管理后台操作
- 常见问题解决

### 项目结构

请参考 [项目结构](STRUCTURE.md) 了解：
- 目录组织结构
- 模块职责划分
- 依赖关系说明

### 技术文档

请参考 [技术文档](DOCS.md) 了解：
- 技术栈介绍
- 核心功能实现
- 依赖管理
- 部署说明

## 🧪 测试

### 运行测试

```bash
# 运行所有测试
zig build test

# 运行特定测试
zig build test -- <test_name>
```

### 数据库测试

每种驱动都有完整测试覆盖：
- **CRUD 操作** - 创建、读取、更新、删除及结果验证
- **QueryBuilder** - SQL 构造器测试
- **事务** - 提交/回滚/自动事务
- **高级查询** - 子查询、EXISTS、NOT EXISTS
- **JOIN 查询** - INNER/LEFT/多表关联
- **边界条件** - NULL 值、特殊字符、Unicode、大数据量
- **内存安全** - GPA 检测内存泄漏
- **连接池** - MySQL 连接池特性（仅 MySQL）

#### SQLite 测试

```bash
cd src/services/sql
zig build-exe sqlite_complete_test.zig -lc -lsqlite3
./sqlite_complete_test
```

#### MySQL 测试

```bash
cd src/services/sql

# macOS (Homebrew - ARM)
zig build-exe mysql_complete_test.zig -lc -lmysqlclient \
  -I /opt/homebrew/include \
  -L /opt/homebrew/lib

# macOS (Homebrew - Intel / MariaDB)
zig build-exe mysql_complete_test.zig -lc -lmysqlclient \
  -I /usr/local/include \
  -L /usr/local/lib

# macOS (MySQL 官方安装)
zig build-exe mysql_complete_test.zig -lc -lmysqlclient \
  -I /usr/local/mysql/include \
  -L /usr/local/mysql/lib

# Linux
zig build-exe mysql_complete_test.zig -lc -lmysqlclient

# 运行测试（需要先创建测试数据库）
mysql -u root -p -e "CREATE DATABASE IF NOT EXISTS test_zigcms;"
./mysql_complete_test
```

#### PostgreSQL 测试

```bash
# 需要通过 build.zig 编译（因为依赖 pg 模块）
# 1. 确保 PostgreSQL 运行
brew services start postgresql@14
# 或
sudo systemctl start postgresql

# 2. 创建测试数据库
psql -U postgres -c "CREATE DATABASE test_zigcms;"

# 3. 编译运行（通过主程序）
zig build

# 或者单独运行测试（需要配置）
# 查看 PGSQL_TEST_GUIDE.md 获取详细说明
```

## 🔧 开发环境设置

### Git 配置

```bash
# 取消代理设置
git config --global --unset http.proxy
git config --global --unset https.proxy
unset http_proxy https_proxy

# 变更协议版本
git config --global http.version HTTP/1.1
```

### Zig 环境

```bash
# 安装 Zig
# macOS
brew install zig

# Linux
# 下载并安装官方二进制包

# 验证安装
zig version
```

## 📋 相关链接

- 管理后台示例: https://y-admin.yijianku.com/
- Layui 文件管理: https://gitee.com/nbnat/layui-filemanage
- 前端MVVM组件: https://cdn.jsdelivr.net/gh/kirakiray/ofa.js/dist/ofa.min.js
- 后台管理系统示例: https://admin.demo.ulthon.com/admin/Index/index.html#/admin/system.auth/index.html
- Layui 组件: https://dev.layuion.com/extend/selectplus/

## 🤝 贡献

请阅读 [开发规范](DEVELOPMENT_SPEC.md) 了解贡献指南和代码规范。

## 📄 许可证

本项目采用 MIT 许可证。




https://y-admin.yijianku.com/#

https://gitee.com/nbnat/layui-filemanage

<script src="https://cdn.jsdelivr.net/gh/kirakiray/ofa.js/dist/ofa.min.js"></script>  前端mvvm组件

https://admin.demo.ulthon.com/admin/Index/index.html#/admin/system.auth/index.html

https://dev.layuion.com/extend/selectplus/ 组件
