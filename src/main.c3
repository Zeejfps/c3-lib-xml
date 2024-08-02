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

	OutStream stream = (OutStream)&outFile;
	printNode(stream, doc.rootNode, 0, 0, 0);
}

fn void printNode(OutStream stream, XmlNode* node, int depth, usz childIndex, usz childCount) {

	for (int i = 0; i < depth - 1; i++) {
		io::fprintf(stream, "%c", '│')!!;
	}

	if (childCount > 0) {
		if(childIndex == childCount - 1) {
			io::fprintf(stream, "%c", '└')!!;
		} else {
			io::fprintf(stream, "%c", '├')!!;
		}
	}

	io::fprintf(stream, "%s", node.name, node.attributes.size)!!;
	for (usz i = 0; i < node.attributes.size; i++) {
		XmlAttribute* attribute = node.attributes[i];
		io::fprintf(stream, ", %s=\"%s\"", attribute.name, attribute.value)!!;
	}

	if (node.value.len > 0) {
		String v = (String)node.value;
		String trimmed = v.trim();
		if (trimmed.len > 0) {
			io::fprintf(stream, " \"%s\"", trimmed)!!;
		}
	}

	io::fprint(stream, "\n")!!;

	depth = depth + 1;
	for (usz i = 0; i < node.children.size; i++) {
		XmlNode* child = node.children[i];
		printNode(stream, child, depth, i, node.children.size);
	}
}