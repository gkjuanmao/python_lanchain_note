---
tags: [python, django, orm, 查询数据]
description: all/filter/exclude/get 四种基本查询方法详解、对比与衍生常用方法。
---

# Django-ORM查询数据

## Django ORM 查询数据的四种基本方法

Django ORM 里最核心、最基础的查询方法有四个：

1. **`all()`** —— 查询全部
2. **`filter()`** —— 条件过滤（满足条件）
3. **`exclude()`** —— 排除过滤（不满足条件）
4. **`get()`** —— 获取单条

这四个是所有查询的起点，其他方法（`first()`、`last()`、`values()`、`order_by()` 等）都是在这四个基础上衍生出来的。

---

### 一、`all()` —— 查询所有记录

返回一个 `QuerySet`，包含表中所有记录。

```python
from students.models import Student

# 查询所有学生
students = Student.objects.all()

# QuerySet 是惰性的，只有遍历/求值时才会执行 SQL
for s in students:
    print(s.name)
```

**生成的 SQL**：

```sql
SELECT * FROM student;
```

**特点**：

- 返回 `QuerySet`，不是列表
- **惰性求值**：定义时不查数据库，遍历/切片/`len()` 时才执行
- 可以继续链式调用：`Student.objects.all().filter(...)`

---

### 二、`filter()` —— 条件过滤（满足条件）

返回满足条件的记录，多个条件之间是 **AND** 关系。

```python
# 单个条件
students = Student.objects.filter(status=1)

# 多个条件（AND）
students = Student.objects.filter(status=1, sex=True)

# 链式调用（等价于上面的 AND）
students = Student.objects.filter(status=1).filter(sex=True)

# 使用查找类型
students = Student.objects.filter(name__icontains="张")
students = Student.objects.filter(age__gte=18)
students = Student.objects.filter(status__in=[0, 1, 2])
```

**生成的 SQL**：

```sql
SELECT * FROM student WHERE status = 1 AND sex = true;
```

**特点**：

- 返回 `QuerySet`，可能 0 条、1 条、多条
- 条件不满足时返回**空 QuerySet**，不报错
- 支持丰富的查找类型：`__gt`、`__lt`、`__in`、`__contains`、`__icontains`、`__startswith`、`__isnull` 等

**常用查找类型**：

| 查找                             | 含义        | 例子                         |
| ------------------------------ | --------- | -------------------------- |
| `__exact`                      | 精确等于（默认）  | `name__exact="张伟"`         |
| `__iexact`                     | 等于，忽略大小写  | `name__iexact="zhang"`     |
| `__contains`                   | 包含        | `name__contains="张"`       |
| `__icontains`                  | 包含，忽略大小写  | `name__icontains="zhang"`  |
| `__gt` / `__gte`               | 大于 / 大于等于 | `age__gt=18`               |
| `__lt` / `__lte`               | 小于 / 小于等于 | `age__lt=60`               |
| `__in`                         | 在列表中      | `status__in=[1, 2]`        |
| `__isnull`                     | 是否为 NULL  | `description__isnull=True` |
| `__range`                      | 范围        | `age__range=(6, 22)`       |
| `__startswith`                 | 以…开头      | `name__startswith="张"`     |
| `__endswith`                   | 以…结尾      | `mobile__endswith="1234"`  |
| `__year` / `__month` / `__day` | 日期部分      | `creat_time__year=2026`    |

---

### 三、`exclude()` —— 排除过滤（不满足条件）

返回**不满足**条件的记录，相当于 `NOT`。

```python
# 排除状态为 1 的学生
students = Student.objects.exclude(status=1)

# 排除多个条件（注意：这里是"不满足所有条件"，不是"不满足任一条件"）
students = Student.objects.exclude(status=1, sex=True)
# 等价于：NOT (status=1 AND sex=True)
# 即：status != 1 或者 sex != true
```

**生成的 SQL**：

```sql
SELECT * FROM student WHERE NOT (status = 1);
```

**特点**：

- 返回 `QuerySet`
- 可以和 `filter()` 链式组合

```python
# 状态为 1，但排除姓张的
students = Student.objects.filter(status=1).exclude(name__startswith="张")
```

**注意 `exclude` 的多个参数是 AND 后再取反**：

```python
Student.objects.exclude(a=1, b=2)   # NOT (a=1 AND b=2) = (a≠1 OR b≠2)
Student.objects.exclude(a=1).exclude(b=2)  # (a≠1) AND (b≠2)
```

两者**不等价**，容易踩坑。

---

### 四、`get()` —— 获取单条记录

返回**恰好一条**记录，直接是模型实例，不是 `QuerySet`。

```python
# 按主键查
student = Student.objects.get(pk=1)

# 按唯一字段查
student = Student.objects.get(mobile="13812345678")

# 按条件查
student = Student.objects.get(name="张伟", classmate="3年级5班")
```

**生成的 SQL**：

```sql
SELECT * FROM student WHERE id = 1 LIMIT 1;
```

**特点**：

- 返回**模型实例**，不是 `QuerySet`
- 可以直接访问属性：`student.name`
- **必须恰好一条**，否则抛异常

**三种异常情况**：

| 情况 | 异常 |
|---|---|
| 没找到 | `Student.DoesNotExist` |
| 找到多条 | `Student.MultipleObjectsReturned` |
| 参数不对 | `TypeError` |

**必须捕获异常**：

```python
from django.core.exceptions import ObjectDoesNotExist
from students.models import Student

try:
    student = Student.objects.get(pk=999)
except Student.DoesNotExist:
    return JsonResponse({"msg": "学生不存在"}, status=404)
except Student.MultipleObjectsReturned:
    return JsonResponse({"msg": "查到多条记录"}, status=500)
```

**更简洁的写法**：用 `get_object_or_404`

```python
from django.shortcuts import get_object_or_404

student = get_object_or_404(Student, pk=999)
# 找不到自动返回 404 页面（HTML）或 Http404 异常
```

---

### 五、四种方法对比

| 方法 | 返回类型 | 记录数 | 找不到时 | 多条时 |
|---|---|---|---|---|
| `all()` | `QuerySet` | 全部 | 空 QuerySet | 正常 |
| `filter()` | `QuerySet` | 满足条件的 | 空 QuerySet | 正常 |
| `exclude()` | `QuerySet` | 不满足条件的 | 空 QuerySet | 正常 |
| `get()` | 模型实例 | 恰好一条 | 抛 `DoesNotExist` | 抛 `MultipleObjectsReturned` |

---

### 六、完整示例

```python
from django.http import JsonResponse
from django.views import View
from students.models import Student


class StudentQueryView(View):
    def get(self, request):
        # 1. all()：查所有
        all_students = Student.objects.all()
        print(f"总数: {all_students.count()}")

        # 2. filter()：查正常状态的学生
        normal_students = Student.objects.filter(status=1)
        print(f"正常状态: {normal_students.count()}")

        # 3. exclude()：排除已毕业的
        not_graduated = Student.objects.exclude(status=3)
        print(f"未毕业: {not_graduated.count()}")

        # 4. get()：按主键查单个
        try:
            student = Student.objects.get(pk=1)
            print(f"ID=1 的学生: {student.name}")
        except Student.DoesNotExist:
            print("ID=1 不存在")
        except Student.MultipleObjectsReturned:
            print("ID=1 查到多条（不可能，主键唯一）")

        # 链式组合
        result = (
            Student.objects
            .filter(status=1)              # 正常状态
            .exclude(name__startswith="张") # 排除姓张的
            .filter(age__gte=18)            # 年龄 >= 18
            .order_by("-age")               # 按年龄降序
            [:10]                            # 取前 10 条
        )

        data = list(result.values("id", "name", "age", "status"))
        return JsonResponse({"code": 200, "data": data})
```

---

### 七、补充：由这四种衍生的常用方法

| 方法 | 作用 | 返回 |
|---|---|---|
| `first()` | 第一条 | 实例或 `None` |
| `last()` | 最后一条 | 实例或 `None` |
| `exists()` | 是否存在 | `bool` |
| `count()` | 总数 | `int` |
| `values()` | 转成字典 | `QuerySet[dict]` |
| `values_list()` | 转成元组 | `QuerySet[tuple]` |
| `order_by()` | 排序 | `QuerySet` |
| `distinct()` | 去重 | `QuerySet` |
| `annotate()` | 聚合注解 | `QuerySet` |
| `aggregate()` | 聚合计算 | `dict` |

这些都是在 `all()` / `filter()` / `exclude()` 返回的 `QuerySet` 上继续调用的。

---

### 八、总结

| 方法 | 一句话 | 返回 |
|---|---|---|
| **`all()`** | 查全部 | `QuerySet` |
| **`filter()`** | 查满足条件的 | `QuerySet` |
| **`exclude()`** | 查不满足条件的 | `QuerySet` |
| **`get()`** | 查恰好一条 | 模型实例 |

**核心区别**：

- **前三个返回 `QuerySet`**，可能 0 条、1 条、多条，找不到不报错。
- **`get()` 返回单个实例**，必须恰好一条，否则抛异常。

**使用建议**：

- 要多条 → `all()` / `filter()` / `exclude()`
- 要单条 → `get()` 或 `get_object_or_404()`
- 要一条但不确定存在 → `filter(...).first()`（不存在返回 `None`，不抛异常）

`filter(...).first()` 是 `get()` 的安全替代：**查不到返回 `None`，查到多条只取第一条，不抛异常**。

---

## 参考信息

- [[2026-09-18-Django-ORM新增数据]] — 先有写入才有数据可查
- [[2026-09-18-Django-ORM更新数据]] — 查询结果上做更新的常见组合
- [[2026-09-18-Django-ORM模糊查询]] — 四种基本方法之上的进阶查询
- [[2026-09-18-Django集成Elasticsearch模糊搜索]] — `icontains` 遇到性能瓶颈后的替代方案
