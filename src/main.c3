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
		io::printf("%s\n", child.name);
	}

	io::print("Done!\n");

	return 0;
}