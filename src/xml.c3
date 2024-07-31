module env::xml;
import std::io;
import std::collections;

def XmlNodeAttributes = List(<XmlAttribute*>);
def XmlNodeList = List(<XmlNode*>);

fault XmlFault {
    ATTRIBUTE_NOT_FOUND
}

struct XmlAttribute {
    char[] name;
    char[] value;
}

struct XmlNode {
    char[] name;
    char[] value;
    XmlNodeAttributes attributes;
    XmlNodeList children;
}

struct XmlDoc {
    XmlNode* rootNode;
}

fn XmlDoc* read_file(File file) {
    char[] buff = mem::new_array(char, 1024);
	defer mem::free(buff);

    XmlDoc* doc = mem::new(XmlDoc);
    Reader* reader = new_reader(doc);
	defer xml::free(reader);

    while (!file.eof()) {
		usz bytesRead = file.read(buff)!!;
		char[] data = buff[0:bytesRead];
		reader.read(data);
	}

    return doc;
}

fn void XmlDoc.free(&self) {
    free_node(self.rootNode);
    mem::free(self);
}

fn void free_node(XmlNode* node) @private {
    if (node == null) {
        return;
    }
    for (usz i = 0; i < node.children.size; i++) {
        XmlNode* child = node.children[i];
        free_node(child);
    }
    node.children.free();
    node.attributes.free();
    mem::free(node);
}

fn void XmlDoc.find_nodes_by_type(&self, char[] type, XmlNodeList* cache) {
    XmlNode* node = self.rootNode;
    node.find_nodes_by_type(type, cache);
}

fn void XmlNode.find_nodes_by_type(&self, char[] type, XmlNodeList* cache) {
    if (self.name == type) {
        cache.push(self);
    }

    for (usz i = 0; i < self.children.size; i++) {
        XmlNode* childNode = self.children[i];
        childNode.find_nodes_by_type(type, cache);
    }
}

fn char[]! XmlNode.get_attrib_value(&self, char[] name) {
    for (usz i = 0; i < self.attributes.size; i++) {
        XmlAttribute* attribute = self.attributes[i];
        if (attribute.name == name) {
            return attribute.value;
        }
    }
    return XmlFault.ATTRIBUTE_NOT_FOUND?;
}