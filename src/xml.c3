module xml;

import std::io;

struct XmlNodeChildren {
    XmlNode** nodes;
    usz count;
}

struct XmlRoot {
    XmlNodeChildren children; 
}

struct XmlNode {
    char[] name;
    XmlNodeChildren children;
}

enum XmlParserState {
	READ_UNTIL_OPEN_BRACE,
	READ_UNTIL_CLOSE_BRACE,
	DETECT_CLOSING_TAG,
	READ_HEADER,
}

struct XmlParser {
	XmlParserState state;
	usz readHead;
	usz writeHead;
	char[] buffer;
    XmlRoot* root;
}

fn XmlParser* new() {
	xml::XmlParser* xmlParser = mem::new(XmlParser);
	xmlParser.buffer = mem::new_array(char, 64);
    xmlParser.root = mem::new(XmlRoot);
    xmlParser.root.children.nodes = mem::new_array(XmlNode*,50);
    xmlParser.root.children.count = 0;
    return xmlParser;
}

fn void free(XmlParser* xmlParser) {
    mem::free(xmlParser.buffer);
    mem::free(xmlParser);
    for (usz i = 0; i < xmlParser.root.children.count; i++) {
        XmlNode* child = xmlParser.root.children.nodes[i];
        mem::free(child);
    }
    mem::free(xmlParser.root);
}

fn void XmlParser.update(XmlParser* this, char[] slice) {
	this.readHead = 0;
	while (this.readHead < slice.len) {
		switch (this.state) {
			case READ_HEADER:
				this.readHeader(slice);
				break;
			case READ_UNTIL_OPEN_BRACE:
				this.readUntilOpenBrace(slice);
				break;
			case READ_UNTIL_CLOSE_BRACE:
				this.readCloseBrace(slice);
				break;
			case DETECT_CLOSING_TAG:
				this.detectClosingTag(slice);
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
		this.state = XmlParserState.DETECT_CLOSING_TAG;
	}
}

fn void XmlParser.detectClosingTag(XmlParser* this, char[] slice) {
	char c = this.readChar(slice)!!;
	if (c == '/') {
		// signify its a closing tag
		this.state = XmlParserState.READ_UNTIL_CLOSE_BRACE;
	} else if (c == '?') {
		this.state = READ_HEADER;
	} else {
		this.writeChar(c);
		this.state = XmlParserState.READ_UNTIL_CLOSE_BRACE;
	}
}

fn void XmlParser.readCloseBrace(XmlParser* this, char[] slice) {
	char c = this.readChar(slice)!!;
	if (c == '>') {
		this.state = XmlParserState.READ_UNTIL_OPEN_BRACE;

        XmlNode* child =  mem::new(XmlNode);
        usz tagNameLength = this.writeHead + 1;
        child.name = mem::new_array(char, tagNameLength);
        mem::copy(child.name, this.buffer, tagNameLength);

        usz newChildIndex = this.root.children.count;
        this.root.children.nodes[newChildIndex] = child;
        this.root.children.count++;

		// char[] tagName = this.buffer[0:this.writeHead];
		this.writeHead = 0;

		//io::printf("Child %d\n", newChildIndex);
	} else {
		this.writeChar(c);
	}
}

fn void XmlParser.readHeader(XmlParser* this, char[] slice) {
	char c = this.readChar(slice)!!;
	if (c == '>') {
		this.state = XmlParserState.READ_UNTIL_OPEN_BRACE;
	}
}