import std::io;
import std::core;
import env::xml;

fn int main(String[] args)
{
	File xmlFile = io::file::open("test/test.xml", "r")!!;
	
	char[] buff = mem::new_array(char, 1024);
	defer mem::free(buff);

	xml::XmlParser* xmlParser = xml::new();
	defer xml::free(xmlParser);

	while (!xmlFile.eof()) {
		usz bytesRead = xmlFile.read(buff)!!;
		char[] slice = buff[0:bytesRead];
		//io::printf("bytes read: %d\n", slice.len);
		xmlParser.update(slice);
	}

	for (usz i = 0; i < xmlParser.root.children.size; i++) {
		XmlNode* child = xmlParser.root.children[i];
		printNode(child, 0, i, xmlParser.root.children.size);
	}

	//io::print("Done!\n");

	return 0;
}

fn void printNode(XmlNode* node, int depth, usz childIndex, usz childCount) {
	for (int i = 0; i < depth; i++) {
		io::printf("|");
	}
	// if (depth > 0) {
		
		if (node.children.size > 0) {
			io::print("+");
		} else {
			io::print("-");
		}

		// if (childIndex < childCount - 1) {
		// 	io::print("+ ");
		// } else {
		// 	io::print(" -");
		// }
	// }

	io::printf("%s Attrs: %d", node.name, node.attributes.size);

	for (usz i = 0; i < node.attributes.size; i++) {
		XmlAttribute* attribute = node.attributes[i];
		io::printf(", %s=\"%s\"", attribute.name, attribute.value);
	}

	io::print("\n");

	depth = depth + 1;
	for (usz i = 0; i < node.children.size; i++) {
		XmlNode* child = node.children[i];
		printNode(child, depth, i, node.children.size);
	}
}