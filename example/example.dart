import 'package:large_xml/large_xml.dart';

var xmlstr = """
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<!DOCTYPE root>
<root 
  xmlns:r="http://schemas.openxmlformats.org/package/2006/relationships"
  xmlns:x="http://schemas.openxmlformats.org/package/2006/x"
>
    <!-- comment here -->
    <person age="1" r:id="2" x:id="3" />
    <!-- comment here -->
    <x:script>
      <![CDATA[function matchwo(a,b){if (a < b && a < 0) then{return 1;}else{return 0;}}]]>
    </x:script>
    <info>
      <child x:name="child name">&lt;n k=&quot;v&quot; t=&apos;v&apos;/&gt;</child>
    </info>
</root>
""";

void main() {
  var doc = XmlDocument.fromString(xmlstr);

  var person = doc.root.into(type: XmlElementType.start)?.mount();
  var info = doc.root
      .into(selector: (n) => n.type == XmlElementType.start && n.name == "info")
      ?.mount();
  var script = person?.next(type: XmlElementType.start)?.mount();
  var comment = person?.next()?.mount();
  var child = info?.into(type: XmlElementType.start)?.mount();
  var root = child?.findAncestor(
      selector: (n) => n.type == XmlElementType.start && n.name == "root");
  root!.name == "name";

  var attributes = person?.getAttributes();
  attributes!.length == 3;
  var rid = person?.getAttribute("r:id");
  rid == "2";
  var age = person?.getAttribute("age");
  age == "3";
  rid = person?.getAttribute(":id");

  var ridNode = person?.getAttributeNode("r:id");
  var xmlnsr = ridNode?.namespace;
  xmlnsr!.value ==
      "http://schemas.openxmlformats.org/package/2006/relationships";
  var ridKey = ridNode?.key;
  ridKey == "r:id";
  var ridValue = ridNode?.value;
  ridValue == "2";
  ridNode?.setAttribute("new value").remove();

  ridNode = person?.addAttribute("r:id", "new rid");
  ridNode?.remove();

  var newNode = XmlNode.create("new");
  newNode.pasteBefore(person!);
  newNode.pasteAfter(person);
  newNode.pasteInner(person);

  var infoCopy = info?.copy();
  infoCopy?.pasteInner(person);

  person.remove();

  var decoded = child!.value.decode();
  decoded == "<n k=\"v\" t='v'/>";

  person.unmount();
  info?.unmount();
  script?.unmount();
  comment?.unmount();
  child.unmount();
}
