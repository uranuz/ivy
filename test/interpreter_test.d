module ivy.interpreter_test;

import std.stdio, std.json, std.file;

import ivy.interpreter, ivy.interpreter_data, ivy.node, ivy.lexer_tools, ivy.lexer, ivy.common, ivy.parser, ivy.ast_writer;



void main()
{
	alias TextRange = TextForwardRange!(string, LocationConfig());

	string sourceFileName = "test/html_template.html";
	string source = cast(string) std.file.read(sourceFileName);
	
	auto parser = new Parser!(TextRange)(source, sourceFileName);
	
	IDeclNode ast;
	
	try {
		parser.lexer.popFront();
		ast = parser.parse();
	} catch(Throwable e) {
// 		printLexemes();
		
		throw e;
	}
	
	JSONValue astJSON;
	
	writeASTasJSON(parser.lexer.sourceRange, ast, astJSON);
	
	stdout.writeln(toJSON(&astJSON, true));
	
	auto visitor = new Interpreter(null);
 	alias TDataNode = DataNode!string;
 	visitor.setValue("content", TDataNode("<div>Основное содержимое формы</div>"));
 	visitor.setValue("content2", TDataNode("Еще какое-то содержимое страницы"));
 	visitor.setValue("content3", TDataNode("Здравствуй, Вася"));
 	visitor.setValue("x", TDataNode(20));
 	visitor.setValue("y", TDataNode("no"));
 	
 	bool hasContent = visitor.canFindValue("content2");
 	auto content = visitor.getValue("content2");
	
	ast.accept(visitor);
	
	writeln(visitor.opnd);
	
}