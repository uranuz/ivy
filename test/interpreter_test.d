module declarative.interpreter_test;

import std.stdio, std.json;

import declarative.interpreter, declarative.interpreter_data, declarative.node, declarative.lexer_tools, declarative.lexer, declarative.common, declarative.parser, declarative.ast_writer;



void main()
{
	alias TextRange = TextForwardRange!(string, LocationConfig());

	string source = 
`	text {*
				Текст
				Другой текст!
	*}`;
	
	
	auto parser = new Parser!(TextRange)(source, "source.tpl");
	
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
// 	alias TDataNode = DataNode!string;
// 	visitor.varTable.setValue("vova", TDataNode(true));
// 	visitor.varTable.setValue("vasya", TDataNode(5));
	
	ast.accept(visitor);
	
	writeln(visitor.opnd);
	
}