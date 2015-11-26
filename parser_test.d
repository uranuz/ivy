module declarative.parser_test;

import std.stdio;

import declarative.node, declarative.common, declarative.parser, declarative.lexer, declarative.lexer_tools;

void printNodesRecursive(IDeclNode node, int indent = 0)
{
	import std.range: repeat;
	import std.conv: to;
	
	if( node )
	{
		writeln( '\t'.repeat(indent), node.kind() );
		
		foreach( child; node.children )
		{
			child.printNodesRecursive(indent+1);
		}
	}
	else
		writeln( '\t'.repeat(indent), "Node is null!" );
}

void main()
{
		
	alias TextRange = TextForwardRange!(string, LocationConfig());
	
	// auto parser = new Parser!(TextRange)(
// ` [ ( 10 + 20 * ( 67 - 22 ) ) ] + [ 100 * 100, 15 ] - [ 16.6 - 7 ] + { "aaa": "bbb" } ~ doIt(  checkIt( [] + {} ) + 15 ) ;`, "source.tpl");

	auto parser = new Parser!(TextRange)(
	` Qt.TextBox 20 kesha hui shit.callMe(10, 20) "Epta" name= 2 + 2 * doIt(50 + 800) value= 20 ; `, "source.tpl");
	
	
	//try {
		parser.lexer.popFront();
		auto expr = parser.parseStatement();
		
		writeln;
		writeln("Recursive printing of nodes:");
		
		expr.printNodesRecursive();

	//} catch(Throwable) {}
	
	writeln;
	writeln("List of lexemes:");
	
	import std.array: array;
	
	foreach( lex; parser.lexer.lexemes )
	{
		writeln( cast(LexemeType) lex.info.typeIndex, "  content: ", lex.getSlice(parser.lexer.sourceRange).array );
	}

}
