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
	doc.print_as_tree(stream);
}