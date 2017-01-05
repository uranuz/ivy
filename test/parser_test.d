module ivy.parser_test;

import std.stdio, std.file;

import ivy.node, ivy.common, ivy.parser, ivy.lexer, ivy.lexer_tools, ivy.ast_writer;

// void printNodesRecursive(IvyNode node, int indent = 0)
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
	
	string sourceFileName = "test/html_template.html";
	string source = cast(string) std.file.read(sourceFileName);

	auto parser = new Parser!(TextRange)(source, sourceFileName);
	IvyNode ast;
	scope(exit) {
		writeln;
		writeln("Recursive printing of nodes:");
		
		import std.stdio;
		import std.json;
		
		JSONValue astJSON;
		
		writeASTasJSON(parser.lexer.sourceRange, ast, astJSON);
		
		stdout.writeln(toJSON(&astJSON, true));
	}

	ast = parser.parse();
}
