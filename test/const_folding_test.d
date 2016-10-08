module ivy.const_folding_test;

import std.stdio, std.json;

import ivy.const_folding, ivy.node, ivy.lexer_tools, ivy.lexer, ivy.common, ivy.parser, ivy.ast_writer;

/+
void main()
{
	alias TextRange = TextForwardRange!(string, LocationConfig());

	auto parser = new Parser!(TextRange)(
	` statement attr= 3 + 5 * 4 `, "source.tpl");
	
	IvyNode ast;
	
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
	
	auto visitor = new ConstFoldVisitor();
	
	ast.children[0].children[0].children[0].accept(visitor);
	
}
+/