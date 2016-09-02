module ivy.lexer_test;

import std.stdio, std.file;

import ivy.lexer, ivy.lexer_tools, ivy.common;

void main()
{
	string source = cast(string) std.file.read("test/html_template.html");

	import std.uni: isAlpha;
	alias MyLexer = Lexer!(string, LocationConfig.init);
	
	MyLexer lexer = MyLexer(source);
	
	void printResults()
	{
		foreach( lex; lexer.lexemes )
		{
			writeln( "lex.index: ", lex.index, " ", "lex.length: ", lex.length, ", lex.type: ", cast(LexemeType) lex.info.typeIndex, ", content: ", lex.getSlice(lexer.sourceRange).toString() );
		}
		
		writeln( "lexer._ctx.statesStack at the end: " );
		writeln( cast(ContextState[]) lexer._ctx.statesStack );
		writeln();
		writeln( "lexer._ctx.parenStack at the end: " );
		writeln( cast(LexemeType[]) lexer._ctx.parenStack );
	}
		
 	try {
		lexer.parse();
	} catch (Throwable e) {
		printResults();
		
		throw e;
	}

	printResults();

}