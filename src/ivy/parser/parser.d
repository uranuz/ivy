module ivy.parser.parser;

import std.range;

import ivy.common;
import ivy.parser.lexer_tools;
import ivy.parser.lexer;
import ivy.parser.node;
import ivy.parser.expression;
import ivy.parser.statement;

// If IvyTotalDebug is defined then enable parser debug
version(IvyTotalDebug) version = IvyParserDebug;

class IvyParserException: IvyException
{
public:
	@nogc @safe this(string msg, string file = __FILE__, size_t line = __LINE__, Throwable next = null) pure nothrow {
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
	alias LogerMethod = void delegate(LogInfo);

	LexerType lexer;
	string fileName;
	size_t spacesPerTab = 4;
	LogerMethod logerMethod;

	this(String source, string fileName, LogerMethod logerMethod = null)
	{
		this.lexer = LexerType(source, logerMethod);
		this.fileName = fileName;
		this.logerMethod = logerMethod;
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

	version(IvyParserDebug)
		enum isDebugMode = true;
	else
		enum isDebugMode = false;

	static struct LogerProxy
	{
		mixin LogerProxyImpl!(IvyParserException, isDebugMode);
		ParserT parser;

		string sendLogInfo(LogInfoType logInfoType, string msg)
		{
			import std.array: array;
			import std.conv: to;
			import std.algorithm: splitter;

			if( parser.logerMethod !is null ) {
				parser.logerMethod(LogInfo(
					msg,
					logInfoType,
					func.splitter('.').retro.take(2).array.retro.join("."),
					file,
					line,
					parser.fileName,
					(!parser.lexer.empty? parser.lexer.front.loc.lineIndex: 0),
					(!parser.lexer.empty? parser.lexer.frontValue.array.to!string: null)
				));
			}
			return msg;
		}
	}

	LogerProxy loger(string func = __FUNCTION__, string file = __FILE__, int line = __LINE__)	{
		return LogerProxy(func, file, line, this);
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

			loger.error("Expected Name");
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

				loger.error( "Expected Name" );
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

		IvyNode val = parseExpression();
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

		loger.write( "Starting to parse directive statement" );

		if( !lexer.front.test( LexemeType.Name ) )
			loger.error("Expected statement name");

		string statementName = parseQualifiedIdentifier();
		loger.write("directive statement identifier: ", statementName);

		if( statementName.empty )
			loger.error("Directive statement name cannot be empty!");

		IvyNode[] attrs;
		while( !lexer.empty && !lexer.front.test( [LexemeType.Semicolon, LexemeType.CodeBlockEnd, LexemeType.CodeListEnd] ) )
		{
			//Try parse named attribute
			IvyNode attr = parseNamedAttribute();

			loger.write("Attempt to parse named attribute finished" );
			loger.write(" attr is", (attr is null ? null : " not"), " null" );

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
				attr = parseExpression();

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

	IExpression parseBlockOrExpression()
	{
		loger.write( "Start parsing block or expression" );
		import std.array: array;
		import std.conv: to;

		IExpression result;

		//CustLocation loc = this.currentLocation;

		switch( lexer.front.typeIndex ) with(LexemeType)
		{
			case ExprBlockBegin:
			{
				result = parseExpressionBlock();
				break;
			}
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
			case LBrace:
			{
				auto testLexer = lexer.save;
				testLexer.popFront(); // Skip LBrace on testing lexer

				if( testLexer.front.test(LexemeType.Name) )
				{
					testLexer.popFront(); // Skip Name
					if( !testLexer.front.test(LexemeType.Colon) )
					{
						result = parseCodeBlock();
						break;
					}
				}
				goto default;
			}
			case DataBlock:
			{
				loger.error("Parsing raw data block is unimplemented for now!");
				break;
			}
			default:
			{
				result = parsePrimaryExp();
				break;
			}
		}

		return result;
	}

	ICodeBlockStatement parseExpressionBlock()
	{
		loger.write( "Start parsing expression block" );

		CustLocation blockLocation = this.currentLocation;

		if( !lexer.front.test(LexemeType.ExprBlockBegin) )
			loger.error(`Expected ExprBlockBegin`);

		lexer.popFront(); // Skip ExprBlockBegin

		ICodeBlockStatement stmt;
		IvyNode[] attrs;

		while( !lexer.empty && !lexer.front.test(LexemeType.ExprBlockEnd) )
		{
			IExpression attr = parseExpression();
			if( !attr )
				loger.error(`Expression is null`);

			if( lexer.front.test(LexemeType.Comma) )
			{
				lexer.popFront(); // Skip optional expression delimiter
			}

			attrs ~= attr;
		}

		if( !lexer.front.test(LexemeType.ExprBlockEnd) )
			loger.error("Expected semicolon as directive statements delimiter");
		lexer.popFront(); // Skip ExprBlockEnd

		IDirectiveStatement dirStmt = new DirectiveStatement!(config)(blockLocation, "expr", attrs);

		stmt = new CodeBlockStatement!(config)(blockLocation, [dirStmt], false );

		return stmt;
	}

	ICodeBlockStatement parseCodeBlock()
	{
		loger.write( "Start parsing of code block" );

		ICodeBlockStatement statement;
		IDirectiveStatement[] statements;

		CustLocation blockLocation = this.currentLocation;

		if( !lexer.front.test([LexemeType.CodeBlockBegin, LexemeType.CodeListBegin, LexemeType.LBrace]) )
			loger.error( "Expected CodeBlockBegin, CodeListBegin or LBrace" );

		auto beginLexemeType = lexer.front.typeIndex;
		auto endLexemeType = lexer.front.info.pairTypeIndex;
		lexer.popFront(); // Skip CodeBlockBegin, CodeListBegin or LBrace

		if( lexer.empty || lexer.front.test(endLexemeType) )
			loger.error("Unexpected end of code block");

		while( !lexer.empty && !lexer.front.test(endLexemeType) )
		{
			IDirectiveStatement stmt;

			if( !lexer.front.test(LexemeType.Name) )
				loger.error("Expected directive statement name");

			stmt = parseDirectiveStatement();

			if( stmt is null )
				loger.error("Directive statement is null");

			if( lexer.front.test(LexemeType.Semicolon) )
			{
				lexer.popFront(); // Skip statements delimeter
			}
			else if( !lexer.front.test(endLexemeType) )
			{
				loger.error("Expected semicolon as directive statements delimiter");
			}

			statements ~= stmt;
		}

		if( !lexer.front.test(endLexemeType) )
			loger.error("Expected CodeBlockEnd, CodeListEnd or RBrace");
		lexer.popFront(); //Skip RBrace

		statement = new CodeBlockStatement!(config)( blockLocation, statements, beginLexemeType != LexemeType.CodeBlockBegin );

		return statement;
	}

	IMixedBlockStatement parseMixedBlock()
	{
		loger.write( "Start parsing of mixed block" );
		import std.array: array;
		import std.conv: to;

		IMixedBlockStatement statement;

		IStatement[] statements;

		CustLocation loc = this.currentLocation;

		if( !lexer.front.test( LexemeType.MixedBlockBegin ) )
			loger.error("Expected MixedBlockBegin");
		lexer.popFront(); //Skip MixedBlockBegin

		while( !lexer.empty && !lexer.front.test(LexemeType.MixedBlockEnd) )
		{
			CustLocation itemLoc = this.currentLocation;

			switch( lexer.front.typeIndex )
			{
				case LexemeType.ExprBlockBegin:
				{
					statements ~= parseExpressionBlock();
					break;
				}
				case LexemeType.CodeBlockBegin, LexemeType.CodeListBegin:
				{
					statements ~= parseCodeBlock();
					break;
				}
				case LexemeType.Data:
				{
					string data = lexer.frontValue().array.to!string;
					statements ~= new DataFragmentStatement!(config)(itemLoc, data);
					lexer.popFront();
					break;
				}
				default:
					loger.error("Expected code block or data as mixed block content, but found: ", cast(LexemeType) lexer.front.typeIndex );
			}
		}

		if( !lexer.front.test( LexemeType.MixedBlockEnd ) )
			loger.error("Expected MixedBlockEnd");
		lexer.popFront(); //Skip MixedBlockEnd

		statement = new MixedBlockStatement!(config)(loc, statements);

		return statement;
	}

	IExpression parseExpression()
	{
		import std.array: array;
		import std.conv: to;

		loger.write("Start parsing expression");

		auto currRangeCopy = lexer.currentRange.save;
		auto expr = parseLogicalOrExp();

		//Restore currentRange if parser cannot find expression
		if( !expr )
			lexer.currentRange = currRangeCopy.save;

		return expr;
	}

	IExpression parseAssocArray()
	{
		import std.conv: to;
		import std.array: array;

		loger.write("Start parsing assoc array literal");
		IExpression expr;
		CustLocation loc = this.currentLocation;

		if( !lexer.front.test(LexemeType.LBrace) )
			loger.error("Expected LBrace as beginning of assoc array literal!");

		lexer.popFront(); // Skip LBrace

		IAssocArrayPair[] assocPairs;

		while( !lexer.empty && !lexer.front.test(LexemeType.RBrace) )
		{
			CustLocation aaPairLoc = this.currentLocation;
			string aaKey;

			if( lexer.front.test(LexemeType.String) )
			{
				aaKey = parseQuotedString();
			}
			else if( lexer.front.test(LexemeType.Name) )
			{
				aaKey = lexer.frontValue.save.array.to!string;
				lexer.popFront();
			}
			else
			{
				loger.error("Expected assoc array key!");
			}

			if( !lexer.front.test(LexemeType.Colon) )
				loger.error("Expected colon as assoc array key: value delimiter!");
			lexer.popFront();

			auto valueExpr = parseExpression();

			if( !valueExpr )
				loger.error("Expected assoc array value expression but got null");

			assocPairs ~= new AssocArrayPair!(config)(loc, aaKey, valueExpr);

			if( lexer.front.test(LexemeType.RBrace) )
				break;

			if( !lexer.front.test(LexemeType.Comma) )
				loger.error("Expected comma as assoc array pairs delimiter!");

			lexer.popFront(); // Skip comma
		}

		if( !lexer.front.test(LexemeType.RBrace) )
			loger.error("Expected right brace, closing assoc array literal!");
		lexer.popFront(); // Skip right curly brace

		expr = new AssocArrayLiteralExp!(config)(loc, assocPairs);

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
						if( !lexer.front.test(LexemeType.Dot) )
							break;

						lexer.popFront();

						if( !lexer.front.test(LexemeType.Name) )
							loger.error("Expected identifier expression");

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
					loger.error("Expected right paren, closing expression!");
				lexer.popFront(); // Skip RParent

				break;
			}
			case LBracket:
			{
				loger.write("Start parsing array literal");
				lexer.popFront(); // Skip LBracket

				IExpression[] values;

				while( !lexer.empty && !lexer.front.test(LexemeType.RBracket) )
				{
					expr = parseExpression();

					if( !expr )
						loger.error("Null array element expression found!!!");

					loger.write("Array item expression parsed");

					values ~= expr;

					if( lexer.front.test(LexemeType.RBracket) )
					{
						break;
					}

					if( !lexer.front.test(LexemeType.Comma) )
						loger.error("Expected Comma as array items delimiter!");

					lexer.popFront();
				}

				if( !lexer.front.test(LexemeType.RBracket) )
					loger.error("Expected right bracket, closing array literal!");
				lexer.popFront(); // Skip RBracket

				expr = new ArrayLiteralExp!(config)(loc, values);

				break;
			}
			case LBrace:
			{
				expr = parseAssocArray();
				break;
			}
			default:

				break;
		}

		//Parse post expr here such as call syntax and array index syntax
		if( expr )
		{
			// TODO: This need to be reworked:
			// For now I failed to disambiguate post expressions like call expr or index expr
			// from plain parentheses and array literal in directive context. Need to think how to solve
			//expr = parsePostExp( expr, this.isDirectiveContext );
		}
		else
		{
			loger.write( "Couldn't parse primary expression. Returning null" );
		}

		return expr;
	}

	static if(false)
	{
	// This bunch of code unused for now
	IExpression parsePostExp( IExpression preExpr )
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
				loger.internalAssert( false, `Member access expression is not implemented yet!!!`);
				break;
			}
			case LParen:
			{
				if( true )
				{
					expr = preExpr;
					break; // Do not catch post expr in directive context
				}

				// Parse call expression
				lexer.popFront();

				IvyNode[] argList;

				//parsing arguments
				while( !lexer.empty && !lexer.front.test(LexemeType.RParen) )
				{
					IvyNode arg = parseNamedAttribute();

					if( !arg )
						arg = parseExpression();

					if( !arg )
						loger.error("Null call argument expression found!!!");

					argList ~= arg;

					if( lexer.front.test(LexemeType.RParen) )
						break;

					if( !lexer.front.test(LexemeType.Comma) )
						loger.error("Expected Comma as call arguments delimeter");

					lexer.popFront();
				}

				if( !lexer.front.test( LexemeType.RParen ) )
					loger.error("Expected right paren");
				lexer.popFront();

				expr = new CallExp!(config)(loc, preExpr, argList);
				break;
			}
			case LBracket:
			{
				if( true )
				{
					expr = preExpr;
					break; // Do not catch post expr in directive context
				}

				lexer.popFront(); // Skip LBracket
				IExpression indexExpr = parseExpression();

				if( !indexExpr )
					loger.error("Null index expression found!!!");

				if( !lexer.front.test(LexemeType.RBracket) )
				{
					loger.error("Expected right bracket, closing array index expression!!!");
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

	} // static if

	String parseQuotedString()
	{
		String result;
		loger.write( "Parsing quoted string expression" );

		if( !lexer.front.test(LexemeType.String) )
			loger.error("Expected quoted string literal");

		auto strRange = lexer.frontValue.save;

		if( strRange.front != '\"' && strRange.front != '\'' )
			loger.error("Expected \" or \' starting quoted string");
		auto quoteChar = strRange.front;
		strRange.popFront();

		auto clearStrRange = strRange.save;
		size_t clearCount;

		while( !strRange.empty && strRange.front != quoteChar )
		{
			if( strRange.front == '\\' )
			{
				strRange.popFront(); // Skip slash

				// Put previous (clear from escape symbols) part to result
				result ~= clearStrRange[0..clearCount].array;

				switch( strRange.front )
				{
					case 'b', 'f', 'n', 'r', 't', 'v', '0', '\'', '\"', '\\':
					{
						result ~= strRange.front;
						strRange.popFront(); // Skip escaped character
						break;
					}
					case 'u':
					{
						loger.internalAssert( 0, "Unicode escaping is not implemented yet!");
						break;
					}
					case 'x':
					{
						loger.internalAssert( 0, "Hex escaping is not implemented yet!");
						break;
					}
					default:
					{
						loger.error("Unexpected escape character: " ~ strRange.front);
						break;
					}
				}

				clearStrRange = strRange.save; // Previous "clear part" starts from there
				clearCount = 0; // Reset "clear part" counter
				continue;
			}

			++clearCount;
			strRange.popFront();
		}

		if( strRange.front != quoteChar )
			loger.error("Expected end of quoted string literal");

		result ~= clearStrRange[0..clearCount].array; //Appending last part of string except last quote

		lexer.popFront(); //Skipping String lexeme

		return result;
	}

	static immutable int[int] lexToBinaryOpMap;

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
					loger.internalAssert(
						lex.info.typeIndex in lexToBinaryOpMap,
						`Unexpected binary arithmetic operation lexeme: `,
						cast(LexemeType) lex.info.typeIndex
					);
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
					loger.internalAssert(
						lex.info.typeIndex in lexToBinaryOpMap,
						`Unexpected binary arithmetic operation lexeme: `,
						cast(LexemeType) lex.info.typeIndex
					);
					left = new BinaryArithmeticExp!(config)(loc, lexToBinaryOpMap[lex.info.typeIndex], left, right);
					continue;
				}
				default:
				{
					//loger.internalAssert( 0, "Expected add, sub or tilde!!" );
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
				expr = parseBlockOrExpression();
				break;
			}
		}
		return expr;
	}

	static immutable int[int] lexToCmpOpMap;

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
		import std.conv: to;
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
				if( lex.info.typeIndex !in lexToCmpOpMap )
				{
					loger.internalAssert(
						lex.info.typeIndex in lexToCmpOpMap,
						`Unexpected binary comparision operation lexeme: `,
						cast(LexemeType) lex.info.typeIndex
					);
				}
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
