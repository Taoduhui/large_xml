# large_xml

a pure dart library for reading, writing large xml

## Usage

### Sample XML

all example code will use this xml string

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

### Getting Started 

first, you need create a XmlDocument Object

this object holding your xml string and dynamicly update mounted `XmlNode`

then, you can access Xml's root xml node

**NOTICE**: if you want to cache the xml node

you **MUST** invoke `node.mount()`, mount the node to `XmlDocument`

so that `XmlDocument` can dynamicly update this `XmlNode`'s pointer when the XML raw string changing.

you should invoke `node.unmount()` when the node is unnecessary

```dart
import 'package:large_xml/large_xml.dart';

var doc = XmlDocument.fromString(xmlstr);
var root = XmlDocument.root;
```

### Finding Node

now we have a `root` node referece object

if you want to get the child node referece, you can invoke `node.into()`

```dart
var root = XmlDocument.root;

// find first normal start element in root chilren
// return <person/> node
var person = doc.root.into(type: XmlElementType.start);
if(person == null){
  print("node not found");
}

// find first normal start element in root chilren and node name is "info"
// return <info/> node
var info = doc.root.into(selector: (n)=>n.type == XmlElementType.start && n.name == "info");
if(info == null){
  print("node not found");
}
```

if you want to get the parallel node referece, you can invoke `node.next()`

```dart
var root = XmlDocument.root;
var person = doc.root.into(type: XmlElementType.start)!;

// find first normal start element after person node
// return <x:script/> node
var script = person.next(type: XmlElementType.start);
if(script == null){
  print("node not found");
}

// find first normal start element in root chilren and node name is "info"
// return <info/> node
var info = doc.root.next(selector: (n)=>n.type == XmlElementType.start && n.name == "info");
if(info == null){
  print("node not found");
}

// find first normal start element after person node and node name is "script", ignore namespace
// return <x:script/> node
script = doc.root.next(selector: (n)=>n.type == XmlElementType.start && n.name.removeNamespace() == "script");
if(script == null){
  print("node not found");
}

// find first normal start element after person node and namespace is "x"
// return <x:script/> node
script = doc.root.next(selector: (n)=>n.type == XmlElementType.start && n.name.namespace() == "x");
if(script == null){
  print("node not found");
}

// find first normal start element after person node and specified whole match "x:script"
// return <x:script/> node
script = doc.root.next(selector: (n)=>n.type == XmlElementType.start && n.name == "x:script");
if(script == null){
  print("node not found");
}
```

if you want to get the ancestor node referece, you can invoke `node.findAncestor()`

like `into()` and `next()`, it also support `type` and `selector`

and you can easily get node's parent node by `node.parent`

### Node Attribute

you can use following method to access node's attribute

- `node.containsAttribute`
- `node.getAttribute`
- `node.getAttributes`
- `node.getAttributeNode`
- `node.addAttribute`

directly get attribute's value like this

```dart
var root = XmlDocument.root;
var person = doc.root.into(type: XmlElementType.start)!;

// directly get attribute's value
// getAttribute(key) you can pass specified or unspecified namespace attribute key,such as "id" or "x:id" or ":id"
// if you pass key like ":id", it will try to find a attribute which named 'id' and has a namespace
String? id = person.getAttribute(":id");
if(id != null){
  // should be attribute r:id
  print(id);
}
```

if you want to update attribute, use `node.getAttributeNode`, you will get a `XmlAttribute` object

**NOTICE**: `XmlAttribute` should not be cached
it should be dropped immediately
after any writing operation, all `XmlAttribute` will point at wrong position

if you make sure that there will be no write action while holding this object, then you can keep it.

*tips*：`attr.setAttribute` will update it self, you can still keep it after `setAttribute`

some method support chain invoke, you can keep the object in a chain
otherwise you should re-find it by `node.getAttributeNode`.

```dart
var root = XmlDocument.root;
var person = doc.root.into(type: XmlElementType.start)!;

XmlAttribute id = person.getAttributeNode(":id")!;
print(id.key); // x:id

// id.namepace should be http://schemas.openxmlformats.org/package/2006/relationships
// it will lookup it ancestors and find first matched "xmlns:r" definition
print(id.namespace);

print(value); // 2

id.setAttribute("new value");
print(value); // new value

id.remove();

person.addAttribute("nattr")!;
print(person.containsAttribute("nattr")); // true

// you can get attributes map like this
Map<String,String> attrs = person.getAttributes();
```

### Node Cache

if you want to holding a node

this is a correct usage example

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

wrong usage

```dart
//root is defaultly mounted
var root = XmlDocument.root;

var person = doc.root
  .into(type: XmlElementType.start)!
  .mount(); // mounted
var info = doc.root
  .next(selector: (n)=>n.type == XmlElementType.start && n.name == "info")!; // unmounted

person.addAttribute("nattr");
// after person node write action
// info node still keep the origin pointer, so it will write the attribute on wrong position
info.addAttribute("nattr");

person.unmount();// release

return;
```

### Node Write

you can use following method to add, remove, and copy a node

- `XmlNode.create`
- `node.remove`
- `node.copy`

and all writing action is depending on `XmlNodeInstance` object

it has following method:

- `inst.pasteBefore`
- `inst.pasteAfter`
- `inst.pasteInner`

here is a example about how to create a new node
```dart
var root = XmlDocument.root;
var person = doc.root
  .into(type: XmlElementType.start)!
  .mount();

XmlNodeInstance inst = XmlNode.create("new");
var newNode = inst.pasteBefore(person).mount();
// xml will be changed like this
// <root>
//    <new/> <-- new node will be add before person node
//    <person/>
//    ...
// </root>
```

you can copy a node to a `XmlNodeInstance` object

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
// xml will be changed like this
// <root>
//    <person>
//      <info> <-- copy to here
//        <child/>
//      </info>
//    </person>
//    ...
// </root>
```