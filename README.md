Example usage
```C
import std::io;
import std::core;
import xml;

File xmlFile = io::file::open("test/test.xml", "r")!!;

XmlDoc* doc = xml::read_file(xmlFile)!!;
defer doc.free();

XmlNodeList bookNodes;
defer bookNodes.free();
doc.find_nodes_by_tag_name("book", &bookNodes);
io::printf("book nodes %d\n", bookNodes.size);

foreach (node : bookNodes) {
    char[]! id = node.get_attrib_value("id");
    if (catch err = id) {
        io::printf("attribute not found\n");
        continue;
    }
    io::printf("Id %s\n", id);
}
```