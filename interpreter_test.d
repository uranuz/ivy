module declarative.const_folding_test;

import std.stdio, std.json;

import declarative.interpreter, declarative.interpreter_data, declarative.node, declarative.lexer_tools, declarative.lexer, declarative.common, declarative.parser, declarative.ast_writer;

void main()
{
	alias TextRange = TextForwardRange!(string, LocationConfig());

	auto parser = new Parser!(TextRange)(
	` for item in [1, 2, 3] {# expr 1 #} `, "source.tpl");
	
	IDeclNode ast;
	
	try {
		parser.lexer.popFront();
		ast = parser.parseDirectiveStatement();
	} catch(Throwable e) {
// 		printLexemes();
		
		throw e;
	}
	
	JSONValue astJSON;
	
	writeASTasJSON(parser.lexer.sourceRange, ast, astJSON);
	
	stdout.writeln(toJSON(&astJSON, true));
	
	auto visitor = new Interpreter();
	
	ast.accept(visitor);
	
	writeln(visitor.opnd);
	
}