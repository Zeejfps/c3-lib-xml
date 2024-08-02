module env::xml;
import std::io;
import std::collections;

def XmlAttributeList = List(<XmlAttribute*>);
def XmlNodeList = List(<XmlNode*>);

fault XmlFault {
	ATTRIBUTE_NOT_FOUND
}

interface IXmlDoc {
    fn XmlNode* get_root_node();
    fn void find_nodes_by_tag_name(String tagName, XmlNodeList* cache);
    fn void free();
}

struct XmlAttribute {
	String name;
	String value;
    Allocator allocator;
}

struct XmlNode {
	String name;
	String value;
	XmlAttributeList attributes;
	XmlNodeList children;
    Allocator allocator;
}

struct XmlDoc (IXmlDoc) {
	Allocator allocator;
	XmlNode* rootNode;
}

fn IXmlDoc! read_file(File file, Allocator allocator = allocator::heap()) {
	char[] buff = allocator::new_array(allocator, char, 2048);
	defer allocator::free(allocator, buff);

	XmlDoc* doc = allocator::new(allocator, XmlDoc);
	doc.allocator = allocator;

	XmlReader* reader = new_reader(doc, allocator);
	defer reader.free();

	while (!file.eof()) {
		usz! bytesRead = file.read(buff);
		if (catch f = bytesRead) {
			return f?;
		}
		char[] data = buff[0:bytesRead];
		reader.read(data);
	}

	return doc;
}

fn XmlNode* XmlDoc.get_root_node(&self) @dynamic {
    return self.rootNode;
}

fn void XmlDoc.free(&self) @dynamic {
	if (!self.allocator) return;
	self.rootNode.free();
	allocator::free(self.allocator, self);
}

fn void XmlNode.free(&node) {
	if (node.allocator == null) {
		return;
	}

    // NOTE(Zee): Does it make sense for the node to free its own children?
    foreach(child : node.children) {
		child.free();
    }

    foreach(attribute : node.attributes) {
        attribute.free();
    }

	node.children.free();
	node.attributes.free();
	node.name.free(node.allocator);
	node.value.free(node.allocator);

    // TODO: Free Name and Value
	allocator::free(node.allocator, node);
}

fn void XmlAttribute.free(&self) {
	if (self.allocator == null) {
		return;
	}
	self.name.free(self.allocator);
	self.value.free(self.allocator);
    // TODO: Free Name and Value;
	allocator::free(self.allocator, self);
}

fn void XmlDoc.find_nodes_by_tag_name(&self, String type, XmlNodeList* cache) @dynamic {
	XmlNode* node = self.rootNode;
	node.find_nodes_by_tag_name(type, cache);
}

fn void XmlNode.find_nodes_by_tag_name(&self, String type, XmlNodeList* cache) {
	if (self.name == type) {
		cache.push(self);
	}

	for (usz i = 0; i < self.children.size; i++) {
		XmlNode* childNode = self.children[i];
		childNode.find_nodes_by_tag_name(type, cache);
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