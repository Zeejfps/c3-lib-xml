module xml;

import std::io;

struct XmlNodeChildren {
    XmlNode** nodes;
    usz count;
}

struct XmlRoot {
    XmlNodeChildren children; 
}

struct XmlAttribute {
    char[] name;
    char[] value;
}

struct XmlAttributes {
    XmlAttribute** attributes;
    usz count;
}

struct XmlNode {
    char[] name;
    XmlAttributes attributes;
    XmlNodeChildren children;
}

enum XmlParserState {
	READ_UNTIL_OPEN_BRACE,
	PARSE_TAG_NAME,
	DETECT_CLOSING_TAG,
	PARSE_HEADER,
    PARSE_CLOSING_TAG,
    PARSE_ATTRIBUTE,
}

struct XmlParser {
	XmlParserState state;
	usz readHead;
	usz writeHead;
    XmlRoot* root;
    char[] buffer;

    // Stack
    XmlNode*[] nodeStack;
    int stackHead;
}

fn XmlParser* new() {
	xml::XmlParser* xmlParser = mem::new(XmlParser);
	xmlParser.buffer = mem::new_array(char, 64);
    xmlParser.root = mem::new(XmlRoot);
    xmlParser.root.children.nodes = mem::new_array(XmlNode*,50);
    xmlParser.root.children.count = 0;
    xmlParser.nodeStack = mem::new_array(XmlNode*, 10);
    xmlParser.stackHead = -1;
    return xmlParser;
}

fn void free(XmlParser* xmlParser) {
    mem::free(xmlParser.nodeStack);
    xmlParser.stackHead = -1;
    mem::free(xmlParser.buffer);
    for (usz i = 0; i < xmlParser.root.children.count; i++) {
        XmlNode* child = xmlParser.root.children.nodes[i];
        mem::free(child);
    }
    mem::free(xmlParser.root.children.nodes);
    mem::free(xmlParser.root);
    mem::free(xmlParser);
}

fn void XmlParser.update(XmlParser* this, char[] slice) {
	this.readHead = 0;
	while (this.readHead < slice.len) {
		switch (this.state) {
			case PARSE_HEADER:
				this.readHeader(slice);
				break;
			case READ_UNTIL_OPEN_BRACE:
				this.readUntilOpenBrace(slice);
				break;
			case PARSE_TAG_NAME:
				this.parseTagName(slice);
				break;
			case DETECT_CLOSING_TAG:
				this.detectClosingTag(slice);
				break;
            case PARSE_CLOSING_TAG:
                this.parseClosingTag(slice);
                break;
            case PARSE_ATTRIBUTE:
                this.parseAttribute(slice);
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
        this.writeHead = 0;
		this.state = XmlParserState.PARSE_CLOSING_TAG;
	} else if (c == '?') {
		this.state = PARSE_HEADER;
	} else {

        io::print("Pushing node: ");
        this.writeHead = 0;
		this.writeChar(c);
		this.state = XmlParserState.PARSE_TAG_NAME;

        XmlNode* child = mem::new(XmlNode);
        child.children.nodes = mem::new_array(XmlNode*, 10);
        child.children.count = 0;
        if (this.stackHead < 0) {
            this.root.children.add(child);
        } else {
            this.nodeStack[this.stackHead].children.add(child);
        }

        this.stackHead += 1;
        this.nodeStack[this.stackHead] = child;
	}
}

fn void XmlParser.parseTagName(XmlParser* this, char[] slice) {
	char c = this.readChar(slice)!!;
	if (c == '>' || c == ' ') {
        usz tagNameLength = this.writeHead;
        XmlNode* child = this.nodeStack[this.stackHead];
        child.name = mem::new_array(char, tagNameLength);
        mem::copy(child.name, this.buffer, tagNameLength);
        io::printf("%s\n", child.name);
		this.writeHead = 0;

        if (c == '>') {
            this.state = XmlParserState.READ_UNTIL_OPEN_BRACE;
        } else if (c == ' ') {
            this.state = XmlParserState.PARSE_ATTRIBUTE;
        }
	} else {
		this.writeChar(c);
	}
}

fn void XmlParser.parseClosingTag(XmlParser* this, char[] slice) {
	char c = this.readChar(slice)!!;
	if (c == '>') {
		this.state = XmlParserState.READ_UNTIL_OPEN_BRACE;
        
        usz tagNameLength = this.writeHead;
        XmlNode* child = this.nodeStack[this.stackHead];
        char[] tagName = this.buffer[0:tagNameLength];

        if (child.name != tagName){
            io::printf("Opening and closing tag name missmatch. Expected %s found %s\n", child.name, tagName);
        }

        this.stackHead -= 1;
		this.writeHead = 0;
		io::printf("Poping Node %s\n", tagName);
	} else {
		this.writeChar(c);
	}
}

fn void XmlParser.parseAttribute(&self, char[] slice) {
	char c = self.readChar(slice)!!;
	if (c == '>') {
        char[] attribute = self.buffer[0:self.writeHead];
        io::printf("Attribute %s\n", attribute);
		self.state = XmlParserState.READ_UNTIL_OPEN_BRACE;
	} else {
        self.writeChar(c);
    }
}

fn void XmlParser.readHeader(XmlParser* this, char[] slice) {
	char c = this.readChar(slice)!!;
	if (c == '>') {
		this.state = XmlParserState.READ_UNTIL_OPEN_BRACE;
	}
}

fn void XmlNodeChildren.add(XmlNodeChildren* this, XmlNode* child) {
    usz index = this.count;
    this.nodes[index] = child;
    this.count = index + 1;
}