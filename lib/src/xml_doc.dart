part of 'xml_core.dart';

class XmlDocument{

  String raw;
  late XmlNode root;
  List<XmlNode> mountedNodes = [];

  XmlNode? get firstElement => XmlNode(document: this, start: raw.indexOf("<"));

  XmlDocument.fromString(this.raw){
    root = _getRootNode();
    root.mount();
  }

  void _update(int start,int length){
    for(var i=0;i<mountedNodes.length;i++){
      mountedNodes[i]._update(start, length);
      if( !mountedNodes[i].mounted || mountedNodes[i].removed){
        mountedNodes.removeAt(i);
        i--;
      }
    }
  }

  XmlNode _getRootNode(){
    var first = raw.indexOf("<");
    if(first == -1){
      throw(Exception("root node not found"));
    }
    for(var i=first;i<raw.length;){
      if(raw.getXmlElementType(i) == XmlElementType.NormalStart){
        return XmlNode(document: this, start: i);
      }else{
        i = raw.findParallelNodeStart(i);
        if(i==-1){
          break;
        }
      }
    }
    throw(Exception("root node not found"));
  }
}
