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
    PARSE_HEADER,
    PARSE_TAG,
	PARSE_TAG_NAME,
    PARSE_TAG_VALUE,
    PARSE_CLOSING_TAG,
    PARSE_ATTRIBUTE_NAME,
    PARSE_ATTRIBUTE_VALUE,
    PARSE_ATTRIBUTE_VALUE_INNER,
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

fn void XmlParser.update(&self, char[] slice) {
	self.readHead = 0;
	while (self.readHead < slice.len) {
        char c = self.readChar(slice)!!;
		switch (self.state) {
			case PARSE_HEADER:
				self.readHeader(c);
				break;
			case READ_UNTIL_OPEN_BRACE:
				self.readUntilOpenBrace(c);
				break;
			case PARSE_TAG_NAME:
				self.parseNodeName(c);
				break;
			case PARSE_TAG:
				self.parseTag(c);
				break;
            case PARSE_CLOSING_TAG:
                self.parseClosingTag(c);
                break;
            case PARSE_ATTRIBUTE_NAME:
                self.parseAttributeName(c);
                break;
            case PARSE_ATTRIBUTE_VALUE:
                self.parseAttributeValue(c);
                break;
            case PARSE_ATTRIBUTE_VALUE_INNER:
                self.parseAttributeValueInner(c);
                break;
            case PARSE_TAG_VALUE:
                self.parseNodeValue(c);
                break;
		}
	}
}

fn char! XmlParser.readChar(XmlParser* this, char[] slice) @private {
	usz readHead = this.readHead;
	if (readHead >= slice.len){
		return IoError.EOF?;
	}
	char c = slice[readHead];
	this.readHead = readHead + 1;
	return c;
}	

fn void XmlParser.writeChar(XmlParser* this, char c) @private {
	usz writeHead = this.writeHead;
	this.buffer[writeHead] = c;
	this.writeHead = writeHead + 1;
}	

fn void XmlParser.readUntilOpenBrace(XmlParser* this, char c) @private {
	if (c == '<') {
		this.state = XmlParserState.PARSE_TAG;
	}
}

fn void XmlParser.parseTag(XmlParser* this, char c) @private {
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
        XmlNode* child = mem::new(XmlNode);
        if (this.stackHead < 0) {
            this.root.children.push(child);
        } else {
            this.nodeStack[this.stackHead].children.push(child);
        }

        this.stackHead += 1;
        this.nodeStack[this.stackHead] = child;

        this.state = XmlParserState.PARSE_TAG_NAME;
	}
}

fn void XmlParser.parseNodeName(XmlParser* this, char c) {
	if (c == '>' || c == ' ') {
        usz tagNameLength = this.writeHead;
        XmlNode* child = this.nodeStack[this.stackHead];
        child.name = mem::new_array(char, tagNameLength);
        mem::copy(child.name, this.buffer, tagNameLength);
        io::printf("%s\n", child.name);
		this.writeHead = 0;

        if (c == '>') {
            this.state = XmlParserState.PARSE_TAG_VALUE;
        } else if (c == ' ') {
            this.state = XmlParserState.PARSE_ATTRIBUTE_NAME;
        }
	} else {
		this.writeChar(c);
	}
}

fn void XmlParser.parseClosingTag(XmlParser* this, char c) {
	if (c == '>') {
		this.state = XmlParserState.PARSE_TAG_VALUE;
        
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

fn void XmlParser.parseAttributeName(&self, char c) {
    if (c == '>') {
        io::print("Encountered closing brace before parsing attribute value?!\n");
        self.state = XmlParserState.PARSE_TAG_VALUE;
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

fn void XmlParser.parseAttributeValue(&self, char c) {
    if (c == ' ') {
        // Skip
    } else if (c == '"') {
        self.state = XmlParserState.PARSE_ATTRIBUTE_VALUE_INNER;
	} else {
        io::printf("Encountere unknown character %s\n", c);
    }
}

fn void XmlParser.parseAttributeValueInner(&self, char c) {
	if (c == '"') {
        char[] attributeValue = self.buffer[0:self.writeHead];
        io::printf("Attribute Value %s\n", attributeValue);
		self.state = XmlParserState.PARSE_ATTRIBUTE_NAME;
        self.writeHead = 0;
	} else {
        self.writeChar(c);
    }
}

fn void XmlParser.readHeader(XmlParser* this, char c) {
	if (c == '>') {
		this.state = XmlParserState.READ_UNTIL_OPEN_BRACE;
	}
}

fn void XmlParser.parseNodeValue(&self, char c) {
	if (c == '<') {
        String innerText = (String)self.buffer[0:self.writeHead];
        String trimmedInnerText = innerText.trim();
        // String s;
        // s.trim(" ");
        io::printf("Inner Text: %s\n", trimmedInnerText);
		self.state = XmlParserState.PARSE_TAG;
	} else {
        self.writeChar(c);
    } 
}