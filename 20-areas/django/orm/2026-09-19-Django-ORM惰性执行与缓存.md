---
tags: [python, django, orm, 查询优化, 缓存]
description: QuerySet 的惰性执行与缓存两大特性，涵盖触发查询的操作、缓存机制与验证方式、filter 与切片导致的缓存失效，以及常见误区与使用建议。
---

# Django-ORM惰性执行与缓存

## QuerySet 的两大核心特性

Django ORM 的 `QuerySet` 有两大核心特性：

1. **惰性执行（Lazy Evaluation）**
2. **缓存（Caching）**

这两点决定了 ORM 的性能表现，也是理解 Django 数据库查询的关键。

---

### 一、惰性执行（Lazy Evaluation）

#### 1. 什么是惰性

**创建 `QuerySet` 时不会立即访问数据库**，只有当你真正需要结果时，才会执行 SQL。

```python
from students.models import Student

# 此时并没有查数据库
qs = Student.objects.filter(status=1)
qs = qs.filter(age__gt=18)
qs = qs.order_by("-id")

# 直到这里才真正执行 SQL
for student in qs:
    print(student.name)
```

#### 2. 哪些操作会触发查询

| 操作                                      | 是否触发查询        |
| --------------------------------------- | ------------- |
| `filter()` / `exclude()` / `order_by()` | ❌ 不触发         |
| `annotate()` / `alias()`                | ❌ 不触发         |
| `for` 循环                                | ✅ 触发          |
| `list(qs)`                              | ✅ 触发          |
| `len(qs)`                               | ✅ 触发          |
| `bool(qs)` / `if qs:`                   | ✅ 触发          |
| `qs[0]` / `qs[:10]`                     | ✅ 触发（切片）      |
| `qs.first()` / `qs.last()`              | ✅ 触发          |
| `qs.exists()`                           | ✅ 触发（但不缓存）    |
| `qs.count()`                            | ✅ 触发（但不缓存）    |
| `repr(qs)`                              | ✅ 触发（调试时）     |
| `print(qs.query)`                       | ❌ 只打印 SQL，不执行 |

#### 3. 惰性的好处

- **可以链式调用**：多次 `filter()` 不会每次都查库，最终合成一条 SQL。
- **可以动态构建查询**：根据条件拼接 `filter()`，最后统一执行。
- **避免无用查询**：如果最终没有用到结果，就不会查库。

```python
# 动态构建，最后才执行
qs = Student.objects.all()

if name:
    qs = qs.filter(name__icontains=name)
if status:
    qs = qs.filter(status=status)
if min_age:
    qs = qs.filter(age__gte=min_age)

# 到这里才执行一条 SQL
students = list(qs)
```

> 相关：[[2026-09-18-Django-ORM查询数据]]

---

### 二、缓存（Caching）

#### 1. 什么是缓存

**第一次求值后，查询结果会被缓存在 `QuerySet` 内部**，后续再使用同一个 `QuerySet`，不会再查数据库。

```python
qs = Student.objects.all()

# 第一次：执行 SQL，结果缓存到 qs._result_cache
students1 = list(qs)

# 第二次：直接取缓存，不再查数据库
students2 = list(qs)

print(students1 is students2)   # True（同一个列表对象）
```

#### 2. 验证缓存

```python
from django.db import connection, reset_queries

reset_queries()
qs = Student.objects.all()

list(qs)   # 第 1 次，查库
list(qs)   # 第 2 次，走缓存

print(len(connection.queries))   # 输出 1，说明只查了一次
```

#### 3. 什么时候会缓存

| 操作                    | 是否缓存结果                  |
| --------------------- | ----------------------- |
| `list(qs)`            | ✅                       |
| `for s in qs`         | ✅                       |
| `len(qs)`             | ✅                       |
| `bool(qs)` / `if qs:` | ✅                       |
| `qs[0]`               | ✅（会缓存整个结果集）             |
| `qs[:10]`             | ⚠️ 返回新 QuerySet，不缓存原 qs |
| `qs.exists()`         | ❌ 不缓存                   |
| `qs.count()`          | ❌ 不缓存                   |
| `qs.iterator()`       | ❌ 不缓存                   |

#### 4. 缓存的坑

##### 坑一：`filter()` 后是新 QuerySet，不共享缓存

```python
qs = Student.objects.all()
list(qs)                  # 查库，缓存到 qs

qs2 = qs.filter(status=1) # 新 QuerySet，没有缓存
list(qs2)                 # 又查一次库
```

##### 坑二：切片后不缓存原 QuerySet

```python
qs = Student.objects.all()
qs[0]        # 查库并缓存整个 qs
qs[0]        # 走缓存

qs2 = qs[:10]  # 新 QuerySet
list(qs2)      # 又查一次库
```

##### 坑三：`if qs:` 会触发查询并缓存

```python
qs = Student.objects.all()

if qs:              # 触发查询，缓存全部结果
    print(qs[0])    # 走缓存，不再查库
```

如果只想判断是否存在，用 `qs.exists()` 更高效：

```python
if qs.exists():     # 只查是否存在，不缓存全部结果
    ...
```

##### 坑四：`iterator()` 不缓存

```python
qs = Student.objects.all()

for s in qs.iterator():   # 不缓存，适合大数据量
    process(s)

for s in qs.iterator():   # 又查一次库
    process(s)
```

`iterator()` 用于**大数据量遍历**，避免一次性把所有记录加载到内存。

> 相关：[[2026-09-19-Django-ORM聚合与分组]]

---

### 三、两大特性的配合

```python
# 惰性：构建查询时不查库
qs = Student.objects.filter(status=1)
qs = qs.filter(age__gt=18)

# 第一次求值：执行 SQL，结果缓存
students = list(qs)

# 第二次求值：直接取缓存
same_students = list(qs)
```

**结果**：只执行了 1 条 SQL。

---

### 四、什么时候不该依赖缓存

| 场景 | 建议 |
|---|---|
| 数据可能被其他请求修改 | 重新查询，别用旧缓存 |
| 跨请求复用 QuerySet | ❌ 不要，每个请求重新查 |
| 大数据量遍历 | 用 `iterator()`，不缓存 |
| 只判断存在 | 用 `exists()` |
| 只取数量 | 用 `count()` |
| 需要最新数据 | `refresh_from_db()` 或重新查询 |

---

### 五、常见误区

#### 1. 以为 `filter()` 会立即查库

```python
qs = Student.objects.filter(status=1)   # 没查库
print(qs.query)                          # 只打印 SQL
```

#### 2. 以为每次 `list(qs)` 都查库

```python
list(qs)   # 查库
list(qs)   # 缓存，不查库
```

#### 3. 以为 `if qs:` 很轻量

```python
if qs:     # 会查库并缓存全部结果
```

用 `qs.exists()` 替代。

#### 4. 以为 `qs[0]` 只查一条

```python
qs[0]   # 会查库并缓存整个结果集（旧版本行为）
```

Django 3.0+ 对 `qs[0]` 有优化，可能只查一条，但**后续再访问 `qs[1]` 会再查库**。

---

### 六、总结

| 特性       | 说明                    | 好处               |
| -------- | --------------------- | ---------------- |
| **惰性执行** | 创建 QuerySet 不查库，求值时才查 | 链式调用、动态构建、避免无用查询 |
| **缓存**   | 第一次求值后缓存结果，重复使用不查库    | 避免重复查询，提升性能      |

**核心要点**：

1. **惰性**：`filter()`、`exclude()`、`order_by()` 都不查库，只有 `for`、`list()`、`len()`、`if` 才查。
2. **缓存**：同一个 QuerySet 第一次求值后，结果缓存，第二次直接用。
3. **`filter()` 后是新 QuerySet**，不共享缓存。
4. **`exists()`、`count()`、`iterator()` 不缓存**。
5. **跨请求不要复用 QuerySet**，每个请求重新查。
6. **大数据量用 `iterator()`**，避免内存爆掉。

**一句话**：QuerySet 的惰性让查询可以延迟到最后一刻，缓存让重复使用不重复查库。理解这两点，就能写出高效的 Django 查询。

## 参考信息

- [[2026-09-18-Django-ORM查询数据]] — filter/exclude 的惰性求值在上篇已提出，本篇展开机制
- [[2026-09-19-Django-ORM聚合与分组]] — aggregate/annotate 的求值时机同样受惰性与缓存影响
- [[2026-09-19-Django-ORM排序]] — order_by 属于不触发查询的链式方法
- [[2026-09-19-Django查询优化]] — exists/count/iterator 的使用建议
