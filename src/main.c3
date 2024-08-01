import std::io;
import std::core;
import env::xml;

fn void main(String[] args)
{
	File xmlFile = io::file::open("test/test.xml", "r")!!;
	File outFile = io::file::open("test/out.txt", "w")!!;

	XmlDoc* doc = xml::read_file(xmlFile)!!;
	defer doc.free();
	io::printf("Is NUll: %b\n", doc.rootNode == null);

	XmlNodeList bookNodes;
	defer bookNodes.free();
	doc.find_nodes_by_tag_name("book", &bookNodes);
	io::printf("book nodes %d\n", bookNodes.size);

	foreach (node : bookNodes) {
		char[]! id = node.get_attrib_value("id");
		if (catch err = id) {
			io::printf("attribute not found\n");
			continue;
		}
		io::printf("Id %s\n", id);
	}

	printNode(outFile, doc.rootNode, 0, 0, doc.rootNode.children.size);
}

fn void printNode(File outFile, XmlNode* node, int depth, usz childIndex, usz childCount) {

	OutStream stream = (OutStream)&outFile;

	for (int i = 0; i < depth; i++) {
		//io::print("|");
		io::fprintf(stream, "%c", '├')!!;
	}
	// if (depth > 0) {
		
		if (node.children.size > 0) {
			//io::print("+");
			io::fprint(stream, "+")!!;
		} else {
			//io::print("-");
			io::fprint(stream, "-")!!;
		}

		// if (childIndex < childCount - 1) {
		// 	io::print("+ ");
		// } else {
		// 	io::print(" -");
		// }
	// }

	//io::printf("%s", node.name, node.attributes.size);
	io::fprintf(stream, "%s", node.name, node.attributes.size)!!;
	for (usz i = 0; i < node.attributes.size; i++) {
		XmlAttribute* attribute = node.attributes[i];
		//io::printf(", %s=\"%s\"", attribute.name, attribute.value);
		io::fprintf(stream, ", %s=\"%s\"", attribute.name, attribute.value)!!;
	}

	if (node.value.len > 0) {
		String v = (String)node.value;
		String trimmed = v.trim();
		if (trimmed.len > 0) {
			// io::printf(" Value: %s", trimmed);
			io::fprintf(stream, " Value: %s", trimmed)!!;
		}
	}

	io::fprint(stream, "\n")!!;
	//io::printf("\n");

	depth = depth + 1;
	for (usz i = 0; i < node.children.size; i++) {
		XmlNode* child = node.children[i];
		printNode(outFile, child, depth, i, node.children.size);
	}
}