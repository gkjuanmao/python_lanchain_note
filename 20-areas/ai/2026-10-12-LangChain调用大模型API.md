---
tags: [langchain, python, api]
description: LangChain 1.X 统一调用 LLM API 的完整方法，含 init_chat_model 配置、invoke/stream/batch 同步与异步调用、消息列表、短期记忆、返回结构与 config 参数。
---
# LangChain调用大模型API


## 以GLM大模型为例调用API

```python
import os

import dotenv
from langchain.chat_models import init_chat_model

dotenv.load_dotenv(override=True)

def langchain_chat(messages):
    model = init_chat_model(
        model="glm-4.7-flash",
        model_provider="openai",
        api_key=os.environ.get("GLM_API_KEY"),
        base_url=os.environ.get("GLM_API_BASE"),
        temperature=0.7,
        max_tokens=65536,
    )
    response = model.invoke(messages)
    return response.content


if __name__ == "__main__":
    messages = [
        {"role": "system", "content": "你是一个有用的助手，你可以回答用户的问题"},
        {"role": "user", "content": "请用一句话介绍你自己"},
    ]
    # print(deepseek_chat(messages))
    # print(glm_chat(messages))
    print(langchain_chat(messages))

```

DeepSeek官网的DeepSeek模型：ChatDeepSeek()、ChatOpenAI()、init_chat_model()
阿里云百炼平台的DeepSeek模型：ChatTongyi()、ChatOpenAI()、init_chat_model()
OpenRouter平台的DeepSeek模型：ChatOpenRouter()、CharOpenAI()、init_chat_model()
CloseAI平台的DeepSeek模型：CharOpenAI()、init_chat_model()

## 模型初始化参数

参见LangChain教程：[模型 - LangChain 文档 - LangChain 教程](https://docs.langchain.org.cn/oss/python/langchain/models#parameters)

temperature 参数根据使用场景选择：
+ 0.0-0.3：需要一致性、准确性的任务（数学计算、数据提取、分类、代码生成）
+ 0.5-0.7：平衡创造性和一致性（聊天、问答）
+ 0.8-1.5：创造性任务（写作、头脑风暴）
+ 1.5-2.0：高度创造性（诗歌、故事创作）

## invoke()同步调用函数的使用

### 1. 文本输入

```python
message = "翻译如下文字:你好世界"
def langchain_invoke(model, messages):# message:翻译如下文字:你好世界
    llm = init_chat_model(
        model=model,
        model_provider="openai",
        api_key=os.environ.get("GLM_API_KEY"),
        base_url=os.environ.get("GLM_API_BASE"),
        temperature=0.7,
        max_tokens=65536,
    )
    response = llm.invoke(messages)
    print(response.content)
```

### 2. 字典列表

```python
def langchain_invoke(model, messages):
	"""
	messages = [
        {"role": "system", "content": "你是一个有用的助手，你可以回答用户的问题"},
        {"role": "user", "content": "翻译如下文字：你好世界"},
    ]
	"""
    llm = init_chat_model(
        model=model,
        model_provider="openai",
        api_key=os.environ.get("GLM_API_KEY"),
        base_url=os.environ.get("GLM_API_BASE"),
        temperature=0.7,
        max_tokens=65536,
    )
    response = llm.invoke(messages)
    print(response.content)
```

### 3. 消息列表

```python
def langchain_invoke(messages):
    llm = init_chat_model(
        model="deepseek-flash",
        model_provider="openai",
        api_key=os.environ.get("DEEPSEEK_API_KEY"),
        base_url=os.environ.get("DEEPSEEK_API_BASE"),
        temperature=0.7,
        max_tokens=65536,
    )
    response1 = llm.invoke(messages)
    print(response1.content)
    messages.append(SystemMessage(content=response1.content))
    messages.append(HumanMessage(content="我是谁?"))
    response2 = llm.invoke(messages)
    print(response2.content)


if __name__ == "__main__":
    messages = [
        SystemMessage(content="你是一个专业的大模型"),
        HumanMessage(content="我叫小明"),
    ]
    langchain_invoke(messages)
```

消息列表中包含：
+ SystemMesage：对应role=system
+ HumanMessage：对应role=user
+ AIMessage：对应role=assistant

### 多轮对话(短期记忆)

```python
	messages = [
        {"role": "system", "content": "你是一个专业的数学老师"},
        {"role": "user", "content": "1 + 2 = ?"},
        {"role": "assistant", "content": "3"},
        {"role": "user", "content": "我刚才问了什么问题?"},
    ]
```

在LangChain中，可以在后面轮次的对话中，将大模型回答塞进旧的messages，然后再添加指令，这样就实现了短期记忆，大模型可以记住之前的问答

```python
def langchain_invoke(messages):
    llm = init_chat_model(
        model="deepseek-flash",
        model_provider="openai",
        api_key=os.environ.get("DEEPSEEK_API_KEY"),
        base_url=os.environ.get("DEEPSEEK_API_BASE"),
        temperature=0.7,
        max_tokens=65536,
    )
    response1 = llm.invoke(messages)
    print(response1.content)
    messages.append({"role": "assistant", "content": response1.content})
    messages.append({"role": "user", "content": "我是谁?"})
    response2 = llm.invoke(messages)
    print(response2.content)
    
if __name__ == "__main__":
    messages = [
        {"role": "system", "content": "你是一个专业的大模型"},
        {"role": "user", "content": "我叫小明"},
    ]
    langchain_invoke(messages)
"""
output:
你好，小明！很高兴认识你 😊 有什么我可以帮你的吗？
你是小明呀！你刚刚告诉我你叫小明 😊
"""
```


### invoke()返回的信息

```js
AIMessage(
    content='4',                                              # 模型生成的核心文本内容
    additional_kwargs={'refusal': None},                      # 模型拒绝回答的情况，比如触碰安全策略，None表示正常回答
    response_metadata={                                       # 响应的元数据
        'token_usage': {                                      # Token消耗统计
            'completion_tokens': 29,                          # 生成内容消耗的Token数
            'prompt_tokens': 36,                              # 输入提示消耗的Token数
            'total_tokens': 65,                               # 总消耗的Token数
            'completion_tokens_details': {                    # 生成Token的明细
                'accepted_prediction_tokens': None,           # 被接受的预测Token数（通常用于投机解码）
                'audio_tokens': None,                         # 音频Token数（多模态场景）
                'reasoning_tokens': 27,                       # 推理过程消耗的Token数
                'rejected_prediction_tokens': None            # 被拒绝的预测Token数
            },
            'prompt_tokens_details': {                        # 输入Token的明细
                'audio_tokens': None,                         # 音频输入Token数
                'cache_write_tokens': None,                   # 写入缓存的Token数
                'cached_tokens': 0                            # 命中的缓存Token数
            },
            'prompt_cache_hit_tokens': 0,                     # 输入Token缓存命中的数量
            'prompt_cache_miss_tokens': 36                    # 输入Token缓存未命中的数量
        },
        'model_provider': 'openai',                           # 模型提供方（此处走OpenAI兼容接口）
        'model_name': 'deepseek-flash',                       # 实际调用的模型名称
        'system_fingerprint': 'aeb56401ca74e127821c4f9126dcb669', # 模型后端配置指纹，用于追踪版本变化
        'id': 'b12b5d4d-4c14-4100-b475-cba40d62414a',         # 本次API调用的唯一标识
        'finish_reason': 'stop',                              # 生成结束原因，stop表示自然结束，length表示达到最大长度
        'logprobs': None                                      # 返回的对数概率信息（此处未启用）
    },
    id='lc_run--01a12ffa-1717-71c2-9508-70a0d35f23ee-0',      # LangChain内部运行追踪ID
    tool_calls=[],                                            # 正常触发的外部工具调用列表
    invalid_tool_calls=[],                                    # 触发失败或格式错误的工具调用
    usage_metadata={                                          # LangChain统一封装的Token消耗元数据
        'input_tokens': 36,                                   # 输入的Token总数
        'output_tokens': 29,                                  # 输出的Token总数
        'total_tokens': 65,                                   # 总Token数
        'input_token_details': {                              # 输入Token的明细
            'cache_read': 0                                   # 从缓存中读取的Token数
        },
        'output_token_details': {                             # 输出Token的明细
            'reasoning': 27                                   # 推理过程消耗的Token数
        }
    }
)
```

## stream()流式调用

```python
import os

import dotenv
from langchain.chat_models import init_chat_model

dotenv.load_dotenv(override=True)

messages = [
    {"role": "system", "content": "你是一个专业的数学助手"},
    {"role": "user", "content": "给我解释一下斐波那契数列是什么"},
]

llm = init_chat_model(
    model="deepseek-flash",
    model_provider="openai",
    api_key=os.environ.get("DEEPSEEK_API_KEY"),
    base_url=os.environ.get("DEEPSEEK_API_BASE"),
    temperature=0.7,
    max_tokens=65536,
    stream=True,
    extra_body={"thinking": {"type": "disabled"}}
)
for chunk in llm.stream(messages):
    if chunk.content:
        print(chunk.content, end="", flush=True)
print()

```

> 注：如果直接使用stream()函数给大模型传入指令，则给大模型的参数中可以不指定stream=true，框架会自己处理

## batch()批量调用

batch()方法允许你一次性发送一组请求（含多条独立请求），模型会在后台并行处理，然后返回所有结果的列表。
与逐个顺序调用（invoke）相比，能大幅减少网络往返开销和等待时间，显著提升性能、降低成本。
适用场景：文档摘要、批量问答、数据预处理、多样本分类等。

### 一次性接收所有响应

```python
import os

import dotenv
from langchain.chat_models import init_chat_model

dotenv.load_dotenv(override=True)

messages1 = [
    {"role": "system", "content": "你是一个专业的数学助手"},
    {"role": "user", "content": "给我解释一下斐波那契数列是什么"},
]
messages2 = [
    {"role": "system", "content": "你是一个专业的物理助手"},
    {"role": "user", "content": "给我解释一下光速是什么"},
]
llm = init_chat_model(
    model="deepseek-flash",
    model_provider="openai",
    api_key=os.environ.get("DEEPSEEK_API_KEY"),
    base_url=os.environ.get("DEEPSEEK_API_BASE"),
    temperature=0.7,
    max_tokens=65536,
    # model_kwargs={"stream": True},
    extra_body={"thinking": {"type": "disabled"}}
)

response = llm.batch([messages1, messages2])
for i in response:
    print(i.content)

```

### 按照完成的顺序接收响应

```python
messages = [
    "你好，你是谁",
    " 2 + 3 * 5 等于几?",
    "中国首都在哪里？"
]
response = llm.batch_as_completed(messages)
for i in response:
    print(i[1].content)

```

## 异步调用

### ainvoke()

```python
import asyncio
import os
import time

import dotenv
from langchain.chat_models import init_chat_model

dotenv.load_dotenv(override=True)

llm = init_chat_model(
    model="deepseek-flash",
    model_provider="openai",
    api_key=os.environ.get("DEEPSEEK_API_KEY"),
    base_url=os.environ.get("DEEPSEEK_API_BASE"),
)


async def ainvoke_example():
    start_time = time.perf_counter()

    print("程序开始")

    # 1.创建任务
    print(">>> 发起异步模型调用(ainvoke)...")

    async_task = asyncio.create_task(llm.ainvoke("用一句话解释人工智能"))

    # 2. 并行执行其他任务
    print(">>> 模型请求已在后台发送，继续执行本地逻辑...")
    for i in range(3):
        await asyncio.sleep(1)
        print(
            f">>> 正在执行第{i + 1}个任务... (已耗时 {time.perf_counter() - start_time:.2f} 秒)"
        )

    # 3. 获取模型结果
    print(">>> 本地任务完成，检查模型状态...")
    response = await async_task
    end_time = time.perf_counter()
    print(f">>> 模型响应: {response.content}")
    print(f">>> 总耗时: {end_time - start_time:.2f} 秒")


async def main():
    await ainvoke_example()


if __name__ == "__main__":
    asyncio.run(main())
"""
output:
程序开始
>>> 发起异步模型调用(ainvoke)...
>>> 模型请求已在后台发送，继续执行本地逻辑...
>>> 正在执行第1个任务... (已耗时 1.02 秒)
>>> 正在执行第2个任务... (已耗时 2.03 秒)
>>> 正在执行第3个任务... (已耗时 3.04 秒)
>>> 本地任务完成，检查模型状态...
>>> 模型响应: 人工智能是让机器模拟人类智能（如学习、推理、感知和决策）以完成通常需要人类智慧的任务的技术。
>>> 总耗时: 3.04 秒
"""
```

可以看到在执行ainvoke的时候，还有另外三个任务依次执行，但是最后所有任务结束的时间依然是3.04秒，说明在其他任务执行的时候，大模型的调用也在同步执行

### astream()

```python
import asyncio
import os
import time

import dotenv
from langchain.chat_models import init_chat_model

dotenv.load_dotenv(override=True)

llm = init_chat_model(
    model="deepseek-flash",
    model_provider="openai",
    api_key=os.environ.get("DEEPSEEK_API_KEY"),
    base_url=os.environ.get("DEEPSEEK_API_BASE"),
)


async def astream_parallel_example():
    start_time = time.perf_counter()
    print("程序开始")

    async def consume_stream():
        collected = []
        async for chunk in llm.astream("用一句话解释人工智能"):
            if chunk.content:
                print(f"[流] {chunk.content}", end="", flush=True)
                collected.append(chunk.content)
        print()
        return "".join(collected)

    # 把“消费流”放到后台任务
    stream_task = asyncio.create_task(consume_stream())

    print(">>> 模型流已在后台消费，继续执行本地逻辑...")
    for i in range(3):
        await asyncio.sleep(1)
        print(
            f">>> 正在执行第{i + 1}个任务... (已耗时 {time.perf_counter() - start_time:.2f} 秒)"
        )

    print(">>> 本地任务完成，等待流式结束...")
    full_text = await stream_task
    end_time = time.perf_counter()
    print(f">>> 完整响应: {full_text}")
    print(f">>> 总耗时: {end_time - start_time:.2f} 秒")


async def main():
    await astream_parallel_example()


if __name__ == "__main__":
    asyncio.run(main())

```
### abatch()

```python
import asyncio
import os
import time

import dotenv
from langchain.chat_models import init_chat_model

dotenv.load_dotenv(override=True)

llm = init_chat_model(
    model="deepseek-flash",
    model_provider="openai",
    api_key=os.environ.get("DEEPSEEK_API_KEY"),
    base_url=os.environ.get("DEEPSEEK_API_BASE"),
)


async def abatch_example():
    start_time = time.perf_counter()

    print("程序开始")

    messages = [
        "你好，你是谁",
        "2 + 3 * 5 等于几?",
        "中国首都在哪里？",
    ]

    print(">>> 发起批量异步模型调用(abatch)...")

    # abatch 本身是协程，可以 create_task 放到后台
    batch_task = asyncio.create_task(llm.abatch(messages))

    print(">>> 批量请求已在后台发送，继续执行本地逻辑...")
    for i in range(3):
        await asyncio.sleep(1)
        print(
            f">>> 正在执行第{i + 1}个任务... (已耗时 {time.perf_counter() - start_time:.2f} 秒)"
        )

    print(">>> 本地任务完成，检查批量任务状态...")
    responses = await batch_task

    end_time = time.perf_counter()
    for idx, resp in enumerate(responses):
        print(f">>> 第{idx + 1}个响应: {resp.content}")
    print(f">>> 总耗时: {end_time - start_time:.2f} 秒")


async def main():
    await abatch_example()


if __name__ == "__main__":
    asyncio.run(main())

```

## 模型配置信息profile

LangChain1.1及更高版本可以通过profile属性查看模型的配置信息。
该方法依赖模型厂商是否提供模型画像

```python
from dotenv import load_dotenv
from langchain_deepseek import ChatDeepSeek

#从.env文件中加载环境变量
load_dotenv(override=True)
model = ChatDeepSeek(
    model="deepseek-flash",
    temperature=0.7,
    max_tokens=1000,
    max_retries=6
)
print(model.profile)
```


## 模型初始化参数

### model_kwargs

有些大模型API支持的参数，LangChain不支持，此时可以通过model_kwargs参数透传给大模型API

### extra_body

这里用于存放模型厂商基于OpenAI API协议扩展的字段。

```python
deepseek_llm.invoke(
    "你好",
    config={
        "run_name": "...",          # 在LangSmith中这次运行会显示为指定名称
        "tags": ["test", "development"], # 打上标签便于分类查找
        "metadata": {"user_id": "123"}, # 记录用户ID
        "callbacks": [custom_handler],  # 启用自定义回调函数
        "configurable": {
            "model": "deepseek-reasoner", # 配置模型参数
            "temperature": 0.7,           # 配置温度参数
            "max_tokens": 100             # 配置最大令牌数
        }
    }
)
```

## 调用大模型方法的config参数

在调用invoke，stream，batch时，我们可以传入config参数
config参数**允许在调用模型时，动态的配置和控制模型的行为**，而无需再初始化时就固定所有参数，这为应用带来了极大的灵活性和可维护性
**需要先在init_chat_model中配置configurable，config参数才生效**


## 参考信息

- [[2026-10-11-LangChain框架]] — 框架概览：本篇是框架的具体 API 调用实践，四大家族中 LangChain 部分的 init_chat_model 等核心接口。
- [[2026-10-11-提示词工程#模型参数与消息角色]] — 概念对应：temperature 分档、system/user/assistant 消息角色在本篇以代码形式落地。
- [[2026-10-11-提示词工程#链式思考（CoT）提示]] — 下游应用：多轮对话短期记忆正是链式提示的基础机制。