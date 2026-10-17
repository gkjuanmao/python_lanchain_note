---
tags: [python, django, orm, 排序, 性能优化]
description: order_by() 的排序用法与性能优化，涵盖升降序与多字段、跨表与表达式排序、NULL 位置控制、自定义顺序、Meta.ordering 陷阱与分页注意事项。
---

# Django-ORM排序

## Django ORM 中的 `order_by()`

`order_by()` 用于给查询结果**排序**，对应 SQL 的 `ORDER BY`。它是 QuerySet 的方法，返回新的 QuerySet，可以链式调用。

---

### 一、基本用法

```python
from students.models import Student

# 按年龄升序
Student.objects.order_by("age")

# 按年龄降序（字段名前加 -）
Student.objects.order_by("-age")

# 多个字段：先按年龄升序，年龄相同的按 ID 降序
Student.objects.order_by("age", "-id")
```

**生成的 SQL**：

```sql
-- order_by("age")
SELECT * FROM student ORDER BY age ASC;

-- order_by("-age")
SELECT * FROM student ORDER BY age DESC;

-- order_by("age", "-id")
SELECT * FROM student ORDER BY age ASC, id DESC;
```

---

### 二、升序与降序

| 写法 | 含义 | SQL |
|---|---|---|
| `order_by("age")` | 升序 | `ORDER BY age ASC` |
| `order_by("-age")` | 降序 | `ORDER BY age DESC` |
| `order_by("age", "-id")` | 先升后降 | `ORDER BY age ASC, id DESC` |

**降序就是在字段名前加 `-`**，不是 `desc` 或 `-1`。

---

### 三、链式调用：后一个覆盖前一个

```python
Student.objects.order_by("age").order_by("-id")
```

**结果是 `ORDER BY id DESC`**，前一个 `order_by("age")` 被覆盖。

```python
# 等价写法
Student.objects.order_by("-id")
```

**规则**：`order_by()` 是**替换**而不是追加。想多字段排序，必须在**同一次调用**里写：

```python
Student.objects.order_by("age", "-id")   # ✅ 多字段
Student.objects.order_by("age").order_by("-id")   # ❌ 只按 id 排
```

---

### 四、按关联字段排序

外键、多对多字段都可以排序，用 `__` 连接。

```python
# 按作者名字排序
Article.objects.order_by("author__name")

# 按分类名字排序
Article.objects.order_by("category__name")

# 多级跨表
Article.objects.order_by("author__profile__city")
```

**注意**：跨表排序会 `JOIN`，可能影响性能。

---

### 五、按表达式排序（`F()`）

```python
from django.db.models import F

# 按两个字段的差排序
Student.objects.order_by(F("update_time") - F("creat_time"))

# 按表达式结果降序
Product.objects.order_by(F("price") * F("stock") * -1)

# 更推荐：用 .desc()
Product.objects.order_by((F("price") * F("stock")).desc())
```

**注意**：表达式排序不能用 `-F("age")`，要用 `.desc()`：

```python
# ❌ 错误
Student.objects.order_by(-F("age"))

# ✅ 正确
Student.objects.order_by(F("age").desc())
```


---

### 六、`nulls_first` / `nulls_last`（Django 4.1+）

控制 `NULL` 值排在最前还是最后。

```python
# 升序，NULL 排最后
Student.objects.order_by(F("description").asc(nulls_last=True))

# 降序，NULL 排最前
Student.objects.order_by(F("description").desc(nulls_first=True))
```

**生成的 SQL**：

```sql
ORDER BY description ASC NULLS LAST
```

**数据库支持**：

| 数据库 | 支持 `NULLS FIRST/LAST` |
|---|---|
| PostgreSQL | ✅ 原生支持 |
| SQLite | ✅ 3.30+ |
| MySQL | ❌ 需用 `ISNULL()` 变通 |

---

### 七、按 `Case` / `When` 自定义顺序

想按"指定顺序"排，用 `Case` / `When`：

```python
from django.db.models import Case, When, IntegerField, Value

# 状态按 1 → 0 → 2 → 3 的顺序排
Student.objects.annotate(
    status_order=Case(
        When(status=1, then=Value(0)),
        When(status=0, then=Value(1)),
        When(status=2, then=Value(2)),
        When(status=3, then=Value(3)),
        default=Value(99),
        output_field=IntegerField(),
    )
).order_by("status_order")
```

**典型场景**：把"正常"排最前、"已毕业"排最后。

---

### 八、按 `annotate()` 的结果排序

先注解，再排序：

```python
from django.db.models import Count, Avg

# 按文章数排序
Author.objects.annotate(article_count=Count("articles")).order_by("-article_count")

# 按平均分排序
Student.objects.annotate(avg_score=Avg("scores__value")).order_by("-avg_score")
```

**生成的 SQL**：

```sql
SELECT author.*, COUNT(article.id) AS article_count
FROM author LEFT JOIN article ...
GROUP BY author.id
ORDER BY article_count DESC;
```


---

### 九、按聚合排序 + `distinct`

跨多对多聚合时可能重复，需要 `distinct()`：

```python
Article.objects.annotate(
    tag_count=Count("tags")
).order_by("-tag_count").distinct()
```

---

### 十、随机排序

```python
# 随机取 10 条
Student.objects.order_by("?" )[:10]
```

**⚠️ 性能警告**：`order_by("?")` 会让数据库对全表做随机排序，**数据量大时非常慢**。

**优化方案**：

```python
import random

# 先取 ID 列表，随机选几个，再查
ids = list(Student.objects.values_list("id", flat=True))
random_ids = random.sample(ids, min(10, len(ids)))
students = Student.objects.filter(id__in=random_ids)
```

---

### 十一、清除排序

```python
Student.objects.order_by("age").order_by()
```

`order_by()` 不传参数会**清除**已有排序。

**生成的 SQL**：

```sql
SELECT * FROM student;   -- 没有 ORDER BY
```

**什么时候用**：

- 聚合时不需要排序，清除可提升性能
- 链式调用中想重置排序
- `distinct()` 和排序冲突时

```python
# 聚合时清除排序（提升性能）
from django.db.models import Sum
Student.objects.order_by("age").order_by().aggregate(total=Sum("age"))
```

---

### 十二、`Meta.ordering` 默认排序

在模型 `Meta` 里定义默认排序：

```python
class Student(models.Model):
    ...
    class Meta:
        ordering = ["-id"]   # 默认按 ID 降序
```

之后 `Student.objects.all()` 会自动加 `ORDER BY id DESC`。

**覆盖默认排序**：

```python
Student.objects.order_by("age")   # 覆盖 Meta.ordering
Student.objects.order_by()        # 清除默认排序
```

**`Meta.ordering` 的坑**：

1. **每个查询都会加 `ORDER BY`**，有性能开销。
2. **聚合、`distinct` 时可能出问题**，需要 `.order_by()` 清除。
3. **`Paginator` 分页时**，如果模型没有默认排序，分页结果不稳定。

**建议**：

- 简单项目可以设 `Meta.ordering`
- 复杂项目**不设默认排序**，在视图里显式 `order_by`
- 分页时必须显式排序


---

### 十三、`order_by` 和分页

分页**必须排序**，否则结果可能重复或遗漏：

```python
# ❌ 不排序，分页结果不稳定
Student.objects.all()[0:10]

# ✅ 排序后分页
Student.objects.order_by("id")[0:10]
```

PostgreSQL 不保证无序查询的返回顺序，两次查询顺序可能不同。

---

### 十四、性能优化

#### 1. 排序字段加索引

```python
class Student(models.Model):
    name = models.CharField(max_length=100, db_index=True)
    status = models.IntegerField(db_index=True)
    creat_time = models.DateTimeField(auto_now_add=True, db_index=True)

    class Meta:
        indexes = [
            models.Index(fields=["status", "-creat_time"]),  # 联合索引
        ]
```

**联合索引的顺序要和 `order_by` 一致**：

```python
# 和索引 (status, -creat_time) 匹配
Student.objects.order_by("status", "-creat_time")

# 不匹配，索引效果打折扣
Student.objects.order_by("-creat_time", "status")
```

#### 2. 避免函数套在排序字段上

```python
# ❌ 索引失效
Student.objects.order_by(Lower("name"))

# ✅ 用函数索引（PostgreSQL）
# CREATE INDEX idx_lower_name ON student (LOWER(username));
```

#### 3. 大数据量避免 `order_by("?")`

见上文"随机排序"。

#### 4. 分页深翻慢

```python
# OFFSET 很大时慢
Student.objects.order_by("id")[10000:10010]
```

**解决**：用游标分页（`WHERE id > last_id ORDER BY id LIMIT 10`）。

---

### 十五、常见坑

#### 1. 链式 `order_by` 是覆盖不是追加

```python
Student.objects.order_by("age").order_by("-id")   # 只按 id 排
```

#### 2. `-F("age")` 不合法

```python
Student.objects.order_by(-F("age"))          # ❌
Student.objects.order_by(F("age").desc())    # ✅
```

#### 3. `order_by("?")` 性能差

数据量大时全表随机排序。

#### 4. `Meta.ordering` 和聚合冲突

```python
# 如果 Meta.ordering = ["-id"]
Student.objects.aggregate(Sum("age"))   # 可能生成无意义的 ORDER BY
```

**解决**：显式 `.order_by()` 清除。

#### 5. `distinct()` + `order_by` 冲突

```python
# 某些数据库会报错：ORDER BY 字段必须出现在 SELECT DISTINCT 里
Student.objects.distinct().order_by("name")
```

**解决**：确保排序字段在 `values()` 里，或调整查询。

#### 6. 排序字段有 `NULL`

```python
Student.objects.order_by("description")
```

不同数据库 `NULL` 位置不同：

| 数据库 | `ASC` 时 NULL 位置 | `DESC` 时 NULL 位置 |
|---|---|---|
| PostgreSQL | 最后 | 最前 |
| MySQL | 最前 | 最后 |
| SQLite | 最前 | 最后 |

**统一控制**：用 `nulls_first` / `nulls_last`（Django 4.1+）。

---

### 十六、速查表

```python
from django.db.models import F, Case, When, Value, IntegerField

# 基本排序
.order_by("age")                    # 升序
.order_by("-age")                   # 降序
.order_by("age", "-id")             # 多字段

# 关联字段
.order_by("author__name")

# 表达式
.order_by(F("a") - F("b"))
.order_by(F("age").desc())

# NULL 控制（Django 4.1+）
.order_by(F("field").asc(nulls_last=True))
.order_by(F("field").desc(nulls_first=True))

# 自定义顺序
.annotate(
    order=Case(
        When(status=1, then=Value(0)),
        default=Value(1),
        output_field=IntegerField(),
    )
).order_by("order")

# 聚合后排序
.annotate(cnt=Count("items")).order_by("-cnt")

# 随机
.order_by("?")[:10]

# 清除排序
.order_by()
```

---

### 十七、总结

| 问题 | 答案 |
|---|---|
| 怎么升序 | `order_by("field")` |
| 怎么降序 | `order_by("-field")` |
| 多字段排序 | `order_by("a", "-b")` |
| 链式调用会追加吗 | 不会，后一个覆盖前一个 |
| 跨表排序 | `order_by("author__name")` |
| 表达式排序 | `order_by(F("a") - F("b"))` |
| 表达式降序 | `order_by(F("a").desc())`，不能用 `-F("a")` |
| NULL 控制 | `F("field").asc(nulls_last=True)`（Django 4.1+） |
| 自定义顺序 | `Case` / `When` + `annotate` |
| 随机排序 | `order_by("?")`，性能差 |
| 清除排序 | `order_by()` 不传参 |
| 默认排序 | `Meta.ordering` |
| 分页必须排序吗 | 是，否则结果不稳定 |
| 性能优化 | 排序字段加索引，联合索引顺序要和 `order_by` 一致 |

**核心要点**：

1. **降序用 `-` 前缀**，多字段必须在同一次调用。
2. **`order_by` 是覆盖不是追加**，链式调用只保留最后一次。
3. **分页必须排序**，否则结果可能重复或遗漏。
4. **排序字段加索引**，大数据量避免 `order_by("?")`。
5. **表达式降序用 `.desc()`**，不能用 `-F()`。
6. **`NULL` 位置因数据库而异**，用 `nulls_first` / `nulls_last` 统一。

## 参考信息

- [[2026-10-17-Django-ORM知识地图]] — 学习路径中的位置：知识地图「四、结果处理」
