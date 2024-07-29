module xml_parser;
import std::io;
import std::core;

fn int main(String[] args)
{
	File xmlFile = io::file::open("test/test.xml", "r")!!;
	
	char[] buff = mem::new_array(char, 256);
	defer mem::free(buff);

	XmlParser* xmlParser = mem::new(XmlParser);
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

struct XmlParser {
	XmlParserState state;
	usz readHead;
	usz writeHead;
	char[] buffer;
}

enum XmlParserState {
	READ_UNTIL_OPEN_BRACE,
	READ_UNTIL_CLOSE_BRACE,
}

fn void XmlParser.update(XmlParser* this, char[] slice) {
	this.readHead = 0;
	while (this.readHead < slice.len) {
		switch (this.state) {
			case READ_UNTIL_OPEN_BRACE:
				this.readUntilOpenBrace(slice);
				break;
			case READ_UNTIL_CLOSE_BRACE:
				this.readCloseBrace(slice);
				break;
		}
	}
}

fn char! XmlParser.readChar(XmlParser* this, char[] slice) {
	usz readHead = this.readHead;
	if (readHead >= slice.len){
		return IoError.EOF?;
	}
	char c = slice[readHead];
	this.readHead = readHead + 1;
	return c;
}	

fn void XmlParser.writeChar(XmlParser* this, char c) {
	usz writeHead = this.writeHead;
	this.buffer[writeHead] = c;
	this.writeHead = writeHead + 1;
}	

fn void XmlParser.readUntilOpenBrace(XmlParser* this, char[] slice) {
	char c = this.readChar(slice)!!;
	if (c == '<') {
		this.state = XmlParserState.READ_UNTIL_CLOSE_BRACE;
	}
}

fn void XmlParser.readCloseBrace(XmlParser* this, char[] slice) {
	char c = this.readChar(slice)!!;
	if (c == '>') {
		this.state = XmlParserState.READ_UNTIL_OPEN_BRACE;
		char[] tagName = this.buffer[0:this.writeHead];
		this.writeHead = 0;
		io::printf("Tag %s\n", tagName);
	} else {
		this.writeChar(c);
	}
}