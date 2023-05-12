# large_xml

一个用于解析、更新大型XML的纯dart库

## 使用

### XML示例

接下来的实例代码中都将使用这段XML作为演示

```xml
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<!DOCTYPE root>
<root 
  xmlns:r="http://schemas.openxmlformats.org/package/2006/relationships"
  xmlns:x="http://schemas.openxmlformats.org/package/2006/x"
>
    <!-- comment here -->
    <person age="1" r:id="2" x:id="3" ></person>
    <!-- comment here -->
    <x:script>
      <![CDATA[function matchwo(a,b){if (a < b && a < 0) then{return 1;}else{return 0;}}]]>
    </x:script>
    <info>
      <child x:name="child name"/>
    </info>
</root>
```

### 开始使用

首先需要创建一个`XmlDocument`对象

这个对象持有你的XML字符串并动态更新挂载的`XmlNode`

创建完毕后，你可以通过`root`属性获取到根节点

**注意**: 如果你希望缓存一个`XmlNode`以便长期使用

你**必须**要调用`node.mount()`，将这个节点挂载到`XmlDocument`上

这样`XmlDocument`才能在文档变更时对节点进行更新

当你不再使用时，应当调用`node.unmount()`以释放资源

```dart
import 'package:large_xml/large_xml.dart';

var doc = XmlDocument.fromString(xmlstr);
var root = XmlDocument.root;
```

### 搜索Node

现在我们有了一个`root`节点

你可以通过`node.into()`来获得子节点的引用

```dart
var root = XmlDocument.root;

// 找到第一个元素类型是start的子节点
// 此处返回 <person/> 节点
var person = doc.root.into(type: XmlElementType.start);
if(person == null){
  print("node not found");
}

// 找到第一个元素类型是start且节点名是info的子节点
// 此处返回  <info/> 节点
var info = doc.root.into(selector: (n)=>n.type == XmlElementType.start && n.name == "info");
if(info == null){
  print("node not found");
}
```

你可以使用`node.next()`获取平行节点的下一个节点

```dart
var root = XmlDocument.root;
var person = doc.root.into(type: XmlElementType.start)!;

// 找到person节点后第一个元素类型是start的节点
// 此处返回 <x:script/> 节点
var script = person.next(type: XmlElementType.start);
if(script == null){
  print("node not found");
}

// 找到person节点后第一个元素类型是start且节点名是info的节点
// 此处返回 <info/> 节点
var info = doc.root.next(selector: (n)=>n.type == XmlElementType.start && n.name == "info");
if(info == null){
  print("node not found");
}

// 找到person节点后第一个元素类型是start，忽略命名空间节点名是script的节点
// 此处返回 <x:script/> 节点
script = doc.root.next(selector: (n)=>n.type == XmlElementType.start && n.name.removeNamespace() == "script");
if(script == null){
  print("node not found");
}

// 找到person节点后第一个元素类型是start，命名空间是x的节点
// 此处返回 <x:script/> 节点
script = doc.root.next(selector: (n)=>n.type == XmlElementType.start && n.name.namespace() == "x");
if(script == null){
  print("node not found");
}

// 找到person节点后第一个元素类型是start，名称完全匹配x:script的节点
// 此处返回 <x:script/> 节点
script = doc.root.next(selector: (n)=>n.type == XmlElementType.start && n.name == "x:script");
if(script == null){
  print("node not found");
}
```

你可以通过`node.findAncestor()`搜索祖先节点

与`into()`和`next()`类似，`node.findAncestor()`同样支持`type` 和 `selector`

你可以通过 `node.parent`来获取当前节点的父节点

### 节点属性

你可以通过以下方法访问属性

- `node.containsAttribute`
- `node.getAttribute`
- `node.getAttributes`
- `node.getAttributeNode`
- `node.addAttribute`

直接获取属性值

```dart
var root = XmlDocument.root;
var person = doc.root.into(type: XmlElementType.start)!;

// 直接获取属性值
// 参数支持以下形式
// "id" "x:id" ":id" "*id"
// - "id" 无命名空间的id属性
// - "x:id" 命名空间为x的id属性
// - ":id" 有命名空间的id属性
// - "*id" id属性，无论是否有命名空间
String? id = person.getAttribute(":id");
if(id != null){
  // 此处为 r:id
  print(id);
}
```

如果您想更新属性，请使用`node.getAttributeNode`，它将返回一个`XmlAttribute`对象。

**注意**：`XmlAttribute`不应该被缓存，应该立即删除，
在任何写入操作后，所有的`XmlAttribute`对象都将指向错误的位置

如果您确定在持有该对象期间不会执行任何写入操作，则可以保留它。

提示：`attr.setAttribute`会自行更新，您可以在`setAttribute`之后保留它。

一些方法支持链式调用，您可以在链式调用中保留该对象，
否则您需要通过`node.getAttributeNode`重新查找它。


```dart
var root = XmlDocument.root;
var person = doc.root.into(type: XmlElementType.start)!;

XmlAttribute id = person.getAttributeNode(":id")!;
print(id.key); // x:id

// id.namespace应该是http://schemas.openxmlformats.org/package/2006/relationships
// 它将查找它的祖先节点并找到第一个匹配的“xmlns:r”定义
print(id.namespace);

print(value); // 2

id.setAttribute("new value");
print(value); // new value

id.remove();

person.addAttribute("nattr")!;
print(person.containsAttribute("nattr")); // true

// 你可以像这样获取一个属性map
Map<String,String> attrs = person.getAttributes();
```

### Node缓存

如果你打算缓存一个节点

以下是正确的使用方法

```dart
//root is defaultly mounted
var root = XmlDocument.root;

var person = doc.root
  .into(type: XmlElementType.start)!
  .mount(); // mounted
var info = doc.root
  .next(selector: (n)=>n.type == XmlElementType.start && n.name == "info")!
  .mount(); // mounted

person.addAttribute("nattr");
info.addAttribute("nattr");

person.unmount();// release
info.unmount();// release

return;
```

错误的使用方法

```dart
//root is defaultly mounted
var root = XmlDocument.root;

var person = doc.root
  .into(type: XmlElementType.start)!
  .mount(); // mounted
var info = doc.root
  .next(selector: (n)=>n.type == XmlElementType.start && n.name == "info")!; // unmounted

person.addAttribute("nattr");
// 在person节点写入操作后，
// info节点仍然保留原始指针，所以这里会在错误的位置写入属性
info.addAttribute("nattr");

person.unmount();// release

return;
```

### Node写入

您可以使用以下方法来添加、删除和复制节点：

- `XmlNode.create`
- `node.remove`
- `node.copy`

所有的写入操作都依赖于`XmlNodeInstance`对象

它拥有以下方法：

- `inst.pasteBefore`
- `inst.pasteAfter`
- `inst.pasteInner`

下面是一个关于如何创建一个新节点的示例：
```dart
var root = XmlDocument.root;
var person = doc.root
  .into(type: XmlElementType.start)!
  .mount();

XmlNodeInstance inst = XmlNode.create("new");
var newNode = inst.pasteBefore(person).mount();
// xml将会被改成像下面的样子
// <root>
//    <new/> <-- new节点会被添加到person节点前
//    <person/>
//    ...
// </root>
```

您可以将节点复制到一个`XmlNodeInstance`对象中。

```dart
var root = XmlDocument.root;
var person = doc.root
  .into(type: XmlElementType.start)!
  .mount();
var info = doc.root
  .next(selector: (n)=>n.type == XmlElementType.start && n.name == "info")!
  .mount();

XmlNodeInstance copy = info.copy();
var newNode = inst.pasteInner(person).mount();
//  xml将会被改成像下面的样子
// <root>
//    <person>
//      <info> <-- 节点被复制到此处
//        <child/>
//      </info>
//    </person>
//    ...
// </root>
```