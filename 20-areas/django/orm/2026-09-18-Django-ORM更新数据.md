---
tags: [python, django, orm, 更新数据]
description: save() 与 update() 的核心区别、auto_now 陷阱、full_clean 缺失、并发问题，以及 bulk_update 批量更新。
---

## Django ORM 数据更新：`save()` vs `update()`

Django 更新数据主要有两种方式：**实例的 `save()`** 和 **QuerySet 的 `update()`**。它们看起来都能改数据，但机制、性能、行为差别很大。

---

### 一、`save()` —— 实例方法

对**单个模型实例**操作，先查出对象，改属性，再保存。

```python
from students.models import Student

student = Student.objects.get(pk=1)
student.name = "张伟"
student.age = 20
student.save()
```

#### 生成的 SQL

```sql
UPDATE student SET username='张伟', age=20, ... WHERE id=1;
```

**默认更新所有字段**，即使你只改了一个。

#### 只更新指定字段

```python
student.name = "张伟"
student.save(update_fields=["name"])
```

生成的 SQL：

```sql
UPDATE student SET username='张伟' WHERE id=1;
```

**`update_fields` 的好处**：

- 只更新指定列，减少 SQL 大小
- 避免并发覆盖其他字段
- 性能更好

#### 强制插入

```python
student.save(force_insert=True)   # 强制 INSERT
student.save(force_update=True)   # 强制 UPDATE
```

---

### 二、`update()` —— QuerySet 方法

对**一批记录**直接发 SQL 更新，不加载到内存。

```python
from students.models import Student

# 把所有状态为 0 的学生改成 1
Student.objects.filter(status=0).update(status=1)
```

#### 生成的 SQL

```sql
UPDATE student SET status=1 WHERE status=0;
```

**一条 SQL 更新所有匹配记录**，不逐条加载。

#### 返回值

返回**受影响的行数**：

```python
updated = Student.objects.filter(status=0).update(status=1)
print(updated)   # 例如 15
```

---

### 三、核心区别

| 维度 | `save()` | `update()` |
|---|---|---|
| 所属 | 模型实例方法 | QuerySet 方法 |
| 操作对象 | 单个实例 | 一批记录 |
| 是否加载到内存 | 是，先 `get()` 再改 | 否，直接 SQL |
| SQL 次数 | 1 条/实例 | 1 条/N 行 |
| 触发 `pre_save` / `post_save` 信号 | ✅ | ❌ |
| 调用自定义 `save()` | ✅ | ❌ |
| 调用 `full_clean()` | ❌（需手动） | ❌ |
| 支持 `auto_now` | ✅ | ❌ |
| 返回值 | `None` | 受影响行数 |
| 支持 `F()` 表达式 | 不推荐 | ✅ 推荐 |
| 原子性 | 单条 | 单条 SQL，天然原子 |

---

### 四、`auto_now` 的坑

`update_time = models.DateTimeField(auto_now=True)` 这个字段：

```python
# save() 会自动更新 update_time
student.name = "张伟"
student.save()   # update_time 自动变成当前时间

# update() 不会自动更新 update_time
Student.objects.filter(pk=1).update(name="张伟")
# update_time 还是旧值！
```

**如果模型有 `auto_now` 字段，用 `update()` 必须手动加上**：

```python
from django.utils import timezone

Student.objects.filter(pk=1).update(
    name="张伟",
    update_time=timezone.now(),
)
```

---

### 五、`save()` 不触发 `full_clean()`

很多人误以为 `save()` 会做字段校验。**不会**。

```python
student = Student(name="", age=-999)   # 空名字、负年龄
student.save()                          # 直接存进数据库，不报错
```

`save()` 不做任何校验，直接发 SQL。

**要校验，必须手动调用**：

```python
from django.core.exceptions import ValidationError

try:
    student.full_clean()
    student.save()
except ValidationError as e:
    print(e.message_dict)
```

或者用 `ModelForm`，它会在 `is_valid()` 时调用 `full_clean()`。

---

### 六、`save()` 的并发问题

两个请求同时改同一条记录，可能**互相覆盖**。

假设初始 `age=18`：

```
请求 A：读 age=18 → 改成 19 → save
请求 B：读 age=18 → 改成 20 → save
```

如果 B 后执行，最终 `age=20`，A 的修改丢失。这叫**丢失更新（Lost Update）**。

#### 解决方案一：`select_for_update()` 行锁

```python
from django.db import transaction

with transaction.atomic():
    student = Student.objects.select_for_update().get(pk=1)
    student.age += 1
    student.save()
```

`select_for_update()` 生成 `SELECT ... FOR UPDATE`，锁住这一行，其他事务必须等待。

#### 解决方案二：`F()` 表达式（推荐）

用数据库层面的原子运算，不用先读再写：

```python
from django.db.models import F

# 阅读量 +1，原子操作
Student.objects.filter(pk=1).update(age=F("age") + 1)
```

生成的 SQL：

```sql
UPDATE student SET age = age + 1 WHERE id = 1;
```

**并发安全**，不会丢失更新。

#### 解决方案三：乐观锁（版本号）

模型加一个 `version` 字段：

```python
class Student(models.Model):
    version = models.IntegerField(default=0)

# 更新时带上版本号
updated = Student.objects.filter(pk=1, version=old_version).update(
    age=20,
    version=F("version") + 1,
)
if updated == 0:
    raise Exception("数据已被修改，请刷新重试")
```

---

### 七、`update()` 的批量更新

`update()` 天然支持批量：

```python
# 所有未入学的学生改成正常
Student.objects.filter(status=2).update(status=1)

# 所有 18 岁的学生年龄 +1
Student.objects.filter(age=18).update(age=F("age") + 1)

# 把某个班级的所有学生状态改成已毕业
Student.objects.filter(classmate="3年级5班").update(status=3)
```

**一条 SQL 搞定**，比循环 `save()` 快得多。

#### 对比：循环 save 1000 条

```python
# ❌ 慢：1000 条 SQL + 1000 次加载
for s in Student.objects.filter(status=0):
    s.status = 1
    s.save()

# ✅ 快：1 条 SQL
Student.objects.filter(status=0).update(status=1)
```

---

### 八、什么时候用哪个

| 场景 | 推荐 |
|---|---|
| 改单个对象，需要触发信号 | `save()` |
| 改单个对象，有自定义 `save()` 逻辑 | `save()` |
| 改单个对象的部分字段 | `save(update_fields=[...])` |
| 批量更新 | `update()` |
| 计数器自增（阅读量、点赞数） | `update(field=F("field") + 1)` |
| 需要 `auto_now` 自动更新 | `save()` |
| 高并发场景 | `update()` + `F()` |
| 需要行锁 | `select_for_update()` + `save()` |

---

### 九、`bulk_update()` —— 批量 `save()`

如果一定要批量更新，又需要触发信号或自定义 `save()`，用 `bulk_update()`：

```python
students = list(Student.objects.filter(status=0))
for s in students:
    s.status = 1

Student.objects.bulk_update(students, ["status"], batch_size=500)
```

**特点**：

- 一次 SQL 更新多行（类似 `bulk_create`）
- **会**调用 `save()` 方法？—— 实际上 Django 4.0+ 的 `bulk_update` 不调用 `save()`
- 不触发信号
- 需要先查出对象

**和 `update()` 的区别**：

| 维度 | `update()` | `bulk_update()` |
|---|---|---|
| 是否加载到内存 | 否 | 是 |
| 每条可不同值 | ❌ 同一个值 | ✅ 可不同 |
| 性能 | 更好 | 稍差 |
| 触发信号 | ❌ | ❌ |

**`update()` 只能把所有匹配记录改成同一个值**；如果每条要改的值不同，用 `bulk_update()`。

---

### 十、完整示例

```python
from django.http import JsonResponse
from django.views import View
from django.db import transaction
from django.db.models import F
from django.utils import timezone
from students.models import Student


class StudentUpdateView(View):

    def put(self, request, pk):
        """方式一：save() 更新单个对象"""
        try:
            student = Student.objects.get(pk=pk)
        except Student.DoesNotExist:
            return JsonResponse({"msg": "不存在"}, status=404)

        import json
        payload = json.loads(request.body)

        if "name" in payload:
            student.name = payload["name"]
        if "age" in payload:
            student.age = int(payload["age"])

        # 只更新改动的字段
        student.save(update_fields=["name", "age", "update_time"])

        return JsonResponse({"msg": "更新成功"})

    def patch(self, request):
        """方式二：update() 批量更新"""
        # 所有未入学改成正常
        count = Student.objects.filter(status=2).update(
            status=1,
            update_time=timezone.now(),   # auto_now 字段要手动加
        )
        return JsonResponse({"msg": f"更新 {count} 条"})

    def post(self, request, pk):
        """方式三：F() 原子自增"""
        Student.objects.filter(pk=pk).update(views=F("views") + 1)
        return JsonResponse({"msg": "阅读量 +1"})
```

---

### 十一、常见坑

#### 1. `update()` 不触发 `auto_now`

必须手动加 `update_time=timezone.now()`。

#### 2. `update()` 不触发信号

如果有 `post_save` 信号做缓存清理、日志记录，`update()` 不会触发。

#### 3. `save()` 默认更新所有字段

并发场景下，A 改了 `name`，B 改了 `age`，A 后 `save()` 会把 B 改的 `age` 覆盖回旧值。

**解决**：用 `save(update_fields=["name"])`。

#### 4. `update()` 不能跨表更新关联字段

```python
# ❌ 不行
Student.objects.filter(...).update(author__name="xxx")

# ✅ 要分两步
author = Author.objects.get(...)
Student.objects.filter(...).update(author=author)
```

#### 5. `F()` 表达式更新后，内存里的值不会自动同步

```python
student = Student.objects.get(pk=1)
student.views = F("views") + 1
student.save()
print(student.views)   # 是 F 表达式对象，不是数字！

# 必须 refresh_from_db()
student.refresh_from_db()
print(student.views)   # 才是最新的数字
```

#### 6. `update()` 返回的是受影响行数，不是对象

```python
result = Student.objects.filter(...).update(...)
# result 是 int，不是 Student 对象
```

---

### 十二、总结

| 方法 | 一句话 | 返回 | 触发信号 | 批量 |
|---|---|---|---|---|
| **`save()`** | 改实例属性后保存 | `None` | ✅ | ❌（单个） |
| **`save(update_fields=[...])`** | 只更新指定字段 | `None` | ✅ | ❌ |
| **`update()`** | QuerySet 批量更新 | 受影响行数 | ❌ | ✅ |
| **`bulk_update()`** | 批量更新不同值 | 受影响行数 | ❌ | ✅ |

**核心选择**：

- **单个对象、需要信号/自定义 `save()`** → `save()`，最好加 `update_fields`
- **批量更新、性能优先** → `update()`
- **计数器、并发安全** → `update(field=F("field") + 1)`
- **批量但每条值不同** → `bulk_update()`
- **需要行锁防并发** → `select_for_update()` + `save()`

**最重要的三条**：

1. `update()` 比 `save()` 快得多，能批量就批量。
2. `update()` 不触发信号、不更新 `auto_now`，要手动处理。
3. 并发自增用 `F()` 表达式，别用"读-改-写"。

## 参考信息

- [[2026-09-18-Django-ORM查询数据]] — 更新前先定位记录
- [[2026-09-18-Django-ORM新增数据]] — `bulk_update` 对应 `bulk_create`
- [[2026-09-18-Django-ORM删除数据]] — 同为批量写入，同样涉及事务与并发
- [[2026-09-18-Django-ORM模糊查询]] — `F` 表达式在两篇中都有使用场景
