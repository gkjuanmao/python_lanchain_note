---
tags: [python, django, 安全, 密码哈希]
description: 在 Django 中配置和使用 Argon2id 密码哈希的完整流程，含参数调优与已有密码的自动迁移。
---

# Django配置Argon2id密码哈希

在 Django 中使用 Argon2id 进行密码存储，是当前提升应用安全性的最佳实践之一。Argon2id 是密码哈希竞赛的获胜者，它不仅抗 GPU 破解，还通过内存硬特性有效抵御定制硬件的攻击。

下面是在 Django 中从零开始配置和使用 Argon2id 的完整指南。

---

### 📦 第一步：安装依赖

Django 将 Argon2 的支持放在了可选依赖中，需要单独安装。推荐使用 `django[argon2]` 来确保版本兼容。

```bash
pip install django[argon2]
```

这条命令会自动安装 `argon2-cffi` 库，它是 Argon2 在 Python 中的实现。如果你使用 `requirements.txt`，可以添加 `argon2-cffi>=23.1.0`。

---

### ⚙️ 第二步：配置 `settings.py`

在 Django 项目的 `settings.py` 中，找到或添加 `PASSWORD_HASHERS` 设置。Django 会使用列表中的**第一个哈希器**来存储新密码。所以，将 `Argon2PasswordHasher` 放在首位即可。

```python
# settings.py

PASSWORD_HASHERS = [
    "django.contrib.auth.hashers.Argon2PasswordHasher",  # 首选：Argon2id
    "django.contrib.auth.hashers.PBKDF2PasswordHasher",  # 回退：兼容旧密码
    "django.contrib.auth.hashers.PBKDF2SHA1PasswordHasher",
    "django.contrib.auth.hashers.BCryptSHA256PasswordHasher",
    "django.contrib.auth.hashers.ScryptPasswordHasher",
]
```

> **注意**：列表中的其他哈希器需要保留。Django 在验证密码时，会根据数据库中存储的算法名来匹配对应的哈希器。如果移除了某个哈希器，使用该算法存储的旧密码将无法验证，可能导致用户无法登录。

配置完成后，**重启 Django 服务**（`runserver` 需 `Ctrl+C` 后重启，生产环境需重载 `uwsgi`/`gunicorn`）使设置生效。

---

### 🔑 第三步：使用密码哈希

配置完成后，Django 的密码系统会自动使用 Argon2id。你通常**不需要修改任何业务代码**，因为 Django 内置的 `User` 模型和认证系统已经集成了 `PASSWORD_HASHERS` 机制。

#### 1. 创建用户（自动使用 Argon2id）

```python
# 通过 Django shell 或你的注册视图
from django.contrib.auth.models import User

user = User.objects.create_user(username="alice", password="my_secure_password")
# user.password 现在是一个 Argon2id 格式的字符串，例如：
# 'argon2$argon2id$v=19$m=102400,t=2,p=8$...'
```

#### 2. 验证密码（自动识别算法）

```python
from django.contrib.auth import authenticate

user = authenticate(username="alice", password="my_secure_password")
if user is not None:
    print("密码正确")
```

#### 3. 手动哈希 / 校验（使用工具函数）

如果你在非 `User` 模型或自定义场景中需要处理密码，可以使用 Django 提供的工具函数：

```python
from django.contrib.auth.hashers import make_password, check_password

# 哈希密码
hashed = make_password("my_secure_password")
# 输出类似：'argon2$argon2id$v=19$m=102400,t=2,p=8$...'

# 校验密码
is_valid = check_password("my_secure_password", hashed)  # True
```

---

### 🎛️ 第四步：调优 Argon2id 参数（可选）

Argon2id 的核心优势在于其可调参数。Django 的 `Argon2PasswordHasher` 允许你通过子类化来调整这些参数，以在安全性和服务器性能之间取得平衡。

#### 三个核心参数

| 参数 | 含义 | 调优方向 |
|---|---|---|
| `time_cost` | 迭代次数 | 增加可提高安全性，但会线性增加哈希耗时 |
| `memory_cost` | 内存使用量（单位：KiB） | 增加可显著抵抗 GPU 攻击，但会增加内存消耗 |
| `parallelism` | 并行线程数 | 通常设为服务器可用核心数，增加可略微提升速度 |

#### 自定义哈希器

创建一个自定义哈希器，重写参数：

```python
# your_app/hashers.py
from django.contrib.auth.hashers import Argon2PasswordHasher

class CustomArgon2PasswordHasher(Argon2PasswordHasher):
    # 根据服务器配置调整以下值
    # 原则：单次哈希耗时约 0.5 ~ 1 秒
    time_cost = 3          # 默认 2
    memory_cost = 64 * 1024  # 默认 102400 KiB (约 100 MiB)，这里设为 64 MiB
    parallelism = 4        # 默认 8，通常设为 CPU 核心数
```

然后在 `settings.py` 中使用你的自定义哈希器：

```python
PASSWORD_HASHERS = [
    "your_app.hashers.CustomArgon2PasswordHasher",  # 替换默认的 Argon2PasswordHasher
    "django.contrib.auth.hashers.PBKDF2PasswordHasher",
    # ... 其他回退
]
```

> **参考值**：Weblate 的推荐配置是 `time_cost=2`, `memory_cost=102400`, `parallelism=8`。RFC 9106 建议 `parallelism=4`，内存“尽可能多”。**最佳做法是根据你的服务器实测**：调整参数使单次哈希耗时在 0.5~1 秒之间。

---

### 🔄 第五步：迁移现有密码（自动升级）

切换到 Argon2id 后，**现有用户的密码不会立即改变**。Django 提供了一种优雅的自动升级机制：

- **新注册用户**：创建时直接使用 `PASSWORD_HASHERS[0]`（即 Argon2id）哈希。
- **现有用户**：当他们**下次成功登录**时，Django 会检测到其密码使用的不是当前首选算法，并在验证成功后**自动用 Argon2id 重新哈希并更新数据库**。

这意味着你**无需编写任何迁移脚本**，用户会无感地完成密码升级。

> **重要提醒**：自动升级仅在用户主动登录时发生。如果某些用户长期不登录，他们的密码会一直保持旧算法。对于安全性要求极高的场景，可以考虑强制所有用户重置密码。另外，当你调整了 Argon2 的参数（如 `time_cost`），Django 也会在用户下次登录时自动用新参数重新哈希。

---

### 🛡️ 安全最佳实践

1. **始终使用 HTTPS**：无论哈希算法多强，明文密码在 HTTP 传输中仍可能被窃听。
2. **保留旧的哈希器**：不要从 `PASSWORD_HASHERS` 中删除 `PBKDF2PasswordHasher` 等旧算法，否则使用这些算法的用户将无法登录。
3. **不要硬编码密钥**：Argon2id 的盐值由 Django 自动生成并嵌入哈希字符串中，无需手动管理。
4. **监控性能**：Argon2id 是计算和内存密集型算法。在高并发登录场景下，需确保服务器有足够的内存和 CPU 资源，必要时可适当降低 `memory_cost`。
5. **结合速率限制**：在登录接口上实施速率限制（如 `django-ratelimit`），防止暴力破解。

---

### 💎 总结

在 Django 中使用 Argon2id 的步骤非常简洁：

1. **安装**：`pip install django[argon2]`
2. **配置**：在 `settings.py` 中把 `Argon2PasswordHasher` 放在 `PASSWORD_HASHERS` 首位
3. **使用**：无需改动业务代码，`create_user` 和 `authenticate` 自动生效
4. **迁移**：用户下次登录时密码自动升级
5. **调优**：通过子类化调整 `time_cost`、`memory_cost`、`parallelism` 以适应服务器

Argon2id 是当前密码哈希的黄金标准，在 Django 中启用它只需几行配置，却能带来实质性的安全提升。

## 参考信息

- [[2026-09-18-Django会话控制与密码安全]] — 认证流程中实际调用密码哈希的场景
- [[2026-09-18-Django-ORM新增数据]] — `create_user` 本质仍是一次 ORM 写入
- [[2026-09-18-Django入门配置与部署]] — `PASSWORD_HASHERS` 所在的 `settings.py` 整体结构
- [[2026-09-10-Python基础知识]] — `parallelism` 参数的线程模型背景
