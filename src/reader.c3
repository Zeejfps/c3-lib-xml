module env::xml;

import std::core;
import std::io;

enum ReaderState {
	READ_UNTIL_OPEN_BRACE,
    READ_HEADER,
    READ_TAG,
	READ_TAG_NAME,
    READ_TEXT_NODE,
    READ_CLOSING_TAG,
    READ_ATTRIBUTE_NAME,
    READ_ATTRIBUTE_VALUE,
    READ_ATTRIBUTE_VALUE_INNER,
    READ_COMMENT,
}

struct XmlReader {
	ReaderState state;
	usz readHead;
	usz writeHead;
    char[] buffer;

    XmlDoc* doc;

    // Stack
    XmlNode*[] nodeStack;
    int stackHead;

    // ----
    XmlAttribute* attributeBeingParsed;
}

fn XmlReader* new_reader(XmlDoc* doc) {
	XmlReader* reader = mem::new(XmlReader);
    reader.doc = doc;
	reader.buffer = mem::new_array(char, 1024);
    reader.nodeStack = mem::new_array(XmlNode*, 10);
    reader.stackHead = -1;
    return reader;
}

fn void XmlReader.free(&self) {
    mem::free(self.nodeStack);
    mem::free(self.buffer);
    mem::free(self);
}

fn void XmlReader.read(&self, char[] slice) {
	self.readHead = 0;
	while (self.readHead < slice.len) {
        char c = self.readChar(slice)!!;
		switch (self.state) {
			case READ_HEADER:
				self.parseHeader(c);
				break;
			case READ_UNTIL_OPEN_BRACE:
				self.readUntilOpenBrace(c);
				break;
			case READ_TAG:
				self.parseTag(c);
				break;
            case READ_TAG_NAME:
				self.parseTagName(c);
				break;
            case READ_TEXT_NODE:
                self.readTextNode(c);
                break;
            case READ_CLOSING_TAG:
                self.parseClosingTag(c);
                break;
            case READ_ATTRIBUTE_NAME:
                self.parseAttributeName(c);
                break;
            case READ_ATTRIBUTE_VALUE:
                self.parseAttributeValue(c);
                break;
            case READ_ATTRIBUTE_VALUE_INNER:
                self.parseAttributeValueInner(c);
                break;
            case READ_COMMENT:
                self.parse_comment(c);
                break;
		}
	}
}

fn char! XmlReader.readChar(&self, char[] slice) @private {
	usz readHead = self.readHead;
	if (readHead >= slice.len){
		return IoError.EOF?;
	}
	char c = slice[readHead];
	self.readHead = readHead + 1;
	return c;
}	

fn void XmlReader.writeChar(&self, char c) @private {
	usz writeHead = self.writeHead;
    if (writeHead >= self.buffer.len) {
        io::printf("%s\n", self.buffer);
    }
	self.buffer[writeHead] = c;
	self.writeHead = writeHead + 1;
}	

fn void XmlReader.push_node(&self, XmlNode* node) {
    self.stackHead += 1;
    self.nodeStack[self.stackHead] = node;
}

fn void XmlReader.pop_node(&self) {
    self.stackHead -= 1;
}

fn XmlNode* XmlReader.peek_node(&self) {
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

fn void XmlReader.readUntilOpenBrace(&self, char c) @private {
	if (c == '<') {
		self.state = ReaderState.READ_TAG;
	}
}

fn void XmlReader.parseTag(&self, char c) @private {
    if (c == '!') {
        // io::print("Parsing comment...\n");
        self.state = ReaderState.READ_COMMENT;
    } else if (c == '/') {
		// signify its a closing tag
        self.writeHead = 0;
		self.state = ReaderState.READ_CLOSING_TAG;
	} else if (c == '?') {
		self.state = READ_HEADER;
	} else {

        //io::print("Pushing node: ");
        self.writeHead = 0;
		self.writeChar(c);
        XmlNode* child = mem::new(XmlNode);
        if (self.doc.rootNode == null) {
            self.doc.rootNode = child;
        } else {
            XmlNode* nodeBeingParsed = self.peek_node();
            nodeBeingParsed.children.push(child);
        }

        self.push_node(child);

        self.state = ReaderState.READ_TAG_NAME;
	}
}

fn void XmlReader.parseTagName(&self, char c) @private {
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
            self.state = ReaderState.READ_ATTRIBUTE_NAME;
        } else if (c == '/') {
            self.state = ReaderState.READ_CLOSING_TAG;
        }
	} else {
		self.writeChar(c);
	}
}

fn void XmlReader.parseClosingTag(&self, char c) @private {
	if (c == '>') {      
        XmlNode* node = self.peek_node(); 
        //io::printf("Poping Node: %s\n", node.name); 
        self.pop_node();
		self.writeHead = 0;
        self.state = ReaderState.READ_TEXT_NODE;
	}
}

fn void XmlReader.enterReadTextNodeState(&self) @private {
    self.writeHead = 0;
    self.state = ReaderState.READ_TEXT_NODE;
}

fn void XmlReader.parseAttributeName(&self, char c) @private {
    if (c == '/') {
        self.state = ReaderState.READ_CLOSING_TAG;
    } else if (c == '>') {
        //io::print("Encountered closing brace before parsing attribute value?!\n");
        self.enterReadTextNodeState();
    } else if (c == ' ') {
        // Skip space
    } else if (c == '=') {
        char[] attributeName = self.copy_write_buffer();
        self.attributeBeingParsed.name = attributeName;
        //io::printf("Attribute Name %s\n", attributeName);
		self.state = ReaderState.READ_ATTRIBUTE_VALUE;
        self.writeHead = 0;
	} else {
        self.writeChar(c);
    }
}

fn void XmlReader.parseAttributeValue(&self, char c) @private {
    if (c == ' ') {
        // Skip
    } else if (c == '"') {
        self.state = ReaderState.READ_ATTRIBUTE_VALUE_INNER;
	} else {
        io::printf("Encountere unknown character %s\n", c);
    }
}

fn char[] XmlReader.copy_write_buffer(&self) @private {
    usz strLength = self.writeHead;
    char[] strValue = mem::new_array(char, strLength);
    mem::copy(strValue, self.buffer, strLength);
    return strValue;
}

fn void XmlReader.parseAttributeValueInner(&self, char c) @private {
	if (c == '"') {
        self.attributeBeingParsed.value = self.copy_write_buffer();
        XmlNode* nodeBeingParsed = self.peek_node();
        nodeBeingParsed.attributes.push(self.attributeBeingParsed);
        //io::printf("Attribute Value %s\n", self.attributeBeingParsed.value);
        self.attributeBeingParsed = mem::new(XmlAttribute);
        self.writeHead = 0;
		self.state = ReaderState.READ_ATTRIBUTE_NAME;
	} else {
        self.writeChar(c);
    }
}

fn void XmlReader.parseHeader(&self, char c) @private {
	if (c == '>') {
		self.state = ReaderState.READ_UNTIL_OPEN_BRACE;
	}
}

fn void XmlReader.readTextNode(&self, char c) @private {
	if (c == '<') {
        if (self.writeHead > 0) {
            char[] textNodeValue = self.copy_write_buffer();
            XmlNode* textNode = mem::new(XmlNode);
            textNode.name = "#text";
            textNode.value = textNodeValue;
            // io::printf("%s\n", textNodeValue);
            XmlNode* nodeBeingParsed = self.peek_node();
            nodeBeingParsed.children.push(textNode);
        }
        self.writeHead = 0;
		self.state = ReaderState.READ_TAG;
	} else {
        self.writeChar(c);
    } 
}

fn void XmlReader.parse_comment(&self, char c) @private {
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