part of 'xml_core.dart';

enum XmlElementType{
  NormalStart,
  ProcessingInstruction,
  Comment,
  CDATA,
  DTD,
  NormalEnd,
  Unknown
}


class XmlNodeDetail{
  late int beginElementStart;
  late int beginElementEnd;
  late int endElementStart;
  late int endElementEnd;
  late XmlElementType type;
}


class XmlNodeInstance{
  String raw;
  XmlNodeInstance(this.raw);

  XmlNode pasteBefore(XmlNode node){
    var mounted = node.mounted;
    node.mount();
    var start = node.start;
    node.document.raw = node.document.raw.insertBefore(raw, start);
    node.document._update(start, raw.length);
    if(!mounted){
      node.unmount();
    }
    return XmlNode(document: node.document, start: start);
  }

  XmlNode pasteAfter(XmlNode node){
    var mounted = node.mounted;
    node.mount();
    var start = node.detail.endElementEnd;
    node.document.raw = node.document.raw.insertAfter(raw, start);
    node.document._update(start + 1, raw.length);
    if(!mounted){
      node.unmount();
    }
    return XmlNode(document: node.document, start: start + 1);
  }

  XmlNode pasteInner(XmlNode node){
    var mounted = node.mounted;
    node.mount();
    var end = node.detail.beginElementEnd;
    if(node.document.raw[end - 1] == "/"){
      var name = node.name;
      node.document.raw = node.document.raw.remove(end - 1, end);
      node.document._update(end - 1, -1);
      end--;
      var endElement = "</$name>";
      node.document.raw = node.document.raw.insertAfter(endElement,end);
      node.document._update(end + 1, endElement.length);
    }
    node.document.raw = node.document.raw.insertAfter(raw,end);
    node.document._update(end + 1, raw.length);

    if(!mounted){
      node.unmount();
    }
    return XmlNode(document: node.document, start: end + 1);
  }
}


/// ============ALERT==============
///
/// `XmlAttribute` should not be cached
///
/// ============ALERT==============
///
/// this is a temp object
///
/// once read should be dropped immediately
///
/// after any writing operation, all `XmlAttribute` will point at wrong position
class XmlAttribute{
  XmlNode node;
  XmlAttribute(this.node);

  late int  keyIdx;
  late int  equalIdx;
  late int  quotaIdx;
  late int  quotaEndIdx;

  XmlAttribute? get namespace{
    var nsEnd = node.document.raw.indexInRange(":",start:keyIdx,end: equalIdx);
    if(nsEnd == -1){
      return null;
    }
    var ns = node.document.raw.substring(keyIdx,nsEnd);
    var nsAttr = "xmlns:${ns}";
    var ancestor = node.findAncestor(selector: (n)=>n.containsAttribute(nsAttr));
    return ancestor?.getAttributeNode(nsAttr);
  }

  String get value{
    return node.document.raw.substring(quotaIdx + 1,quotaEndIdx);
  }

  XmlAttribute setAttribute(String value){
      var modifiedLength = value.length - (quotaEndIdx - quotaIdx - 1);
      node.document.raw = node.document.raw.remove(quotaIdx + 1, quotaEndIdx);
      node.document.raw = node.document.raw.insertAfter(value, quotaIdx);
      node.document._update(quotaEndIdx + 1, modifiedLength);
      quotaEndIdx = quotaIdx + value.length + 1;
      return this;
  }

  void remove(){
    node.document.raw = node.document.raw.remove(keyIdx - 1, quotaEndIdx + 1);
    node.document._update(quotaEndIdx + 1, -(quotaEndIdx - keyIdx + 2));
  }

  String get key{
    return node.document.raw.substring(keyIdx,equalIdx);
  }
}

class XmlNode{
  XmlDocument document;
  int start;
  bool removed = false;
  bool mounted = false;
  XmlNodeDetail? _detail;
  XmlNodeDetail get detail{
    _detail ??= _parseDetail(document,start);
    return _detail!;
  }

  XmlElementType get type => _detail?.type ?? document.raw.getXmlElementType(start);

  String get beginElement => document.raw.substring(detail.beginElementStart,detail.beginElementEnd + 1);

  String get endElement => document.raw.substring(detail.endElementStart,detail.endElementEnd + 1);

  XmlNode mount(){
    if(!mounted){
      mounted = true;
      document.mountedNodes.add(this);
    }
    return this;
  }

  void unmount(){
    mounted = false;
  }

  void remove(){
    unmount();
    removed = true;
    document.raw = document.raw.remove(detail.beginElementStart, detail.endElementEnd + 1);
    document._update(detail.beginElementStart, -(detail.endElementEnd - detail.beginElementStart + 1));
  }

  XmlNodeInstance copy(){
    return XmlNodeInstance(outerXML);
  }

  static XmlNodeInstance create(String name){
    return XmlNodeInstance("<$name/>");
  }

  String get outerXML => document.raw.substring(detail.beginElementStart,detail.endElementEnd + 1);

  bool _update(int modifiedStart,int modifiedLength){
    if(modifiedStart>start){
      if(_detail != null){
        if(modifiedStart <= _detail!.endElementEnd){
          _detail!.endElementEnd += modifiedLength;
        }
        if(modifiedStart <= _detail!.endElementStart){
          _detail!.endElementStart += modifiedLength;
        }
        if(modifiedStart <= _detail!.beginElementEnd){
          _detail!.beginElementEnd += modifiedLength;
        }
        if(modifiedStart <= _detail!.beginElementStart){
          _detail!.beginElementStart += modifiedLength;
        }
      }
    }else if(modifiedStart < start || (modifiedStart == start && modifiedLength > 0)){
      start += modifiedLength;
      if(_detail != null){
        _detail!.beginElementStart += modifiedLength;
        _detail!.beginElementEnd += modifiedLength;
        _detail!.endElementStart += modifiedLength;
        _detail!.endElementEnd += modifiedLength;
      }
    }else if(modifiedStart == start && modifiedLength < 0){
      removed = true;
      unmount();
      return false;
    }
    return true;
  }

  XmlNode({required this.document,required this.start});

  XmlNode? get parent{
    var parentStart = document.raw.findParentNodeStart(start);
    if(parentStart != -1){
      return XmlNode(document: document, start: parentStart);
    }
    return null;
  }

  XmlAttribute? addAttribute(String key,String value){
    if(detail.type == XmlElementType.NormalStart) {
      var newAttr = " $key=\"$value\"";
      var insertAt = document.raw.findNodeNameEnd(start);
      if(insertAt == -1){
        return null;
      }
      document.raw = document.raw.insertAfter(newAttr, insertAt);
      document._update(insertAt, newAttr.length);
      var _n = XmlAttribute(this);
      _n.keyIdx = insertAt + 1;
      _n.equalIdx = _n.keyIdx + key.length + 1;
      _n.quotaIdx =  _n.equalIdx + 1;
      _n.quotaEndIdx = _n.quotaIdx + value.length + 1;
      return _n;
    }
    return null;
  }

  bool containsAttribute(String key){
    if(detail.type == XmlElementType.NormalStart) {
      var keyIdx = 0;
      if(key.contains(":")){
        // specified namespace
        keyIdx = document.raw.indexInRange(" $key",start: detail.beginElementStart,end: detail.beginElementEnd);
      }else{
        // unspecified namespace

        // find none namespace attribute first
        keyIdx = document.raw.indexInRange(" $key",start: detail.beginElementStart,end: detail.beginElementEnd);

        // not found none namespace attribute which has same key
        // guessed the namespace is omitted
        // match the first node which has same key and has namespace
        if(keyIdx == -1){
          keyIdx = document.raw.indexInRange(":$key",start: detail.beginElementStart,end: detail.beginElementEnd);
          keyIdx = document.raw.indexBackward(" ",keyIdx);
        }
      }
      if(keyIdx == -1){
        return false;
      }
      return true;
    }
    return false;
  }

  /// ============ALERT==============
  ///
  /// `XmlAttribute` should not be cached
  ///
  /// ============ALERT==============
  ///
  /// once read should be dropped immediately
  ///
  /// after any writing operation, all `XmlAttribute` will point at wrong position
  XmlAttribute? getAttributeNode(String key){
    if(detail.type == XmlElementType.NormalStart){
      var attr = XmlAttribute(this);
      if(key.contains(":")){
        // specified namespace
        attr.keyIdx = document.raw.indexInRange(" $key",start: detail.beginElementStart,end: detail.beginElementEnd);
      }else{
        // unspecified namespace

        // find none namespace attribute first
        attr.keyIdx = document.raw.indexInRange(" $key",start: detail.beginElementStart,end: detail.beginElementEnd);

        // not found none namespace attribute which has same key
        // guessed the namespace is omitted
        // match the first node which has same key and has namespace
        if(attr.keyIdx == -1){
          attr.keyIdx = document.raw.indexInRange(":$key",start: detail.beginElementStart,end: detail.beginElementEnd);
          attr.keyIdx = document.raw.indexBackward(" ",attr.keyIdx);
        }
      }
      if(attr.keyIdx == -1){
        return null;
      }
      attr.keyIdx++;
      attr.equalIdx = document.raw.indexInRange("=",start: attr.keyIdx,end: detail.beginElementEnd);
      if(attr.equalIdx == -1){
        return null;
      }
      attr.quotaIdx = document.raw.indexInRange("\"",start: attr.equalIdx,end: detail.beginElementEnd);
      if(attr.quotaIdx == -1){
        return null;
      }
      attr.quotaEndIdx = document.raw.findEndQuotation(attr.quotaIdx);
      if(attr.quotaEndIdx == -1){
        return null;
      }
      if(attr.quotaEndIdx < attr.quotaIdx){
        return null;
      }
      return attr;
    }
    return null;
  }

  String? getAttribute(String key){
    if(detail.type == XmlElementType.NormalStart){
      var attr =  getAttributeNode(key);
      if(attr == null){
        return null;
      }
      return attr.value;
    }
    return null;
  }



  Map<String,String> getAttributes(){
    if(detail.type == XmlElementType.NormalStart){
      return document.raw.parseAttributes(detail.beginElementStart,detail.beginElementEnd);
    }
    return {};
  }

  String get name{
    if(detail.type == XmlElementType.NormalStart) {
      var nameEnd = document.raw.findNodeNameEnd(start);
      return document.raw.substring(start + 1, nameEnd + 1);
    }
    return "";
  }


  XmlNode? findAncestor({XmlElementType? type,bool Function(XmlNode node)? selector}){
    if(type == null && selector == null){
      return parent;
    }
    if(selector != null){
      var _p = parent;
      while(_p != null){
        if(selector(_p)){
          return _p;
        }
        _p = _p.parent;
      }
      return null;
    }
    if(type != null){
      findAncestor(selector: (n)=>n.type == type);
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
  XmlNode? into({XmlElementType? type,bool Function(XmlNode node)? selector}){
    var nodeStart = document.raw.findInnerNodeStart(start);
    if(nodeStart == -1){
      return null;
    }
    XmlNode? node = XmlNode(document: document, start: nodeStart) ;
    if((selector != null && !selector(node)) || (type != null && node.type != type)){
      node = node.next(type: type,selector: selector);
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
  XmlNode? next({XmlElementType? type,bool Function(XmlNode node)? selector}){
    if(type != null || selector != null){
      XmlNode? node;
      while(true){
        node = (node??this).next();
        if(node != null && selector != null && !selector(node)){
          continue;
        }
        if(node != null && type != null && node.type != type){
          continue;
        }
        return node;
      }
    }
    var nodeStart = document.raw.findParallelNodeStart(start);
    if(nodeStart == -1){
      return null;
    }
    return XmlNode(document: document, start: nodeStart) ;
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
  String get innerXML{
    if(detail.type == XmlElementType.NormalStart){
      return document.raw.substring(detail.beginElementEnd + 1,detail.endElementStart);
    }
    return "";
  }

  String get value{
    //TODO: parse special character
    return innerXML;
  }

  static XmlNodeDetail _parseDetail(XmlDocument document,int start){
    var detail = XmlNodeDetail();
    detail.type = document.raw.getXmlElementType(start);
    detail.beginElementStart = start;
    detail.endElementEnd = document.raw.findNodeEnd(start);
    detail.beginElementEnd = document.raw.findElementEnd(detail.beginElementStart,detail.type);
    detail.endElementStart = document.raw.findElementStart(detail.endElementEnd,detail.type);
    return detail;
  }
}