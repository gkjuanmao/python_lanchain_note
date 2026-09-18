---
tags: [python, django, 中间件, csrf, 安全]
description: 内置中间件清单、CSRF 攻击的原理与防御、GZIP 压缩、中间件的执行顺序。
---

# 中间件

Middleware，是 **Django 请求/响应**处理的钩子框架。它是一个轻量级的、低级的“插件”系统，用于全局改变 Django 的输入或输出。【输入指代的就是客户端向服务端django发送数据，输出指代django根据客户端要求处理数据的结果返回给客户端】

钩子就是编程开发的一个术语，hook，钩子可以理解为一段代码(要么是类，要么是函数)，它的作用就类似日常生活中墙上的钩子，不需要的时候，挂在墙上不会占用房子的空间，但是需要的时候我们可以把一些物件挂在上面。

这种中间件在平时不使用情况下不会耗费任何的性能,如果编写了中间件以后,可以在特定的条件下,全局执行!!

文档: [https://docs.djangoproject.com/zh-hans/3.2/topics/http/middleware/](https://docs.djangoproject.com/zh-hans/3.2/topics/http/middleware/)

## 内置中间件

```python
MIDDLEWARE = [  
    'django.middleware.security.SecurityMiddleware',  
    'django.contrib.sessions.middleware.SessionMiddleware',  
    'django.middleware.common.CommonMiddleware',  
    'django.middleware.csrf.CsrfViewMiddleware',  
    'django.contrib.auth.middleware.AuthenticationMiddleware',  
    'django.contrib.messages.middleware.MessageMiddleware',  
    'django.middleware.clickjacking.XFrameOptionsMiddleware',  
    'whitenoise.middleware.WhiteNoiseMiddleware',  
]
```

## CSRF攻击

### 一句话解释

**CSRF（Cross-Site Request Forgery，跨站请求伪造）** 是一种攻击方式：攻击者诱导**已经登录目标网站的你**，在不知情的情况下，用你的身份向目标网站发送一个恶意请求。

关键词：**利用你已有的登录状态，冒充你发请求。**

---
---

### 攻击原理

CSRF 能成功，依赖三个条件同时成立：

1. **目标网站用 Cookie 识别用户身份**  
    浏览器每次请求目标网站，都会自动带上该网站的 Cookie（比如 `sessionid`）。
2. **攻击者能构造出目标网站接受的请求**  
    请求的 URL、参数格式是可预测的，比如 `POST /transfer?to=xxx&amount=1000`。
3. **用户已登录，且没有额外的校验机制**  
    目标网站只靠 Cookie 判断"你是谁"，不检查请求是否真的来自自己的页面。

攻击者不需要知道你的密码，也不需要偷你的 Cookie，**只需要让你在登录状态下访问一个恶意页面**。

### 一个具体场景

假设你登录了银行网站 `bank.com`，浏览器里存着有效的 `sessionid`。

银行有个转账接口：

```text
POST https://bank.com/transfer
Body: to=attacker&amount=10000

攻击者做了一个恶意网页 `evil.com`，里面藏了这样一段代码：
```

```html
<!-- 方式一：自动提交的表单 -->
<form action="https://bank.com/transfer" method="POST" id="f">
    <input type="hidden" name="to" value="attacker">
    <input type="hidden" name="amount" value="10000">
</form>
<script>document.getElementById('f').submit();</script>
```

或者更隐蔽的：

```html
<!-- 方式二：图片请求（只能发 GET） -->
<img src="https://bank.com/transfer?to=attacker&amount=10000">
```

你只要访问了 `evil.com`：

1. 浏览器自动提交表单到 `bank.com`
2. 浏览器**自动带上 `bank.com` 的 Cookie**
3. 银行服务器看到有效的 `sessionid`，认为是你本人操作
4. 转账成功，你毫不知情

**攻击者全程没有拿到你的密码，也没有读到你的 Cookie，只是"借"了你的登录状态。**

### 如何防御

#### 1. CSRF Token（最核心）

服务器在页面里嵌入一个随机 token，提交表单时必须带上。攻击者无法预测这个 token，所以伪造的请求会被拒绝。

Django 模板中：

```html
<form method="post">
    {% csrf_token %}
    ...
</form>
```

渲染出来是：

```html
<input type="hidden" name="csrfmiddlewaretoken" value="随机字符串">
```

Django 的 `CsrfViewMiddleware` 会校验这个 token 是否和 Cookie 中的 `csrftoken` 匹配。

**关键点**：攻击者的 `evil.com` 无法读取 `bank.com` 页面里的 token（同源策略），所以无法伪造。

#### 2. SameSite Cookie

给 Cookie 设置 `SameSite` 属性，限制跨站请求携带 Cookie：

|值|行为|
|---|---|
|`Strict`|跨站请求完全不带 Cookie（最安全，但影响体验）|
|`Lax`|跨站的 GET 导航带 Cookie，POST 等不带（现代浏览器默认）|
|`None`|总是带，必须配合 `Secure`|

Django 中：

```python
SESSION_COOKIE_SAMESITE = 'Lax'
CSRF_COOKIE_SAMESITE = 'Lax'
```

`Lax` 已经能挡住绝大多数 CSRF 攻击，是现代浏览器的默认值。

#### 3. 检查 Referer / Origin

服务器检查请求头里的 `Referer` 或 `Origin` 是否来自自己的域名。Django 的 `CsrfViewMiddleware` 也会做这个校验。

#### 4. 关键操作二次验证

转账、改密码等敏感操作，要求重新输入密码、短信验证码、OTP 等。即使 CSRF 成功，攻击者也过不了这一关。

#### 5. 不要用 GET 做写操作

GET 请求应该只读。如果用 `GET /delete?id=1` 删除数据，一个 `<img src="...">` 就能触发 CSRF。

## GZIP

建议在nginx中配置

## 中间件的执行顺序

![20260916150035.png](images/20260916150035.png)

http请求阶段是从上往下执行
http响应阶段是从下往上执行
先进后出



---

**相关笔记**：[[2026-09-18-Django自定义中间件详解]]、[[2026-09-18-Django会话控制与密码安全]]
