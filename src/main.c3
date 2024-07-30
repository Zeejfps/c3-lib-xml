import std::io;
import std::core;
import xml;

fn int main(String[] args)
{
	File xmlFile = io::file::open("test/test.xml", "r")!!;
	
	char[] buff = mem::new_array(char, 256);
	defer mem::free(buff);

	xml::XmlParser* xmlParser = xml::new();
	defer xml::free(xmlParser);

	while (!xmlFile.eof()) {
		usz bytesRead = xmlFile.read(buff)!!;
		char[] slice = buff[0:bytesRead];
		io::printf("bytes read: %d\n", slice.len);
		xmlParser.update(slice);
	}

	for (usz i = 0; i < xmlParser.root.children.count; i++) {
		XmlNode* child = xmlParser.root.children.nodes[i];
		printNode(child, 0, i, xmlParser.root.children.count);
	}

	io::print("Done!\n");

	return 0;
}

fn void printNode(XmlNode* node, int depth, usz childIndex, usz childCount) {
	for (int i = 0; i < depth; i++) {
		io::printf("|");
	}
	// if (depth > 0) {
		
		if (node.children.count > 0) {
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

	io::printf("%s\n", node.name);

	depth = depth + 1;
	for (usz i = 0; i < node.children.count; i++) {
		XmlNode* child = node.children.nodes[i];
		printNode(child, depth, i, node.children.count);
	}
}