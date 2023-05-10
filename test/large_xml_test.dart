import 'package:flutter_test/flutter_test.dart';

import 'package:large_xml/large_xml.dart';

var xmlstr = """
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<!DOCTYPE root>
<root 
  xmlns:r="http://schemas.openxmlformats.org/package/2006/relationships"
  xmlns:x="http://schemas.openxmlformats.org/package/2006/x"
>
    <!-- comment here -->
    <person age="1" r:id="2" x:id="3"/>
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
  test('XmlDocument Init Test', () {
    var doc = XmlDocument.fromString(xmlstr);

    expect(doc.root.type, XmlElementType.start);
    expect(doc.root.name, "root");
  });

  test('XmlNode misc', () {
    var doc = XmlDocument.fromString(xmlstr);
    var pi = doc.firstElement!;
    expect(pi.type, XmlElementType.pi);
    expect(pi.outerXML.trim(),
        '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>');
    var dtd = pi.next()!;
    expect(dtd.type, XmlElementType.dtd);
    expect(dtd.outerXML.trim(), '<!DOCTYPE root>');
    var child = doc.root
        .into(
            selector: (n) =>
                n.type == XmlElementType.start && n.name == "info")!
        .into(type: XmlElementType.start)!;
    expect(child.value.trim(), "<n k=\"v\" t='v'/>");
  });

  test('XmlNode inner', () {
    var doc = XmlDocument.fromString(xmlstr);

    var person = doc.root.into(type: XmlElementType.start);
    expect(person != null, isTrue);
    expect(person!.type, XmlElementType.start);
    expect(person.name, "person");

    var info = doc.root.into(
        selector: (n) => n.type == XmlElementType.start && n.name == "info");
    expect(info != null, isTrue);
    expect(info!.type, XmlElementType.start);
    expect(info.name, "info");
    expect(info.innerXML.trim(),
        '<child x:name="child name">&lt;n k=&quot;v&quot; t=&apos;v&apos;/&gt;</child>');
  });

  test('XmlNode parallel', () {
    var doc = XmlDocument.fromString(xmlstr);

    var person = doc.root.into(type: XmlElementType.start)!;
    var script = person.next(type: XmlElementType.start);
    expect(script != null, isTrue);
    expect(script!.type, XmlElementType.start);
    expect(script.name, "x:script");

    var comment = person.next();
    expect(comment != null, isTrue);
    expect(comment!.type, XmlElementType.comment);
  });

  test('XmlNode ancestor', () {
    var doc = XmlDocument.fromString(xmlstr);

    var person = doc.root.into(type: XmlElementType.start)!;
    var info = doc.root.into(
        selector: (n) => n.type == XmlElementType.start && n.name == "info")!;

    var root = person.parent;
    expect(root != null, isTrue);
    expect(root!.type, XmlElementType.start);
    expect(root.name, "root");

    var child = info.into(type: XmlElementType.start)!;
    root = child.findAncestor(
        selector: (n) => n.type == XmlElementType.start && n.name == "root");
    expect(root != null, isTrue);
    expect(root!.type, XmlElementType.start);
    expect(root.name, "root");
  });

  test('XmlNode attributes', () {
    var doc = XmlDocument.fromString(xmlstr);

    var person = doc.root.into(type: XmlElementType.start)!;
    var attributes = person.getAttributes();
    expect(attributes.length, 3);
    expect(attributes["age"], "1");
    expect(attributes["r:id"], "2");
    expect(attributes["x:id"], "3");
    expect(person.containsAttribute("age"), isTrue);
    expect(person.containsAttribute("r:id"), isTrue);
    expect(person.containsAttribute("x:id"), isTrue);
    expect(person.containsAttribute("id"), isTrue);

    var id = person.getAttribute("id");
    expect(id != null, isTrue);
    expect(id, "2");

    var idNode = person.getAttributeNode("id");
    expect(idNode != null, isTrue);
    expect(idNode!.key.namespace(), "r");
    expect(idNode.key.removeNamespace(), "id");
    var idNsNode = idNode.namespace;
    expect(idNsNode != null, isTrue);
    expect(idNsNode!.value,
        "http://schemas.openxmlformats.org/package/2006/relationships");

    var rid = person.getAttributeNode("r:id")!;
    rid.setAttribute("set_rid_value");
    expect(person.getAttributeNode("r:id")!.value, "set_rid_value");

    var age = person.getAttributeNode("age")!;
    age.setAttribute("100");
    expect(person.getAttributeNode("age")!.value, "100");

    person.addAttribute("name", "KagariKoumei");
    expect(person.containsAttribute("name"), isTrue);
    expect(person.getAttribute("name"), "KagariKoumei");

    person.getAttributeNode("name")!.remove();
    expect(person.containsAttribute("name"), isFalse);
  });

  test('XmlNode mount', () {
    var doc = XmlDocument.fromString(xmlstr);

    var root = doc.root;
    var person = doc.root.into(type: XmlElementType.start)!.mount();
    var info = doc.root
        .into(
            selector: (n) =>
                n.type == XmlElementType.start && n.name == "info")!
        .mount();
    var child = info.into(type: XmlElementType.start)!.mount();

    person.getAttributeNode("age")!.setAttribute("1234567");
    expect(root.name, "root");
    expect(person.name, "person");
    expect(info.name, "info");
    expect(child.name, "child");

    info.addAttribute("name", "info name");
    expect(root.name, "root");
    expect(person.name, "person");
    expect(info.name, "info");
    expect(child.name, "child");

    info.getAttributeNode("name")!.remove();
    expect(root.name, "root");
    expect(person.name, "person");
    expect(info.name, "info");
    expect(child.name, "child");

    child.unmount();
    info.addAttribute("name", "info name");
    expect(doc.mountedNodes.length, 3);

    child = info.into(type: XmlElementType.start)!.mount();
    expect(doc.mountedNodes.length, 4);
    child.remove();
    info.getAttributeNode("name")!.remove();
    expect(doc.mountedNodes.length, 3);
    var removed = info.into(type: XmlElementType.start);
    expect(removed, null);
  });

  test("XmlNodeInstance", () {
    var doc = XmlDocument.fromString(xmlstr);

    var root = doc.root;
    var person = doc.root.into(type: XmlElementType.start)!.mount();
    var info = doc.root
        .into(
            selector: (n) =>
                n.type == XmlElementType.start && n.name == "info")!
        .mount();
    var child = info.into(type: XmlElementType.start)!.mount();
    var script = person.next(type: XmlElementType.start)!.mount();

    var newNodeInst = XmlNode.create("new");
    late XmlNode newNode;

    newNode = newNodeInst.pasteAfter(person).mount();
    expect(root.name, "root");
    expect(person.name, "person");
    expect(info.name, "info");
    expect(child.name, "child");
    expect(newNode.name, "new");
    newNode = person.next(type: XmlElementType.start)!;
    expect(newNode.name, "new");

    newNode.remove();
    expect(script.name, "x:script");
    expect(root.name, "root");
    expect(person.name, "person");
    expect(info.name, "info");
    expect(child.name, "child");

    newNode = newNodeInst.pasteBefore(info);
    expect(newNode.name, "new");
    newNode = script.next(type: XmlElementType.start)!;
    expect(root.name, "root");
    expect(person.name, "person");
    expect(info.name, "info");
    expect(child.name, "child");
    expect(newNode.name, "new");
    expect(script.name, "x:script");

    newNode.remove();
    newNode = newNodeInst.pasteInner(info);
    expect(newNode.name, "new");
    newNode = info.into(type: XmlElementType.start)!;
    expect(root.name, "root");
    expect(person.name, "person");
    expect(info.name, "info");
    expect(child.name, "child");
    expect(newNode.name, "new");
    expect(script.name, "x:script");

    newNode.remove();
    newNode = newNodeInst.pasteInner(child);
    expect(newNode.name, "new");
    newNode = child.into(type: XmlElementType.start)!;
    expect(root.name, "root");
    expect(person.name, "person");
    expect(info.name, "info");
    expect(child.name, "child");
    expect(newNode.name, "new");
    expect(script.name, "x:script");

    newNode.remove();
    var infoCopyInst = info.copy();
    infoCopyInst.pasteInner(info);
    var infoCopy = info.into(type: XmlElementType.start)!;
    expect(infoCopy.name, "info");
    var childCopy = infoCopy.into(type: XmlElementType.start)!;
    expect(childCopy.name, "child");
  });
}
