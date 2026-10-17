---
tags: [python, django, 视图, 模板渲染]
description: Django render() 快捷函数的完整使用指南，涵盖签名参数、基础与高级用法、上下文处理器、异步视图、CRUD 示例与常见错误。
---

# Django的render函数

`render()` 是 Django 中最常用的快捷函数，用于**加载模板、填充上下文、渲染成 HTML，并返回 `HttpResponse`**。它把"模板加载 → 上下文处理 → 渲染 → 包装响应"封装成一行代码。

---

## 一、导入与函数签名

```python
from django.shortcuts import render

def render(
    request,
    template_name,
    context=None,
    content_type=None,
    status=None,
    using=None,
):
    ...
```

返回一个**已渲染的 [[2026-09-18-Django请求与响应对象|TemplateResponse]]**，它是 `HttpResponse` 的子类。

---

## 二、参数详解

| 参数 | 是否必填 | 类型 | 说明 |
|---|---|---|---|
| `request` | ✅ | `HttpRequest` | 当前请求对象，用于上下文处理器、CSRF、auth、messages |
| `template_name` | ✅ | `str` 或 `list` | 模板路径，或模板路径列表（回退机制） |
| `context` | 可选 | `dict` | 传给模板的变量，默认 `None`（空上下文） |
| `content_type` | 可选 | `str` | 响应的 MIME 类型，默认 `'text/html; charset=utf-8'` |
| `status` | 可选 | `int` | HTTP 状态码，默认 `200` |
| `using` | 可选 | `str` | 指定模板引擎，如 `'django'`、`'jinja2'` |

> ⚠️ `context` 必须是**字典**，不能写成关键字参数。  
> ✅ `render(request, 'index.html', {'name': 'tom'})`  
> ❌ `render(request, 'index.html', name='tom')`

---

## 三、返回值

`render()` 返回一个 `TemplateResponse` 实例（已渲染）。它继承自 `HttpResponse`，所以你可以：

```python
response = render(request, 'index.html', {'name': 'tom'})
response['X-Custom'] = 'value'
response.set_cookie('sessionid', 'abc')
response.status_code = 201
return response
```

---

## 四、基础用法

### 1. 最简用法

```python
from django.shortcuts import render

def index(request):
    return render(request, 'index.html')
```

模板 `templates/index.html`：

```html
<!DOCTYPE html>
<html>
<head><title>首页</title></head>
<body>
    <h1>Hello World</h1>
</body>
</html>
```

### 2. 传递上下文

```python
def index(request):
    context = {
        'title': '首页',
        'username': '张三',
        'items': ['苹果', '香蕉', '橙子'],
    }
    return render(request, 'index.html', context)
```

模板中使用：

```html
<h1>{{ title }}</h1>
<p>欢迎，{{ username }}</p>
<ul>
    {% for item in items %}
        <li>{{ item }}</li>
    {% endfor %}
</ul>
```

### 3. 直接传字典

```python
return render(request, 'index.html', {'name': 'tom', 'age': 18})
```

---

## 五、高级用法

### 1. 指定状态码

```python
def not_found(request):
    return render(request, '404.html', {'msg': '页面不存在'}, status=404)
```

状态码可以是任意合法 HTTP 状态码：

```python
return render(request, 'created.html', context, status=201)
return render(request, 'error.html', context, status=500)
```

### 2. 指定 Content-Type

```python
return render(request, 'index.xml', context, content_type='application/xml')
return render(request, 'index.json', context, content_type='application/json')
```

默认是 `text/html; charset=utf-8`。

### 3. 指定模板引擎

Django 可以同时配置多个模板引擎，用 `using` 指定：

```python
return render(request, 'index.html', context, using='jinja2')
```

需要在 `settings.py` 里配置：

```python
TEMPLATES = [
    {
        'BACKEND': 'django.template.backends.django.DjangoTemplates',
        'DIRS': [BASE_DIR / 'templates'],
        'APP_DIRS': True,
    },
    {
        'NAME': 'jinja2',
        'BACKEND': 'django.template.backends.jinja2.Jinja2',
        'DIRS': [BASE_DIR / 'jinja2_templates'],
    },
]
```

### 4. 模板名列表（回退机制）

```python
return render(request, ['mobile/index.html', 'index.html'], context)
```

Django 按顺序查找，使用**第一个存在**的模板。适合移动端/桌面端模板切换。

### 5. 修改响应对象

```python
response = render(request, 'index.html', context)
response['X-Custom-Header'] = 'value'
response.set_cookie('theme', 'dark', max_age=3600)
response.status_code = 201
return response
```

### 6. 返回 JSON 数据（不推荐用 render）

```python
# ❌ 不要用 render 返回 JSON
return render(request, 'data.json', {'data': data})

# ✅ 用 JsonResponse
from django.http import JsonResponse
return JsonResponse({'code': 200, 'data': data})
```

`render` 是给 HTML 模板用的，JSON 用 `JsonResponse`。

---

## 六、完整示例：CRUD 视图

### 1. 列表页

```python
from django.shortcuts import render
from django.core.paginator import Paginator
from .models import Student


def student_list(request):
    queryset = Student.objects.all().order_by('-id')

    # 筛选
    name = request.GET.get('name', '').strip()
    if name:
        queryset = queryset.filter(name__icontains=name)

    status = request.GET.get('status')
    if status not in (None, ''):
        queryset = queryset.filter(status=status)

    # 分页
    paginator = Paginator(queryset, 10)
    page_obj = paginator.get_page(request.GET.get('page', 1))

    context = {
        'page_obj': page_obj,
        'paginator': paginator,
        'name': name,
        'status': status,
    }
    return render(request, 'students/list.html', context)
```

### 2. 详情页

```python
from django.shortcuts import render, get_object_or_404


def student_detail(request, pk):
    student = get_object_or_404(Student, pk=pk)
    return render(request, 'students/detail.html', {'student': student})
```

### 3. 新增页（GET 显示表单，POST 处理提交）

```python
from django.shortcuts import render, redirect


def student_create(request):
    if request.method == 'POST':
        # 处理表单
        name = request.POST.get('name', '').strip()
        mobile = request.POST.get('mobile', '').strip()

        errors = {}
        if not name:
            errors['name'] = '姓名不能为空'
        if not mobile:
            errors['mobile'] = '手机号不能为空'

        if errors:
            return render(request, 'students/create.html', {
                'errors': errors,
                'name': name,
                'mobile': mobile,
            })

        Student.objects.create(
            name=name,
            mobile=mobile,
            age=int(request.POST.get('age', 0)),
            status=int(request.POST.get('status', 1)),
        )
        return redirect('students:student-list')

    # GET：显示空表单
    return render(request, 'students/create.html')
```

### 4. 更新页

```python
def student_update(request, pk):
    student = get_object_or_404(Student, pk=pk)

    if request.method == 'POST':
        student.name = request.POST.get('name', '').strip()
        student.age = int(request.POST.get('age', 0))
        student.save(update_fields=['name', 'age', 'update_time'])
        return redirect('students:student-detail', pk=student.pk)

    return render(request, 'students/update.html', {'student': student})
```

### 5. 删除确认页

```python
def student_delete(request, pk):
    student = get_object_or_404(Student, pk=pk)

    if request.method == 'POST':
        student.delete()
        return redirect('students:student-list')

    return render(request, 'students/delete_confirm.html', {'student': student})
```

---

## 七、模板继承与 `render` 配合

### 父模板 `base.html`

```html
<!DOCTYPE html>
<html>
<head>
    <title>{% block title %}默认标题{% endblock %}</title>
    <link rel="stylesheet" href="{% static 'css/style.css' %}">
</head>
<body>
    <header>
        <nav>
            <a href="{% url 'home' %}">首页</a>
            <a href="{% url 'students:student-list' %}">学生管理</a>
        </nav>
    </header>

    <main>
        {% block content %}{% endblock %}
    </main>

    <footer>
        {% block footer %}
            <p>&copy; 2026 我的网站</p>
        {% endblock %}
    </footer>
</body>
</html>
```

### 子模板 `students/list.html`

```html
{% extends "base.html" %}

{% block title %}学生列表 - {{ block.super }}{% endblock %}

{% block content %}
    <h1>学生列表</h1>
    <table>
        <thead>
            <tr><th>ID</th><th>姓名</th><th>年龄</th><th>状态</th></tr>
        </thead>
        <tbody>
            {% for student in page_obj %}
                <tr>
                    <td>{{ student.id }}</td>
                    <td>{{ student.name }}</td>
                    <td>{{ student.age }}</td>
                    <td>{{ student.get_status_display }}</td>
                </tr>
            {% empty %}
                <tr><td colspan="4">暂无数据</td></tr>
            {% endfor %}
        </tbody>
    </table>

    {# 分页 #}
    {% if page_obj.has_previous %}
        <a href="?page={{ page_obj.previous_page_number }}">上一页</a>
    {% endif %}
    <span>第 {{ page_obj.number }} / {{ paginator.num_pages }} 页</span>
    {% if page_obj.has_next %}
        <a href="?page={{ page_obj.next_page_number }}">下一页</a>
    {% endif %}
{% endblock %}
```

---

## 八、`render()` 内部工作流程

```
1. 根据 using 选择模板引擎
        ↓
2. 加载 template_name 对应的模板
        ↓
3. 把 context 转成 RequestContext
        ↓
4. 应用所有上下文处理器（context processors）
        ↓
5. 渲染模板，得到 HTML 字符串
        ↓
6. 包装成 HttpResponse，附带 content_type 和 status
        ↓
7. 返回响应对象
```

**第 4 步是关键**：[[2026-09-16-DTL模板语法速查|上下文处理器]]会自动往模板上下文里注入变量。

---

## 九、上下文处理器（Context Processors）

Django 默认配置的上下文处理器：

| 处理器 | 注入变量 |
|---|---|
| `django.template.context_processors.request` | `request` |
| `django.contrib.auth.context_processors.auth` | `user`、`perms` |
| `django.contrib.messages.context_processors.messages` | `messages` |
| `django.template.context_processors.csrf` | `csrf_token` |
| `django.template.context_processors.debug` | `debug`、`sql_queries` |
| `django.template.context_processors.i18n` | `LANGUAGES`、`LANGUAGE_CODE` |
| `django.template.context_processors.static` | `STATIC_URL` |
| `django.template.context_processors.media` | `MEDIA_URL` |

配置在 `settings.py`：

```python
TEMPLATES = [
    {
        'BACKEND': 'django.template.backends.django.DjangoTemplates',
        'DIRS': [BASE_DIR / 'templates'],
        'APP_DIRS': True,
        'OPTIONS': {
            'context_processors': [
                'django.template.context_processors.debug',
                'django.template.context_processors.request',
                'django.contrib.auth.context_processors.auth',
                'django.contrib.messages.context_processors.messages',
            ],
        },
    },
]
```

因为这些处理器，模板里可以直接用：

```html
{% csrf_token %}
<p>欢迎，{{ user.username }}</p>
{% if messages %}
    {% for msg in messages %}
        <div>{{ msg }}</div>
    {% endfor %}
{% endif %}
```

---

## 十、自定义上下文处理器

如果多个页面都需要同一个变量（比如网站名称、导航菜单），可以自定义上下文处理器。

### 1. 创建 `context_processors.py`

```python
# myapp/context_processors.py

def site_info(request):
    return {
        'site_name': '我的网站',
        'site_version': '1.0.0',
        'current_year': 2026,
    }


def navigation(request):
    return {
        'nav_items': [
            {'name': '首页', 'url': '/'},
            {'name': '学生管理', 'url': '/students/'},
            {'name': '关于', 'url': '/about/'},
        ],
    }
```

### 2. 注册到 `settings.py`

```python
TEMPLATES = [
    {
        ...
        'OPTIONS': {
            'context_processors': [
                ...
                'myapp.context_processors.site_info',
                'myapp.context_processors.navigation',
            ],
        },
    },
]
```

### 3. 模板中使用

```html
<h1>{{ site_name }}</h1>
<nav>
    {% for item in nav_items %}
        <a href="{{ item.url }}">{{ item.name }}</a>
    {% endfor %}
</nav>
```

**注意**：上下文处理器的变量会应用到**所有模板**，不要往里面塞只给一个页面用的变量。

---

## 十一、`render()` vs 相关函数

| 函数 | 作用 | 传 request | 上下文处理器 | 返回值 |
|---|---|---|---|---|
| `render()` | 渲染模板并返回响应 | ✅ | ✅ | `TemplateResponse` |
| `render_to_string()` | 只渲染成字符串 | ❌ | ❌ | `str` |
| `TemplateResponse` | 延迟渲染的响应类 | ✅ | ✅ | `TemplateResponse` |
| `HttpResponse` | 直接返回内容 | ❌ | ❌ | `HttpResponse` |
| `JsonResponse` | 返回 JSON | ❌ | ❌ | `JsonResponse` |
| `redirect()` | 重定向 | ❌ | ❌ | `HttpResponseRedirect` |

### `render()` vs `render_to_string()`

```python
from django.template.loader import render_to_string
from django.http import HttpResponse

# render：直接返回响应
return render(request, 'index.html', {'name': 'tom'})

# render_to_string：先渲染成字符串，再自己包装
html = render_to_string('index.html', {'name': 'tom'})
return HttpResponse(html)
```

`render_to_string()` 不传 `request`，**不会应用上下文处理器**，所以拿不到 `user`、`messages` 等变量。需要时手动传：

```python
html = render_to_string('index.html', {'name': 'tom'}, request=request)
```

### `render()` vs `TemplateResponse`

`render()` 是 `TemplateResponse` 的快捷方式，但它**立即渲染**。`TemplateResponse` 是**延迟渲染**，中间件可以在渲染前修改上下文。

```python
from django.template.response import TemplateResponse

def index(request):
    response = TemplateResponse(request, 'index.html', {'name': 'tom'})
    response['X-Custom'] = 'value'   # 渲染前设置
    return response                   # Django 负责渲染
```

**什么时候用 `TemplateResponse`**：

- 需要中间件在渲染前修改上下文
- 需要自定义模板渲染逻辑
- 需要延迟渲染以优化性能

日常开发用 `render()` 就够了。

---

## 十二、异步视图中的 `render()`

`render()` 是**同步函数**。在 `async def` 视图里直接调用会报 `SynchronousOnlyOperation`。

### 解决方案一：用 `sync_to_async` 包装

```python
from asgiref.sync import sync_to_async
from django.shortcuts import render

async def index(request):
    return await sync_to_async(render)(request, 'index.html', {'name': 'tom'})
```

### 解决方案二：用 `arender()`（Django 5.0+）

Django 5.0 引入了 `arender()`：

```python
from django.shortcuts import arender

async def index(request):
    return await arender(request, 'index.html', {'name': 'tom'})
```

### 解决方案三：用异步 ORM + `arender`

```python
from django.shortcuts import arender

async def student_list(request):
    students = []
    async for s in Student.objects.all():
        students.append(s)

    return await arender(request, 'students/list.html', {'students': students})
```

---

## 十三、常见错误与注意事项

### 1. 忘记传 `request`

```python
render('index.html', {'name': 'tom'})   # ❌ TypeError
render(request, 'index.html', {'name': 'tom'})   # ✅
```

### 2. `context` 传成关键字参数

```python
render(request, 'index.html', name='tom')   # ❌ 错误
render(request, 'index.html', {'name': 'tom'})   # ✅
```

### 3. 模板不存在

```
TemplateDoesNotExist: index.html
```

检查：

- `TEMPLATES` 配置的 `DIRS` 和 `APP_DIRS`
- 模板文件路径是否正确
- 文件名大小写

### 4. 返回 JSON 用 `render`

```python
# ❌ 不推荐
return render(request, 'data.json', {'data': data})

# ✅ 推荐
return JsonResponse({'data': data})
```

### 5. 在 `async def` 里直接用

```python
async def index(request):
    return render(request, 'index.html')   # ❌ SynchronousOnlyOperation
```

用 `arender()` 或 `sync_to_async`。

### 6. 自动转义

Django 模板默认对变量自动转义，防止 XSS：

```html
{{ user_input }}   {# <script> 会变成 &lt;script&gt; #}
```

需要输出原始 HTML 时用 `|safe`，但要确保内容可信：

```html
{{ html_content|safe }}   {# ⚠️ 只在可信内容上使用 #}
```

### 7. 上下文处理器变量名冲突

如果自定义上下文处理器返回的变量名和视图 `context` 里的同名，**视图的 context 会覆盖处理器**。

```python
# context_processor 返回 {'site_name': '默认'}
# 视图 context 传 {'site_name': '自定义'}
# 模板里 {{ site_name }} → "自定义"
```

### 8. `render()` 不处理表单校验

`render()` 只负责渲染，不校验数据。表单校验要用 `Form` 或 `ModelForm`：

```python
from django import forms

class StudentForm(forms.ModelForm):
    class Meta:
        model = Student
        fields = ['name', 'age', 'mobile']


def student_create(request):
    if request.method == 'POST':
        form = StudentForm(request.POST)
        if form.is_valid():
            form.save()
            return redirect('students:student-list')
    else:
        form = StudentForm()

    return render(request, 'students/create.html', {'form': form})
```

---

## 十四、完整速查表

```python
from django.shortcuts import render, redirect, get_object_or_404

# 最简
return render(request, 'index.html')

# 带上下文
return render(request, 'index.html', {'name': 'tom'})

# 带状态码
return render(request, '404.html', context, status=404)

# 带 Content-Type
return render(request, 'index.xml', context, content_type='application/xml')

# 指定模板引擎
return render(request, 'index.html', context, using='jinja2')

# 模板列表（回退）
return render(request, ['mobile/index.html', 'index.html'], context)

# 修改响应
response = render(request, 'index.html', context)
response['X-Custom'] = 'value'
response.set_cookie('theme', 'dark')
return response

# 异步视图（Django 5.0+）
from django.shortcuts import arender
return await arender(request, 'index.html', context)
```

---

## 十五、总结

| 问题 | 答案 |
|---|---|
| `render()` 是什么 | Django 快捷函数，渲染模板并返回 `HttpResponse` |
| 必须传什么 | `request` 和 `template_name` |
| `context` 怎么传 | 字典，第三个位置参数 |
| 支持状态码吗 | 支持，`status=404` |
| 支持 Content-Type 吗 | 支持，`content_type='application/xml'` |
| 支持多模板引擎吗 | 支持，`using='jinja2'` |
| 支持模板回退吗 | 支持，`template_name` 传列表 |
| 和 `render_to_string` 区别 | 前者返回响应，后者返回字符串 |
| 和 `TemplateResponse` 区别 | 前者立即渲染，后者延迟渲染 |
| 异步视图能用吗 | 用 `arender()` 或 `sync_to_async` |
| 必须传 `request` 吗 | 是，否则上下文处理器不工作 |

**核心要点**：

1. **`render()` = 加载模板 + 填充上下文 + 渲染 + 包装响应**，一行搞定。
2. **`request` 必须传**，它驱动上下文处理器（`user`、`messages`、`csrf_token`）。
3. **`context` 必须是字典**，不能写关键字参数。
4. **返回 HTML 用 `render()`，返回 JSON 用 `JsonResponse`**。
5. **需要延迟渲染或[[2026-09-18-Django自定义中间件详解|中间件]]介入**时，用 `TemplateResponse`。
6. **异步视图**用 `arender()`（Django 5.0+）或 `sync_to_async(render)`。

## 参考信息

- [[2026-10-17-Django基础知识地图]] — 学习路径中的位置：知识地图「三、模板与静态文件」
