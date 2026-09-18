---
tags: [python, django, orm, 删除数据]
description: 实例与 QuerySet 的 delete()、视图中的删除写法、级联删除 on_delete 七种取值、软删除方案与事务包裹。
---

## Django ORM删除数据的完整方法汇总

Django 里删除数据，主要分**硬删除**和**软删除**两大类。硬删除又分实例删除、QuerySet 批量删除；软删除靠自定义字段实现。

---

### 一、实例 `delete()` —— 删除单个对象

先查出对象，再调用 `delete()`。

```python
from students.models import Student

try:
    student = Student.objects.get(pk=1)
    student.delete()
except Student.DoesNotExist:
    print("不存在")
```

**生成的 SQL**：

```sql
DELETE FROM student WHERE id = 1;
```

**返回值**：

```python
deleted, details = student.delete()
# deleted: 总删除数（含级联）
# details: {'students.Student': 1, 'students.Enrollment': 3, ...}
```

**特点**：

- 触发 `pre_delete` / `post_delete` 信号
- 会执行级联删除（根据 `on_delete` 配置）
- 删除后实例的 `pk` 会被置为 `None`，但其他字段还在内存里
- 不要重复调用 `delete()`，第二次会报错

---

### 二、QuerySet `delete()` —— 批量删除

直接在 QuerySet 上调用，**一条 SQL 删除所有匹配记录**。

```python
# 删除所有状态为 0 的学生
Student.objects.filter(status=0).delete()

# 删除所有学生（危险）
Student.objects.all().delete()

# 删除指定 ID 列表
Student.objects.filter(id__in=[1, 2, 3]).delete()
```

**生成的 SQL**：

```sql
DELETE FROM student WHERE status = 0;
```

**返回值**：

```python
deleted, details = Student.objects.filter(status=0).delete()
print(deleted)   # 15
print(details)   # {'students.Student': 15}
```

**特点**：

- **一条 SQL 删全部**，性能好
- 触发 `pre_delete` / `post_delete` 信号（Django 会逐条触发）
- 会执行级联删除
- **不调用模型的 `delete()` 方法**（如果重写了的话）

**重要限制**：

- QuerySet 的 `delete()` **不能用于带 `distinct()`、`annotate()` 等复杂查询**，Django 会报 `NotSupportedError`
- 如果 QuerySet 有 `select_related` / `prefetch_related`，`delete()` 会忽略它们

**先切片再删除会报错**：

```python
Student.objects.all()[:10].delete()   # ❌ 报错，QuerySet 切片后不能 delete
```

**正确做法**：

```python
ids = list(Student.objects.values_list("id", flat=True)[:10])
Student.objects.filter(id__in=ids).delete()
```

---

### 三、`get_object_or_404` + `delete()` —— 视图里最常用

```python
from django.shortcuts import get_object_or_404
from django.http import JsonResponse
from students.models import Student

def delete_student(request, pk):
    student = get_object_or_404(Student, pk=pk)
    student.delete()
    return JsonResponse({"code": 200, "msg": "删除成功"})
```

找不到自动返回 404，不用手写 `try/except`。

---

### 四、类视图里删除

```python
from django.views import View
from django.http import JsonResponse
from django.views.decorators.csrf import csrf_exempt
from django.utils.decorators import method_decorator
from students.models import Student


@method_decorator(csrf_exempt, name="dispatch")
class StudentDetailView(View):
    def delete(self, request, pk):
        try:
            student = Student.objects.get(pk=pk)
        except Student.DoesNotExist:
            return JsonResponse({"code": 404, "msg": "不存在"}, status=404)

        student.delete()
        return JsonResponse({"code": 200, "msg": "删除成功"})
```

---

### 五、级联删除：`on_delete` 的 7 种取值

删除一条记录时，关联的外键怎么办？由 `on_delete` 决定。

```python
class Enrollment(models.Model):
    student = models.ForeignKey(
        Student,
        on_delete=models.CASCADE,   # 关键
        related_name="enrollments",
    )
```

| `on_delete` | 行为 |
|---|---|
| `CASCADE` | 级联删除，学生删了，选课记录也删 |
| `PROTECT` | 阻止删除，抛 `ProtectedError` |
| `RESTRICT` | 类似 `PROTECT`，但行为更严格（Django 3.1+） |
| `SET_NULL` | 外键置为 `NULL`（要求 `null=True`） |
| `SET_DEFAULT` | 外键置为默认值（要求有 `default`） |
| `SET(value)` | 外键置为指定值 |
| `DO_NOTHING` | 什么都不做，数据库层面可能报错 |

#### `CASCADE` 示例

```python
class Student(models.Model):
    ...

class Enrollment(models.Model):
    student = models.ForeignKey(Student, on_delete=models.CASCADE)

# 删除学生会自动删除其选课记录
student.delete()
# 生成的 SQL 先 DELETE FROM enrollment WHERE student_id = 1
# 再 DELETE FROM student WHERE id = 1
```

#### `PROTECT` 示例

```python
class Enrollment(models.Model):
    student = models.ForeignKey(Student, on_delete=models.PROTECT)

# 删除有选课记录的学生会报错
from django.db.models import ProtectedError

try:
    student.delete()
except ProtectedError:
    print("该学生有选课记录，不能删除")
```

#### `SET_NULL` 示例

```python
class Enrollment(models.Model):
    student = models.ForeignKey(
        Student,
        on_delete=models.SET_NULL,
        null=True,   # 必须
    )

# 删除学生，选课记录的 student_id 变成 NULL
student.delete()
```

---

### 六、软删除 —— 不真正删，只打标记

实际项目里，很多数据不能真删（审计、恢复需求），用**软删除**。

#### 1. 加 `is_deleted` 字段

```python
class Student(models.Model):
    name = models.CharField(max_length=100)
    is_deleted = models.BooleanField(default=False, db_index=True)
    deleted_at = models.DateTimeField(null=True, blank=True)

    class Meta:
        db_table = "student"
```

#### 2. 自定义 Manager，自动过滤已删除

```python
class StudentManager(models.Manager):
    def get_queryset(self):
        return super().get_queryset().filter(is_deleted=False)


class Student(models.Model):
    ...
    objects = StudentManager()          # 默认只查未删除
    all_objects = models.Manager()      # 查全部，含已删除
```

使用：

```python
Student.objects.all()       # 只返回未删除的
Student.all_objects.all()   # 返回全部
```

#### 3. 软删除方法

```python
from django.utils import timezone

class Student(models.Model):
    ...
    def soft_delete(self):
        self.is_deleted = True
        self.deleted_at = timezone.now()
        self.save(update_fields=["is_deleted", "deleted_at"])

    def restore(self):
        self.is_deleted = False
        self.deleted_at = None
        self.save(update_fields=["is_deleted", "deleted_at"])
```

使用：

```python
student.soft_delete()   # 标记删除
student.restore()       # 恢复
```

#### 4. 批量软删除

```python
Student.objects.filter(status=3).update(
    is_deleted=True,
    deleted_at=timezone.now(),
)
```

**注意**：`update()` 不触发信号。

#### 5. 第三方库：`django-safedelete`

```bash
uv add django-safedelete
```

```python
from safedelete.models import SafeDeleteModel
from safedelete.models import SOFT_DELETE_CASCADE


class Student(SafeDeleteModel):
    _safedelete_policy = SOFT_DELETE_CASCADE
    name = models.CharField(max_length=100)
```

使用：

```python
student.delete()              # 软删除
student.delete(force=True)    # 硬删除
Student.deleted_objects.all() # 查已删除
Student.all_objects.all()     # 查全部
```

---

### 七、原生 SQL 删除

绕过 ORM，直接执行 SQL。

```python
from django.db import connection

with connection.cursor() as cursor:
    cursor.execute("DELETE FROM student WHERE id = %s", [1])
```

或者用 `raw()`：

```python
Student.objects.raw("DELETE FROM student WHERE id = %s RETURNING id", [1])
```

**特点**：

- 不触发信号
- 不执行级联删除（由数据库层面决定）
- 性能最高，但容易出错

**什么时候用**：大批量删除、复杂条件、性能敏感场景。

---

### 八、删除文件字段

如果模型有 `FileField` / `ImageField`，`delete()` **不会自动删除磁盘上的文件**。

```python
class Student(models.Model):
    avatar = models.ImageField(upload_to="avatars/")
```

```python
student.delete()
# ❌ 数据库记录删了，但 avatars/xxx.jpg 还在磁盘上
```

#### 手动删除文件

```python
student = Student.objects.get(pk=1)
# 先删文件
if student.avatar:
    student.avatar.delete(save=False)
# 再删记录
student.delete()
```

#### 用信号自动删除

```python
from django.db.models.signals import post_delete
from django.dispatch import receiver
from students.models import Student


@receiver(post_delete, sender=Student)
def delete_avatar_file(sender, instance, **kwargs):
    if instance.avatar:
        instance.avatar.delete(save=False)
```

#### 用 `django-cleanup` 自动处理

```bash
uv add django-cleanup
```

```python
# settings.py
INSTALLED_APPS = [
    ...
    "django_cleanup.apps.CleanupConfig",   # 必须放最后
]
```

之后 `delete()` 会自动删除关联文件。

---

### 九、批量删除的三种方式对比

| 方式 | SQL 次数 | 触发信号 | 性能 | 适用场景 |
|---|---|---|---|---|
| 循环 `instance.delete()` | N 条 | ✅ | 差 | 需要逐条处理 |
| QuerySet `delete()` | 1 条 | ✅ | 好 | 批量删除 |
| 原生 SQL | 1 条 | ❌ | 最好 | 超大批量、性能敏感 |

```python
# ❌ 慢
for s in Student.objects.filter(status=0):
    s.delete()

# ✅ 快
Student.objects.filter(status=0).delete()

# ✅ 最快，但不触发信号
from django.db import connection
with connection.cursor() as cursor:
    cursor.execute("DELETE FROM student WHERE status = %s", [0])
```

---

### 十、事务包裹删除

删除多条时，用事务保证要么全成功，要么全回滚。

```python
from django.db import transaction

with transaction.atomic():
    Student.objects.filter(status=0).delete()
    Enrollment.objects.filter(student__isnull=True).delete()
```

出错时自动回滚。

---

### 十一、常见坑

#### 1. QuerySet 切片后不能 delete

```python
Student.objects.all()[:10].delete()   # ❌ NotSupportedError
```

**解决**：先取 ID 再删。

```python
ids = list(Student.objects.values_list("id", flat=True)[:10])
Student.objects.filter(id__in=ids).delete()
```

#### 2. `distinct()` / `annotate()` 后不能 delete

```python
Student.objects.distinct().delete()   # ❌ 报错
```

**解决**：先取 ID。

```python
ids = Student.objects.distinct().values_list("id", flat=True)
Student.objects.filter(id__in=list(ids)).delete()
```

#### 3. 级联删除可能删掉大量数据

```python
# 删除一个用户，可能级联删掉他的所有订单、评论、日志...
user.delete()
```

**建议**：

- 先查关联数据量：`user.orders.count()`
- 用 `PROTECT` 保护重要数据
- 生产环境先备份

#### 4. `delete()` 不删除文件

见上文第八节。

#### 5. 软删除后 `unique=True` 冲突

```python
mobile = models.CharField(unique=True, max_length=20)
is_deleted = models.BooleanField(default=False)
```

如果软删除了手机号为 `138xxx` 的记录，再插入同手机号会因 `unique=True` 冲突。

**解决**：用 `unique_together` + 软删除标记，或者把手机号改成 `mobile + deleted_at` 组合唯一。

#### 6. `delete()` 后实例状态

```python
student = Student.objects.get(pk=1)
student.delete()
print(student.pk)        # None
print(student.name)      # 还是原值（内存里）
student.delete()         # ❌ 第二次报错
```

#### 7. `pre_delete` / `post_delete` 信号在批量删除时逐条触发

```python
Student.objects.all().delete()   # 1000 条，信号触发 1000 次
```

如果信号里有耗时操作（发邮件、调 API），批量删除会很慢。

---

### 十二、总结

| 方法 | 作用 | 返回 | 触发信号 | 级联 |
|---|---|---|---|---|
| `instance.delete()` | 删单个 | `(总数, 详情)` | ✅ | ✅ |
| `QuerySet.delete()` | 批量删 | `(总数, 详情)` | ✅ | ✅ |
| `get_object_or_404().delete()` | 视图里删单个 | 同上 | ✅ | ✅ |
| `update(is_deleted=True)` | 软删除 | 行数 | ❌ | ❌ |
| 原生 SQL | 批量删 | 无 | ❌ | 数据库层 |
| `bulk` 循环 `delete()` | 逐条删 | - | ✅ | ✅ |

**核心选择**：

- **单个删除** → `instance.delete()` 或 `get_object_or_404().delete()`
- **批量删除** → `QuerySet.delete()`
- **不能真删** → 软删除 + 自定义 Manager
- **超大批量** → 原生 SQL
- **有文件字段** → 配合信号或 `django-cleanup`

**最重要的三条**：

1. **级联删除**由 `on_delete` 决定，`CASCADE` 会删关联数据，`PROTECT` 会阻止删除。
2. **软删除**用 `is_deleted` 字段 + 自定义 Manager，生产环境更安全。
3. **QuerySet 切片/distinct 后不能 delete**，要先取 ID 再删。



---

**相关笔记**：[[2026-09-18-Django-ORM更新数据]]、[[2026-09-18-Django-ORM查询数据]]
