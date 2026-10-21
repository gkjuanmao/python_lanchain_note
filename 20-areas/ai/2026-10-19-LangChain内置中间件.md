---
tags: [langchain, agent, 中间件, 示例代码]
description: LangChain 1.x 内置中间件：中间件的定位与分类、13 个内置中间件的用途与参数用法，以及组合与执行顺序。
---

# LangChain内置中间件


简单说就是Agent执行过程中的钩子函数，是LangChain1.x的“王牌”工程化能力
中间件的价值就在于把这些与业务无关、但与执行过程强相关的横切逻辑，从Agent主流程中分离出来，让Agent主体代码聚焦业务，而借助中间件，实现“拦截流程、修改流程、增强流程”。

## 中间件的分类

**自定义中间件：** 允许开发者自定义，从而实现更加灵活的Agent行为管理
**内置中间件：** LangChain实现并提供的，一共16个

## 1. SummarizationMiddleware中间件

**作用：** 对历史消息列表进行摘要&总结，达到压缩上下文的效果。
**原理：** 在达到触发条件时，调用大模型对历史消息进行摘要，将摘要的结果作为HumanMessage，放到消息列表最开始的位置。

## 2. HumanInTheLoopMiddleware
**用途**：为 Agent 的工具调用增加"人工审批"环节。当模型试图调用敏感工具（如写文件、执行 SQL）时，中间件会暂停执行并等待人类做出**批准（approve）**、**编辑（edit）**或**拒绝（reject）**的决定。
**重要参数**：
- `interrupt_on`：一个字典，键是工具名，值定义该工具允许的决策类型。例如 `{"send_email": {"allowed_decisions": ["approve", "reject"]}}` 表示发送邮件只允许批准或拒绝，不允许编辑。
- **必须配合 `checkpointer` 使用**：为了实现暂停和恢复，Agent 必须配置检查点（如 `MemorySaver`）来持久化状态。

```python
from langchain.agents.middleware import HumanInTheLoopMiddleware
from langchain_core.tools import tool
from langgraph.checkpoint.memory import MemorySaver
from rich import print as rprint


@tool
def read_email(email: str) -> str:
    """读取邮件内容"""
    return f"这是邮件内容：{email}"


@tool
def send_email(email: str) -> str:
    """发送邮件"""
    print(f"发送邮件：{email}")
    return "邮件发送成功"


agent = create_agent(
    model=model,
    tools=[read_email, send_email],
    middleware=[
        HumanInTheLoopMiddleware(
            interrupt_on={
                "send_email": {"allowed_decisions": ["approve", "edit", "reject"]},
                "read_email": False,  # 读取邮件无需审批
            }
        )
    ],
    checkpointer=MemorySaver(),  # 必须配置
)
# 调用时需提供 thread_id
result = agent.invoke(
    {
        "messages": [
            {
                "role": "user",
                "content": "帮我给gkjuanmao发送一封邮件，邮箱地址是gkjuanmao@example.com，邮件内容是：你好",
            }
        ]
    },
    config={"configurable": {"thread_id": "thread_1"}},
)

interrupts = result["__interrupt__"]
request = interrupts[0].value

rprint(request["action_requests"])  # 模型想调用的工具 + 参数
rprint(request["review_configs"])  # 允许的决定类型

from langgraph.types import Command

resumed = agent.invoke(
    Command(
        resume={"decisions": [{"type": "reject", "message": "不允许发送这封邮件"}]}
    ),
    config={"configurable": {"thread_id": "thread_1"}},  # 必须和第一次一致
)
rprint(resumed["messages"][-1].content)

```

## 3. PIIMiddleware
**用途**：检测并处理用户输入或模型输出中的敏感个人信息（PII），如邮箱、信用卡号、IP 地址等，用于合规和隐私保护。
**重要参数**：
- `pii_type`（或 `detector`）：内置类型（如 `"email"`、`"credit_card"`）或自定义正则表达式。
- `strategy`：处理策略，可选 `"redact"`（替换为 `[REDACTED]`）、`"mask"`（部分遮蔽）、`"hash"`（哈希）或 `"block"`（抛出异常）。
- `apply_to_input` / `apply_to_output`：是否对输入和输出生效。

```python
from langchain.agents import create_agent
from langchain.agents.middleware import PIIMiddleware
from langchain_core.messages import HumanMessage

agent = create_agent(
    model=model,
    middleware=[
        PIIMiddleware("email", strategy="redact", apply_to_input=True),
        PIIMiddleware(
            "credit_card", strategy="mask", apply_to_input=True, apply_to_output=True
        ),
        PIIMiddleware("api_key", detector=r"sk-[a-zA-Z0-9]{32}", strategy="hash", apply_to_output=True),
    ],
)

messages = [
    HumanMessage(
        content="我的邮箱是gkjuanmao@example.com，我的信用卡号是4242424242424242，我的API密钥是sk-1234567890abcdef1234567890abcdef，帮我分析这三个信息"
    ),
]

resopnse = agent.invoke(
    {
        "messages": messages,
    }
)
rprint(resopnse)
```

## 4. TodoListMiddleware
**用途**：为 Agent 注入一个 `write_todos` 工具和 `todos` 状态，使其能够为复杂多步任务创建并动态更新待办列表，实现显式的任务规划与进度跟踪。
**重要参数**：
- `system_prompt`：自定义系统提示，指导模型如何使用待办工具。
- `tool_description`：自定义 `write_todos` 工具的描述。

```python
from langchain.agents import create_agent
from langchain.agents.middleware import TodoListMiddleware
from rich.table import Table

agent = create_agent(
    model=model,
    middleware=[TodoListMiddleware()],
)

def show_todos(todos):
    status_icon = {"pending": "⬜", "in_progress": "🔄", "completed": "✅"}
    table = Table(title="TodoList 当前状态")
    table.add_column("状态")
    table.add_column("任务")
    for todo in todos:
        table.add_row(status_icon.get(todo["status"], todo["status"]), todo["content"])
    rprint(table)

question = (
    "请务必使用 todo list 工具来跟踪进度，帮我完成以下多步骤任务：\n"
    "1. 分析现有代码库结构\n"
    "2. 制定重构方案\n"
    "3. 实施核心模块重构\n"
    "4. 补充测试并输出总结报告"
)

final_todos = None
for state in agent.stream(
    {"messages": [{"role": "user", "content": question}]},
    stream_mode="values",
):
    todos = state.get("todos")
    if todos and todos != final_todos:
        show_todos(todos)
        final_todos = todos

print("\n最终回复：")
print(state["messages"][-1].text())
```

## 5. ModelCallLimitMiddleware
**用途**：限制 Agent 在一次运行或整个线程中调用模型的次数，防止因无限循环或异常行为导致成本失控。
**重要参数**：
- `run_limit` / `thread_limit`：单次运行或整个线程的最大模型调用次数。
- `exit_behavior`：达到限制后的行为，如 `"end"`（结束）或 `"error"`（抛出错误）。

```python
from langchain.agents import create_agent
from langchain.agents.middleware import ModelCallLimitMiddleware

agent = create_agent(
    model=model,
    middleware=[
        ModelCallLimitMiddleware(run_limit=10, thread_limit=50, exit_behavior="end")
    ],
)
```

## 6. ToolCallLimitMiddleware
**用途**：与模型调用限制类似，但专门针对工具调用次数进行限制，可以全局限制，也可以针对特定工具。
**重要参数**：
- `tool_name`：可选，指定要限制的工具名；不指定则限制所有工具。
- `run_limit` / `thread_limit`：工具调用的次数上限。
- `exit_behavior`：`"continue"`（阻止超额工具但继续运行）、`"end"`（结束）或 `"error"`（抛出异常）。

```python
from langchain.agents import create_agent
from langchain.agents.middleware import ToolCallLimitMiddleware

agent = create_agent(
    model=model,
    tools=[search_tool, database_tool],
    middleware=[
        ToolCallLimitMiddleware(tool_name="search", thread_limit=5, run_limit=3),
        ToolCallLimitMiddleware(run_limit=20, exit_behavior="continue"),
    ],
)
```

## 7. ModelFallbackMiddleware
**用途**：当主模型因提供商故障或 API 错误而不可用时，自动切换到备选模型，保障服务连续性。
**重要参数**：
- 直接传入备选模型标识符（可多个），按顺序尝试。

```python
from langchain.agents import create_agent
from langchain.agents.middleware import ModelFallbackMiddleware

agent = create_agent(
    model="openai:gpt-4o",  # 主模型
    middleware=[
        ModelFallbackMiddleware(
            "anthropic:claude-sonnet-4-5-20250929",  # 第一备选
            "openai:gpt-4o-mini",                     # 第二备选
        )
    ],
)
```

## 8. LLMToolSelectorMiddleware
**用途**：当可用工具数量很多时，先用一个（通常更便宜的）LLM 根据用户查询筛选出最相关的工具，再交给主模型决策，以降低 token 消耗并提高工具选择的准确性。
**重要参数**：
- `model`：用于筛选的模型，不指定则使用主模型。
- `max_tools`：最多筛选出的工具数量。
- `always_include`：始终包含的工具名列表，不计入 `max_tools` 限制。

```python
from langchain.agents import create_agent
from langchain.agents.middleware import LLMToolSelectorMiddleware

agent = create_agent(
    model=model,
    tools=[tool1, tool2, tool3, tool4, tool5],  # 假设有很多工具
    middleware=[
        LLMToolSelectorMiddleware(
            model="openai:gpt-4o-mini",
            max_tools=3,
            always_include=["get_weather"],  # 天气工具始终可用
        )
    ],
)
```

## 9. ToolRetryMiddleware
**用途**：当工具调用失败时（如网络超时、临时 API 错误），自动进行重试，支持指数退避策略。
**重要参数**：
- `max_retries`：最大重试次数。
- `initial_delay` / `backoff_factor`：指数退避的初始延迟和退避因子。
- `tools` / `retry_on`：限定重试的工具列表或异常类型。

```python
from langchain.agents import create_agent
from langchain.agents.middleware import ToolRetryMiddleware

agent = create_agent(
    model=model,
    tools=[search_tool, database_tool],
    middleware=[
        ToolRetryMiddleware(
            max_retries=3,
            initial_delay=1.0,
            backoff_factor=2.0,
            tools=["search_tool"],  # 只对搜索工具重试
            retry_on=(TimeoutError, ConnectionError),
        )
    ],
)
```

## 10. ModelRetryMiddleware
**用途**：与 `ToolRetryMiddleware` 对应，专门用于在**模型调用**失败时（如 API 限流、超时）进行自动重试。
**重要参数**：与 `ToolRetryMiddleware` 类似，包括 `max_retries`、`initial_delay`、`backoff_factor`、`retry_on` 等。

```python
from langchain.agents import create_agent
from langchain.agents.middleware import ModelRetryMiddleware

agent = create_agent(
    model=model,
    middleware=[
        ModelRetryMiddleware(
            max_retries=3,
            initial_delay=1.0,
            backoff_factor=2.0,
            retry_on=(TimeoutError, ConnectionError),
        )
    ],
)
```

## 11. LLMToolEmulator
**用途**：在**测试和开发阶段**，用 LLM 生成模拟的工具响应，来代替真实执行工具，避免依赖外部服务、产生费用或副作用。
**重要参数**：
- `tools`：要模拟的工具列表。不传（`None`）则模拟所有工具；传空列表则不模拟任何工具。
- `model`：用于生成模拟响应的 LLM，不指定则使用主模型。

```python
from langchain.agents import create_agent
from langchain.agents.middleware import LLMToolEmulator
from langchain_core.tools import tool


@tool
def get_weather(location: str) -> str:
    """Get the current weather in a given location"""

    return f"The current weather in {location} is sunny with a temperature of 25 degrees."

agent = create_agent(
    model=model,
    tools=[get_weather, send_email],
    middleware=[
        LLMToolEmulator(tools=["get_weather"], model=model),  # 只模拟天气工具
    ],
)

response = agent.invoke(
    {
        "messages": [
            HumanMessage(content="北京天气怎么样？"),
        ]
    }
)

rprint(response)
```

## 12. ContextEditingMiddleware
**用途**：当对话上下文达到 token 阈值时，自动清理**旧的工具执行结果**（保留最近的结果），以缩减上下文长度，是比摘要更轻量的上下文管理策略。
**重要参数**（通过 `ClearToolUsesEdit` 配置）：
- `trigger`：触发编辑的 token 阈值。
- `keep`：保留最近 N 个工具结果不被清理。
- `exclude_tools`：永不清理其结果的工具名单。
- `placeholder`：清理后替换的占位文本。

```python
from langchain.agents import create_agent
from langchain.agents.middleware import ContextEditingMiddleware, ClearToolUsesEdit

agent = create_agent(
    model=model,
    tools=[search_tool, calculator_tool],
    middleware=[
        ContextEditingMiddleware(
            edits=[
                ClearToolUsesEdit(
                    trigger=2000,   # 超过 2000 token 时触发
                    keep=3,         # 保留最近 3 个工具结果
                    placeholder="[cleared]",
                )
            ]
        )
    ],
)
```

## 13. FilesystemFileSearchMiddleware
**用途**：为 Agent 提供基于文件系统的 **Glob**（按路径模式查找文件）和 **Grep**（按内容搜索文件）两种搜索工具，使其能够探索和分析本地代码库或文档目录。
**重要参数**：
- `root_path`（必需）：搜索的根目录。
- `use_ripgrep`：是否使用 `ripgrep` 进行内容搜索（性能更好），不可用时自动回退到 Python。
- `max_file_size_mb`：单个文件的最大搜索大小（MB）。

```python
from langchain.agents import create_agent
from langchain.agents.middleware import FilesystemFileSearchMiddleware

agent = create_agent(
    model=model,
    tools=[],  # 工具由中间件自动添加
    middleware=[
        FilesystemFileSearchMiddleware(
            root_path="/path/to/your/project",
            use_ripgrep=True,
            max_file_size_mb=10,
        )
    ],
)
```

---

### 💡 补充说明
- **执行顺序**：`middleware` 列表中的顺序会影响执行逻辑，特别是对于有依赖关系的中间件（如先做 PII 检查，再做模型调用限制）。
- **组合使用**：这些中间件可以自由组合，以构建满足复杂生产需求的 Agent 管道。

## 中间件的组合和执行顺序

按照中间件传入顺序执行
进入：[MW1 before] → [MW2 before] → [MW3 before] → 模型调用
返回：[MW3 after] → [MW2 after] → [MW1 after]
## 参考信息

- [[2026-10-11-AI知识地图]] — 学习路径中的位置：知识地图「第五步：应用开发」
- [[2026-10-18-Agent创建与基本用法]] — 配套：middleware 是 create_agent 的参数，与该篇的创建与调用方式配套
