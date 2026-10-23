---
tags: [langchain, 上下文工程, 记忆, 对话历史]
description: 记忆与上下文工程的动机、上下文类型与相关 API、LangChain 记忆的分类与管理方式。
---
# LangChain上下文与记忆概述
## 1.1 为什么需要记忆(Memory)

记忆是一种记住之前互动信息的系统。随着Agent处理涉及大量用户交互的复杂任务，记忆变得至关重要！

大多数的大模型应用程序都会有一个会话接口，允许我们进行多轮的对话，并有一定的上下文记忆能力。比如：

![[images/ctx-chat-example.png]]

但实际上，大模型本身是“无状态”的，不会记忆任何上下文的。即每次调用 agent.invoke() 都是全新的开始，不记得之前的对话。

举例：

```python
from langchain.chat_models import init_chat_model
from dotenv import load_dotenv
import os

# 从.env文件中加载环境变量
load_dotenv(override=True)
model = init_chat_model(
    model="gpt-5.4-mini",
    model_provider="openai",
    api_key=os.getenv("CLOSEAI_API_KEY"),
    base_url=os.getenv("CLOSEAI_BASE_URL"),
)
```

情况1：

```python
from langchain.agents import create_agent
from langchain_core.messages import HumanMessage, AIMessage

messages1 = [
    HumanMessage("你好，我叫小明"),
    AIMessage("很高兴认识你，小明"),
    HumanMessage("你用一句话介绍下你自己"),
]
agent = create_agent(
    model=model,
    tools=[],
)
response1 = agent.invoke({"messages": messages1})
for msg in response1["messages"]:
    msg.pretty_print()
```

```text
================================ Human Message
你好，我叫小明
================================== Ai Message
很高兴认识你，小明
================================ Human Message
你用一句话介绍下你自己
================================== Ai Message
我是一个可以帮助你回答问题、写作、翻译和思考的 AI 助手。
```

```python
messages2 = [HumanMessage("我叫什么名字？")]
response2 = agent.invoke({"messages": messages2})
for msg in response2["messages"]:
    msg.pretty_print()
```

```text
================================ Human Message
我叫什么名字？
================================== Ai Message
我不知道你的名字，除非你告诉我。
如果你愿意，可以直接告诉我，我就记住并称呼你。
```

情况2：

```python
messages3 = [
    HumanMessage("你好，我叫小明"),
    AIMessage("很高兴认识你，小明"),
    HumanMessage("你用一句话介绍下你自己"),
    AIMessage(
        "我是一个由 OpenAI 训练的人工智能助手，可以帮你回答问题、写作和解决各种任务。"
    ),
    HumanMessage("我叫什么名字？"),
]
response3 = agent.invoke({"messages": messages3})
for msg in response3["messages"]:
    msg.pretty_print()
```

```text
================================ Human Message
你好，我叫小明
================================== Ai Message
很高兴认识你，小明
================================ Human Message
你用一句话介绍下你自己
================================== Ai Message
我是一个由 OpenAI 训练的人工智能助手，可以帮你回答问题、写作和解决各种任务。
================================ Human Message
我叫什么名字？
================================== Ai Message
你叫小明。
```

我们希望的智能体应该是右图的情况：

![[images/ctx-memory-comparison.png]]

## 1.2 如何解决记忆问题

### 1.2.1 上下文工程

实现这个记忆功能，就需要额外的模块去保存我们和模型对话的上下文信息，然后在下一次请求时，把历史信息都输入给模型，让模型输出结果。

在 LangChain 中，记忆(Memory) 就是专门负责“ 存储历史交互信息”的组件，核心作用是「保存上下文」和「提供上下文」，让LLM在每次响应时，都能“看到”之前的对话内容。

上下文工程(Context Engineering) 负责“合理组织”这些记忆和任务信息，让LLM的响应更连贯、更贴合需求。这也是Agent能实现复杂多轮交互的核心基础。

类比：

![[images/ctx-engineering-notebook.png]]

举例：

![[images/ctx-engineering-pipeline.png]]

### 1.2.2 上下文类型及相关的API

LangChain的上下文工程是基于Agent讨论的，而上下文工程是构建在LangGraph之上的。

LangGraph 提供了三种管理上下文的方法，这些方法结合了可变性和生命周期维度：

| 上下文类型    | 描述                           | 可变性 | 生命周期 | 访问方法                |
| -------- | ---------------------------- | --- | ---- | ------------------- |
| 动态运行时上下文 | 在单次运行中会演变的可变数据               | 动态  | 单次运行 | LangGraph state对象   |
| 动态跨会话上下文 | 在对话间共享的持久数据。比如用户偏好、历史洞察、知识条目 | 动态  | 跨对话  | LangGraph store对象   |
| 静态运行时上下文 | 在启动时传入的用户元数据、工具、数据库连接        | 静态  | 单次运行 | LangGraph context对象 |

## 1.3 LangChain的记忆

### 1.3.1 记忆的分类

官方说明：https://docs.langchain.com/oss/python/concepts/memory

记忆分为短期记忆和长期记忆，对应不同的使用场景：

短期记忆（Short-term memory、会话级记忆、thread-scoped memory）：作用范围是单个对话线程（Thread）内，一旦开启新对话（更换 thread_id ），记忆即消失。

长期记忆（Long-term memory，跨会话级记忆 ）：在会话间存储用户特定或应用级数据， 并在会话线程间共享。它可以随时在任何线程中被调用。记忆的范围是任意自定义命名空间，而不仅仅是单一线程 ID。

![[images/ctx-memory-types.png]]

### 1.3.2 记忆的管理

在LangChain v0.x版本中，通过专用的xxxMemory类管理记忆。

在LangChain v1.x版本中，Agent是构建在LangGraph图结构之上的，通过上文提到的state和store构建记忆系统。使用更简单、功能更统一。

state：短期记忆对象，以会话为单位组织，包含当前会话的所有消息记录以及自定义信息。

store：长期记忆对象，跨会话持久化的数据，通常需要结合向量数据库或外部存储实现。

## 参考信息

- [[2026-10-23-AI记忆与上下文知识地图]] — 学习路径中的位置：知识地图「1、概述」
- [[2026-10-11-Agent开发与架构]] — 关系类型：配套：记忆是 Agent 五大模块之一
