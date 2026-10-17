---
tags: [langchain, 提示词模板, 示例代码]
description: ChatPromptTemplate 提示词模板用法：from_messages 六种初始化参数类型、format/format_messages/invoke 输出差异、partial 预填充、Placeholder 消息占位符与可复用模板库。
---
# LangChain提示词模板


## 为什么推荐提示词模板？

在LangChain开发中，构造提示词既可以直接使用Python字符串拼接（如f-string、format()或+)，也可以使用LangChain提供的`PromptTemplate`或`ChatPromptTemplate`.

## ChatPromptTemplate

### 1. from_messages()

```python
chat_prompt_templete = ChatPromptTemplate.from_messages([
    ("system", "你叫{name}你是一个专业的翻译, 你需要将用户的问题翻译成英文"),
    ("human", "{input}"),
])

# 调用
result = chat_prompt_templete.invoke({"name": "小智", "input": "你是谁"})
print(result)
```

### 2. format() 方法,以字符串格式返回

```python
chat_prompt_templete = ChatPromptTemplate.from_messages([
    ("system", "你叫{name}你是一个专业的翻译, 你需要将用户的问题翻译成英文"),
    ("human", "{input}"),
])

# 调用
result = chat_prompt_templete.format(name= "小智", input= "你是谁")
print(result)
response = model.invoke(result)
rprint(response.content)
```

### 3. format_messages() 方法,以消息列表格式返回

```python
chat_prompt_templete = ChatPromptTemplate.from_messages([
    ("system", "你叫{name},你是一个专业的翻译, 你需要将用户的问题翻译成英文"),
    ("human", "{input}"),
])

result = chat_prompt_templete.format_messages(name= "小智", input= "你是谁")
print(result)
response = model.invoke(result)
rprint(response.content)
```

### 4. 更丰富的初始化参数类型

#### 类型1：str列表类型

```python
chat_prompt_template = ChatPromptTemplate.from_messages(
    [
        ("system", "你叫{name}你是一个专业的翻译, 你需要将用户的问题翻译成英文"),
        ("human", "{input}"),
    ]
)

# 调用
result = chat_prompt_template.format(name="小智", input="你是谁")
print(result)
response = model.invoke(result)
rprint(response.content)
```
#### 类型2：tuple列表类型

```python
chat_prompt_template = ChatPromptTemplate.from_messages(
    [
        ("system", "你叫{name},你是一个专业的翻译, 你需要将用户的问题翻译成英文"),
        ("human", "{input}"),
    ]
)

result = chat_prompt_template.format_messages(name="小智", input="你是谁")
print(result)
response = model.invoke(result)
rprint(response.content)
```
#### 类型3：dict列表类型

```python
chat_prompt_template = ChatPromptTemplate.from_messages(
    [
        {"role": "system","content": "你叫{name},你是一个专业的翻译, 你需要将用户的问题翻译成英文"},
        {"role": "human","content": "{input}"},
    ]
)

result = chat_prompt_template.format_messages(name="小智", input="你是谁")
print(result)
response = model.invoke(result)
rprint(response.content)
```
#### 类型4：Message列表类型

```python
from langchain_core.messages import SystemMessage, HumanMessage
system_prompt = SystemMessage(content="你是一个专业的翻译, 你需要将用户的问题翻译成英文")
user_prompt = HumanMessage(content="{input}")
 
chat_prompt_template = ChatPromptTemplate.from_messages(
    [
        system_prompt,
        user_prompt,
    ]
)

result = chat_prompt_template.format_messages(name="小智", input="你是谁")
print(result)
response = model.invoke(result)
rprint(response.content)
# 注意，如果使用BaseMessage类型，是无法往ChatPromptTemplate里面传入变量的，result的值是：[SystemMessage(content='你叫{name}，一个专业的翻译, 你需要将用户的问题翻译成英文', additional_kwargs={}, response_metadata={}), HumanMessage(content='{input}', additional_kwargs={}, response_metadata={})]
```
#### 类型5：MessagePromptTemplate列表类型

```python
from langchain_core.prompts import (
    HumanMessagePromptTemplate,
    SystemMessagePromptTemplate,
)
from rich import print

system_prompt = SystemMessagePromptTemplate.from_template("你是：{name}")
user_prompt = HumanMessagePromptTemplate.from_template("{input}")
chat_prompt_template = ChatPromptTemplate.from_messages([
    system_prompt,
    user_prompt,
])
result = chat_prompt_template.invoke({"name": "小智", "input": "你是谁"})
print(result)
response = model.invoke(result)
print(response.content)
```
#### 类型6：BaseChatPromptTemplate列表类型

```python
system_prompt = ChatPromptTemplate.from_messages(
    [("system", "你叫{name}, 你是一个专业的智能体助手")]
)
user_prompt = ChatPromptTemplate.from_messages([("human", "{input}")])

chat_prompt_template = ChatPromptTemplate.from_messages(
    [
        system_prompt,
        user_prompt,
    ]
)
result = chat_prompt_template.invoke({"name": "小智", "input": "你是谁"})
print(result)
response = model.invoke(result)
print(response.content)
```

### 高级使用

#### 部分变量的预填充

```python
from langchain_core.prompts import ChatPromptTemplate
from rich import print

template = ChatPromptTemplate.from_messages(
    [
        ("system", "你叫{name},你是一个专业的{work}, 你需要给客户提供专业的服务"),
        ("human", "{input}"),
    ]
)
partial_template = template.partial(name="小智", work="导游")
result1 = partial_template.invoke({"input":"给我介绍一下故宫"})
result2 = partial_template.invoke({"input":"给我介绍一下颐和园"})
print(result1)
print(result2)
```

#### 消息占位符 Placeholder

```python
template = ChatPromptTemplate.from_messages(
    [
        ("system", "你是一个AI助手"),
        ("placeholder", "{input}"),
    ]
)

prompt = template.invoke({
    "input":[
        ("user", "南京天天气怎么样？"),
        ("ai", "明天天气晴朗"),
        ("user", "后天天气怎么样？")
    ]
})
```

#### 消息占位符 MessagePlaceholder

```python
from langchain_core.prompts import MessagesPlaceholder

template = ChatPromptTemplate.from_messages(
    [
        ("system", "你是一个AI助手"),
        MessagesPlaceholder(variable_name="input"),
    ]
)

prompt = template.invoke({
    "input":[
        ("user", "南京天天气怎么样？"),
        ("ai", "明天天气晴朗"),
        ("user", "后天天气怎么样？")
    ]
})

print(prompt)
```

#### 可复用的模板库 templates.py

```python
from langchain_core.prompts import ChatPromptTemplate

class PromptLibrary:
    """可复用的提示词模板库"""

    TRANSLATOR = ChatPromptTemplate.from_messages([
        ("system", "你是专业翻译，精通{source_lang}和{target_lang}"),
        ("user", "翻译以下文本：\n{text}")
    ])

    CODE_REVIEWER = ChatPromptTemplate.from_messages([
        ("system", "你是{language}代码审查专家，重点关注{focus}"),
        ("user", "审查代码：\n```{language}\n{code}\n```")
    ])

    SUMMARIZER = ChatPromptTemplate.from_messages([
        ("system", "你是内容摘要专家"),
        ("user", "将以下内容总结为{num}个要点：\n{content}")
    ])

    TUTOR = ChatPromptTemplate.from_messages([
        ("system", "你是{subject}导师，学生水平：{level}"),
        ("user", "{question}")
    ])
```

## 参考信息

- [[2026-10-11-AI知识地图]] — 学习路径中的位置：知识地图「第五步：应用开发」
- [[2026-10-14-LangChain消息与对话历史]] — 配套机制：format_messages 的输出就是该篇消息模型的实例
