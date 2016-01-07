import declarative.lexer_tools, declarative.common;

import std.stdio;
import std.array: array;

void main()
{
	string str = 
`	statement {*
		Текст
		Еще какой-то текст
			Здравствуй, Вася
	*} 
`;
	
	alias TextRange = TextForwardRange!(string, LocationConfig());
	
	auto codeRange = TextRange(str);
	auto codeLinesRange = codeRange.byLine();
	
	
	foreach( lineRange; codeLinesRange )
	{
		write("indentCount: ", lineRange.indentCount);
		
		write(lineRange.save.array);
	}

}