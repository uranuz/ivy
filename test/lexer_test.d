module ivy.lexer_test;

import std.stdio, std.file;

import ivy.lexer, ivy.lexer_tools, ivy.common;

void main()
{
	string source = cast(string) std.file.read("test/compiler_test_template.html");

	import std.uni: isAlpha;
	alias MyLexer = Lexer!(string, LocationConfig.init);
	alias MyLexeme = Lexeme!(LocationConfig.init);
	
	MyLexer lexer = MyLexer(source);
	MyLexeme[] lexemes;
	
	void printResults()
	{
		foreach( lex; lexemes )
		{
			writeln( "lex.index: ", lex.loc.index, " ", "lex.length: ", lex.loc.length, ", lex.type: ", cast(LexemeType) lex.info.typeIndex, ", ctx.state: ", lexer._ctx.state, ", content: ", lex.getSlice(lexer.sourceRange).toString() );
		}
		
		writeln( "lexer._ctx.statesStack at the end: " );
		writeln( cast(ContextState[]) lexer._ctx.statesStack );
		writeln();
		writeln( "lexer._ctx.parenStack at the end: " );
		writeln( cast(LexemeInfo[]) lexer._ctx.parenStack );
	}
		
 	try {
		while( !lexer.empty )
		{
			auto lex = lexer.front;
			lexemes ~= lex;
			writeln( "lex.index: ", lex.loc.index, " ", "lex.length: ", lex.loc.length, ", lex.type: ", cast(LexemeType) lex.info.typeIndex, ", ctx.state: ", lexer._ctx.state, ", content: ", lex.getSlice(lexer.sourceRange).toString() );
			lexer.popFront();
		}
		//lexer.parse();
	} catch (Throwable e) {
		writeln("//---------------------------------------------");
		printResults();
		
		throw e;
	}

	//printResults();

}