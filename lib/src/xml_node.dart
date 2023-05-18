part of 'xml_core.dart';

enum XmlElementType { start, pi, comment, cdata, dtd, end, unknown }

class XmlNodeDetail {
  XmlNode node;

  XmlNodeDetail(this.node);

  int? _beginElementStart;
  int? _beginElementEnd;
  int? _endElementStart;
  int? _endElementEnd;
  XmlElementType? _type;

  int get beginElementStart {
    _beginElementStart ??= node.start;
    return _beginElementStart!;
  }

  int get beginElementEnd {
    _beginElementEnd ??=
        node.document.raw._findElementEnd(beginElementStart, node.type);
    return _beginElementEnd!;
  }

  int get endElementStart {
    _endElementStart ??=
        node.document.raw._findElementStart(endElementEnd, type);
    return _endElementStart!;
  }

  int get endElementEnd {
    _endElementEnd = node.document.raw._findNodeEnd(node.start);
    return _endElementEnd!;
  }

  XmlElementType get type {
    _type ??= node.document.raw._getXmlElementType(node.start);
    return _type!;
  }
}

class XmlNodeInstance {
  String raw;

  XmlNodeInstance(this.raw);

  /// write this node before target node
  XmlNode pasteBefore(XmlNode node) {
    var mounted = node.mounted;
    node.mount();
    var start = node.start;
    node.document.raw = node.document.raw._insertBefore(raw, start);
    node.document._update(start, raw.length);
    if (!mounted) {
      node.unmount();
    }
    return XmlNode(document: node.document, start: start);
  }

  /// write this node after target node
  XmlNode pasteAfter(XmlNode node) {
    var mounted = node.mounted;
    node.mount();
    var start = node.detail.endElementEnd;
    node.document.raw = node.document.raw._insertAfter(raw, start);
    node.document._update(start + 1, raw.length);
    if (!mounted) {
      node.unmount();
    }
    return XmlNode(document: node.document, start: start + 1);
  }

  /// write this node inner target node
  XmlNode pasteInner(XmlNode node) {
    var mounted = node.mounted;
    node.mount();
    var end = node.detail.beginElementEnd;
    if (node.document.raw[end - 1] == "/") {
      var name = node.name;
      node.document.raw = node.document.raw._remove(end - 1, end);
      node.document._update(end - 1, -1);
      end--;
      var endElement = "</$name>";
      node.document.raw = node.document.raw._insertAfter(endElement, end);
      node.document._update(end + 1, endElement.length);
    }
    node.document.raw = node.document.raw._insertAfter(raw, end);
    node.document._update(end + 1, raw.length);

    if (!mounted) {
      node.unmount();
    }
    return XmlNode(document: node.document, start: end + 1);
  }
}

/// **[NOTICE]** `XmlAttribute` should not be cached
///
/// this is a temp object
///
/// once read should be dropped immediately
///
/// after any writing operation, all `XmlAttribute` will point at wrong position
class XmlAttribute {
  XmlNode node;

  XmlAttribute(this.node);

  late int keyIdx;
  late int equalIdx;
  late int quotaIdx;
  late int quotaEndIdx;

  /// lookup ancestors and find first matched namespace definition
  XmlAttribute? get namespace {
    var nsEnd =
        node.document.raw._indexInRange(":", start: keyIdx, end: equalIdx);
    if (nsEnd == -1) {
      return null;
    }
    var ns = node.document.raw.substring(keyIdx, nsEnd);
    var nsAttr = "xmlns:$ns";
    var ancestor =
        node.findAncestor(selector: (n) => n.containsAttribute(nsAttr));
    return ancestor?.getAttributeNode(nsAttr);
  }

  /// get attribute's value
  String get value {
    return node.document.raw.substring(quotaIdx + 1, quotaEndIdx);
  }

  /// set attribute node's value
  /// setAttribute will update itself
  /// you can still keep this object after setAttribute
  /// return self
  XmlAttribute setAttribute(String value) {
    var modifiedLength = value.length - (quotaEndIdx - quotaIdx - 1);
    node.document.raw = node.document.raw._remove(quotaIdx + 1, quotaEndIdx);
    node.document.raw = node.document.raw._insertAfter(value, quotaIdx);
    node.document._update(quotaEndIdx + 1, modifiedLength);
    quotaEndIdx = quotaIdx + value.length + 1;
    return this;
  }

  /// remove attribute from node
  void remove() {
    node.document.raw = node.document.raw._remove(keyIdx - 1, quotaEndIdx + 1);
    node.document._update(quotaEndIdx + 1, -(quotaEndIdx - keyIdx + 2));
  }

  /// get attribute's key including namespace
  String get key {
    return node.document.raw.substring(keyIdx, equalIdx);
  }
}

class XmlNode {
  /// reference of document
  XmlDocument document;

  /// the index of this node first character in xml document
  int start;

  /// is this node removed
  bool removed = false;

  /// is this node mounted
  bool mounted = false;

  XmlNodeDetail? _detail;

  /// node detail info
  XmlNodeDetail get detail {
    _detail ??= XmlNodeDetail(this);
    return _detail!;
  }

  /// get node type
  XmlElementType get type =>
      _detail?.type ?? document.raw._getXmlElementType(start);

  /// get begin element of this node
  String get beginElement => document.raw
      .substring(detail.beginElementStart, detail.beginElementEnd + 1);

  /// get ending element of this node
  String get endElement =>
      document.raw.substring(detail.endElementStart, detail.endElementEnd + 1);

  /// start updating node from document
  XmlNode mount() {
    if (!mounted) {
      mounted = true;
      document.mountedNodes.add(this);
    }
    return this;
  }

  /// stop updating node from document
  void unmount() {
    mounted = false;
  }

  /// remove this node from document
  void remove() {
    unmount();
    removed = true;
    document._update(detail.beginElementStart,
        -(detail.endElementEnd - detail.beginElementStart + 1));
    document.raw = document.raw
        ._remove(detail.beginElementStart, detail.endElementEnd + 1);
  }

  /// create a XmlNodeInstance holding of this node's outerXML
  XmlNodeInstance copy() {
    return XmlNodeInstance(outerXML);
  }

  /// create a XmlNodeInstance holding of this node's outerXML and remove origin node
  XmlNodeInstance cut() {
    var inst = XmlNodeInstance(outerXML);
    remove();
    return inst;
  }

  /// create a `XmlNodeInstance` holding new node xml string
  /// you need to paste it
  static XmlNodeInstance create(String name) {
    return XmlNodeInstance("<$name/>");
  }

  /// return XML including begin element and ending element
  String get outerXML => document.raw
      .substring(detail.beginElementStart, detail.endElementEnd + 1);

  bool _update(int modifiedStart, int modifiedLength) {
    if (modifiedStart > start) {
      if (_detail != null) {
        if (_detail!._endElementEnd != null &&
            modifiedStart <= _detail!.endElementEnd) {
          _detail!._endElementEnd = _detail!._endElementEnd! + modifiedLength;
        }
        if (_detail!._endElementStart != null &&
            modifiedStart <= _detail!.endElementStart) {
          _detail!._endElementStart =
              _detail!._endElementStart! + modifiedLength;
        }
        if (_detail!._beginElementEnd != null &&
            modifiedStart <= _detail!.beginElementEnd) {
          _detail!._beginElementEnd =
              _detail!._beginElementEnd! + modifiedLength;
        }
      }
    } else if (modifiedStart < start ||
        (modifiedStart == start && modifiedLength > 0)) {
      start += modifiedLength;
      if (_detail != null) {
        if (_detail!._beginElementStart != null) {
          _detail!._beginElementStart =
              _detail!._beginElementStart! + modifiedLength;
        }
        if (_detail!._beginElementEnd != null) {
          _detail!._beginElementEnd =
              _detail!._beginElementEnd! + modifiedLength;
        }
        if (_detail!._endElementStart != null) {
          _detail!._endElementStart =
              _detail!._endElementStart! + modifiedLength;
        }
        if (_detail!._endElementEnd != null) {
          _detail!._endElementEnd = _detail!._endElementEnd! + modifiedLength;
        }
      }
    } else if (modifiedStart == start && modifiedLength < 0) {
      removed = true;
      unmount();
      return false;
    }
    return true;
  }

  XmlNode({required this.document, required this.start});

  /// get the parent node of this node
  XmlNode? get parent {
    var parentStart = document.raw._findParentNodeStart(start);
    if (parentStart != -1) {
      return XmlNode(document: document, start: parentStart);
    }
    return null;
  }

  /// add a new attribute
  ///
  /// return the new attribute's `XmlAttribute` object
  XmlAttribute? addAttribute(String key, String value) {
    if (detail.type == XmlElementType.start) {
      var newAttr = " $key=\"$value\"";
      var insertAt = document.raw._findNodeNameEnd(start);
      if (insertAt == -1) {
        return null;
      }
      document.raw = document.raw._insertAfter(newAttr, insertAt);
      document._update(insertAt, newAttr.length);
      var n = XmlAttribute(this);
      n.keyIdx = insertAt + 1;
      n.equalIdx = n.keyIdx + key.length + 1;
      n.quotaIdx = n.equalIdx + 1;
      n.quotaEndIdx = n.quotaIdx + value.length + 1;
      return n;
    }
    return null;
  }

  int _indexOfAttributeKey(String key) {
    var keyIdx = -1;
    if (key.startsWith("*")) {
      //match key like *id
      var realKey = key.substring(1);
      keyIdx = document.raw._indexInRange(" $realKey",
          start: detail.beginElementStart, end: detail.beginElementEnd);

      // not found none namespace attribute which has same key
      // guessed the namespace is omitted
      // match the first node which has same key and has namespace
      if (keyIdx == -1) {
        keyIdx = document.raw._indexInRange(":$realKey",
            start: detail.beginElementStart, end: detail.beginElementEnd);
        keyIdx = document.raw.indexBackward(" ", keyIdx);
      }
    } else if (key.contains(":")) {
      // specified namespace
      keyIdx = document.raw._indexInRange(key,
          start: detail.beginElementStart, end: detail.beginElementEnd);
    } else {
      // unspecified namespace

      // find none namespace attribute
      keyIdx = document.raw._indexInRange(" $key",
          start: detail.beginElementStart, end: detail.beginElementEnd);
    }
    return keyIdx;
  }

  /// is this node has attribute named key
  ///
  /// parameter key should like these
  ///
  /// "id" or "x:id" or ":id" or "*id"
  ///
  /// - "id" no namespace named "id" attribute
  ///
  /// - "x:id" namespace is "x" and name is "id"
  ///
  /// - ":id" has a namespace and name is "id"
  ///
  /// - "*id" just name is "id"
  bool containsAttribute(String key) {
    if (detail.type == XmlElementType.start) {
      var keyIdx = _indexOfAttributeKey(key);
      if (keyIdx == -1) {
        return false;
      }
      return true;
    }
    return false;
  }

  /// **[NOTICE]** `XmlAttribute` should not be cached
  ///
  /// once read should be dropped immediately
  ///
  /// after any writing operation, all `XmlAttribute` will point at wrong position
  ///
  /// parameter key should like these
  ///
  /// "id" or "x:id" or ":id" or "*id"
  ///
  /// - "id" no namespace named "id" attribute
  ///
  /// - "x:id" namespace is "x" and name is "id"
  ///
  /// - ":id" has a namespace and name is "id"
  ///
  /// - "*id" just name is "id"
  XmlAttribute? getAttributeNode(String key) {
    if (detail.type == XmlElementType.start) {
      var attr = XmlAttribute(this);

      attr.keyIdx = _indexOfAttributeKey(key);

      if (attr.keyIdx == -1) {
        return null;
      }
      attr.keyIdx++;
      attr.equalIdx = document.raw
          ._indexInRange("=", start: attr.keyIdx, end: detail.beginElementEnd);
      if (attr.equalIdx == -1) {
        return null;
      }
      attr.quotaIdx = document.raw._indexInRange("\"",
          start: attr.equalIdx, end: detail.beginElementEnd);
      if (attr.quotaIdx == -1) {
        return null;
      }
      attr.quotaEndIdx = document.raw._findEndQuotation(attr.quotaIdx);
      if (attr.quotaEndIdx == -1) {
        return null;
      }
      if (attr.quotaEndIdx < attr.quotaIdx) {
        return null;
      }
      return attr;
    }
    return null;
  }

  /// directly get node attribute value
  ///
  /// parameter key should like these
  ///
  /// "id" or "x:id" or ":id" or "*id"
  ///
  /// - "id" no namespace named "id" attribute
  ///
  /// - "x:id" namespace is "x" and name is "id"
  ///
  /// - ":id" has a namespace and name is "id"
  ///
  /// - "*id" just name is "id"
  String? getAttribute(String key) {
    if (detail.type == XmlElementType.start) {
      var attr = getAttributeNode(key);
      if (attr == null) {
        return null;
      }
      return attr.value;
    }
    return null;
  }

  /// get node all attributes as map
  Map<String, String> getAttributes() {
    if (detail.type == XmlElementType.start) {
      return document.raw
          ._parseAttributes(detail.beginElementStart, detail.beginElementEnd);
    }
    return {};
  }

  /// get node name include namespace
  ///
  /// you can use `node.name.removeNamespace()` or `node.name.namespace()` get part
  String get name {
    if (detail.type == XmlElementType.start) {
      var nameEnd = document.raw._findNodeNameEnd(start);
      return document.raw.substring(start + 1, nameEnd + 1);
    }
    return "";
  }

  /// find node ancestor node
  ///
  /// can specified node type or selector
  XmlNode? findAncestor(
      {XmlElementType? type, bool Function(XmlNode node)? selector}) {
    if (type == null && selector == null) {
      return parent;
    }
    if (selector != null) {
      var p = parent;
      while (p != null) {
        if (selector(p)) {
          return p;
        }
        p = p.parent;
      }
      return null;
    }
    if (type != null) {
      findAncestor(selector: (n) => n.type == type);
    }
    return null;
  }

  /// Find next inner node
  ///
  /// ```XML
  /// <Person>
  ///   <Name></Name>
  ///   <Age></Age>
  /// </Person>
  /// ```
  /// such as Person.into() is Name
  XmlNode? into({XmlElementType? type, bool Function(XmlNode node)? selector}) {
    var nodeStart = document.raw._findInnerNodeStart(start);
    if (nodeStart == -1) {
      return null;
    }
    XmlNode? node = XmlNode(document: document, start: nodeStart);
    if ((selector != null && !selector(node)) ||
        (type != null && node.type != type)) {
      node = node.next(type: type, selector: selector);
    }
    return node;
  }

  /// Find next parallel node
  ///
  /// ```XML
  /// <Person>
  ///   <Name></Name>
  ///   <Age></Age>
  /// </Person>
  /// ```
  /// such as Name.next() is Age
  XmlNode? next({XmlElementType? type, bool Function(XmlNode node)? selector}) {
    if (type != null || selector != null) {
      XmlNode? node;
      while (true) {
        node = (node ?? this).next();
        if (node != null && selector != null && !selector(node)) {
          continue;
        }
        if (node != null && type != null && node.type != type) {
          continue;
        }
        return node;
      }
    }
    var nodeStart = document.raw._findParallelNodeStart(start);
    if (nodeStart == -1) {
      return null;
    }
    return XmlNode(document: document, start: nodeStart);
  }

  /// Get node inner XML String
  ///
  /// ```XML
  /// <Person>
  ///   <Name></Name>
  ///   <Age></Age>
  /// </Person>
  /// ```
  /// such as Person.innerXML should be
  /// ```XML
  /// \t<Name></Name>\t\n<Age></Age>
  /// ```
  String get innerXML {
    if (detail.type == XmlElementType.start) {
      if(detail.endElementStart != start){
        return document.raw
            .substring(detail.beginElementEnd + 1, detail.endElementStart);
      }else{
        return "";
      }
    }
    return "";
  }

  set innerXML(String v) {
    if (detail.type == XmlElementType.start) {
      document.raw = document.raw._remove(detail.beginElementEnd + 1, detail.endElementStart);
      document.raw = document.raw._insertAfter(v, detail.beginElementEnd);
      document._update(detail.beginElementEnd + 1, v.length - detail.endElementStart + detail.beginElementEnd + 1);
    }
  }

  set innerValue(String v){
    innerXML = v.encode();
  }

  /// decoded innerXML
  String get value {
    return innerXML.decode();
  }
}
