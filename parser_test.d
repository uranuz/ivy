module declarative.parser_test;

import std.stdio;

import declarative.node, declarative.common, declarative.parser, declarative.lexer, declarative.lexer_tools, declarative.ast_writer;

// void printNodesRecursive(IDeclNode node, int indent = 0)
// {
// 	import std.range: repeat;
// 	import std.conv: to;
// 	
// 	if( node )
// 	{
// 		writeln( '\t'.repeat(indent), node.kind() );
// 		
// 		foreach( child; node.children )
// 		{
// 			child.printNodesRecursive(indent+1);
// 		}
// 	}
// 	else
// 		writeln( '\t'.repeat(indent), "Node is null!" );
// }

void main()
{
		
	alias TextRange = TextForwardRange!(string, LocationConfig());
	
	// auto parser = new Parser!(TextRange)(
// ` [ ( 10 + 20 * ( 67 - 22 ) ) ] + [ 100 * 100, 15 ] - [ 16.6 - 7 ] + { "aaa": "bbb" } ~ doIt(  checkIt( [] + {} ) + 15 ) ;`, "source.tpl");

	//` Qt.TextBox 10 {% Qt.Font size= 10 {% vasya name= vasya; petya name=petya; goblin name=vova, rank= 3, type="big"; do_nothing {* trololo abcd xyz *} %} %} `

	auto parser = new Parser!(TextRange)(
	` if {% doIf %} :else {% doElse %} `, "source.tpl");

	void printLexemes()
	{
		writeln;
		writeln("List of lexemes:");
		
		import std.array: array;
		
		foreach( lex; parser.lexer.lexemes )
		{
			writeln( cast(LexemeType) lex.info.typeIndex, "  content: ", lex.getSlice(parser.lexer.sourceRange).array );
		}
		
		writeln;
	
	}
	
	IDeclNode ast;
	
	try {
		parser.lexer.popFront();
		ast = parser.parseDirectiveStatement();
	} catch(Throwable e) {
		printLexemes();
		
		throw e;
	}
	
	writeln;
	writeln("Recursive printing of nodes:");
	
	import std.stdio;
	import std.json;
	
	JSONValue astJSON;
	
	writeASTasJSON(parser.lexer.sourceRange, ast, astJSON);
	
	stdout.writeln(toJSON(&astJSON, true));
	
	printLexemes();

}
