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

```dart
import 'package:large_xml/large_xml.dart';

var doc = XmlDocument.fromString(xmlstr);
var root = XmlDocument.root;
```

### Finding Node

now we have a `root` node referece object



```dart
var root = XmlDocument.root;

```

