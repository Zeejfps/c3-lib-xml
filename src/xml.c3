module env::xml;
import std::io;
import std::collections;

def XmlNodeAttributes = List(<XmlAttribute*>);
def XmlNodeChildren = List(<Node*>);

struct XmlAttribute {
    char[] name;
    char[] value;
}

struct Node {
    char[] type;
    char[] value;
    XmlNodeAttributes attributes;
    XmlNodeChildren children;
}

struct Doc {
    Node* rootNode;
}

fn Doc* read_file(File file) {
    char[] buff = mem::new_array(char, 1024);
	defer mem::free(buff);

    Doc* doc = mem::new(Doc);
    Reader* reader = new_reader(doc);
	defer xml::free(reader);

    while (!file.eof()) {
		usz bytesRead = file.read(buff)!!;
		char[] data = buff[0:bytesRead];
		reader.read(data);
	}

    return doc;
}

fn void Doc.free(&self) {
    free_node(self.rootNode);
    mem::free(self);
}

fn void free_node(Node* node) @private {
    if (node == null) {
        return;
    }
    for (usz i = 0; i < node.children.size; i++) {
        Node* child = node.children[i];
        free_node(child);
    }
    node.children.free();
    node.attributes.free();
    mem::free(node);
}