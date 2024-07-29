import std::io;
import std::core;
import xml;

fn int main(String[] args)
{
	File xmlFile = io::file::open("test/test.xml", "r")!!;
	
	char[] buff = mem::new_array(char, 256);
	defer mem::free(buff);

	xml::XmlParser* xmlParser = mem::new(XmlParser);
	defer mem::free(xmlParser);

	xmlParser.buffer = mem::new_array(char, 64);
	defer mem::free(xmlParser.buffer);

	while (!xmlFile.eof()) {
		usz bytesRead = xmlFile.read(buff)!!;
		char[] slice = buff[0:bytesRead];
		io::printf("bytes read: %d\n", slice.len);
		xmlParser.update(slice);
	}

	return 0;
}