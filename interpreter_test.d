module declarative.const_folding_test;

import std.stdio, std.json;

import declarative.interpreter, declarative.interpreter_data, declarative.node, declarative.lexer_tools, declarative.lexer, declarative.common, declarative.parser, declarative.ast_writer;

void main()
{
	alias TextRange = TextForwardRange!(string, LocationConfig());

	auto parser = new Parser!(TextRange)(
	` statement attr= true == true {* "vasya" {% petya %} *} `, "source.tpl");
	
	IDeclNode ast;
	
	try {
		parser.lexer.popFront();
		ast = parser.parseDeclarativeStatement();
	} catch(Throwable e) {
// 		printLexemes();
		
		throw e;
	}
	
	JSONValue astJSON;
	
	writeASTasJSON(parser.lexer.sourceRange, ast, astJSON);
	
	stdout.writeln(toJSON(&astJSON, true));
	
	auto visitor = new Interpreter();
	
	ast.children[0].children[0].children[0].accept(visitor);
	
	writeln(visitor.opnd);
	
}