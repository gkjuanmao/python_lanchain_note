---
tags: [python, django, orm, 聚合, 分组]
description: aggregate() 与 annotate() 的用法与差别，涵盖聚合函数、条件聚合、values 与 annotate 顺序、WHERE 与 HAVING 判定、跨表分组及常见坑与性能优化。
---

# Django-ORM聚合与分组

## Django ORM 聚合与分组详解

Django ORM 的聚合分为两个层次：**`aggregate()` 对整个查询集做聚合**，**`annotate()` 对每个对象做聚合（分组）**。理解这两个方法是掌握 ORM 聚合的关键。

---

### 一、聚合函数一览

Django 内置的聚合函数（`django.db.models`）：

| 函数 | 作用 | 对应 SQL |
|---|---|---|
| `Count` | 计数 | `COUNT()` |
| `Sum` | 求和 | `SUM()` |
| `Avg` | 平均值 | `AVG()` |
| `Max` | 最大值 | `MAX()` |
| `Min` | 最小值 | `MIN()` |
| `StdDev` | 标准差 | `STDDEV()` |
| `Variance` | 方差 | `VARIANCE()` |
| `ArrayAgg` | 聚合成数组（PostgreSQL） | `ARRAY_AGG()` |
| `StringAgg` | 聚合成字符串（PostgreSQL） | `STRING_AGG()` |

---

### 二、`aggregate()` —— 整表聚合

对**整个 QuerySet** 做聚合，返回**一个字典**，不是 QuerySet。

#### 1. 基本用法

```python
from django.db.models import Count, Sum, Avg, Max, Min
from students.models import Student

result = Student.objects.aggregate(
    total=Count("id"),
    avg_age=Avg("age"),
    max_age=Max("age"),
    min_age=Min("age"),
)
print(result)
# {'total': 100, 'avg_age': 15.3, 'max_age': 22, 'min_age': 6}
```

**生成的 SQL**：

```sql
SELECT COUNT(id), AVG(age), MAX(age), MIN(age) FROM student;
```

**特点**：

- 返回 `dict`，不是 `QuerySet`
- 一条 SQL 搞定所有聚合
- 不分组，整表算一个结果
- 返回值不能继续链式调用

#### 2. 不指定别名

```python
result = Student.objects.aggregate(Count("id"))
# {'id__count': 100}
```

Django 会自动生成别名：`字段名__聚合函数名小写`。**建议始终显式指定别名**，避免猜名字。

#### 3. 带过滤条件

```python
# 只统计正常状态的学生
result = Student.objects.filter(status=1).aggregate(
    total=Count("id"),
    avg_age=Avg("age"),
)
```

**生成的 SQL**：

```sql
SELECT COUNT(id), AVG(age) FROM student WHERE status = 1;
```

#### 4. 条件聚合：`filter=` 参数

想在**一次聚合里对不同条件分别统计**，用 `filter=` 参数：

```python
from django.db.models import Count, Q

result = Student.objects.aggregate(
    total=Count("id"),
    normal=Count("id", filter=Q(status=1)),
    abnormal=Count("id", filter=Q(status=0)),
    graduated=Count("id", filter=Q(status=3)),
    male=Count("id", filter=Q(sex=True)),
    female=Count("id", filter=Q(sex=False)),
)
print(result)
# {'total': 100, 'normal': 60, 'abnormal': 5, 'graduated': 20, 'male': 55, 'female': 45}
```

**生成的 SQL**：

```sql
SELECT
    COUNT(id),
    COUNT(id) FILTER (WHERE status = 1),
    COUNT(id) FILTER (WHERE status = 0),
    ...
FROM student;
```

**这是最实用的技巧之一**：一条 SQL 完成多个条件的统计，避免多次查询。


#### 5. `Count` 的三种用法

```python
# 1. 计数所有记录（含 NULL）
Student.objects.aggregate(c=Count("id"))

# 2. 计数某字段非 NULL 的记录
Student.objects.aggregate(c=Count("description"))

# 3. 去重计数
Student.objects.aggregate(c=Count("classmate", distinct=True))
```

**区别**：

| 写法 | SQL | 含义 |
|---|---|---|
| `Count("id")` | `COUNT(id)` | id 非 NULL 的数量 |
| `Count("description")` | `COUNT(description)` | description 非 NULL 的数量 |
| `Count("id", distinct=True)` | `COUNT(DISTINCT id)` | id 去重后的数量 |

#### 6. `Count("*")` 的坑

```python
# ❌ 错误写法
Student.objects.aggregate(c=Count("*"))   # 会报错

# ✅ 正确写法
Student.objects.aggregate(c=Count("id"))
```

Django 不支持 `Count("*")`，要指定字段。

---

### 三、`annotate()` —— 分组聚合

对**每个对象**做聚合，返回**新的 QuerySet**，每个对象多一个注解字段。这是 Django 里实现 **GROUP BY** 的方式。

#### 1. 基本用法

```python
from django.db.models import Count

# 每个班级有多少学生
result = Student.objects.values("classmate").annotate(
    count=Count("id")
)
print(list(result))
# [
#   {'classmate': '3年级5班', 'count': 12},
#   {'classmate': '3年级6班', 'count': 15},
#   ...
# ]
```

**生成的 SQL**：

```sql
SELECT classmate, COUNT(id) AS count
FROM student
GROUP BY classmate;
```

**关键**：`values("classmate")` + `annotate(...)` = `GROUP BY classmate`。

#### 2. 不带 `values()` 的 `annotate()`

```python
# 给每个学生对象加一个注解字段
students = Student.objects.annotate(
    name_length=Length("name")
)
for s in students:
    print(s.name, s.name_length)
```

**生成的 SQL**：

```sql
SELECT *, LENGTH(username) AS name_length FROM student;
```

**注意**：不带 `values()` 时，`annotate()` 是**给每条记录加一个计算字段**，不是分组。

#### 3. `values()` + `annotate()` = GROUP BY

```python
# 按班级分组，统计人数和平均年龄
Student.objects.values("classmate").annotate(
    count=Count("id"),
    avg_age=Avg("age"),
)
```

**生成的 SQL**：

```sql
SELECT classmate, COUNT(id) AS count, AVG(age) AS avg_age
FROM student
GROUP BY classmate;
```

#### 4. 多字段分组

```python
# 按班级和性别分组
Student.objects.values("classmate", "sex").annotate(
    count=Count("id")
)
```

**生成的 SQL**：

```sql
SELECT classmate, sex, COUNT(id)
FROM student
GROUP BY classmate, sex;
```

#### 5. 分组后排序

```python
# 按班级分组，按人数降序
Student.objects.values("classmate").annotate(
    count=Count("id")
).order_by("-count")
```

**生成的 SQL**：

```sql
SELECT classmate, COUNT(id) AS count
FROM student
GROUP BY classmate
ORDER BY count DESC;
```


#### 6. 分组后过滤：`HAVING`

**`filter()` 在 `annotate()` 前 = `WHERE`**，**`filter()` 在 `annotate()` 后 = `HAVING`**。

```python
# WHERE：先筛选，再分组
Student.objects.filter(status=1).values("classmate").annotate(
    count=Count("id")
)
# SQL: ... WHERE status = 1 GROUP BY classmate

# HAVING：先分组，再筛选
Student.objects.values("classmate").annotate(
    count=Count("id")
).filter(count__gt=10)
# SQL: ... GROUP BY classmate HAVING COUNT(id) > 10
```

**`HAVING` 用于过滤聚合结果**，比如"人数大于 10 的班级"。

#### 7. 聚合字段别名冲突

如果模型有字段叫 `count`，注解也叫 `count`，会冲突。用别的名字：

```python
Student.objects.values("classmate").annotate(
    student_count=Count("id")   # 避免用 count
)
```

#### 8. `default` 参数

```python
Student.objects.values("classmate").annotate(
    count=Count("id", default=0)
)
```

`default` 用于处理 `NULL` 情况（比如 `Sum` 空集返回 `None`，可以设默认值）。

---

### 四、`aggregate()` vs `annotate()` 对比

| 维度 | `aggregate()` | `annotate()` |
|---|---|---|
| 返回类型 | `dict` | `QuerySet` |
| 分组 | 不分组，整表一个结果 | 可分组（配合 `values()`） |
| SQL | `SELECT COUNT(*) FROM ...` | `SELECT ..., COUNT(*) GROUP BY ...` |
| 链式调用 | ❌ 不能继续 | ✅ 可以继续 filter/order_by |
| 用途 | 统计整表 | 分组统计、给每条记录加注解 |
| 别名 | 显式指定 | 显式指定 |

---

### 五、典型用法汇总

#### 1. 统计每个班级的人数

```python
from django.db.models import Count

Student.objects.values("classmate").annotate(
    student_count=Count("id")
).order_by("-student_count")
```

#### 2. 统计每个班级的平均年龄、最大年龄

```python
from django.db.models import Avg, Max, Min

Student.objects.values("classmate").annotate(
    avg_age=Avg("age"),
    max_age=Max("age"),
    min_age=Min("age"),
    count=Count("id"),
)
```

#### 3. 统计每个状态的分布

```python
from django.db.models import Count

Student.objects.values("status").annotate(
    count=Count("id")
).order_by("status")
```

**结果**：

```python
[
    {'status': 0, 'count': 5},
    {'status': 1, 'count': 60},
    {'status': 2, 'count': 15},
    {'status': 3, 'count': 20},
]
```

#### 4. 按日期分组统计

```python
from django.db.models.functions import TruncDate
from django.db.models import Count

Student.objects.annotate(
    day=TruncDate("creat_time")
).values("day").annotate(
    count=Count("id")
).order_by("day")
```

**生成的 SQL**：

```sql
SELECT DATE(creat_time) AS day, COUNT(id)
FROM student
GROUP BY DATE(creat_time)
ORDER BY day;
```

#### 5. 按月份分组

```python
from django.db.models.functions import TruncMonth

Student.objects.annotate(
    month=TruncMonth("creat_time")
).values("month").annotate(
    count=Count("id")
).order_by("month")
```

#### 6. 每个作者的文章数（跨表分组）

```python
from django.db.models import Count

Author.objects.annotate(
    article_count=Count("articles")
).order_by("-article_count")
```

**生成的 SQL**：

```sql
SELECT author.*, COUNT(article.id) AS article_count
FROM author
LEFT JOIN article ON article.author_id = author.id
GROUP BY author.id
ORDER BY article_count DESC;
```


#### 7. 每个作者已发布文章数（条件聚合）

```python
from django.db.models import Count, Q

Author.objects.annotate(
    total=Count("articles"),
    published=Count("articles", filter=Q(articles__is_published=True)),
    draft=Count("articles", filter=Q(articles__is_published=False)),
)
```

**这是最强大的技巧**：一次查询统计多个条件下的数量。

#### 8. 多对多分组

```python
# 每个标签下的文章数
Tag.objects.annotate(
    article_count=Count("articles")
)
```

**注意**：多对多分组可能产生重复，必要时加 `distinct=True`。

#### 9. 去重计数

```python
# 每个班级有多少个不同的年龄
Student.objects.values("classmate").annotate(
    distinct_ages=Count("age", distinct=True)
)
```

#### 10. 分组后 HAVING 过滤

```python
# 人数大于 10 的班级
Student.objects.values("classmate").annotate(
    count=Count("id")
).filter(count__gt=10)
```

#### 11. 分组后取前 N 个

```python
# 每个班级年龄最大的学生
from django.db.models import Max

Student.objects.values("classmate").annotate(
    max_age=Max("age")
)
```

#### 12. 结合 `F()` 计算

```python
from django.db.models import F, Sum, ExpressionWrapper, DecimalField

# 每个订单的总价
Order.objects.annotate(
    total=ExpressionWrapper(
        F("price") * F("quantity"),
        output_field=DecimalField(max_digits=10, decimal_places=2),
    )
).aggregate(grand_total=Sum("total"))
```

#### 13. 分组统计后排序、分页

```python
Student.objects.values("classmate").annotate(
    count=Count("id")
).order_by("-count")[:10]
```

---

### 六、`values()` + `annotate()` 的执行顺序

**关键规则**：

- `values()` 在 `annotate()` **前** → 决定 `GROUP BY` 的字段
- `values()` 在 `annotate()` **后** → 决定 `SELECT` 的字段

```python
# 情况一：values 在前 → 按 classmate 分组
Student.objects.values("classmate").annotate(count=Count("id"))
# SQL: SELECT classmate, COUNT(id) GROUP BY classmate

# 情况二：values 在后 → 按 id 分组（默认按主键），只选 classmate
Student.objects.annotate(count=Count("id")).values("classmate")
# SQL: SELECT classmate, COUNT(id) GROUP BY id  （每个学生一行）
```

**这是最容易混淆的地方**。记住：

- **`values()` 在 `annotate()` 前**：`values` 的字段进 `GROUP BY`
- **`values()` 在 `annotate()` 后**：`values` 的字段进 `SELECT`，`GROUP BY` 还是按主键

---

### 七、`filter()` 位置决定 WHERE 还是 HAVING

```python
# filter 在 annotate 前 → WHERE（分组前过滤）
Student.objects.filter(status=1).values("classmate").annotate(count=Count("id"))
# SQL: ... WHERE status = 1 GROUP BY classmate

# filter 在 annotate 后 → HAVING（分组后过滤）
Student.objects.values("classmate").annotate(count=Count("id")).filter(count__gt=10)
# SQL: ... GROUP BY classmate HAVING COUNT(id) > 10
```

**规则**：

- `annotate()` 之前的 `filter()` → `WHERE`，过滤原始行
- `annotate()` 之后的 `filter()` → `HAVING`，过滤聚合结果

---

### 八、常见坑

#### 1. `annotate()` 后 `filter()` 容易误用

```python
# 想筛"正常状态的学生"，然后按班级统计
# ❌ 错误：filter 在 annotate 后，变成了 HAVING
Student.objects.values("classmate").annotate(
    count=Count("id")
).filter(status=1)   # 可能报错或结果不对

# ✅ 正确：filter 在 annotate 前
Student.objects.filter(status=1).values("classmate").annotate(
    count=Count("id")
)
```

#### 2. `Meta.ordering` 干扰分组

如果模型有 `Meta.ordering = ["-id"]`，`values().annotate()` 会自动带上 `ORDER BY id`，可能影响 `GROUP BY`。

**解决**：显式清除排序。

```python
Student.objects.values("classmate").annotate(
    count=Count("id")
).order_by()   # 清除默认排序
```

#### 3. `Count` 跨多对多产生重复

```python
# ❌ 可能重复计数
Article.objects.annotate(tag_count=Count("tags"))

# ✅ 去重
Article.objects.annotate(tag_count=Count("tags", distinct=True))
```

#### 4. `Sum` 空集返回 `None`

```python
result = Student.objects.filter(status=99).aggregate(total=Sum("age"))
print(result)   # {'total': None}，不是 0
```

**解决**：用 `Coalesce` 或 Python 层处理。

```python
from django.db.models.functions import Coalesce

Student.objects.aggregate(total=Coalesce(Sum("age"), 0))
```

#### 5. `values()` 和 `annotate()` 顺序搞反

```python
# ❌ 每个学生一行，不是按班级分组
Student.objects.annotate(count=Count("id")).values("classmate")

# ✅ 按班级分组
Student.objects.values("classmate").annotate(count=Count("id"))
```

#### 6. 多字段 `values()` 时 `GROUP BY` 所有字段

```python
Student.objects.values("classmate", "sex").annotate(count=Count("id"))
# GROUP BY classmate, sex
```

如果只想按 `classmate` 分组，但 `SELECT` 里出现 `sex`，`GROUP BY` 会包含 `sex`，分组粒度变细。

---

### 九、性能优化

#### 1. 分组字段加索引

```python
class Student(models.Model):
    classmate = models.CharField(max_length=50, db_index=True)
    status = models.IntegerField(db_index=True)
```

#### 2. 避免 `annotate()` + `order_by()` 导致全表扫描

```python
Student.objects.values("classmate").annotate(
    count=Count("id")
).order_by("-count")
```

`ORDER BY count` 是对聚合结果排序，数据库无法用索引优化，大数据量时慢。

#### 3. 条件聚合替代多次查询

```python
# ❌ 多次查询
total = Student.objects.count()
normal = Student.objects.filter(status=1).count()
abnormal = Student.objects.filter(status=0).count()

# ✅ 一次查询
result = Student.objects.aggregate(
    total=Count("id"),
    normal=Count("id", filter=Q(status=1)),
    abnormal=Count("id", filter=Q(status=0)),
)
```

#### 4. 大表分组考虑物化视图

如果分组统计非常频繁，考虑用 PostgreSQL 的物化视图或定时任务预计算。

---

### 十、速查表

```python
from django.db.models import Count, Sum, Avg, Max, Min, Q
from django.db.models.functions import TruncDate, TruncMonth

# ========== aggregate：整表聚合，返回 dict ==========
Student.objects.aggregate(
    total=Count("id"),
    avg_age=Avg("age"),
    max_age=Max("age"),
)

# 条件聚合
Student.objects.aggregate(
    total=Count("id"),
    normal=Count("id", filter=Q(status=1)),
    abnormal=Count("id", filter=Q(status=0)),
)

# ========== annotate：分组聚合，返回 QuerySet ==========
# 按班级分组
Student.objects.values("classmate").annotate(count=Count("id"))

# 多字段分组
Student.objects.values("classmate", "sex").annotate(count=Count("id"))

# 分组 + 排序
Student.objects.values("classmate").annotate(
    count=Count("id")
).order_by("-count")

# 分组 + HAVING
Student.objects.values("classmate").annotate(
    count=Count("id")
).filter(count__gt=10)

# 按日期分组
Student.objects.annotate(
    day=TruncDate("creat_time")
).values("day").annotate(count=Count("id"))

# 跨表分组
Author.objects.annotate(article_count=Count("articles"))

# 条件聚合
Author.objects.annotate(
    total=Count("articles"),
    published=Count("articles", filter=Q(articles__is_published=True)),
)

# 去重计数
Student.objects.values("classmate").annotate(
    distinct_ages=Count("age", distinct=True)
)
```

---

### 十一、总结

| 问题                              | 答案                                                         |
| ------------------------------- | ---------------------------------------------------------- |
| `aggregate()` 和 `annotate()` 区别 | 前者整表聚合返回 dict，后者分组/注解返回 QuerySet                           |
| 怎么分组                            | `values("字段").annotate(...)`                               |
| `GROUP BY` 由什么决定                | `values()` 在 `annotate()` 前，其字段进 `GROUP BY`                |
| `WHERE` 和 `HAVING` 怎么区分         | `filter()` 在 `annotate()` 前是 `WHERE`，在后是 `HAVING`          |
| 一次统计多个条件                        | `Count("id", filter=Q(...))`                               |
| 跨表分组                            | `annotate(Count("关联字段"))`                                  |
| 按日期分组                           | `annotate(day=TruncDate(...)).values("day").annotate(...)` |
| `Sum` 空集返回 `None`               | 用 `Coalesce(Sum(...), 0)`                                  |
| 多对多重复计数                         | `Count("tags", distinct=True)`                             |
| `Meta.ordering` 干扰分组            | `.order_by()` 清除                                           |

**核心三句话**：

1. **`aggregate()` 是整表统计**，返回一个字典，一条 SQL 出所有聚合值。
2. **`annotate()` 是分组统计**，配合 `values()` 使用，`values()` 在 `annotate()` 前决定 `GROUP BY`。
3. **`filter()` 的位置决定 `WHERE` 还是 `HAVING`**，在 `annotate()` 前是 `WHERE`，在后是 `HAVING`。

掌握 `aggregate()` 和 `annotate()`，加上 `filter=Q(...)` 条件聚合，就能用一条 SQL 完成大部分统计需求，避免多次查询。

## 参考信息

- [[2026-09-18-Django知识地图]] — 学习路径中的位置：知识地图「五、数据库与 ORM」
