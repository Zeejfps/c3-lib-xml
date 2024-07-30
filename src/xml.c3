module env::xml;

import std::core;
import std::io;
import std::collections;

def XmlNodeAttributes = List(<XmlAttribute*>);
def XmlNodeChildren = List(<XmlNode*>);

struct XmlRoot {
    XmlNodeChildren children; 
}

struct XmlAttribute {
    char[] name;
    char[] value;
}

struct XmlNode {
    char[] name;
    char[] value;
    XmlNodeAttributes attributes;
    XmlNodeChildren children;
}

enum ReaderState {
	READ_UNTIL_OPEN_BRACE,
    PARSE_HEADER,
    PARSE_TAG,
	PARSE_TAG_NAME,
    READ_TEXT_NODE,
    PARSE_CLOSING_TAG,
    PARSE_ATTRIBUTE_NAME,
    PARSE_ATTRIBUTE_VALUE,
    PARSE_ATTRIBUTE_VALUE_INNER,
    PARSE_COMMENT,
}

struct Reader {
	ReaderState state;
	usz readHead;
	usz writeHead;
    XmlRoot* root;
    char[] buffer;

    // Stack
    XmlNode*[] nodeStack;
    int stackHead;

    // ----
    XmlAttribute* attributeBeingParsed;
}

fn Reader* new_reader() {
	Reader* reader = mem::new(Reader);
	reader.buffer = mem::new_array(char, 1024);
    reader.root = mem::new(XmlRoot);
    reader.nodeStack = mem::new_array(XmlNode*, 10);
    reader.stackHead = -1;
    return reader;
}

fn void free(Reader* reader) {
    mem::free(reader.nodeStack);
    reader.stackHead = -1;
    mem::free(reader.buffer);
    for (usz i = 0; i < reader.root.children.size; i++) {
        XmlNode* child = reader.root.children[i];
        free_node(child);
    }
    reader.root.children.free();
    mem::free(reader.root);
    mem::free(reader);
}

fn void free_node(XmlNode* node) @private {
    for (usz i = 0; i < node.children.size; i++) {
        XmlNode* child = node.children[i];
        free_node(child);
    }
    node.children.free();
    node.attributes.free();
    mem::free(node);
}

fn void Reader.update(&self, char[] slice) {
	self.readHead = 0;
	while (self.readHead < slice.len) {
        char c = self.readChar(slice)!!;
		switch (self.state) {
			case PARSE_HEADER:
				self.parseHeader(c);
				break;
			case READ_UNTIL_OPEN_BRACE:
				self.readUntilOpenBrace(c);
				break;
			case PARSE_TAG:
				self.parseTag(c);
				break;
            case PARSE_TAG_NAME:
				self.parseTagName(c);
				break;
            case READ_TEXT_NODE:
                self.readTextNode(c);
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
            case PARSE_COMMENT:
                self.parse_comment(c);
                break;
		}
	}
}

fn char! Reader.readChar(&self, char[] slice) @private {
	usz readHead = self.readHead;
	if (readHead >= slice.len){
		return IoError.EOF?;
	}
	char c = slice[readHead];
	self.readHead = readHead + 1;
	return c;
}	

fn void Reader.writeChar(&self, char c) @private {
	usz writeHead = self.writeHead;
    if (writeHead >= self.buffer.len) {
        io::printf("%s\n", self.buffer);
    }
	self.buffer[writeHead] = c;
	self.writeHead = writeHead + 1;
}	

fn void Reader.push_node(&self, XmlNode* node) {
    self.stackHead += 1;
    self.nodeStack[self.stackHead] = node;
}

fn void Reader.pop_node(&self) {
    self.stackHead -= 1;
}

fn XmlNode* Reader.peek_node(&self) {
    if (self.stackHead < 0) {
        
        for (usz i = 0; i < self.nodeStack.len; i++) {
            XmlNode* prevNode = self.nodeStack[i];
            if (prevNode != null) {
                io::printf("[%d] Node %s, Value: %s", i, prevNode.name, prevNode.value);
                for (usz j = 0; j < prevNode.attributes.size; j++) {
                    XmlAttribute* attr = prevNode.attributes[j];
                    io::printf(", %s=\"%s\"", attr.name, attr.value);
                }
                io::print("\n");
            }
        }
    }
    return self.nodeStack[self.stackHead];
}

fn void Reader.readUntilOpenBrace(&self, char c) @private {
	if (c == '<') {
		self.state = ReaderState.PARSE_TAG;
	}
}

fn void Reader.parseTag(&self, char c) @private {
    if (c == '!') {
        // io::print("Parsing comment...\n");
        self.state = ReaderState.PARSE_COMMENT;
    } else if (c == '/') {
		// signify its a closing tag
        self.writeHead = 0;
		self.state = ReaderState.PARSE_CLOSING_TAG;
	} else if (c == '?') {
		self.state = PARSE_HEADER;
	} else {

        //io::print("Pushing node: ");
        self.writeHead = 0;
		self.writeChar(c);
        XmlNode* child = mem::new(XmlNode);
        if (self.stackHead < 0) {
            self.root.children.push(child);
        } else {
            self.nodeStack[self.stackHead].children.push(child);
        }

        self.push_node(child);

        self.state = ReaderState.PARSE_TAG_NAME;
	}
}

fn void Reader.parseTagName(&self, char c) @private {
	if (c == '/' || c == '>' || c == ' ') {
        XmlNode* nodeBeingParsed = self.peek_node();
        nodeBeingParsed.name = self.copy_write_buffer();
        //io::printf("%s\n", nodeBeingParsed.name);
        if (c == '>') {
            self.writeHead = 0;
            self.state = ReaderState.READ_TEXT_NODE;
        } else if (c == ' ') {
            self.writeHead = 0;
            self.attributeBeingParsed = mem::new(XmlAttribute);
            self.state = ReaderState.PARSE_ATTRIBUTE_NAME;
        } else if (c == '/') {
            self.state = ReaderState.PARSE_CLOSING_TAG;
        }
	} else {
		self.writeChar(c);
	}
}

fn void Reader.parseClosingTag(&self, char c) @private {
	if (c == '>') {      
        XmlNode* node = self.peek_node(); 
        //io::printf("Poping Node: %s\n", node.name); 
        self.pop_node();
		self.writeHead = 0;
        self.state = ReaderState.READ_TEXT_NODE;
	}
}

fn void Reader.enterReadTextNodeState(&self) @private {
    self.writeHead = 0;
    self.state = ReaderState.READ_TEXT_NODE;
}

fn void Reader.parseAttributeName(&self, char c) @private {
    if (c == '/') {
        self.state = ReaderState.PARSE_CLOSING_TAG;
    } else if (c == '>') {
        //io::print("Encountered closing brace before parsing attribute value?!\n");
        self.enterReadTextNodeState();
    } else if (c == ' ') {
        // Skip space
    } else if (c == '=') {
        char[] attributeName = self.copy_write_buffer();
        self.attributeBeingParsed.name = attributeName;
        //io::printf("Attribute Name %s\n", attributeName);
		self.state = ReaderState.PARSE_ATTRIBUTE_VALUE;
        self.writeHead = 0;
	} else {
        self.writeChar(c);
    }
}

fn void Reader.parseAttributeValue(&self, char c) @private {
    if (c == ' ') {
        // Skip
    } else if (c == '"') {
        self.state = ReaderState.PARSE_ATTRIBUTE_VALUE_INNER;
	} else {
        io::printf("Encountere unknown character %s\n", c);
    }
}

fn char[] Reader.copy_write_buffer(&self) @private {
    usz strLength = self.writeHead;
    char[] strValue = mem::new_array(char, strLength);
    mem::copy(strValue, self.buffer, strLength);
    return strValue;
}

fn void Reader.parseAttributeValueInner(&self, char c) @private {
	if (c == '"') {
        self.attributeBeingParsed.value = self.copy_write_buffer();
        XmlNode* nodeBeingParsed = self.peek_node();
        nodeBeingParsed.attributes.push(self.attributeBeingParsed);
        //io::printf("Attribute Value %s\n", self.attributeBeingParsed.value);
        self.attributeBeingParsed = mem::new(XmlAttribute);
        self.writeHead = 0;
		self.state = ReaderState.PARSE_ATTRIBUTE_NAME;
	} else {
        self.writeChar(c);
    }
}

fn void Reader.parseHeader(&self, char c) @private {
	if (c == '>') {
		self.state = ReaderState.READ_UNTIL_OPEN_BRACE;
	}
}

fn void Reader.readTextNode(&self, char c) @private {
	if (c == '<') {
        if (self.writeHead > 0) {
            char[] textNodeValue = self.copy_write_buffer();
            XmlNode* textNode = mem::new(XmlNode);
            textNode.name = "text";
            textNode.value = textNodeValue;
            // io::printf("%s\n", textNodeValue);
            XmlNode* nodeBeingParsed = self.peek_node();
            nodeBeingParsed.children.push(textNode);
        }
        self.writeHead = 0;
		self.state = ReaderState.PARSE_TAG;
	} else {
        self.writeChar(c);
    } 
}

fn void Reader.parse_comment(&self, char c) @private {
    self.writeChar(c);
    if (self.writeHead < 3) {
        return;
    }

    if (c != '>') {
        return;
    }

    char[] lastThreeChars = self.buffer[self.writeHead-3:3];
	if (lastThreeChars == "-->") {
        self.writeHead = 0;
		self.state = ReaderState.READ_UNTIL_OPEN_BRACE;
	}
}