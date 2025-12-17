# 配置文件目录

## 目录说明

此目录用于集中管理项目的各种配置文件。

## 配置文件说明

### 环境配置

- **`.env`**: 开发环境配置（不提交到 Git）
- **`.env.example`**: 环境配置模板
- **`.env.production`**: 生产环境配置模板
- **`.env.test`**: 测试环境配置

### 应用配置

- **`app.toml`**: 应用主配置
- **`database.toml`**: 数据库配置
- **`cache.toml`**: 缓存配置
- **`upload.toml`**: 文件上传配置

## 配置优先级

```
命令行参数 > 环境变量 > 配置文件 > 默认值
```

## 使用方法

### 1. 初始化配置

```bash
# 复制环境配置模板
cp .env.example .env

# 编辑配置
vim .env
```

### 2. 加载配置

```zig
const config = @import("config.zig");

// 加载配置
const app_config = try config.load(allocator);

// 访问配置
const db_host = app_config.database.host;
const db_port = app_config.database.port;
```

### 3. 环境特定配置

```bash
# 开发环境
export APP_ENV=development

# 测试环境
export APP_ENV=test

# 生产环境
export APP_ENV=production
```

## 配置示例

### .env.example

```bash
# 应用配置
APP_NAME=ZigCMS
APP_ENV=development
APP_DEBUG=true
APP_PORT=3030

# 数据库配置
DB_CONNECTION=postgresql
DB_HOST=localhost
DB_PORT=5432
DB_DATABASE=zigcms
DB_USERNAME=postgres
DB_PASSWORD=password

# 缓存配置
CACHE_DRIVER=redis
REDIS_HOST=127.0.0.1
REDIS_PORT=6379
REDIS_PASSWORD=

# 日志配置
LOG_LEVEL=debug
LOG_FILE=logs/app.log
```

### app.toml

```toml
[app]
name = "ZigCMS"
version = "0.1.0"
env = "development"

[server]
host = "0.0.0.0"
port = 3030
workers = 4

[security]
jwt_secret = "your-secret-key"
jwt_expire = 86400
cors_enabled = true
cors_origins = ["*"]

[upload]
max_size = 10485760  # 10MB
allowed_types = ["image/jpeg", "image/png", "image/gif"]
storage_path = "uploads"
```

## 配置管理最佳实践

### 1. 敏感信息

- ❌ **不要**将敏感信息提交到 Git
- ✅ **使用**环境变量或加密配置
- ✅ **使用** `.env.example` 作为模板

### 2. 配置验证

```zig
pub fn validate(config: Config) !void {
    if (config.database.host.len == 0) {
        return error.InvalidDatabaseHost;
    }
    if (config.server.port == 0) {
        return error.InvalidServerPort;
    }
}
```

### 3. 配置文档

- 每个配置项必须有注释说明
- 提供合理的默认值
- 说明配置项的影响范围

### 4. 配置分层

```
configs/
├── base.toml           # 基础配置
├── development.toml    # 开发环境
├── test.toml          # 测试环境
└── production.toml    # 生产环境
```

## 注意事项

⚠️ **安全提醒**:

1. 永远不要提交 `.env` 文件到 Git
2. 生产环境密钥必须使用强随机值
3. 定期轮换密钥和密码
4. 使用密钥管理服务（如 Vault）
5. 限制配置文件的访问权限

## 相关文档

- [环境配置指南](../IFLOW.md#配置管理)
- [部署文档](../IFLOW.md#部署指南)
