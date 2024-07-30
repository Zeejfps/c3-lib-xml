import std::io;
import std::core;
import env::xml;

fn int main(String[] args)
{
	File xmlFile = io::file::open("test/gl.xml", "r")!!;
	File outFile = io::file::open("test/out.txt", "w")!!;
	
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
		printNode(outFile, child, 0, i, xmlParser.root.children.size);
	}

	//io::print("Done!\n");

	return 0;
}

fn void printNode(File outFile, XmlNode* node, int depth, usz childIndex, usz childCount) {

	OutStream stream = (OutStream)&outFile;

	for (int i = 0; i < depth; i++) {
		//io::print("|");
		io::fprint(stream, "|")!!;
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