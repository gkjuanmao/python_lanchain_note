---
tags: [python, django, orm, 条件查询, 查询优化]
description: F 对象与 Q 对象的核心作用与典型用法，涵盖字段间比较、原子更新与计数器、OR 与 NOT 组合、动态构建查询、Q 与 F 结合，以及常见坑与速查表。
---

# Django-ORM的F对象与Q对象

## Django ORM 中的 F 对象和 Q 对象

`F()` 和 `Q()` 是 Django ORM 里两个最强大的工具：**`F` 用于引用数据库字段，`Q` 用于组合复杂查询条件**。它们让 ORM 能表达更复杂的 SQL，而不必退回原生 SQL。


---

### 一、F 对象：引用数据库字段

#### 1. 核心作用

`F("field")` 表示"**数据库里这个列的值**"，而不是 Python 内存里的值。

```python
from django.db.models import F

Student.objects.filter(update_time__gt=F("create_time"))
```

生成的 SQL：

```sql
WHERE update_time > create_time
```

**如果没有 `F()`**：

```python
Student.objects.filter(update_time__gt="create_time")
```

生成的 SQL 变成：

```sql
WHERE update_time > 'create_time'   -- 把字符串当值比较，错误
```

**`F()` 的本质**：告诉 Django"这是列引用，不是字面量"。

---

#### 2. 典型用法一：字段之间比较

```python
# 年龄大于班级编号（假设 classmate 是数字）
Student.objects.filter(age__gt=F("classmate"))

# 更新时间晚于创建时间 1 小时以上
from datetime import timedelta
Student.objects.filter(update_time__gt=F("create_time") + timedelta(hours=1))

# 两个字段相等
Student.objects.filter(creat_time=F("update_time"))
```

**生成的 SQL**：

```sql
WHERE age > classmate
WHERE update_time > create_time + INTERVAL '1 hour'
WHERE creat_time = update_time
```

---

#### 3. 典型用法二：原地更新（原子操作，最常用）

这是 `F()` 最有价值的场景之一。


**❌ 错误做法：读-改-写**

```python
student = Student.objects.get(pk=1)
student.views = student.views + 1   # Python 层面 +1
student.save()
```

并发场景下会丢失更新：

```
请求 A：读 views=10 → +1 → 写 11
请求 B：读 views=10 → +1 → 写 11
最终 views=11，A 的 +1 丢了
```

**✅ 正确做法：`F()` 表达式**

```python
Student.objects.filter(pk=1).update(views=F("views") + 1)
```

生成的 SQL：

```sql
UPDATE student SET views = views + 1 WHERE id = 1;
```

**在数据库层面原子完成**，并发安全。

**常见计数器场景**：

```python
# 阅读量 +1
Article.objects.filter(pk=pk).update(views=F("views") + 1)

# 点赞数 +1
Article.objects.filter(pk=pk).update(likes=F("likes") + 1)

# 库存 -1
Product.objects.filter(pk=pk, stock__gte=1).update(stock=F("stock") - 1)

# 余额 +100
Account.objects.filter(pk=pk).update(balance=F("balance") + 100)
```

**库存扣减的经典写法**：

```python
updated = Product.objects.filter(pk=pk, stock__gte=1).update(stock=F("stock") - 1)
if updated == 0:
    raise Exception("库存不足")
```

`filter(stock__gte=1)` 保证只有库存足够时才扣，`update` 返回受影响行数，为 0 说明库存不足。**一条 SQL 完成判断 + 扣减，并发安全。**

---

#### 4. 典型用法三：在 `save()` 里用

```python
student = Student.objects.get(pk=1)
student.views = F("views") + 1
student.save(update_fields=["views"])
```

**⚠️ 注意**：`save()` 后 `student.views` 是 `F()` 表达式对象，不是数字：

```python
student.views = F("views") + 1
student.save()
print(student.views)   # CombinedExpression 对象，不是数字！
```

想拿到最新值，要 `refresh_from_db()`：

```python
student.save()
student.refresh_from_db()
print(student.views)   # 现在才是数字
```

**所以计数器场景更推荐用 `QuerySet.update()`**，而不是 `save()`。

---

#### 5. 典型用法四：字段复制

把一列的值复制到另一列：

```python
# 把所有学生的 age 复制到 score
Student.objects.update(score=F("age"))

# 备份手机号到备用字段
Student.objects.update(mobile_backup=F("mobile"))
```

---

#### 6. 典型用法五：表达式组合

`F()` 可以参与算术运算：

```python
# 加
F("age") + 1
F("age") + F("bonus")

# 减
F("stock") - 1
F("total") - F("used")

# 乘
F("price") * F("quantity")
F("price") * 0.9   # 打 9 折

# 除
F("total") / F("count")

# 取模
F("id") % 10

# 幂
F("x") ** 2

# 拼接（字符串）
from django.db.models.functions import Concat
Concat(F("first_name"), F("last_name"))
```

**综合示例**：

```python
# 商品打 8 折
Product.objects.update(price=F("price") * 0.8)

# 总价 = 单价 * 数量
Order.objects.update(total=F("price") * F("quantity"))

# 平均分 = 总分 / 科目数
Student.objects.update(average=F("total_score") / F("subject_count"))
```

---

#### 7. 典型用法六：配合 `annotate()`

```python
from django.db.models import F, ExpressionWrapper, DecimalField

# 计算总价，指定输出类型
Order.objects.annotate(
    total=ExpressionWrapper(
        F("price") * F("quantity"),
        output_field=DecimalField(max_digits=10, decimal_places=2),
    )
)
```

**整数除法问题**：

```python
# ❌ 可能返回 0（整数除法）
Student.objects.annotate(avg=F("total") / F("count"))

# ✅ 用 ExpressionWrapper 指定输出类型
Student.objects.annotate(
    avg=ExpressionWrapper(
        F("total") / F("count"),
        output_field=FloatField(),
    )
)
```

---

#### 8. 典型用法七：排序

```python
# 按两个字段的差排序
Student.objects.order_by(F("update_time") - F("creat_time"))

# 按表达式结果排序
Product.objects.order_by(F("price") * F("stock"))
```

---

#### 9. 典型用法八：`nulls_first` / `nulls_last`

Django 4.1+：

```python
Student.objects.order_by(F("age").asc(nulls_last=True))
Student.objects.order_by(F("age").desc(nulls_first=True))
```

---

#### 10. `F()` 不能做的

| 限制 | 说明 |
|---|---|
| 不能用 `filter(field=F("other"))` 后访问实例属性 | 结果里的字段还是原值 |
| 不能跨表用 `F("author__name")` 更新 | `update()` 只能改本表字段 |
| 不能在 Python 里直接运算 | `F("age") + 1` 是表达式对象，不是数字 |
| 不能用于 `save()` 后立即读值 | 需 `refresh_from_db()` |

---

### 二、Q 对象：组合复杂查询条件


#### 1. 核心作用

`filter(a=1, b=2)` 里的多个参数是 **AND**。想做 **OR**、**NOT**、**分组**，必须用 `Q()`。

```python
from django.db.models import Q

# OR：名字含"张" 或 名字含"李"
Student.objects.filter(
    Q(name__icontains="张") | Q(name__icontains="李")
)
```

生成的 SQL：

```sql
WHERE name LIKE '%张%' OR name LIKE '%李%'
```

---

#### 2. 三种运算符

| 运算符 | 含义 | 例子 |
|---|---|---|
| `&` | AND | `Q(a=1) & Q(b=2)` |
| `\|` | OR | `Q(a=1) \| Q(b=2)` |
| `~` | NOT | `~Q(a=1)` |

```python
# AND
Q(status=1) & Q(sex=True)         # status=1 AND sex=true

# OR
Q(status=1) | Q(status=2)         # status=1 OR status=2

# NOT
~Q(status=3)                       # NOT (status=3)
```

---

#### 3. 典型用法一：OR 查询

```python
# 名字含"张" 或 班级含"3年级"
Student.objects.filter(
    Q(name__icontains="张") | Q(classmate__icontains="3年级")
)

# 状态是 0 或 1
Student.objects.filter(Q(status=0) | Q(status=1))

# 等价写法：用 __in
Student.objects.filter(status__in=[0, 1])
```

**`__in` 和 `Q` OR 的选择**：

- 同一个字段多个值 → 用 `__in`
- 不同字段的 OR → 用 `Q`

---

#### 4. 典型用法二：NOT 查询

```python
# 排除已毕业的
Student.objects.filter(~Q(status=3))

# 等价写法
Student.objects.exclude(status=3)
```

**`~Q` 和 `exclude` 的区别**：

```python
# 排除 status=3
Student.objects.exclude(status=3)

# 排除 (status=3 AND sex=True)
Student.objects.exclude(status=3, sex=True)

# 排除 status=3 或 sex=True
Student.objects.filter(~(Q(status=3) | Q(sex=True)))

# 排除 status=3 且 sex=True
Student.objects.filter(~Q(status=3) & ~Q(sex=True))
Student.objects.filter(~Q(status=3)).exclude(sex=True)
```

**`exclude(a=1, b=2)` 是 `NOT (a=1 AND b=2)`，不是 `NOT a=1 AND NOT b=2`**，这是最容易踩的坑。

---

#### 5. 典型用法三：复杂组合

```python
# (名字含张 OR 名字含李) AND 状态=1
Student.objects.filter(
    (Q(name__icontains="张") | Q(name__icontains="李")) & Q(status=1)
)

# (状态=1 OR 状态=2) AND 年龄>=18 AND 不是3年级5班
Student.objects.filter(
    (Q(status=1) | Q(status=2))
    & Q(age__gte=18)
    & ~Q(classmate="3年级5班")
)
```

**关键：用括号明确优先级**。`&` 优先级高于 `|`，不加括号容易出错。

---

#### 6. 典型用法四：动态构建查询

这是 `Q()` 最实用的场景。过滤条件不确定，根据用户输入动态拼接。

```python
def search_students(request):
    q = Q()

    name = request.GET.get("name")
    if name:
        q &= Q(name__icontains=name)

    status = request.GET.get("status")
    if status:
        q &= Q(status=status)

    min_age = request.GET.get("min_age")
    if min_age:
        q &= Q(age__gte=min_age)

    max_age = request.GET.get("max_age")
    if max_age:
        q &= Q(age__lte=max_age)

    # 所有条件都是 AND
    queryset = Student.objects.filter(q)
    return queryset
```

**动态 OR**：

```python
q = Q()
keywords = request.GET.getlist("keyword")
for kw in keywords:
    q |= Q(name__icontains=kw) | Q(description__icontains=kw)

if q:
    queryset = queryset.filter(q)
```

---

#### 7. 典型用法五：跨表查询

```python
# 作者名字含"张" 或 分类名字含"技术"
Article.objects.filter(
    Q(author__name__icontains="张") | Q(category__name__icontains="技术")
)

# 多对多：标签含"python" 或 "django"
Article.objects.filter(
    Q(tags__name="python") | Q(tags__name="django")
).distinct()
```

**注意**：跨多对多时可能产生重复，需要 `.distinct()`。

---

#### 8. 典型用法六：`Q` 和 `F` 结合

```python
# 状态=1 且 更新时间晚于创建时间
Student.objects.filter(
    Q(status=1) & Q(update_time__gt=F("create_time"))
)

# 名字含张 或 年龄大于班级编号
Student.objects.filter(
    Q(name__icontains="张") | Q(age__gt=F("classmate"))
)
```

---

#### 9. 典型用法七：条件表达式 `When` / `Case`

`Q()` 可以和 `Case` / `When` 配合，做"分类统计"：

```python
from django.db.models import Case, When, IntegerField, Value

Student.objects.annotate(
    level=Case(
        When(Q(age__lt=12), then=Value("小学")),
        When(Q(age__lt=15), then=Value("初中")),
        When(Q(age__lt=18), then=Value("高中")),
        default=Value("大学"),
        output_field=CharField(),
    )
)
```

生成的 SQL：

```sql
CASE
    WHEN age < 12 THEN '小学'
    WHEN age < 15 THEN '初中'
    WHEN age < 18 THEN '高中'
    ELSE '大学'
END
```

---

#### 10. `Q` 的 `__in` / `__range` 组合

```python
# 状态在 [1, 2] 且年龄在 [6, 22]
Student.objects.filter(
    Q(status__in=[1, 2]) & Q(age__range=(6, 22))
)

# 名字在列表中，或手机号以 138 开头
Student.objects.filter(
    Q(name__in=["张伟", "李娜"]) | Q(mobile__startswith="138")
)
```

---

### 三、F 和 Q 结合的典型场景

#### 1. 计数器 + 条件更新

```python
# 只有状态为"正常"的才 +1
Article.objects.filter(
    Q(is_published=True) & Q(status=1)
).update(views=F("views") + 1)
```

#### 2. 复杂条件的批量更新

```python
# 名字含张 或 年龄大于 20 的，状态改成已毕业
Student.objects.filter(
    Q(name__icontains="张") | Q(age__gt=20)
).update(status=3, update_time=timezone.now())
```

#### 3. 动态搜索 + 排序

```python
q = Q()
if name:
    q &= Q(name__icontains=name)
if status:
    q &= Q(status=status)

queryset = (
    Student.objects
    .filter(q)
    .annotate(score=F("age") * 10)
    .order_by("-score")
)
```

---

### 四、常见坑

#### 1. `exclude` 的 AND 语义

```python
Student.objects.exclude(a=1, b=2)   # NOT (a=1 AND b=2)
Student.objects.exclude(a=1).exclude(b=2)  # (NOT a=1) AND (NOT b=2)
```

两者**不等价**，前者等价于 `a≠1 OR b≠2`。

#### 2. `F()` 更新后实例值不同步

```python
student.views = F("views") + 1
student.save()
print(student.views)   # 表达式对象，不是数字
student.refresh_from_db()   # 必须刷新
```

#### 3. `Q` 的括号不能省

```python
# ❌ 优先级错误，& 先算
Q(a=1) | Q(b=2) & Q(c=3)   # = Q(a=1) | (Q(b=2) & Q(c=3))

# ✅ 显式括号
(Q(a=1) | Q(b=2)) & Q(c=3)
```

#### 4. `F()` 不能跨表更新

```python
# ❌ 不行
Student.objects.update(author__name="xxx")

# ✅ 要分两步
author = Author.objects.get(...)
Student.objects.update(author=author)
```

#### 5. 多对多 OR 查询要 `distinct()`

```python
Article.objects.filter(
    Q(tags__name="python") | Q(tags__name="django")
).distinct()
```

#### 6. `F()` 在 `filter` 里不能和 Python 变量混用

```python
threshold = 18
Student.objects.filter(age__gt=F("classmate") + threshold)   # ✅ 可以
Student.objects.filter(age__gt=F("classmate") + "abc")        # ❌ 类型错误
```

#### 7. `Q()` 对象可以复用

```python
base_q = Q(status=1) & Q(is_active=True)

Student.objects.filter(base_q & Q(age__gte=18))
Student.objects.filter(base_q & Q(sex=True))
```

`Q()` 对象是**不可变**的，组合后返回新对象，原对象不变。

---

### 五、F vs Q 对比

| 维度 | `F()` | `Q()` |
|---|---|---|
| 作用 | 引用数据库字段 | 组合查询条件 |
| 用于 | `filter` / `update` / `annotate` / `order_by` | `filter` / `exclude` / `get` |
| 核心场景 | 字段比较、原子更新、计数器 | OR / NOT / 动态查询 |
| 运算符 | 算术：`+ - * / % **` | 逻辑：`& \| ~` |
| 返回值 | 表达式对象 | `Q` 对象 |
| 能否组合 | 可以参与算术 | 可以用 `& \| ~` 组合 |
| 跨表 | 不支持 update 跨表 | 支持跨表查询 |

---

### 六、速查表

```python
from django.db.models import F, Q, Case, When, Value
from datetime import timedelta

# ========== F 对象 ==========
# 字段比较
.filter(update_time__gt=F("create_time"))
.filter(age__gt=F("classmate"))

# 时间差
.filter(update_time__gt=F("create_time") + timedelta(hours=1))

# 原子更新
.update(views=F("views") + 1)
.update(stock=F("stock") - 1)
.update(price=F("price") * 0.8)

# 条件更新（防超卖）
.filter(pk=pk, stock__gte=1).update(stock=F("stock") - 1)

# 字段复制
.update(backup=F("mobile"))

# 表达式组合
F("a") + F("b")
F("a") * 2
F("a") / F("b")

# 排序
.order_by(F("a") - F("b"))

# ========== Q 对象 ==========
# OR
.filter(Q(a=1) | Q(b=2))

# NOT
.filter(~Q(a=1))
.exclude(a=1)

# AND
.filter(Q(a=1) & Q(b=2))

# 复杂组合
.filter((Q(a=1) | Q(b=2)) & Q(c=3))

# 动态构建
q = Q()
if name:
    q &= Q(name__icontains=name)
if status:
    q &= Q(status=status)
.filter(q)

# 跨表
.filter(Q(author__name__icontains="张") | Q(category__name="技术"))

# 多对多去重
.filter(Q(tags__name="python") | Q(tags__name="django")).distinct()

# ========== F + Q 结合 ==========
.filter(Q(status=1) & Q(update_time__gt=F("create_time")))
.filter(Q(is_published=True) & Q(status=1)).update(views=F("views") + 1)
```

---

### 七、总结

| 问题 | 答案 |
|---|---|
| `F()` 是什么 | 引用数据库字段的表达式 |
| `F()` 核心用途 | 字段比较、原子更新、计数器、字段复制 |
| `F()` 最经典场景 | `update(views=F("views") + 1)` 并发安全的计数器 |
| `Q()` 是什么 | 组合查询条件的对象 |
| `Q()` 核心用途 | OR、NOT、动态查询、复杂组合 |
| `Q()` 运算符 | `&` AND、`\|` OR、`~` NOT |
| 什么时候必须用 `Q()` | 需要 OR 或 NOT 时；`filter()` 的多参数只能是 AND |
| `F` 和 `Q` 能结合吗 | 能，`Q(status=1) & Q(update_time__gt=F("create_time"))` |
| 最大坑 | `exclude(a=1, b=2)` 是 `NOT (a AND b)`，不是 `NOT a AND NOT b` |
| `F()` 更新后要刷新 | `refresh_from_db()` 才能拿到新值 |

**核心两句话**：

- **`F()` = 引用列**，用于字段间比较和数据库层面的原子运算。计数器、库存扣减必须用它。
- **`Q()` = 组合条件**，用于 OR、NOT、动态查询。`filter()` 的多参数只能 AND，要 OR 必须用 `Q()`。

## 参考信息

- [[2026-09-18-Django知识地图]] — 学习路径中的位置：知识地图「五、数据库与 ORM」
- [[2026-09-19-Django-ORM聚合与分组]] — 下游：条件聚合 filter=Q(...) 依赖 Q 对象
