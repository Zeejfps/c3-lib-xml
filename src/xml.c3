module xml;

import std::core;
import std::io;
import std::collections;

def XmlNodeAttributes = List(<XmlAttribute>);
def XmlNodeChildren = List(<XmlNode*>);

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
    char[] value;
    XmlAttributes attributes;
    XmlNodeChildren children;
}

enum XmlParserState {
	READ_UNTIL_OPEN_BRACE,
	PARSE_TAG_NAME,
	DETECT_CLOSING_TAG,
	PARSE_HEADER,
    PARSE_CLOSING_TAG,
    PARSE_ATTRIBUTE_NAME,
    PARSE_ATTRIBUTE_VALUE,
    PARSE_ATTRIBUTE_VALUE_INNER,
    PARSE_NODE_VALUE,
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
    xmlParser.nodeStack = mem::new_array(XmlNode*, 10);
    xmlParser.stackHead = -1;
    return xmlParser;
}

fn void free(XmlParser* xmlParser) {
    mem::free(xmlParser.nodeStack);
    xmlParser.stackHead = -1;
    mem::free(xmlParser.buffer);
    for (usz i = 0; i < xmlParser.root.children.size; i++) {
        XmlNode* child = xmlParser.root.children[i];
        mem::free(child);
    }
    xmlParser.root.children.free();
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
            case PARSE_ATTRIBUTE_NAME:
                this.parseAttributeName(slice);
                break;
            case PARSE_ATTRIBUTE_VALUE:
                this.parseAttributeValue(slice);
                break;
            case PARSE_ATTRIBUTE_VALUE_INNER:
                this.parseAttributeValueInner(slice);
                break;
            case PARSE_NODE_VALUE:
                this.parseNodeValue(slice);
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
        if (this.stackHead < 0) {
            this.root.children.push(child);
        } else {
            this.nodeStack[this.stackHead].children.push(child);
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
            this.state = XmlParserState.PARSE_NODE_VALUE;
        } else if (c == ' ') {
            this.state = XmlParserState.PARSE_ATTRIBUTE_NAME;
        }
	} else {
		this.writeChar(c);
	}
}

fn void XmlParser.parseClosingTag(XmlParser* this, char[] slice) {
	char c = this.readChar(slice)!!;
	if (c == '>') {
		this.state = XmlParserState.PARSE_NODE_VALUE;
        
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

fn void XmlParser.parseAttributeName(&self, char[] slice) {
	char c = self.readChar(slice)!!;
    if (c == '>') {
        io::print("Encountered closing brace before parsing attribute value?!\n");
        self.state = XmlParserState.PARSE_NODE_VALUE;
    } else if (c == ' ') {
        // Skip space
    } else if (c == '=') {
        char[] attributeName = self.buffer[0:self.writeHead];
        io::printf("Attribute Name %s\n", attributeName);
		self.state = XmlParserState.PARSE_ATTRIBUTE_VALUE;
        self.writeHead = 0;
	} else {
        self.writeChar(c);
    }
}

fn void XmlParser.parseAttributeValue(&self, char[] slice) {
	char c = self.readChar(slice)!!;
    if (c == ' ') {
        // Skip
    } else if (c == '"') {
        self.state = XmlParserState.PARSE_ATTRIBUTE_VALUE_INNER;
	} else {
        io::printf("Encountere unknown character %s\n", c);
    }
}

fn void XmlParser.parseAttributeValueInner(&self, char[] slice) {
	char c = self.readChar(slice)!!;
	if (c == '"') {
        char[] attributeValue = self.buffer[0:self.writeHead];
        io::printf("Attribute Value %s\n", attributeValue);
		self.state = XmlParserState.PARSE_ATTRIBUTE_NAME;
        self.writeHead = 0;
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

fn void XmlParser.parseNodeValue(&self, char[] slice) {
	char c = self.readChar(slice)!!;
	if (c == '<') {
        String innerText = (String)self.buffer[0:self.writeHead];
        String trimmedInnerText = innerText.trim();
        // String s;
        // s.trim(" ");
        io::printf("Inner Text: %s\n", trimmedInnerText);
		self.state = XmlParserState.DETECT_CLOSING_TAG;
	} else {
        self.writeChar(c);
    } 
}