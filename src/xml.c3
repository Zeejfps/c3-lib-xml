module xml;

import std::io;

struct XmlParser {
	XmlParserState state;
	usz readHead;
	usz writeHead;
	char[] buffer;
}

enum XmlParserState {
	READ_UNTIL_OPEN_BRACE,
	READ_UNTIL_CLOSE_BRACE,
	DETECT_CLOSING_TAG,
	READ_HEADER,
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
		char[] tagName = this.buffer[0:this.writeHead];
		this.writeHead = 0;
		io::printf("Tag %s\n", tagName);
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