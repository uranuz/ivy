module declarative.ast_writer;

import declarative.node;

void writeAST(SourceRange, OutRange)(ref const(SourceRange) source, IDeclNode node, ref OutRange output, int indent = 0)
{
	import std.range: repeat;
	import std.array: array;
	import std.conv: to;
	
	if( node )
	{
		output.put( '\t'.repeat(indent).array.to!string ~ node.kind() ~ " content:  " ~  source[node.location.index .. node.location.index + node.location.length].array.to!string ~ "\r\n" );
		
		foreach( child; node.children )
		{
			writeAST(source, child, output, indent+1);
		}
	}
	else
		output.put( '\t'.repeat(indent).array.to!string ~ "Node is null! \r\n" );
}

import std.json;

void writeASTasJSON(SourceRange)(ref const(SourceRange) source, IDeclNode node, ref JSONValue json)
{
	import std.range: repeat;
	import std.array: array;
	import std.conv: to;
	
	if( node )
	{
		json["kind"] = node.kind();
		
		auto index = node.location.index;
		auto length = node.location.length;
		
		json["index"] = index;
		json["length"] = length;
		json["source"] = source[index .. index + length].array.to!string;
		
		JSONValue[] childrenJSON;
		foreach( child; node.children )
		{
			JSONValue childJSON;
			writeASTasJSON(source, child, childJSON);
			childrenJSON ~= childJSON;
		}
		json["children"] = childrenJSON;
	}
	else
		json = null;
}