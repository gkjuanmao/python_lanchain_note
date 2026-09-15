给你整理一份 SQLite 命令行速查表，开发时够用了。  
先记住一个关键区别：

- **点命令**（`.tables`、`.schema` 等）：在 `sqlite3` 交互模式里用，**不用加分号**。
- **SQL 语句**（`SELECT`、`PRAGMA` 等）：**必须加分号** `;`。

---

### 1. 连接与退出

```bash
# 打开或创建数据库
sqlite3 db.sqlite3

# 打开只读模式
sqlite3 "file:db.sqlite3?mode=ro" -readonly
```

进入交互模式后：

```sql
.quit      -- 退出
.exit      -- 退出，同上
.help      -- 查看所有点命令帮助
```

---

### 2. 查看数据库信息

```sql
.databases          -- 列出当前连接的数据库文件
.database           -- 同上
.show               -- 显示当前各项设置
```

查看 SQLite 版本（在系统命令行，不是交互模式）：

```bash
sqlite3 --version
```

---

### 3. 查看表

```sql
.tables             -- 列出所有表和视图
.tables user%       -- 模糊匹配，列出以 user 开头的表
```

用 SQL 查：

```sql
SELECT name FROM sqlite_master WHERE type='table';
SELECT name FROM sqlite_master WHERE type='view';
```

---

### 4. 查看表结构 / 字段

```sql
.schema             -- 查看所有表的建表语句
.schema users       -- 只看 users 表的建表语句
```

查看字段详情（SQL，必须加分号）：

```sql
PRAGMA table_info('users');
```

输出列含义：
- `cid`：字段序号
- `name`：字段名
- `type`：类型
- `notnull`：是否非空
- `dflt_value`：默认值
- `pk`：是否主键

查看外键：

```sql
PRAGMA foreign_key_list('users');
```

查看索引：

```sql
.indexes            -- 列出所有索引
.indexes users      -- 列出 users 表的索引
```

用 SQL 查索引：

```sql
PRAGMA index_list('users');
```

---

### 5. 查询数据

```sql
.headers on         -- 显示列名
.mode column        -- 列对齐
SELECT * FROM users LIMIT 10;
```

其他常用模式：

```sql
.mode box           -- 更漂亮的表格
.mode json          -- JSON 输出
.mode csv           -- CSV 输出
.mode line          -- 每行一个字段
```

设置 NULL 显示：

```sql
.nullvalue NULL
```

---

### 6. 从系统命令行直接执行

不用进交互模式，直接查：

```bash
# 看所有表
sqlite3 db.sqlite3 ".tables"

# 看某张表字段
sqlite3 db.sqlite3 "PRAGMA table_info('users');"

# 看建表语句
sqlite3 db.sqlite3 ".schema users"

# 查数据
sqlite3 -header -column db.sqlite3 "SELECT * FROM users LIMIT 5;"
```

---

### 7. 导出与导入

```sql
.dump               -- 导出整个数据库为 SQL
.dump users         -- 只导出 users 表
.output backup.sql  -- 后续输出写到文件
.read backup.sql    -- 执行 SQL 文件
.import data.csv users  -- 导入 CSV 到 users 表
```

---

### 8. 日常最常用的“三板斧”

记这三条就够排查大部分问题了：

```sql
.tables
.schema 表名
PRAGMA table_info('表名');
```

再配上输出美化：

```sql
.headers on
.mode column
```

---

### 9. 完整示例：打开 Django 的 db.sqlite3

```bash
sqlite3 db.sqlite3
```

```sql
.headers on
.mode column
.tables
.schema auth_user
PRAGMA table_info('auth_user');
SELECT id, username, email FROM auth_user LIMIT 5;
.quit
```

---

### 10. 速查表

| 目的 | 命令 |
|---|---|
| 打开数据库 | `sqlite3 db.sqlite3` |
| 退出 | `.quit` |
| 列出表 | `.tables` |
| 查看建表语句 | `.schema 表名` |
| 查看字段 | `PRAGMA table_info('表名');` |
| 查看索引 | `.indexes 表名` |
| 查看外键 | `PRAGMA foreign_key_list('表名');` |
| 显示列名 | `.headers on` |
| 列对齐 | `.mode column` |
| 查询数据 | `SELECT * FROM 表名 LIMIT 10;` |
| 看帮助 | `.help` |

把这些记下来，开发阶段查 SQLite 基本不用再翻文档了。