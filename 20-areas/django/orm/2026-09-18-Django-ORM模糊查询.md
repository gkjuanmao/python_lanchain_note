---
tags: [python, django, orm, 模糊查询, 性能优化]
description: contains/startswith/endswith/regex/in/range/isnull 等查询方法、跨表关联查询、Q 与 F 表达式、性能对比与优化。
---

# Django-ORM模糊查询

## Django ORM 模糊查询的一些方法

Django 的模糊查询通过**字段查找（field lookup）实现，写在 `filter()` / `exclude()` / `get()` 里，用双下划线 `__` 连接字段名和查找类型。

---

### 一、包含类：`contains` / `icontains`

判断字段是否**包含**某段字符串。

```python
# 区分大小写
Student.objects.filter(name__contains="张")

# 不区分大小写（i = insensitive）
Student.objects.filter(name__icontains="zhang")
```

**生成的 SQL**：

| 查找 | PostgreSQL | MySQL |
|---|---|---|
| `contains` | `LIKE '%张%'` | `LIKE '%张%'` |
| `icontains` | `ILIKE '%zhang%'` | `LIKE '%zhang%'`（默认不区分大小写） |

**特点**：

- 最常用的模糊查询
- `%` 开头，**无法使用普通 B-Tree 索引**，数据量大时全表扫描
- 搜索词里的 `%` 和 `_` 会被自动转义

---

### 二、开头类：`startswith` / `istartswith`

判断字段是否**以某段字符串开头**。

```python
Student.objects.filter(name__startswith="张")
Student.objects.filter(name__istartswith="zhang")
```

**生成的 SQL**：

```sql
WHERE name LIKE '张%'
```

**特点**：

- `%` 在结尾，**可以使用 B-Tree 索引**，性能远好于 `contains`
- 适合"前缀搜索"场景

---

### 三、结尾类：`endswith` / `iendswith`

判断字段是否**以某段字符串结尾**。

```python
Student.objects.filter(mobile__endswith="1234")
Student.objects.filter(name__iendswith="wei")
```

**生成的 SQL**：

```sql
WHERE mobile LIKE '%1234'
```

**特点**：

- `%` 在开头，**无法使用普通索引**
- 适合后缀匹配，但性能一般

---

### 四、精确匹配（区分/不区分大小写）

```python
# 精确匹配，区分大小写
Student.objects.filter(name__exact="张伟")

# 精确匹配，不区分大小写
Student.objects.filter(name__iexact="zhang wei")
```

**生成的 SQL**：

```sql
-- exact
WHERE name = '张伟'

-- iexact
WHERE UPPER(name) = UPPER('zhang wei')
```

`exact` 是默认查找，`filter(name="张伟")` 等价于 `filter(name__exact="张伟")`。

---

### 五、正则匹配：`regex` / `iregex`

用正则表达式匹配。

```python
# 区分大小写
Student.objects.filter(name__regex=r"^张")

# 不区分大小写
Student.objects.filter(name__iregex=r"^zhang")
```

**生成的 SQL**：

| 数据库 | `regex` | `iregex` |
|---|---|---|
| PostgreSQL | `~ 'pattern'` | `~* 'pattern'` |
| MySQL | `REGEXP 'pattern'` | `REGEXP 'pattern'` |
| SQLite | `REGEXP 'pattern'`（需自定义函数） |

**特点**：

- 灵活性最高，但性能最差
- **SQLite 默认不支持 `REGEXP`**，需要注册 Python 函数
- 能用 `contains` / `startswith` 解决的就不要用正则

---

### 六、`in` —— 在列表中

```python
Student.objects.filter(status__in=[0, 1, 2])
Student.objects.filter(name__in=["张伟", "李娜"])
```

**生成的 SQL**：

```sql
WHERE status IN (0, 1, 2)
```

不是字符串模糊匹配，但常用于"多值匹配"。

---

### 七、`range` —— 范围

```python
Student.objects.filter(age__range=(6, 22))
```

**生成的 SQL**：

```sql
WHERE age BETWEEN 6 AND 22
```

---

### 八、`isnull` —— 是否为空

```python
Student.objects.filter(description__isnull=True)   # 为 NULL
Student.objects.filter(description__isnull=False)  # 不为 NULL
```

**生成的 SQL**：

```sql
WHERE description IS NULL
```

---

### 九、跨表关联模糊查询

外键、多对多都可以跨表用模糊查询，用 `__` 连接。

```python
# 查作者名字包含"张"的文章
Article.objects.filter(author__name__icontains="张")

# 查标签名包含"python"的文章
Article.objects.filter(tags__name__icontains="python")

# 多级跨表
Article.objects.filter(author__profile__city__icontains="北京")
```

**注意**：跨多对多时可能产生**重复结果**，需要 `.distinct()`：

```python
Article.objects.filter(tags__name__icontains="python").distinct()
```

---

### 十、`Q` 对象组合复杂条件

`filter()` 里的多个参数是 **AND**，要做 **OR** 或更复杂组合，用 `Q`。


```python
from django.db.models import Q

# OR：名字包含"张" 或 班级包含"3年级"
Student.objects.filter(
    Q(name__icontains="张") | Q(classmate__icontains="3年级")
)

# NOT：排除名字包含"张"的
Student.objects.filter(~Q(name__icontains="张"))

# 组合：(名字含张 OR 名字含李) AND 状态=1
Student.objects.filter(
    (Q(name__icontains="张") | Q(name__icontains="李")) & Q(status=1)
)
```

**`Q` 是复杂模糊查询的关键**，`filter()` 的参数写法表达不了 OR。

---

### 十一、`F` 表达式：字段之间比较

不是模糊匹配，但常和查询一起用。

```python
from django.db.models import F

# 年龄大于班级编号（假设班级编号是数字）
Student.objects.filter(age__gt=F("classmate"))
```

---

### 十二、全文检索（PostgreSQL 专用）

模糊查询性能差时，用 PostgreSQL 的全文检索。

```python
from django.contrib.postgres.search import SearchVector, SearchQuery

Student.objects.annotate(
    search=SearchVector("name", "description")
).filter(search=SearchQuery("张伟"))
```

需要建 GIN 索引，适合大文本搜索。

---

### 十三、性能对比

| 查找 | SQL 模式 | 能否走 B-Tree 索引 | 性能 |
|---|---|---|---|
| `exact` | `= 'x'` | ✅ | 最好 |
| `startswith` | `LIKE 'x%'` | ✅ | 好 |
| `endswith` | `LIKE '%x'` | ❌ | 差 |
| `contains` | `LIKE '%x%'` | ❌ | 差 |
| `icontains` | `ILIKE '%x%'` | ❌ | 差 |
| `regex` | `~ 'pattern'` | ❌ | 最差 |

**核心规律**：`%` 在开头 → 索引失效 → 全表扫描。

---

### 十四、`contains` 和 `icontains` 的性能优化

数据量大时，`icontains` 很慢。优化方案：

#### 1. PostgreSQL：`pg_trgm` + GIN 索引

```sql
CREATE EXTENSION pg_trgm;
CREATE INDEX idx_student_name_trgm ON student USING gin (username gin_trgm_ops);
```

模型里声明：

```python
from django.contrib.postgres.indexes import GinIndex

class Student(models.Model):
    ...
    class Meta:
        indexes = [
            GinIndex(
                name="idx_student_name_trgm",
                fields=["name"],
                opclasses=["gin_trgm_ops"],
            ),
        ]
```

这样 `icontains` 就能走索引。

#### 2. 改用前缀匹配

如果业务允许"以 x 开头"，用 `istartswith`，能走 B-Tree 索引。

#### 3. 外部搜索引擎

百万级数据用 Elasticsearch、Meilisearch、Typesense。

---

### 十五、常见坑

#### 1. MySQL 的 `contains` 和 `icontains` 可能没区别

MySQL 默认排序规则 `utf8mb4_general_ci` 本身不区分大小写，所以两者生成的 SQL 一样。想区分大小写，用 `utf8mb4_bin` 排序规则。

#### 2. 搜索词里的特殊字符

```python
Student.objects.filter(name__icontains="100%")
```

Django 会自动转义 `%` 和 `_`，生成 `LIKE '%100\%%' ESCAPE '\'`，不会误匹配。

#### 3. `NULL` 不会被 `contains` 匹配

```python
Student.objects.filter(description__icontains="学习")
```

`description` 是 `NULL` 的记录**不会**被匹配。想包含，用 `Q`：

```python
Student.objects.filter(
    Q(description__icontains="学习") | Q(description__isnull=True)
)
```

#### 4. `regex` 在 SQLite 上不可用

SQLite 默认没有 `REGEXP` 函数，需要注册：

```python
import re
from django.db.backends.signals import connection_created

def register_regex(sender, connection, **kwargs):
    if connection.vendor == "sqlite":
        connection.connection.create_function(
            "regexp", 2, lambda pattern, value: bool(re.search(pattern, value or ""))
        )

connection_created.connect(register_regex)
```

#### 5. 跨多对多查询要 `distinct()`

```python
Article.objects.filter(tags__name__icontains="python")
# 一篇文章有 3 个匹配的标签，会返回 3 次

Article.objects.filter(tags__name__icontains="python").distinct()
# 去重
```

---

### 十六、速查表

```python
# 包含
.filter(name__contains="x")       # 区分大小写
.filter(name__icontains="x")      # 不区分大小写

# 开头
.filter(name__startswith="x")
.filter(name__istartswith="x")

# 结尾
.filter(name__endswith="x")
.filter(name__iendswith="x")

# 精确
.filter(name__exact="x")
.filter(name__iexact="x")

# 正则
.filter(name__regex=r"^x")
.filter(name__iregex=r"^x")

# 列表 / 范围 / 空
.filter(status__in=[1, 2])
.filter(age__range=(6, 22))
.filter(description__isnull=True)

# 跨表
.filter(author__name__icontains="张")
.filter(tags__name__icontains="python").distinct()

# OR 组合
from django.db.models import Q
.filter(Q(name__icontains="张") | Q(name__icontains="李"))
```

---

### 十七、总结

| 方法 | 作用 | 区分大小写 | 索引 |
|---|---|---|---|
| `contains` | 包含 | ✅ | ❌ |
| `icontains` | 包含 | ❌ | ❌ |
| `startswith` | 开头 | ✅ | ✅ |
| `istartswith` | 开头 | ❌ | ✅ |
| `endswith` | 结尾 | ✅ | ❌ |
| `iendswith` | 结尾 | ❌ | ❌ |
| `exact` | 精确 | ✅ | ✅ |
| `iexact` | 精确 | ❌ | ❌ |
| `regex` | 正则 | ✅ | ❌ |
| `iregex` | 正则 | ❌ | ❌ |

**核心三点**：

1. **`contains` / `icontains` 是最常用的模糊查询**，但 `%x%` 无法走索引，大数据量要优化。
2. **`startswith` 比 `contains` 快**，因为 `x%` 能用 B-Tree 索引，能用前缀就用前缀。
3. **OR 条件必须用 `Q` 对象**，`filter()` 的多个参数只能表达 AND。

**选择建议**：

- 普通搜索 → `icontains`
- 前缀搜索 → `istartswith`（性能最好）
- 复杂条件 → `Q` 对象组合
- 超大文本 → PostgreSQL 全文检索
- 百万级数据 → 外部搜索引擎

## 参考信息

- [[2026-10-17-Django-ORM知识地图]] — 学习路径中的位置：知识地图「三、查询」
- [[2026-09-10-Python基础知识]] — 依赖：regex / iregex 查询的正则语法基础在该篇
