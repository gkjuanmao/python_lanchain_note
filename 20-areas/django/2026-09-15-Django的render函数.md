---
tags: [python, django, 视图, 模板渲染]
description: Django render() 快捷函数的签名、参数、返回值与内部工作流程详解。
---

`render()` 是 Django 中最常用的快捷函数，用于**加载模板、填充上下文、渲染成 HTML，并返回一个 `HttpResponse`**。它把“模板加载 → 上下文处理 → 渲染 → 包装响应”这一套流程封装成一行代码，是编写 HTML 视图的标准方式。

---

## 一、导入与函数签名

```python
from django.shortcuts import render

def render(request, template_name, context=None, content_type=None, status=None, using=None):
    ...
```

返回一个**已渲染的 `TemplateResponse`**，它是 `HttpResponse` 的子类，因此可以像普通响应一样设置响应头、Cookie、状态码等。

---

## 二、参数详解

| 参数 | 是否必填 | 说明 |
|---|---|---|
| `request` | ✅ 必填 | `HttpRequest` 对象。用于上下文处理器、CSRF、messages、auth 等 |
| `template_name` | ✅ 必填 | 模板路径字符串，如 `'blog/index.html'`；也可以是模板名列表，Django 会选第一个存在的 |
| `context` | 可选 | 字典，传给模板的变量。默认 `None`，即空上下文 |
| `content_type` | 可选 | 响应的 MIME 类型，默认 `'text/html; charset=utf-8'` |
| `status` | 可选 | HTTP 状态码，默认 `200` |
| `using` | 可选 | 指定模板引擎，如 `'django'`、`'jinja2'` |

> ⚠️ `context` 必须是**字典**，不能写成关键字参数。  
> ✅ 正确：`render(request, 'index.html', {'name': 'tom'})`  
> ❌ 错误：`render(request, 'index.html', name='tom')`

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

## 四、内部工作流程

`render()` 内部大致做了这几步：

1. 根据 `using` 选择模板引擎，加载 `template_name` 对应的模板。
2. 把 `context` 转换为 `RequestContext`，并**应用所有上下文处理器**。
3. 渲染模板，得到 HTML 字符串。
4. 用 `content_type` 和 `status` 包装成 `HttpResponse`。
5. 返回响应对象。

关键点：**第 2 步的上下文处理器依赖 `request`**。这就是为什么 `render()` 必须传 `request`，也是它和 `render_to_response()` 的本质区别。

---

## 五、为什么必须传 `request`？

Django 的上下文处理器会自动往模板上下文里注入一些变量，例如：

| 上下文处理器 | 注入变量 |
|---|---|
| `django.template.context_processors.request` | `request` |
| `django.contrib.auth.context_processors.auth` | `user`、`perms` |
| `django.contrib.messages.context_processors.messages` | `messages` |
| `django.template.context_processors.csrf` | `csrf_token` |

所以模板里能直接写：

```html
{% csrf_token %}
<p>欢迎，{{ user.username }}</p>
{% if messages %}...{% endif %}
```

这些都依赖 `request`。如果改用 `render_to_response()`（已移除），这些变量就不会自动注入。

---

## 六、基本示例

```python
# views.py
from django.shortcuts import render

def index(request):
    context = {
        'title': '首页',
        'items': ['苹果', '香蕉', '橙子'],
    }
    return render(request, 'blog/index.html', context)
```

```html
<!-- templates/blog/index.html -->
<!DOCTYPE html>
<html>
<head><title>{{ title }}</title></head>
<body>
  <h1>{{ title }}</h1>
  <ul>
    {% for item in items %}
      <li>{{ item }}</li>
    {% endfor %}
  </ul>
</body>
</html>
```

---

## 七、高级用法

### 1. 指定状态码

```python
return render(request, '404.html', {'message': '页面不存在'}, status=404)
```

### 2. 指定 Content-Type

```python
return render(request, 'index.html', context, content_type='application/xhtml+xml')
```

### 3. 指定模板引擎

```python
return render(request, 'index.html', context, using='jinja2')
```

### 4. 模板名列表（回退机制）

```python
return render(request, ['mobile/index.html', 'index.html'], context)
```

Django 会按顺序查找，使用第一个存在的模板。

### 5. 修改响应

```python
response = render(request, 'index.html', context)
response['X-Frame-Options'] = 'DENY'
response.set_cookie('theme', 'dark', max_age=3600)
return response
```

---

## 八、与相关函数对比

| 函数 | 作用 | 是否传 request | 是否应用上下文处理器 | 返回值 |
|---|---|---|---|---|
| `render()` | 渲染模板并返回响应 | ✅ | ✅ | `TemplateResponse` |
| `render_to_string()` | 只渲染成字符串 | ❌ | ❌（除非手动传） | `str` |
| `TemplateResponse` | 延迟渲染的响应类 | ✅ | ✅ | `TemplateResponse` |
| `HttpResponse` | 直接返回内容 | ❌ | ❌ | `HttpResponse` |
| `JsonResponse` | 返回 JSON | ❌ | ❌ | `JsonResponse` |
| `redirect()` | 重定向 | ❌ | ❌ | `HttpResponseRedirect` |
| `render_to_response()` | 旧版快捷函数，Django 3.0 已移除 | ❌ | ❌ | `HttpResponse` |

**`render()` vs `TemplateResponse`**  
`render()` 是 `TemplateResponse` 的快捷方式，但它**立即渲染**。如果你需要中间件在渲染前修改上下文或响应头，可以手动使用 `TemplateResponse`：

```python
from django.template.response import TemplateResponse

def index(request):
    response = TemplateResponse(request, 'index.html', {'name': 'tom'})
    response['X-Custom'] = 'value'   # 渲染前设置
    return response                   # 由 Django 负责渲染
```

`process_template_response` 中间件可以介入 `TemplateResponse` 的渲染过程。

---

## 九、常见错误与注意事项

1. **忘记传 `request`**  
   `render('index.html', {})` → `TypeError`。

2. **`context` 传成关键字参数**  
   `render(request, 'index.html', name='tom')` → 错误，必须用字典。

3. **模板不存在**  
   抛出 `TemplateDoesNotExist`，检查 `TEMPLATES` 配置和模板路径。

4. **在异步视图中直接调用**  
   `render()` 是同步函数，在 `async def` 视图中直接调用会抛 `SynchronousOnlyOperation`。  
   解决：用 `sync_to_async` 包装：

   ```python
   from asgiref.sync import sync_to_async
   from django.shortcuts import render

   async def index(request):
       return await sync_to_async(render)(request, 'index.html', {'name': 'tom'})
   ```

5. **不要用 `render` 返回 JSON**  
   JSON 用 `JsonResponse`，模板渲染有额外开销。

6. **自动转义**  
   Django 模板默认对变量自动转义，防止 XSS。如果确实需要输出原始 HTML，使用 `|safe` 或 `mark_safe`，但要非常谨慎。

---

## 十、总结

`render()` 是 Django 视图层最核心的快捷函数，它：

- 接收 `request`、模板名、上下文字典；
- 自动应用上下文处理器，注入 `user`、`messages`、`csrf_token` 等；
- 渲染模板并返回 `HttpResponse`；
- 支持状态码、Content-Type、指定模板引擎、模板列表回退。

写 HTML 视图时，**优先使用 `render()`**；需要延迟渲染或中间件介入时，再用 `TemplateResponse`；返回 JSON 用 `JsonResponse`；返回纯文本用 `HttpResponse`。记住：**只要渲染模板，就传 `request`。**

## 参考信息

- [[2026-09-18-Django请求与响应对象]] — `render()` 返回的 `TemplateResponse` 属于响应对象家族，此处有完整对照
- [[2026-09-18-Django模板引擎与静态文件]] — 模板加载与静态文件配置是 `render()` 能工作的前提
- [[2026-09-16-DTL模板语法速查]] — `render()` 渲染的正是 DTL 模板，模板中可用哪些标签由此决定
- [[2026-09-18-Django中间件与CSRF安全]] — 必须传 `request` 才能让 CSRF 与认证信息注入上下文
- [[2026-09-18-Django自定义中间件详解]] — `process_template_response` 可介入 `render()` 返回对象的渲染过程
