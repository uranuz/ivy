module ivy.parser;

import std.stdio;
import std.range;

import ivy.lexer, ivy.lexer_tools, ivy.node, ivy.expression,
	ivy.statement, ivy.common;

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
	enum LocationConfig config = GetSourceRangeConfig!R;
	alias Char = Unqual!( ElementEncodingType!R );
	alias String = immutable(Char)[];
	alias LexemeT = Lexeme!(config);
	alias LexerType = Lexer!(String, config);
	alias CustLocation = CustomizedLocation!(config);
	alias ParserT = Parser!R;
	
	LexerType lexer;
	string fileName;
	size_t spacesPerTab = 4;
	bool isDirectiveContext = true;
	
	this(String source, string fileName)
	{
		this.lexer = LexerType(source);
		this.fileName = fileName;
	}
	
	IvyNode parse()
	{
		// Start parsing with master directive, that describes type of file
		// It's also done, because CodeBlock has CodeBlockEnd check at the end
		// and I don't want do special case for it
		return parseDirectiveStatement();
	}
	
	@property CustLocation currentLocation() //const
	{
		CustLocation loc = lexer.front.loc;
		loc.fileName = fileName;
		
		return loc;
	}
	
	void error( string msg, string func = __FUNCTION__, int line = __LINE__ )
	{
		throw new ParserException("Parser error in  " ~ func ~ ":\r\n" ~ msg, __FILE__, line);
	}
	
	static struct LogerInfo
	{
		ParserT parser;
		string func;
		int line;
		
		void write(T...)(T data)
		{
			debug {
				import std.stdio;
				import std.algorithm: splitter;
				import std.range: retro;
				import std.range: take;
				import std.array: array;
				import std.conv: to;
	
				string shortFuncName = func.splitter('.').retro.take(2).array.retro.join(".");
				debug writeln( shortFuncName, "[", line, "]: ", data, ", frontValue is: ", parser.lexer.frontValue.array.to!string );
			}
		}
	}

	LogerInfo loger(string func = __FUNCTION__, int line = __LINE__)
	{
		return LogerInfo(this, func, line);
	}

	string parseQualifiedIdentifier(bool justTry = false)
	{
		loger.write( "Start parsing of qualified identifier" );

		import std.array: array;
		import std.conv: to;
		
		string[] nameParts;
		
		if( !lexer.front.test(LexemeType.Name) )
		{
			if( justTry )
				return null;
		
			error( "Expected Name" );
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
					
				error( "Expected Name" );
			}
			
			nameParts ~= lexer.frontValue.array.to!string;
			lexer.popFront();
		}
		
		import std.array: join;
		loger.write( "Parsed qualified identifier: " ~ nameParts.join(".") );
		
		return nameParts.join(".");
	}
	
	IKeyValueAttribute parseNamedAttribute()
	{
		import std.array: array;
		import std.conv: to;

		CustLocation loc = this.currentLocation;
		
		LexerType lexerCopy = lexer.save;
		
		string attrName = parseQualifiedIdentifier(true);
		
		loger.write( "Parsing named attribute, attribute name is: ", attrName );
		
		if( attrName.empty || !lexer.front.test( LexemeType.Colon ) || lexer.empty )
		{
			lexer = lexerCopy.save;
			loger.write( "Couldn't parse name for named attribute, so lexer is restored. Returning null" );
			return null;
		}

		lexer.popFront(); //Skip key-value delimeter

		IvyNode val = parseBlockOrExpression();
		if( !val )
		{
			lexer = lexerCopy.save;
			loger.write( "Couldn't parse value expression for named attribute, so lexer is restored. Returning null" );
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
			error( "Expected statement name" );
		
		string statementName = parseQualifiedIdentifier();
		loger.write("directive statement identifier: ", statementName);
		
		if( statementName.empty )
			error( "Directive statement name cannot be empty!" );

		IvyNode[] attrs;
		while( !lexer.empty && !lexer.front.test( [LexemeType.Semicolon, LexemeType.CodeBlockEnd] ) )
		{
			//Try parse named attribute
			IvyNode attr = parseNamedAttribute();
			
			loger.write( "Attempt to parse named attribute finished" );
			loger.write( " attr is", ( attr is null ? null : " not" ) ~ " null" );
			
			//If no named attrs detected yet then we try parse unnamed attrs
			if( attr )
			{	//Named attribute parsed, add it to list
				loger.write( "Named attribute detected!!!" );
				attrs ~= attr;
			}
			else
			{
				loger.write( "Attempt to parse unnamed attribute" );
				//Named attribute was not found will try to parse unnamed one
				//True means that we not catch some post expressions in this context
				attr = parseBlockOrExpression( true );
				
				if( attr )
				{
					loger.write( "Unnamed attribute detected!!!" );
					attrs ~= attr;
				}
				else
					break; // We should break if cannot parse attribute
			}
			
			if( lexer.front.test( LexemeType.Comma ) )
				lexer.popFront(); //Skip optional Comma
		}
		
		stmt = new DirectiveStatement!(config)(loc, statementName, attrs);
		return stmt;

	}
	
	IvyNode parseBlockOrExpression( bool isDirectiveContext = false )
	{
		loger.write( "Start parsing block or expression" );
		import std.array: array;
		import std.conv: to;
		
		IvyNode result;
		
		//CustLocation loc = this.currentLocation;
		
		switch( lexer.front.typeIndex ) with(LexemeType)
		{
			case CodeBlockBegin, CodeListBegin:
			{
				result = parseCodeBlock();
				break;
			}
			case MixedBlockBegin:
			{
				result = parseMixedBlock();
				break;
			}
			case DataBlock:
			{
				error( "Parsing raw data block is unimplemented for now!");
				break;
			}
			default:
			{
				result = parseExpression( isDirectiveContext );
				break;
			}
		}
	
		return result;
	}
	
	ICompoundStatement parseCodeBlock()
	{
		loger.write( "Start parsing of code block" );
		import std.conv: to;
		
		ICompoundStatement statement;
		
		IDirectiveStatement[] statements;
					
		CustLocation blockLocation = this.currentLocation;
		
		if( !lexer.front.test( [LexemeType.CodeBlockBegin, LexemeType.CodeListBegin] ) )
				error( "Expected CodeBlockBegin or CodeListBegin" );
		LexemeType endLexemeType = cast(LexemeType) lexer.front.info.pairTypeIndex;

		lexer.popFront(); // Skip CodeBlockBegin, CodeListBegin

		if( lexer.empty || lexer.front.test(endLexemeType) )
			error( "Unexpected end of code block" );

		while( !lexer.empty && !lexer.front.test(endLexemeType) )
		{
			IDirectiveStatement stmt;

			if( !lexer.front.test( LexemeType.Name ) )
				error( "Expected directive statement Name" );

			stmt = parseDirectiveStatement();

			if( stmt is null )
				error( "Directive statement is null" );

			if( lexer.front.test( LexemeType.Semicolon ) )
			{
				lexer.popFront(); // Skip statements delimeter
			}
			else if( !lexer.front.test(endLexemeType) )
			{
				error( "Expected semicolon as directive statements delimiter" );
			}

			statements ~= stmt;
		}
		
		if( !lexer.front.test(endLexemeType) )
			error( "Expected " ~ endLexemeType.to!string );
		lexer.popFront(); //Skip CodeBlockEnd

		statement = new CodeBlockStatement!(config)(blockLocation, statements, endLexemeType == LexemeType.CodeListEnd );
		
		return statement;
	}
	
	ICompoundStatement parseMixedBlock()
	{
		loger.write( "Start parsing of mixed block" );
		import std.array: array;
		import std.conv: to;
		
		ICompoundStatement statement;
		
		IStatement[] statements;
		
		CustLocation loc = this.currentLocation;
		
		if( !lexer.front.test( LexemeType.MixedBlockBegin ) )
			error( "Expected MixedBlockBegin" );
		lexer.popFront(); //Skip MixedBlockBegin

		while( !lexer.empty && !lexer.front.test(LexemeType.MixedBlockEnd) )
		{
			CustLocation itemLoc = this.currentLocation;

			if( lexer.front.test( [LexemeType.CodeBlockBegin, LexemeType.CodeListBegin] ))
			{
				statements ~= parseCodeBlock();
			}
			else if( lexer.front.test( LexemeType.Data ) )
			{
				string data = lexer.frontValue().array.to!string;
				statements ~= new DataFragmentStatement!(config)(itemLoc, data);
				lexer.popFront();
			}
			else
				error( "Expected code block or data as mixed block content!" );
		}
		
		if( !lexer.front.test( LexemeType.MixedBlockEnd ) )
			error( "Expected MixedBlockEnd" );
		lexer.popFront(); //Skip MixedBlockEnd

		statement = new MixedBlockStatement!(config)(loc, statements);
		
		return statement;
	}

	IExpression parseExpression( bool isDirectiveContext = false )
	{
		import std.array: array;
		import std.conv: to;
		
		auto currRangeCopy = lexer.currentRange.save;
		auto expr = parseLogicalOrExp();

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

		loger.write( "Parsing of primary expression" );
		switch( lexer.front.typeIndex ) with( LexemeType )
		{
			case Name:
			{
				loger.write("Start parsing of name-like expression");
				
				auto frontValue = lexer.frontValue;
				
				if( frontValue.save.equal("undef") )
				{
					expr = new UndefExp!(config)(loc);
					lexer.popFront();
				}
				else if( frontValue.save.equal("null") )
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
							error( "Expected identifier expression" );
						
						identName ~= "." ~ lexer.frontValue.save.array.idup;
						lexer.popFront();
					}

					expr = new IdentifierExp!(config)( loc, new Identifier(identName) );
				}

				break;
			}
			case Integer:
			{
				loger.write("Start parsing of integer literal");
				//loger.write("lexer.frontValue.array: ", lexer.frontValue.array);
				expr = new IntegerExp!(config)(loc, lexer.frontValue.array.to!IntegerType);
				lexer.popFront();
				
				break;
			}
			case Float:
			{
				loger.write("Start parsing of float literal");
				//loger.write("lexer.frontValue.array: ", lexer.frontValue.array);
				expr = new FloatExp!(config)(loc, lexer.frontValue.array.to!FloatType);
				lexer.popFront();
			
				break;
			}
			case String:
			{
				loger.write("Start parsing of string literal");
				string escapedStr = parseQuotedString();

				expr = new StringExp!(config)(loc, escapedStr);
		
				break;
			}
			case LParen:
			{
				loger.write("Start parsing expression in parentheses");
				
				lexer.popFront();
				expr = parseExpression();
				
				if( !lexer.front.test(LexemeType.RParen) )
					error( "Expected right paren, closing expression!" );
				lexer.popFront();
				
				break;
			}
			case LBracket:
			{
				loger.write("Start parsing array literal");
				lexer.popFront();
				
				IExpression[] values;
				
				while( !lexer.empty && !lexer.front.test( LexemeType.RBracket ) )
				{
					expr = parseExpression();
					
					if( !expr )
						error( "Null array element expression found!!!" );
					
					loger.write("Array item expression parsed");
					
					values ~= expr;
					
					if( lexer.front.test( LexemeType.RBracket ) )
					{
						break;
					}

					if( !lexer.front.test( LexemeType.Comma ) )
						error( "Expected Comma as array items delimiter!" );
					
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
				loger.write("Start parsing assoc array literal");
				lexer.popFront();

				IAssocArrayPair[] assocPairs;

				while( !lexer.empty && !lexer.front.test( LexemeType.RBrace ) )
				{
					CustLocation aaPairLoc = this.currentLocation;
					string aaKey;

					if( lexer.front.test( LexemeType.String )  )
					{
						aaKey = parseQuotedString();
					}
					else if( lexer.front.test( LexemeType.Name ) )
					{
						aaKey = lexer.frontValue.save.array.to!string;
						lexer.popFront();
					}
					else
					{
						error( "Expected assoc array key!" );
					}

					if( !lexer.front.test( LexemeType.Colon ) )
						error( "Expected colon as assoc array key: value delimiter!" );
					lexer.popFront();

					auto valueExpr = parseExpression();

					if( !valueExpr )
						error( "Expected assoc array value expression but got null" );

					assocPairs ~= new AssocArrayPair!(config)(loc, aaKey, valueExpr);

					if( lexer.front.test( LexemeType.RBrace ) )
						break;

					if( !lexer.front.test( LexemeType.Comma ) )
						error( "Expected comma as assoc array pairs delimiter!");

					lexer.popFront(); // Skip comma
				}
				
				if( !lexer.front.test(LexemeType.RBrace) )
					error( "Expected right brace, closing assoc array literal!" );
				lexer.popFront(); // Skip right curly brace
				
				expr = new AssocArrayLiteralExp!(config)(loc, assocPairs);
				
				break;
			}
			default:
			
				break;
		}
		
		//Parse post expr here such as call syntax and array index syntax
		if( expr )
		{
			expr = parsePostExp( expr, this.isDirectiveContext );
		}
		else
		{
			loger.write( "Couldn't parse primary expression. Returning null" );
		}

		return expr;
	}

	IExpression parsePostExp( IExpression preExpr, bool isDirectiveContext )
	{
		import std.conv: to;

		IExpression expr;
		CustLocation loc = this.currentLocation;

		loger.write( "Parsing post expression for primary expression" );

		switch( lexer.front.typeIndex ) with( LexemeType )
		{
			case Dot:
			{
				// Parse member access expression
				assert( false, `Member access expression is not implemented yet!!!`);
				break;
			}
			case LParen:
			{
				if( isDirectiveContext )
				{
					expr = preExpr;
					break; // Do not catch post expr in directive context
				}
				
				// Parse call expression
				lexer.popFront();

				IvyNode[] argList;

				//parsing arguments
				while( !lexer.empty && !lexer.front.test( LexemeType.RParen ) )
				{
					IvyNode arg = parseNamedAttribute();

					if( !arg )
						arg = parseBlockOrExpression();

					if( !arg )
						error( "Null call argument expression found!!!" );

					argList ~= arg;

					if( lexer.front.test( LexemeType.RParen ) )
						break;

					if( !lexer.front.test( LexemeType.Comma ) )
						error( "Expected Comma as call arguments delimeter" );

					lexer.popFront();
				}

				if( !lexer.front.test( LexemeType.RParen ) )
					error( "Expected right paren" );
				lexer.popFront();

				expr = new CallExp!(config)(loc, preExpr, argList);
				break;
			}
			case LBracket:
			{
				if( isDirectiveContext )
				{
					expr = preExpr;
					break; // Do not catch post expr in directive context
				}
				lexer.popFront();
				IExpression indexExpr = parseExpression();

				if( !indexExpr )
					error( "Null index expression found!!!" );

				if( !lexer.front.test( LexemeType.RBracket ) )
				{
					error( "Expected right bracket, closing array index expression!!! " );
				}
				lexer.popFront(); // Skip RBracket

				expr = new ArrayIndexExp!(config)(loc, preExpr, indexExpr);

				// Parse array index expression
				break;
			}
			default:
			{
				loger.write( "No post expression found for primary expression" );

				expr = preExpr;
				break;
			}
		}
		return expr;
	}
	
	String parseQuotedString()
	{
		String result;
		loger.write( "Parsing quoted string expression" );
		
		if( !lexer.front.test(LexemeType.String) )
			error( "Expected quoted string literal" );
		
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
				clearStrRange = strRange.save;
				
				clearCount = 0;
				continue;
			}
			
			++clearCount;
			strRange.popFront();
		}
		
		ch = strRange.front;
		
		if( strRange.front != '\"' )
			error( "Expected \" closing quoted string literal" );
			
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
		left = parseUnaryExp();
		
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
		left = parseMulExp();

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
		import std.algorithm: equal;
		
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
				expr = parsePrimaryExp();
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
			{
				//assert( 0, "Expected compare lexeme!!!" );
				break;
			}
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
