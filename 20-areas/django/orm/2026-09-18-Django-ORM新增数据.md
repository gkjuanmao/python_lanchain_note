---
tags: [python, django, orm, 新增数据]
description: ORM 写入数据的三种主流方法（create/save/bulk_create）、get_or_create 与 update_or_create，及五种方法对比与选型。
---

# Django-ORM新增数据

## Django ORM 里添加数据的三种主流方法

在 Django 视图里往数据库插入数据，最常见的是这三种：

1. **`Model.objects.create()`** —— 一步创建并保存
2. **实例化 + `save()`** —— 分两步，灵活
3. **`Model.objects.bulk_create()`** —— 批量插入，高性能

另外还有两个常用的变体：`get_or_create()` 和 `update_or_create()`，也一并说明。

---

### 一、`Model.objects.create()` —— 最常用

一步完成"创建对象 + 保存到数据库"。

```python
# views.py
from django.http import JsonResponse
from students.models import Student

def add_student(request):
    student = Student.objects.create(
        name="张伟",
        age=18,
        sex=True,
        classmate="3年级5班",
        mobile="13812345678",
        status=1,
        description="热爱学习",
    )
    return JsonResponse({
        "code": 200,
        "msg": "创建成功",
        "data": {"id": student.id, "name": student.name},
    }, status=201)
```

**特点**：

- 等价于 `Student(...)` + `student.save()` 的简写
- 返回创建好的模型实例，带 `id`
- **会触发** `pre_save` / `post_save` 信号
- **会触发** `auto_now_add` / `auto_now` 自动填时间
- 每次调用执行一条 `INSERT`

**什么时候用**：单条插入，绝大多数场景。

---

### 二、实例化 + `save()` —— 最灵活

先构造对象，可以改属性、做校验，再保存。

```python
def add_student(request):
    student = Student(
        name="张伟",
        age=18,
        sex=True,
        classmate="3年级5班",
        mobile="13812345678",
        status=1,
    )
    # 保存前可以改属性、做额外处理
    if student.age < 6:
        student.status = 2   # 未入学

    student.save()

    return JsonResponse({
        "code": 200,
        "msg": "创建成功",
        "data": {"id": student.id},
    }, status=201)
```

**和 `create()` 的区别**：

| 维度 | `create()` | `实例化 + save()` |
|---|---|---|
| 代码量 | 一行 | 两行 |
| 保存前修改 | 不方便 | 方便 |
| 条件逻辑 | 难插入 | 灵活 |
| 触发信号 | ✅ | ✅ |
| 自动时间字段 | ✅ | ✅ |
| 本质 | 内部就是 `save()` | 显式 `save()` |

**什么时候用**：

- 保存前需要根据业务逻辑修改字段
- 需要在保存前后做额外操作
- 想让代码更清晰、分步骤

**`save()` 的常用参数**：

```python
student.save(force_insert=True)       # 强制 INSERT
student.save(update_fields=['name'])  # 只更新指定字段（更新时用）
```

---

### 三、`bulk_create()` —— 批量插入，性能最好

一次 SQL 插入多条，适合大量数据。

```python
def add_students_batch(request):
    students = [
        Student(name=f"学生{i}", age=18, mobile=f"1380000{i:04d}", status=1)
        for i in range(100)
    ]
    created = Student.objects.bulk_create(students, batch_size=500)

    return JsonResponse({
        "code": 200,
        "msg": f"批量创建 {len(created)} 条",
    }, status=201)
```

**特点**：

- **一次 SQL 插入多条**，比逐条 `create()` 快几十倍
- `batch_size` 控制每条 SQL 插入多少行（默认全部一次）
- 返回创建的实例列表（Django 4.0+ 在 PostgreSQL 上会回填 `id`）

**重要限制**：

| 限制 | 说明 |
|---|---|
| **不触发** `pre_save` / `post_save` 信号 | 需要信号的话不能用 |
| **不调用** `save()` 方法 | 如果重写了 `save()`，逻辑不会执行 |
| `auto_now_add` / `auto_now` | 仍然生效（Django 内部处理） |
| 主键回填 | PostgreSQL / SQLite 支持，MySQL 某些版本不支持 |
| 不适合有复杂 `clean()` 校验的场景 | `full_clean()` 不会自动调用 |

**什么时候用**：

- 一次插入几十条以上
- 数据来自文件导入、批量生成
- 不依赖信号和自定义 `save()`

---

### 四、补充：`get_or_create()` 和 `update_or_create()`

这两个是"查询 + 插入"的组合，也常用于添加数据。

#### `get_or_create()` —— 有就取，没有就建

```python
student, created = Student.objects.get_or_create(
    mobile="13812345678",   # 查找条件
    defaults={              # 不存在时用来创建的字段
        "name": "张伟",
        "age": 18,
        "status": 1,
    },
)

if created:
    msg = "新建成功"
else:
    msg = "已存在，直接返回"

return JsonResponse({"msg": msg, "id": student.id})
```

- 返回 `(object, created)` 元组
- `created=True` 表示新建，`False` 表示已存在
- 查找字段和 `defaults` 要分开写

#### `update_or_create()` —— 有就更新，没有就建

```python
student, created = Student.objects.update_or_create(
    mobile="13812345678",
    defaults={
        "name": "张伟",
        "age": 20,
        "status": 3,
    },
)
```

- 存在则用 `defaults` 更新
- 不存在则创建
- 返回 `(object, created)`

**注意**：这两个方法在并发下可能抛 `IntegrityError`（两个请求同时判断"不存在"然后都去创建）。生产环境要配合唯一约束和 `try/except`。

---

### 五、五种方法对比

| 方法 | SQL 次数 | 触发信号 | 触发 save() | 适用场景 |
|---|---|---|---|---|
| `create()` | 1 条/次 | ✅ | ✅ | 单条插入 |
| 实例化 + `save()` | 1 条/次 | ✅ | ✅ | 需保存前修改 |
| `bulk_create()` | 1 条/N 行 | ❌ | ❌ | 批量插入 |
| `get_or_create()` | 1-2 条 | ✅ | ✅ | 幂等创建 |
| `update_or_create()` | 1-2 条 | ✅ | ✅ | 存在则更新 |

---

### 六、在视图里的完整示例

```python
import json
from django.http import JsonResponse
from django.views import View
from django.views.decorators.csrf import csrf_exempt
from django.utils.decorators import method_decorator
from django.db import IntegrityError, transaction
from students.models import Student


@method_decorator(csrf_exempt, name="dispatch")
class StudentCreateView(View):

    def post(self, request):
        payload = json.loads(request.body)

        # 方式一：create()
        try:
            student = Student.objects.create(
                name=payload["name"],
                age=payload.get("age", 0),
                mobile=payload["mobile"],
                status=payload.get("status", 1),
            )
        except IntegrityError:
            return JsonResponse({"msg": "mobile 已存在"}, status=400)

        return JsonResponse({"msg": "创建成功", "id": student.id}, status=201)

    def put(self, request):
        """方式二：实例化 + save()"""
        payload = json.loads(request.body)

        student = Student(
            name=payload["name"],
            mobile=payload["mobile"],
        )
        # 保存前处理业务逻辑
        if payload.get("age", 0) < 6:
            student.status = 2   # 未入学
        else:
            student.status = 1

        try:
            student.save()
        except IntegrityError:
            return JsonResponse({"msg": "mobile 已存在"}, status=400)

        return JsonResponse({"msg": "创建成功", "id": student.id}, status=201)

    def patch(self, request):
        """方式三：bulk_create()"""
        payload = json.loads(request.body)
        items = payload.get("items", [])

        students = [
            Student(
                name=item["name"],
                age=item.get("age", 0),
                mobile=item["mobile"],
                status=item.get("status", 1),
            )
            for item in items
        ]

        with transaction.atomic():
            created = Student.objects.bulk_create(students, batch_size=500)

        return JsonResponse({"msg": f"批量创建 {len(created)} 条"}, status=201)
```

---

### 七、怎么选

| 场景 | 推荐方法 |
|---|---|
| 普通单条插入 | `create()` |
| 保存前要改字段、做判断 | 实例化 + `save()` |
| 一次插入几十条以上 | `bulk_create()` |
| 要幂等（重复请求不重复插） | `get_or_create()` |
| 存在则更新、不存在则建 | `update_or_create()` |
| 需要触发信号 | 不能用 `bulk_create()` |

---

### 八、总结

| 方法 | 一句话 |
|---|---|
| **`Model.objects.create()`** | 一步创建并保存，最常用 |
| **实例化 + `save()`** | 分两步，保存前可改属性，最灵活 |
| **`Model.objects.bulk_create()`** | 批量插入，性能最好，但不触发信号 |
| `get_or_create()` | 有就取，没有就建 |
| `update_or_create()` | 有就更新，没有就建 |

**核心三点**：

- 单条插入用 `create()`，简单直接。
- 需要保存前处理逻辑用"实例化 + `save()`"。
- 批量插入用 `bulk_create()`，但记住它不触发信号、不调用 `save()`。

## 参考信息

- [[2026-09-18-Django模型与数据库配置]] — 写入目标模型的字段定义
- [[2026-09-18-Django-ORM查询数据]] — 写入之后如何取回验证
- [[2026-09-18-Django-ORM更新数据]] — `bulk_create` 与 `bulk_update` 的批量思路一致
- [[2026-09-18-Django-ORM删除数据]] — 同样需要 `atomic` 事务包裹的写入场景
- [[2026-09-15-Django配置Argon2id密码哈希]] — `create_user` 内部的密码哈希过程
- [[2026-09-19-Django-ORM的F对象与Q对象]] — 条件的动态组合
- [[2026-09-19-Django-ORM聚合与分组]] — 统计口径与写入后的数据核算
- [[2026-09-19-Django查询优化]] — bulk_create 的批量写入建议
