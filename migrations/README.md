# 数据库迁移文件

## 目录说明

此目录用于存放数据库迁移文件，按照时间顺序管理数据库结构变更。

## 文件命名规范

```
YYYYMMDD_HHMMSS_description.up.sql    # 升级脚本
YYYYMMDD_HHMMSS_description.down.sql  # 回滚脚本
```

### 示例

```
20251217_100000_create_users_table.up.sql
20251217_100000_create_users_table.down.sql
20251217_110000_add_email_to_users.up.sql
20251217_110000_add_email_to_users.down.sql
```

## 迁移规范

### 1. 每个迁移必须包含

- ✅ **up.sql**: 升级脚本（应用迁移）
- ✅ **down.sql**: 回滚脚本（撤销迁移）

### 2. 迁移内容要求

- ✅ 必须是幂等的（可重复执行）
- ✅ 必须考虑数据兼容性
- ✅ 不能破坏现有数据
- ✅ 必须包含事务处理
- ✅ 必须添加注释说明

### 3. UP 脚本示例

```sql
-- 迁移: 创建用户表
-- 作者: ZigCMS Team
-- 日期: 2025-12-17

BEGIN;

-- 创建用户表
CREATE TABLE IF NOT EXISTS users (
    id SERIAL PRIMARY KEY,
    username VARCHAR(50) NOT NULL UNIQUE,
    email VARCHAR(100) NOT NULL UNIQUE,
    password_hash VARCHAR(255) NOT NULL,
    status INTEGER DEFAULT 1,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    is_delete INTEGER DEFAULT 0
);

-- 创建索引
CREATE INDEX idx_users_username ON users(username);
CREATE INDEX idx_users_email ON users(email);
CREATE INDEX idx_users_status ON users(status);

-- 插入默认数据
INSERT INTO users (username, email, password_hash) 
VALUES ('admin', 'admin@example.com', 'hash_placeholder')
ON CONFLICT (username) DO NOTHING;

COMMIT;
```

### 4. DOWN 脚本示例

```sql
-- 回滚: 删除用户表
-- 作者: ZigCMS Team
-- 日期: 2025-12-17

BEGIN;

-- 删除表
DROP TABLE IF EXISTS users CASCADE;

COMMIT;
```

## 使用方法

### 执行迁移

```bash
# 使用迁移工具
zig build migrate -- up

# 或使用脚本
./scripts/migrate.sh up
```

### 回滚迁移

```bash
# 回滚最后一次迁移
zig build migrate -- down

# 或使用脚本
./scripts/migrate.sh down
```

### 查看迁移状态

```bash
zig build migrate -- status
```

## 最佳实践

### 1. 添加新表

```sql
-- up.sql
CREATE TABLE IF NOT EXISTS table_name (
    id SERIAL PRIMARY KEY,
    -- 字段定义
);

-- down.sql
DROP TABLE IF EXISTS table_name CASCADE;
```

### 2. 添加字段

```sql
-- up.sql
ALTER TABLE users 
ADD COLUMN IF NOT EXISTS phone VARCHAR(20);

-- down.sql
ALTER TABLE users 
DROP COLUMN IF EXISTS phone;
```

### 3. 修改字段

```sql
-- up.sql
ALTER TABLE users 
ALTER COLUMN email TYPE VARCHAR(200);

-- down.sql
ALTER TABLE users 
ALTER COLUMN email TYPE VARCHAR(100);
```

### 4. 添加索引

```sql
-- up.sql
CREATE INDEX IF NOT EXISTS idx_users_phone 
ON users(phone);

-- down.sql
DROP INDEX IF EXISTS idx_users_phone;
```

### 5. 数据迁移

```sql
-- up.sql
BEGIN;

-- 添加新字段
ALTER TABLE users ADD COLUMN full_name VARCHAR(100);

-- 迁移数据
UPDATE users SET full_name = username WHERE full_name IS NULL;

-- 设置非空约束
ALTER TABLE users ALTER COLUMN full_name SET NOT NULL;

COMMIT;

-- down.sql
BEGIN;

ALTER TABLE users DROP COLUMN full_name;

COMMIT;
```

## 注意事项

⚠️ **重要提醒**:

1. 迁移文件一旦应用到生产环境，**不应修改**
2. 如需修改，应创建新的迁移文件
3. 回滚脚本必须经过测试
4. 大数据量迁移应分批执行
5. 生产环境迁移前必须备份数据库

## 迁移历史

| 版本 | 日期 | 描述 | 状态 |
|------|------|------|------|
| 001 | 2025-12-17 | 初始化数据库结构 | ✅ 已应用 |

## 相关文档

- [数据库设计规范](../DEVELOPMENT_SPEC.md#数据库设计规范)
- [ORM 使用指南](../IFLOW.md#orm-使用规范)
