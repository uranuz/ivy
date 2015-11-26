module declarative.parser_test;

import std.stdio;

import declarative.lexer, declarative.lexer_tools, declarative.common;

void main()
{
	string str = 
` {  { { trololo pish` ;
	
	import std.uni: isAlpha;
	alias MyLexer = Lexer!(string, LocationConfig.init);
	
	MyLexer lexer = MyLexer(str);
		
 	//try {
		lexer.parse();
	//} catch (Throwable e){}

	
	foreach( lex; lexer.lexemes )
	{
		writeln( "lex.index: ", lex.index, " ", "lex.length: ", lex.length, ", lex.type: ", cast(LexemeType) lex.info.typeIndex, ", content: ", lex.getSlice(lexer.sourceRange).toString() );
	}

}