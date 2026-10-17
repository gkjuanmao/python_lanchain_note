---
tags: [python, 内置函数, 示例代码]
description: enumerate() 内置函数的语法、遍历示例、转列表/字典用法与常见场景，对比 range(len()) 写法。
---
# enumerate函数


`enumerate()` 是 Python 的内置函数，作用是：**在遍历一个可迭代对象时，同时拿到“索引”和“元素值”**。

## 基本语法

```python
enumerate(iterable, start=0)
```

- `iterable`：可迭代对象，比如列表、元组、字符串、字典、文件等
- `start`：索引从几开始，默认是 `0`
- 返回一个 `enumerate` 对象，每次迭代产生一个 `(索引, 元素)` 元组

## 例子

```python
fruits = ["apple", "banana", "cherry"]

for index, fruit in enumerate(fruits):
    print(index, fruit)
```

输出：

```text
0 apple
1 banana
2 cherry
```

如果想从 `1` 开始编号：

```python
for index, fruit in enumerate(fruits, start=1):
    print(index, fruit)
```

输出：

```text
1 apple
2 banana
3 cherry
```

## 转成列表或字典

```python
list(enumerate(["a", "b"]))
# [(0, 'a'), (1, 'b')]

dict(enumerate(["a", "b"]))
# {0: 'a', 1: 'b'}
```

## 它相当于什么？

以前可能会这样写：

```python
fruits = ["apple", "banana", "cherry"]

for i in range(len(fruits)):
    print(i, fruits[i])
```

用 `enumerate()` 可以更简洁、更 Pythonic：

```python
for i, fruit in enumerate(fruits):
    print(i, fruit)
```

## 常见用途

- 遍历列表时同时需要下标和值
- 给文件行加行号
- 构建 `{索引: 值}` 形式的字典
- 查找元素位置时更方便

## 注意

如果只需要元素值，不需要索引，直接写：

```python
for fruit in fruits:
    print(fruit)
```

如果既需要索引又需要值，就用：

```python
for index, fruit in enumerate(fruits):
    print(index, fruit)
```

一句话总结：**`enumerate()` 用来在循环中同时获得索引和元素，避免手动维护计数器或使用 `range(len(...))`。**

## 参考信息

- [[2026-10-17-Python知识地图]] — 学习路径中的位置：知识地图「第三步：常用工具」
