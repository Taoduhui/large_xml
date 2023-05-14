part of 'xml_core.dart';

extension XmlStringExtension on String {
  /// repace `< > & ' \`
  String encode() {
    return replaceAll("&", "&amp;")
        .replaceAll("<", "&lt;")
        .replaceAll(">", "&gt;")
        .replaceAll("'", "&apos;")
        .replaceAll("\"", "&quot;");
  }

  /// recovery `< > & ' \`
  String decode() {
    return replaceAll("&lt;", "<")
        .replaceAll("&gt;", ">")
        .replaceAll("&amp;", "&")
        .replaceAll("&apos;", "'")
        .replaceAll("&quot;", "\"");
  }

  /// get namespace part
  String? namespace() {
    var idx = indexOf(":");
    if (idx == -1) {
      return null;
    }
    return substring(0, idx);
  }

  /// remove namespace part
  String removeNamespace() {
    var idx = indexOf(":");
    if (idx == -1) {
      return this;
    }
    return substring(idx + 1);
  }

  int _findEndQuotation(int start) {
    var type = this[start];
    for (int i = start + 1; i < length; i++) {
      if (this[i] == type) {
        return i;
      }
    }
    throw (Exception("unquoted element, start:$start"));
  }

  int _findDoubleQuotationBackward(int end) {
    var type = this[end];
    for (int i = end - 1; i >= 0; i--) {
      if (this[i] == type) {
        return i;
      }
    }
    throw (Exception("unquoted element, end:$end"));
  }

  int _findNormalElementEnd(int start) {
    for (int i = start + 1; i < length; i++) {
      if (this[i] == "\"") {
        i = _findEndQuotation(i);
        continue;
      }
      if (this[i] == ">") {
        return i;
      }
    }
    throw (Exception("missing >, start:$start"));
  }

  int _findNormalElementStart(int end) {
    for (int i = end - 1; i >= 0; i--) {
      if (this[i] == "\"") {
        i = _findDoubleQuotationBackward(i);
        continue;
      }
      if (this[i] == "<") {
        return i;
      }
    }
    throw (Exception("missing <, end:$end"));
  }

  int indexBackward(String str, [int? end]) {
    end = end ?? (length - 1);
    var strLastIdx = str.length - 1;
    for (var i = end; i >= strLastIdx; i--) {
      bool matched = true;
      for (var c = strLastIdx; c >= 0; c--) {
        if (this[i - (strLastIdx - c)] != str[c]) {
          matched = false;
          break;
        }
      }
      if (matched) {
        return i - strLastIdx;
      }
    }
    return -1;
  }

  int _findCommentElementStart(int end) {
    var start = indexBackward("<!--", end);
    if (start == -1) {
      throw (Exception("missing Comment start element <!--, end:$end"));
    }
    return start;
  }

  int _findCommentElementEnd(int start) {
    var end = indexOf("-->", start);
    if (end == -1) {
      throw (Exception("missing Comment end element -->, start:$start"));
    }
    return end + 2;
  }

  int _findCDATAElementStart(int end) {
    var start = indexBackward("<![CDATA[", end);
    if (start == -1) {
      throw (Exception("missing CDATA start element <![CDATA[, end:$end"));
    }
    return start;
  }

  int _findCDATAElementEnd(int start) {
    var end = indexOf("]]>", start);
    if (end == -1) {
      throw (Exception("missing CDATA end element ]]>, start:$start"));
    }
    return end + 2;
  }

  int _findProcessingInstructionElementStart(int end) {
    var start = indexBackward("<?", end);
    if (start == -1) {
      throw (Exception(
          "missing processing instruction start element <?, end:$end"));
    }
    return start;
  }

  int _findProcessingInstructionElementEnd(int start) {
    var end = indexOf("?>", start);
    if (end == -1) {
      throw (Exception(
          "missing processing instruction end element ?>, start:$start"));
    }
    return end + 1;
  }

  int _findDTDElementStart(int end) {
    for (int i = end - 1; i >= 0; i--) {
      if (this[i] == ">") {
        i = _findNormalElementStart(i);
      } else if (this[i] == "<") {
        return i;
      }
    }
    throw (Exception("missing >, end:$end"));
  }

  int _findDTDElementEnd(int start) {
    for (int i = start + 2; i < length; i++) {
      if (this[i] == "<") {
        i = _findNormalElementEnd(i);
      } else if (this[i] == ">") {
        return i;
      }
    }
    throw (Exception("missing >, start:$start"));
  }

  int _findParentNodeStart(int start) {
    for (int i = start - 1; i >= 0; i--) {
      if (this[i] == ">") {
        if (this[i - 1] == "/") {
          i = _findNodeStart(i);
          continue;
        } else {
          var type = _getXmlElementTypeBySuffix(i);
          if (type == XmlElementType.start) {
            return _findElementStart(i);
          } else {
            i = _findNodeStart(i);
            continue;
          }
        }
      }
    }
    return -1;
  }

  int _findInnerNodeStart(int start) {
    var end = _findNormalElementEnd(start);
    for (var i = end + 1; i < length; i++) {
      if (this[i] == "<") {
        if (this[i + 1] == "/") {
          return -1;
        }
        return i;
      }
    }
    return -1;
  }

  int _findParallelNodeStart(int start) {
    var end = _findNodeEnd(start);
    for (var i = end + 1; i < length; i++) {
      if (this[i] == "<") {
        if (this[i + 1] == "/") {
          return -1;
        }
        return i;
      }
    }
    return -1;
  }

  int _findElementStart(int end, [XmlElementType? type]) {
    type = type ?? _getXmlElementTypeBySuffix(end);
    switch (type) {
      case XmlElementType.start:
        return _findNormalElementStart(end);
      case XmlElementType.pi:
        return _findProcessingInstructionElementStart(end);
      case XmlElementType.comment:
        return _findCommentElementStart(end);
      case XmlElementType.cdata:
        return _findCDATAElementStart(end);
      case XmlElementType.dtd:
        return _findDTDElementStart(end);
      case XmlElementType.end:
        return _findNormalElementStart(end);
      case XmlElementType.unknown:
        return -1;
    }
  }

  int _findElementEnd(int start, [XmlElementType? type]) {
    type = type ?? _getXmlElementType(start);
    switch (type) {
      case XmlElementType.start:
        return _findNormalElementEnd(start);
      case XmlElementType.pi:
        return _findProcessingInstructionElementEnd(start);
      case XmlElementType.comment:
        return _findCommentElementEnd(start);
      case XmlElementType.cdata:
        return _findCDATAElementEnd(start);
      case XmlElementType.dtd:
        return _findDTDElementEnd(start);
      case XmlElementType.end:
        return _findNormalElementEnd(start);
      case XmlElementType.unknown:
        throw Exception("unknown node type");
    }
  }

  int _findNodeNameEnd(int start) {
    var area = indexOf(RegExp("[ >]"), start);
    if (area == -1) {
      return -1;
    }
    if (this[area] == ">" && this[area - 1] == "/") {
      return area - 2;
    }
    return area - 1;
  }

  Map<String, String> _parseAttributes(int start, int end) {
    Map<String, String> map = {};
    start = _findNodeNameEnd(start) + 1;
    end = end - 1;
    for (int i = start; i <= end; i++) {
      if (this[i] == " " || this[i] == "/" || this[i] == ">") {
        continue;
      }
      var keyEndIdx = indexOf(RegExp("[ =]"), i);
      var key = substring(i, keyEndIdx);
      var quotaIdx = indexOf("\"", i);
      var quotaEndIdx = _findEndQuotation(quotaIdx);
      var value = substring(quotaIdx + 1, quotaEndIdx);
      map[key] = value;
      i = quotaEndIdx;
    }
    return map;
  }

  int _findNodeStart(int end) {
    int pair = 0;
    for (int i = end; i >= 0; i--) {
      if (this[i] != ">") {
        continue;
      }
      var type = _getXmlElementTypeBySuffix(i);
      if (type == XmlElementType.start) {
        if (this[i - 1] != "/") {
          pair++;
        }
      } else if (type == XmlElementType.end) {
        pair--;
      }
      i = _findElementStart(i, type);
      if (pair == 0) {
        return i;
      }
    }
    return -1;
  }

  int _findNodeEnd(int start) {
    int pair = 0;
    for (int i = start; i < length; i++) {
      if (this[i] != "<") {
        continue;
      }
      var type = _getXmlElementType(i);
      i = _findElementEnd(i, type);
      if (type == XmlElementType.end) {
        pair--;
      } else if (type == XmlElementType.start) {
        if (this[i - 1] != "/") {
          pair++;
        }
      }
      if (pair == 0) {
        return i;
      }
    }
    return -1;
  }

  XmlElementType _getXmlElementTypeBySuffix(int end) {
    switch (this[end]) {
      case ">":
        {
          switch (this[end - 1]) {
            case "?":
              {
                // ?>: Processing instruction.
                return XmlElementType.pi;
              }
            case "-":
              {
                // Probably --> for a comment.
                return XmlElementType.comment;
              }
            case "]":
              {
                // Probably <![CDATA[...]]>
                if (this[end - 2] == "]") {
                  return XmlElementType.cdata;
                }
                return XmlElementType.dtd;
              }
            default:
              {
                var start = _findNormalElementStart(end);
                var type = _getXmlElementType(start);
                switch (type) {
                  case XmlElementType.start:
                    return XmlElementType.start;
                  case XmlElementType.end:
                    return XmlElementType.end;
                  default:
                    return XmlElementType.unknown;
                }
              }
          }
        }
    }
    return XmlElementType.unknown;
  }

  XmlElementType _getXmlElementType(int start) {
    switch (this[start]) {
      case "<":
        {
          switch (this[start + 1]) {
            case "?":
              {
                // <?: Processing instruction.
                return XmlElementType.pi;
              }
            case "/":
              {
                // </: End element
                return XmlElementType.end;
              }
            case "!":
              {
                // <!: Maybe comment, maybe CDATA.
                switch (this[start + 2]) {
                  case "-":
                    {
                      // Probably <!-- for a comment.
                      return XmlElementType.comment;
                    }
                  case "[":
                    {
                      // Probably <![CDATA[.
                      return XmlElementType.cdata;
                    }
                  default:
                    {
                      // Probably DTD, such as <!DOCTYPE ...>
                      return XmlElementType.dtd;
                    }
                }
              }
            default:
              {
                return XmlElementType.start;
              }
          }
        }
    }
    return XmlElementType.unknown;
  }

  int _indexInRange(String str, {int start = 0, int? end}) {
    end ??= length - 1;
    for (int i = start; i < end; i++) {
      bool matched = true;
      for (int c = 0; c < str.length; c++) {
        if (this[i + c] != str[c]) {
          matched = false;
          break;
        }
      }
      if (matched) {
        return i;
      }
    }
    return -1;
  }

  String _insertAfter(String str, int index) {
    var str1 = substring(0, index + 1);
    var str2 = substring(index + 1);
    return "$str1$str$str2";
  }

  String _insertBefore(String str, int index) {
    var str1 = substring(0, index);
    var str2 = substring(index);
    return "$str1$str$str2";
  }

  String _remove(int start, int end) {
    var str1 = substring(0, start);
    var str2 = substring(end);
    return "$str1$str2";
  }
}
