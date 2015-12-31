module declarative.parser;

import std.stdio;
import std.range;

import declarative.lexer, declarative.lexer_tools, declarative.node, declarative.expression, 
	declarative.statement, declarative.common;

class ParserException : Exception
{
public:
	
	@nogc @safe this(string msg, string file = __FILE__, size_t line = __LINE__, Throwable next = null) pure nothrow
	{
		super(msg, file, line, next);
	}
}
	
	
class Parser(R)
{
public:
	import std.traits: Unqual;

	alias SourceRange = R;
	enum config = GetSourceRangeConfig!R;
	alias Char = Unqual!( ElementEncodingType!R );
	alias String = immutable(Char)[];
	alias LexemeT = Lexeme!(config);
	alias LexerType = Lexer!(String, config);
	alias CustLocation = CustomizedLocation!(config);
	
	LexerType lexer;
	string fileName;
	
	this(String source, string fileName)
	{
		this.lexer = LexerType(source);
		this.fileName = fileName;
	}
	
	IDeclNode parse()
	{
		return parseCodeBlock(true); //true - don't check type of block
	}
	
	@property CustLocation currentLocation() //const
	{
		pragma( msg, "lexer.front type:" );
		pragma( msg, typeof(lexer.front) )
		
		return getCustomizedLocation( lexer.front, fileName );
	}
	
	void error( string msg, string func = __FUNCTION__, int line = __LINE__ )
	{
		throw new ParserException("Parser error in  " ~ func ~ ":\r\n" ~ msg, __FILE__, line);
	}
	
	static struct LogerInfo
	{
		string func;
		int line;
		
		void write(T...)(T data)
		{
			import std.stdio;
			import std.algorithm: splitter;
			import std.range: retro;
			import std.range: take;
			import std.array: array;

			string shortFuncName = func.splitter('.').retro.take(2).array.retro.join(".");
			writeln( shortFuncName, "[", line, "]:  ", data );
		}
	}

	LogerInfo loger(string func = __FUNCTION__, int line = __LINE__)
	{
		return LogerInfo(func, line);
	}

	string parseQualifiedIdentifier(bool justTry = false)
	{
		import std.array: array;
		import std.conv: to;
		
		string[] nameParts;
		
		if( !lexer.front.test(LexemeType.Name) )
		{
			if( justTry )
				return null;
		
			error( "Expected Name, but got: " ~ lexer.frontValue.array.to!string );
		}
		nameParts ~= lexer.frontValue.array.to!string;
		lexer.popFront();
		
		while( !lexer.empty )
		{
			if( !lexer.front.test(LexemeType.Dot) )
				break;
				
			lexer.popFront();
			
			if( !lexer.front.test(LexemeType.Name) )
			{
				if( justTry )
					return null;
					
				error( "Expected Name, but got: " ~ lexer.frontValue.array.to!string );
			}
			
			nameParts ~= lexer.frontValue.array.to!string;
			lexer.popFront();
		}
		
		import std.array: join;
		
		return nameParts.join(".");
	}
	
	IKeyValueAttribute parseNamedAttribute()
	{
		import std.array: array;
		import std.conv: to;

		CustLocation loc = this.currentLocation;
		
		LexerType lexerCopy = lexer.save;
		
		string attrName = parseQualifiedIdentifier(true);
		
		loger.write( "parseNamedAttribute: attrName: ", attrName );
		loger.write( "parseNamedAttribute: frontValue is: ", lexer.frontValue.array.to!string );
		
		if( attrName.empty || !lexer.front.test( LexemeType.Colon ) || lexer.empty )
		{
			lexer = lexerCopy.save;
			loger.write( "parseNamedAttribute(0): lexer restored, LexemeType is: ", 
				cast(LexemeType) lexer.front.info.typeIndex,
				", frontValue is: ", lexer.frontValue.array.to!string
			);
			return null;
		}
		
		auto frontValue = lexer.frontValue.array.to!string;
		
		lexer.popFront(); //Skip key-value delimeter
		
		IDeclNode val = parseBlockOrExpression();
		
		frontValue = lexer.frontValue.array.to!string;
		
		if( !val )
		{
			lexer = lexerCopy.save;
			loger.write( "parseNamedAttribute(1): lexer restored, LexemeType is: ", 
				cast(LexemeType) lexer.front.info.typeIndex,
				", frontValue is: ", lexer.frontValue.array.to!string
			);
			return null;
		}
		
		return new KeyValueAttribute!(config)(loc, attrName, val);
	}
	
	IDirectiveStatement parseDirectiveStatement()
	{
		import std.array: array;
		import std.conv: to;
		
		IDirectiveStatement stmt = null;
		CustLocation loc = this.currentLocation;
		
		if( !lexer.front.test( LexemeType.Name ) )
			error( "Expected statement name, but got: " ~ lexer.frontValue.array.to!string );
		
		string statementName = parseQualifiedIdentifier();
		loger.write("directive statement identifier: ", statementName);
		
		if( statementName.empty )
			return null;
		
		if( lexer.front.test( LexemeType.Colon ) ) 
			error( "parseDirectiveStatement: unexpected Colon. Maybe it's an assoc array instead of directive section" );

		IDeclNode[] attrs;
		
		while( !lexer.empty )
		{
			auto frontLex = (cast(LexemeType) lexer.front.info.typeIndex).to!string;
			
			if( lexer.front.test( LexemeType.Semicolon ) )
			{
				lexer.popFront();
				break;
			}
			
			//Try parse named attribute
			IDeclNode attr = parseNamedAttribute();
			
			frontLex = (cast(LexemeType) lexer.front.info.typeIndex).to!string;
			
			loger.write( "parseDirectiveStatement: parsed named attr, frontValue: ", lexer.frontValue.array.to!string );
			loger.write( "parseDirectiveStatement: attr is", ( attr is null ? null : " not" ) ~ " null" );
			
			//If no named attrs detected yet then we try parse unnamed attrs
			if( attr )
			{	//Named attribute parsed, add it to list
				loger.write( "Named attribute detected!!!" );
				attrs ~= attr;
			}
			else
			{	//Named attribute was not found will try to parse unnamed one
				attr = parseBlockOrExpression();
				
				frontLex = (cast(LexemeType) lexer.front.info.typeIndex).to!string;
				
				if( attr )
				{
					loger.write( "Unnamed attribute detected!!!" );
					attrs ~= attr;
				}
				else
					break; 
			}
			
			if( lexer.front.test( LexemeType.Comma ) )
				lexer.popFront(); //Skip optional Comma
		}
		
		auto frontLex = (cast(LexemeType) lexer.front.info.typeIndex).to!string;
		
		stmt = new DirectiveStatement!(config)(loc, statementName, attrs);
		return stmt;

	}
	
	IDeclNode parseBlockOrExpression()
	{
		import std.array: array;
		import std.conv: to;
		
		IDeclNode result;
		
		//CustLocation loc = this.currentLocation;
		
		switch( lexer.front.info.typeIndex ) with(LexemeType)
		{
			case LBrace:
			{
				result = parseExpression(); //Try to parse assoc array
				
				if( !result )
					result = parseCodeBlock();
				
				break;
			}
			case CodeBlockBegin:
			{
				result = parseCodeBlock();
				
				break;
			}
			case MixedBlockBegin:
			{
				result = parseMixedBlock();
				break;
			}
			case RawDataBlockBegin:
			{
				error( "Parsing raw data block is unimplemented for now!");
				break;
			}
			case RawDataBlock:
			{
				error( "Parsing raw data block is unimplemented for now!");
				break;
			}
			default:
			{	auto frontValue = lexer.frontValue.array.to!string;
				result = parseExpression();
				frontValue = lexer.frontValue.array.to!string;
				break;
			}
		}
		auto frontValue = lexer.frontValue.array.to!string;
	
		return result;
	}
	
	ICompoundStatement parseCodeBlock(bool parseInternals = false)
	{
		import std.conv: to;
		
		ICompoundStatement statement;
		
		IStatement[] statements;
					
		CustLocation blockLocation = this.currentLocation;
		
		if( !parseInternals )
		{
			if( lexer.front.test( LexemeType.LBrace ) )
			{
				auto lexerCopy = lexer.save();
				lexer.popFront();
				if( lexer.front.test( LexemeType.String ) )
				{
					lexer.popFront();
					if( lexer.front.test( LexemeType.Colon ) )
						error( "Unexpected Colon found. Maybe it's assoc array" );
					lexer = lexerCopy.save;
				}
				else
				{
					string attrName = parseQualifiedIdentifier();
					if( attrName.length > 0 && lexer.front.test( LexemeType.Colon ) )
						error( "Unexpected Colon found. Maybe it's assoc array" );
					lexer = lexerCopy.save;
				}
			
			}
			
			if( !lexer.front.test( LexemeType.LBrace ) && !lexer.front.test( LexemeType.CodeBlockBegin ) )
				error( "parseCodeBlock: Expected LBrace or CodeBlockbegin" );
			lexer.popFront();
		}
		
		lexer_loop:
		while( !lexer.empty && !lexer.front.test(LexemeType.CodeBlockEnd) )
		{
			IStatement stmt;

			switch( lexer.front.info.typeIndex ) with( LexemeType )
			{
				/+
				case MixedBlockBegin:
				{
					stmt = parseMixedBlock();
					break;
				}
				case CodeBlockBegin:
				{
					stmt = parseCodeBlock();
					break;
				}
				+/
				case Name:
				{
					stmt = parseDirectiveStatement();
					break;
				}
				/+
				case Semicolon:
				{
					lexer.popFront(); //Accidental statement delimeters just should be skipped
					continue lexer_loop;
				}
				+/
				default:
					error( "Unexpected type of lexeme: " ~ lexer.frontValue.array.to!string );
			}
			if( stmt is null )
				error( "parseCodeBlock: statement is null" );
			statements ~= stmt;
		}
		
		lexer.popFront(); //Skip CodeBlockEnd
		
		statement = new CodeBlockStatement!(config)(blockLocation, statements);
		
		return statement;
	}
	
	ICompoundStatement parseMixedBlock(bool parseInternals = false)
	{
		import std.conv: to;
		
		ICompoundStatement statement;
		
		IStatement[] statements;
		
		CustLocation loc = this.currentLocation;
		
		if( !parseInternals )
		{
			if( !lexer.front.test( LexemeType.MixedBlockBegin ) )
				error( "Expected MixedBlockBegin" );
			lexer.popFront();
		}
		
		while( !lexer.empty && !lexer.front.test(LexemeType.MixedBlockEnd) )
		{
			CustLocation itemLoc = this.currentLocation;
			
			if( lexer.front.test( LexemeType.CodeBlockBegin ))
			{
				statements ~= parseCodeBlock();
			}
			else if( lexer.front.test( LexemeType.Data ) )
			{
				statements ~= new DataFragmentStatement!(config)(itemLoc);
				lexer.popFront();
			}
			else
				error( "Unexpected lexeme type: " ~ (cast(LexemeType) lexer.front.info.typeIndex).to!string );
		}
		
		lexer.popFront(); //Skip MixedBlockEnd
		
		statement = new MixedBlockStatement!(config)(loc, statements);
		
		return statement;
	}

	IExpression parseExpression()
	{
		import std.array: array;
		import std.conv: to;
		
		auto currRangeCopy = lexer.currentRange.save;
		
		auto frontValue = lexer.frontValue.array.to!string;
		
		auto expr = parseLogicalOrExp();
		
		frontValue = lexer.frontValue.array.to!string;
				
		//Restore currentRange if parser cannot find expression
		if( !expr )
			lexer.currentRange = currRangeCopy.save;
		
		return expr;
	}
	
	IExpression parsePrimaryExp()
	{
		import std.algorithm: equal;
		import std.conv: to;
		import std.array: array;
		
		IExpression expr;
		CustLocation loc = this.currentLocation;
		
		LexemeT lex = lexer.front;
		
		loger.write( "parsePrimaryExp: " );
		loger.write( "lexemeType: ", cast(LexemeType) lex.info.typeIndex );
		switch( lex.info.typeIndex ) with( LexemeType )
		{
			case Name:
			{
				loger.write("case Name: ");
				
				auto frontValue = lexer.frontValue;
				
				if( frontValue.save.equal("null") )
				{
					expr = new NullExp!(config)(loc);
					lexer.popFront();
				}
				else if( frontValue.save.equal("true") )
				{
					expr = new BooleanExp!(config)(loc, true);
					lexer.popFront();
				}
				else if( frontValue.save.equal("false") )
				{
					expr = new BooleanExp!(config)(loc, false);
					lexer.popFront();
				}
				else
				{
					Identifier ident;
					string identName = frontValue.save.array.idup;
					
					lexer.popFront();
					
					while( !lexer.empty )
					{
						if( !lexer.front.test( LexemeType.Dot ) )
							break;
							
						lexer.popFront();
							
						if( !lexer.front.test( LexemeType.Name ) )
							error( "Expected name, but got: " ~ lexer.frontValue.array.to!string );
						
						identName ~= "." ~ lexer.frontValue.save.array.idup;
					}
					
					ident = new Identifier(identName);
					
					if( lexer.front.test( LexemeType.LParen ) )
					{
						lexer.popFront();
						
						IExpression[] argList;
						
						//parsing arguments
						while( !lexer.empty && !lexer.front.test( LexemeType.RParen ) )
						{
							IExpression arg = parseExpression();
							
							if( !arg )
								error( "Null call argument expression found!!!" );
							
							argList ~= arg;
							
							if( lexer.front.test( LexemeType.RParen ) )
								break;
							
							if( !lexer.front.test( LexemeType.Comma ) )
								error( "Expected Comma, but got: " ~ lexer.frontValue.array.to!string );

							lexer.popFront();
						}
						
						
						//Parse function call syntax
						if( !lexer.front.test( LexemeType.RParen ) )
							error( "Expected right paren, but got: " ~ lexer.frontValue.array.to!string );
						lexer.popFront();
						
						expr = new CallExp!(config)(loc, ident, argList);
					}
					else
					{
						expr = new IdentifierExp!(config)(loc, ident);
					}
				}

				break;
			}
			case Integer:
			{
				loger.write("case Integer: ");
				//loger.write("lexer.frontValue.array: ", lexer.frontValue.array);
				expr = new IntegerExp!(config)(loc, lexer.frontValue.array.to!IntegerType);
				lexer.popFront();
				
				break;
			}
			case Float:
			{
				loger.write("case Float: ");
				//loger.write("lexer.frontValue.array: ", lexer.frontValue.array);
				expr = new FloatExp!(config)(loc, lexer.frontValue.array.to!FloatType);
				lexer.popFront();
			
				break;
			}
			case String:
			{
				loger.write("case String: ");
				
				string frontValueS = lexer.frontValue.array.to!string;
				
				string escapedStr = parseQuotedString();
				
				frontValueS = lexer.frontValue.array.to!string;
				
				expr = new StringExp!(config)(loc, escapedStr);
		
				break;
			}
			case LParen:
			{
				loger.write("case LParen: ");
				
				lexer.popFront();
				expr = parseExpression();
				
				if( !lexer.front.test(LexemeType.RParen) )
					error( "Expected right paren, closing expression!" );
				lexer.popFront();
				
				break;
			}
			case LBracket:
			{
				loger.write("case LBracket: ");
				
				lexer.popFront();
				
				IExpression[] values;
				
				while( !lexer.empty && !lexer.front.test( LexemeType.RBracket ) )
				{
					expr = parseExpression();
					
					if( !expr )
						error( "Null array element expression found!!!" );
					
					loger.write("LEXER: ", cast(LexemeType) lexer.front.info.typeIndex);
					
					values ~= expr;
					
					loger.write( "ERROR TEST 1: ", cast(LexemeType) lexer.front.info.typeIndex );
					if( lexer.front.test( LexemeType.RBracket ) )
					{
						//lexer.popFront();
						loger.write( "ERROR TEST 2: ", cast(LexemeType) lexer.front.info.typeIndex );
						break;
					}

					if( !lexer.front.test( LexemeType.Comma ) )
						error( "Expected Comma, but got: " 
							~ (cast(LexemeType) lexer.front.info.typeIndex).to!string
							~ " at " ~ this.currentLocation.index.to!string 
						);
					
					lexer.popFront();
				}
				
				if( !lexer.front.test(LexemeType.RBracket) )
					error( "Expected right bracket, closing array literal!" );
				lexer.popFront();
				
				expr = new ArrayLiteralExp!(config)(loc, values);
			
				break;
			}
			case LBrace:
			{
				loger.write("case LBrace: ");
				
				lexer.popFront();
				
				IExpression[] keys;
				IExpression[] values;
				
				while( !lexer.empty && !lexer.front.test( LexemeType.RBrace ) )
				{
					auto keyExpr = parseExpression();
					
					if( !lexer.front.test( LexemeType.Colon ) )
						error( "Expected colon, but got: " 
							~ (cast(LexemeType) lexer.front.info.typeIndex).to!string
							~ " at " ~ this.currentLocation.index.to!string 
						);
				
					lexer.popFront();
					
					auto valueExpr = parseExpression();
					
					keys ~= keyExpr;
					values ~= valueExpr;					
					
					if( lexer.front.test( LexemeType.RBrace ) )
					{
						//lexer.popFront();
						break;
					}
						
					if( lexer.front.test( LexemeType.Comma ) )
						error( "Expected comma, but got: " 
							~ (cast(LexemeType) lexer.front.info.typeIndex).to!string
							~ " at " ~ this.currentLocation.index.to!string 
						);
					
					lexer.popFront();
				}
				
				if( !lexer.front.test(LexemeType.RBrace) )
					error( "Expected right brace, closing assoc array literal!" );
				lexer.popFront();
				
				expr = new AssocArrayLiteralExp!(config)(loc, keys, values);
				
				break;
			}
			default:
			
				break;
		}
		return expr;
	}
	
	String parseQuotedString()
	{
		String result;
		
		if( !lexer.front.test(LexemeType.String) )
			error( "Expected quoted string literal" );
		
		pragma( msg, "lexer.frontValue: " );
		pragma( msg, typeof(lexer.frontValue) );
		auto strRange = lexer.frontValue.save;
		
		auto ch = strRange.front;
		
		if( strRange.front != '\"' )
			error( "Expected \"" );
		strRange.popFront();
		
		auto clearStrRange = strRange.save;
		size_t clearCount;
		
		while( !strRange.empty && strRange.front != '\"' )
		{
			ch = strRange.front;
			
			if( strRange.front == '\\' )
			{
				strRange.popFront();
				
				ch = strRange.front;
				
				auto resPart = clearStrRange[0..clearCount].array;
				
				result ~= resPart;
				
				switch( strRange.front )
				{
					case 'b':
					{
						result ~= '\b';
						break;
					}
					case 'f':
					{
						result ~= '\f';
						break;
					}
					case 'n':
					{
						result ~= '\n';
						break;
					}
					case 'r':
					{
						result ~= '\r';
						break;
					}
					case 't':
					{
						result ~= '\t';
						break;
					}
					case 'v':
					{
						result ~= '\v';
						break;
					}
					case '0':
					{
						result ~= '\0';
						break;
					}
					case '\'':
					{
						result ~= '\'';
						break;
					}
					case '\"':
					{
						result ~= '\"';
						break;
					}
					case '\\':
					{
						result ~= '\\';
						break;
					}
					
					case 'u':
					{
						assert( 0, "Unicode escaping is not implemented yet!");
						break;
					}
					case 'x':
					{
						assert( 0, "Hex escaping is not implemented yet!");
						break;
					}
					default:
					{
						result ~= strRange.front;
						break;
					}
				}
				
				strRange.popFront();
				
				ch = strRange.front;
				
				clearCount = 0;
				continue;
			}
			
			++clearCount;
			strRange.popFront();
		}
		
		ch = strRange.front;
		
		if( strRange.front != '\"' )
			error( "Expected \"" );
			
		result ~= clearStrRange[0..clearCount].array; //Appending last part of string except last quote
			
		lexer.popFront(); //Skipping String lexeme
		
		return result;
	}
	
	static int[int] lexToBinaryOpMap;
	
	shared static this()
	{
		lexToBinaryOpMap = [
			LexemeType.Add: Operator.Add,
			LexemeType.Sub: Operator.Sub,
			LexemeType.Mul: Operator.Mul,
			LexemeType.Div: Operator.Div,
			LexemeType.Mod: Operator.Mod,
			LexemeType.Tilde: Operator.Concat
		];
	}
	
	IExpression parseMulExp()
	{
		import std.array: array;
		import std.conv: to;
		
		loger.write("parseMulExp");
		
		IExpression left;
		IExpression right;
		
		CustLocation loc = currentLocation;
		
		auto frontValue = lexer.frontValue.array.to!string;
		
		left = parseUnaryExp();
		
		frontValue = lexer.frontValue.array.to!string;
		
		lexerRangeLoop:
		while( !lexer.empty )
		{
			LexemeT lex = lexer.front;
			
			switch( lex.info.typeIndex ) with(LexemeType)
			{
				case Mul, Div, Mod:
				{
					lexer.popFront();
					right = parseUnaryExp();
					left = new BinaryArithmeticExp!(config)(loc, lexToBinaryOpMap[lex.info.typeIndex], left, right);
					continue;
				}
				default:
					break lexerRangeLoop;
			}
		}
		
		return left;
	}
	
	IExpression parseAddExp()
	{
		import std.array: array;
		import std.conv: to;
		
		loger.write("parseAddExp");
		
		IExpression left;
		IExpression right;
		
		CustLocation loc = currentLocation;
		
		auto frontValue = lexer.frontValue.array.to!string;
		
		left = parseMulExp();
		
		frontValue = lexer.frontValue.array.to!string;
		
		lexerRangeLoop:
		while( !lexer.empty )
		{
			LexemeT lex = lexer.front;
			
			switch( lex.info.typeIndex ) with(LexemeType)
			{
				case Add, Sub, Tilde: 
				{
					lexer.popFront();
					right = parseMulExp();
					left = new BinaryArithmeticExp!(config)(loc, lexToBinaryOpMap[lex.info.typeIndex], left, right);
					continue;
				}
				default:
				{
					frontValue = lexer.frontValue.array.to!string;
					
					//assert( 0, "Expected add, sub or tilde!!" );
					break lexerRangeLoop;
				}
			}
		}
		
		return left;
	}

	IExpression parseUnaryExp()
	{
		import std.array: array;
		import std.conv: to;
		
		loger.write("parseUnaryExp");
		
		IExpression expr;
		
		CustLocation loc = currentLocation;
		
		LexemeT lex = lexer.front;
		
		switch( lex.info.typeIndex ) with(LexemeType)
		{
			case Sub:
			{
				lexer.popFront();
				expr = parseUnaryExp();
				expr = new UnaryArithmeticExp!(config)(loc, Operator.UnaryMin, expr);
				break;
			}
			case Add:
			{
				lexer.popFront();
				expr = parseUnaryExp();
				expr = new UnaryArithmeticExp!(config)(loc, Operator.UnaryPlus, expr);
				break;
			}
			case Name:
			{
				if( lex.getSlice(lexer.sourceRange).array.equal("not") )
				{
					lexer.popFront();
					expr = parseUnaryExp();
					expr = new LogicalNotExp!(config)(loc, expr);
				}
				else
					goto default;

				break;
			}
			default:
			{
				auto frontValue = lexer.frontValue.array.to!string;
				
				expr = parsePrimaryExp();
				
				frontValue = lexer.frontValue.array.to!string;
				int a = 30;
				break;
			}
		}
		return expr;
	}
	
	static int[int] lexToCmpOpMap;
	
	shared static this()
	{
		lexToCmpOpMap = [
			LexemeType.Equal: Operator.Equal,
			LexemeType.NotEqual: Operator.NotEqual,
			LexemeType.LT: Operator.LT,
			LexemeType.GT: Operator.GT,
			LexemeType.LTEqual: Operator.LTEqual,
			LexemeType.GTEqual: Operator.GTEqual
		];
	}
	
	IExpression parseCompareExp()
	{
		loger.write("parseCompareExp");
		
		IExpression left;
		IExpression right;
		
		CustLocation loc = currentLocation;

		left = parseAddExp();
		
		LexemeT lex = lexer.front;
				
		switch( lex.info.typeIndex ) with(LexemeType)
		{
			case Equal, NotEqual, LT, GT, LTEqual, GTEqual:
			{
				lexer.popFront();
				right = parseAddExp();
				left = new CompareExp!(config)(loc, lexToCmpOpMap[lex.info.typeIndex], left, right);
			}
			default:
				//assert( 0, "Expected compare lexeme!!!" );
				break;
		
		}
		return left;
	}

/+
	IExpression parseLogicalXorExp()
	{
	
	}
+/
	
	IExpression parseLogicalAndExp()
	{
		loger.write("parseLogicalAndExp");
		
		import std.algorithm: equal;
		
		IExpression e;
		IExpression e2;
		CustLocation loc = this.currentLocation;

		e = parseCompareExp();
		while( lexer.front.test( LexemeType.Name ) && equal( lexer.frontValue, "and" ) )
		{
			lexer.popFront();
			e2 = parseCompareExp();
			e = new BinaryLogicalExp!(config)(loc, Operator.And, e, e2);
		}
		return e;
	}
	
	IExpression parseLogicalOrExp()
	{
		loger.write("parseLogicalOrExp");
		
		import std.algorithm: equal;
		
		IExpression e;
		IExpression e2;
		CustLocation loc = this.currentLocation;

		e = parseLogicalAndExp();
		while( lexer.front.test( LexemeType.Name ) && equal( lexer.frontValue, "or" ) )
		{
			lexer.popFront();
			e2 = parseLogicalAndExp();
			e = new BinaryLogicalExp!(config)(loc, Operator.Or, e, e2);
		}
		return e;
	}
}
