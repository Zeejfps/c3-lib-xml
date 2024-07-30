module env::xml;
import std::io;

struct Doc {
    XmlNode* root;
}

fn Doc* read_file(File file) {
    char[] buff = mem::new_array(char, 1024);
	defer mem::free(buff);

    xml::Reader* reader = xml::new_reader();
	defer xml::free(reader);

    while (!file.eof()) {
		usz bytesRead = file.read(buff)!!;
		char[] data = buff[0:bytesRead];
		reader.read(data);
	}

    return mem::new(Doc);
}

fn void Doc.free(&self) {

}