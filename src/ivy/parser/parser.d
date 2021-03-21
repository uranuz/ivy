module ivy.parser.parser;

// If IvyTotalDebug is defined then enable parser debug
version(IvyTotalDebug) version = IvyParserDebug;

class Parser(R)
{
	import trifle.text_forward_range: TextForwardRange;
	import trifle.location: Location;
	import trifle.utils: ensure;

	import ivy.log: LogInfoType, LogInfo, IvyLogProxy, LogerMethod;
	import ivy.lexer.lexer: Lexer;
	import ivy.lexer.lexeme: Lexeme;
	import ivy.lexer.consts;
	import ivy.ast.consts;
	import ivy.ast.iface;
	import ivy.ast.expr;
	import ivy.ast.statement;
	import ivy.parser.exception: IvyParserException;

	import std.traits: Unqual;
	import std.range: empty, ElementEncodingType;
public:

	alias SourceRange = R;
	alias Char = Unqual!( ElementEncodingType!R );
	alias String = immutable(Char)[];
	alias LexerType = Lexer!String;
	alias ParserT = Parser!R;
	alias assure = ensure!IvyParserException;

	LexerType lexer;
	IvyLogProxy log;

	this(String source, string fileName, LogerMethod logerMethod = null)
	{
		this.lexer = LexerType(source, fileName, logerMethod);
		this.log = IvyLogProxy(logerMethod? (ref LogInfo logInfo) {
			logInfo.location = this.currentLocation;
			logerMethod(logInfo);
		}: null);
	}

	IvyNode parse()
	{
		// Start parsing with master directive, that describes type of file
		// It's also done, because CodeBlock has CodeBlockEnd check at the end
		// and I don't want do special case for it
		return parseDirectiveStatement();
	}

	Location currentLocation() @property {
		return lexer.front.loc;
	}

	version(IvyParserDebug)
		enum isDebugMode = true;
	else
		enum isDebugMode = false;

	string parseQualifiedIdentifier(bool justTry = false)
	{
		log.info("Start parsing of qualified identifier");

		import std.array: array;
		import std.conv: to;

		string[] nameParts;

		if( !lexer.front.test(LexemeType.Name) )
		{
			assure(justTry, "Expected Name");
			return null;
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
				assure(justTry, "Expected Name");
				return null;
			}

			nameParts ~= lexer.frontValue.array.to!string;
			lexer.popFront();
		}

		import std.array: join;
		log.info( "Parsed qualified identifier: " ~ nameParts.join(".") );

		return nameParts.join(".");
	}

	IKeyValueAttribute parseNamedAttribute()
	{
		import std.array: array;
		import std.conv: to;

		Location loc = this.currentLocation;

		LexerType lexerCopy = lexer.save;

		string attrName = parseQualifiedIdentifier(true);

		log.info( "Parsing named attribute, attribute name is: ", attrName );

		if( attrName.empty || lexer.empty || !lexer.front.test(LexemeType.Colon) )
		{
			lexer = lexerCopy.save;
			log.info( "Couldn't parse name for named attribute, so lexer is restored. Returning null" );
			return null;
		}

		lexer.popFront(); //Skip key-value delimeter

		IvyNode val = parseExpression();
		if( !val )
		{
			lexer = lexerCopy.save;
			log.info( "Couldn't parse value expression for named attribute, so lexer is restored. Returning null" );
			return null;
		}

		return new KeyValueAttribute(loc, attrName, val);
	}

	IDirectiveStatement parseDirectiveStatement()
	{
		import std.array: array;
		import std.conv: to;

		IDirectiveStatement stmt = null;
		Location loc = this.currentLocation;

		log.info( "Starting to parse directive statement" );

		assure(lexer.front.test( LexemeType.Name ), "Expected statement name");

		string statementName = parseQualifiedIdentifier();
		log.info("directive statement identifier: ", statementName);

		assure(!statementName.empty, "Directive statement name cannot be empty!");

		IvyNode[] attrs;
		while( !lexer.empty && !lexer.front.test( [LexemeType.Semicolon, LexemeType.CodeBlockEnd, LexemeType.CodeListEnd] ) )
		{
			//Try parse named attribute
			IvyNode attr = parseNamedAttribute();

			log.info("Attempt to parse named attribute finished attr is ", (attr is null ? null : " not"), " null");

			//If no named attrs detected yet then we try parse unnamed attrs
			if( attr )
			{	//Named attribute parsed, add it to list
				log.info("Named attribute detected!!!");
				attrs ~= attr;
			}
			else
			{
				log.info("Attempt to parse unnamed attribute");
				//Named attribute was not found will try to parse unnamed one
				attr = parseExpression();

				if( attr )
				{
					log.info("Unnamed attribute detected!!!");
					attrs ~= attr;
				}
				else
					break; // We should break if cannot parse attribute
			}

			if( lexer.front.test( LexemeType.Comma ) )
				lexer.popFront(); //Skip optional Comma
		}

		stmt = new DirectiveStatement(loc, statementName, attrs);

		return stmt;
	}

	IExpression parseBlockOrExpression()
	{
		log.info( "Start parsing block or expression" );
		import std.array: array;
		import std.conv: to;

		IExpression result;

		//Location loc = this.currentLocation;

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
				assure(false, "Parsing raw data block is unimplemented for now!");
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
		log.info( "Start parsing expression block" );

		Location blockLocation = this.currentLocation;

		assure(lexer.front.test(LexemeType.ExprBlockBegin), "Expected ExprBlockBegin");

		lexer.popFront(); // Skip ExprBlockBegin

		ICodeBlockStatement stmt;
		IvyNode[] attrs;

		while( !lexer.empty && !lexer.front.test(LexemeType.ExprBlockEnd) )
		{
			IExpression attr = parseExpression();
			assure(attr, "Expression is null");

			if( lexer.front.test(LexemeType.Comma) )
			{
				lexer.popFront(); // Skip optional expression delimiter
			}

			attrs ~= attr;
		}

		assure(lexer.front.test(LexemeType.ExprBlockEnd), "Expected semicolon as directive statements delimiter");
		lexer.popFront(); // Skip ExprBlockEnd

		IDirectiveStatement dirStmt = new DirectiveStatement(blockLocation, "expr", attrs);

		stmt = new CodeBlockStatement(blockLocation, [dirStmt], false );

		return stmt;
	}

	ICodeBlockStatement parseCodeBlock()
	{
		log.info( "Start parsing of code block" );

		ICodeBlockStatement statement;
		IDirectiveStatement[] statements;

		Location blockLocation = this.currentLocation;

		assure(
			lexer.front.test([LexemeType.CodeBlockBegin, LexemeType.CodeListBegin, LexemeType.LBrace]),
			"Expected CodeBlockBegin, CodeListBegin or LBrace");

		auto beginLexemeType = lexer.front.typeIndex;
		auto endLexemeType = lexer.front.info.pairTypeIndex;
		lexer.popFront(); // Skip CodeBlockBegin, CodeListBegin or LBrace

		assure(
			!lexer.empty && !lexer.front.test(endLexemeType),
			"Unexpected end of code block");

		while( !lexer.empty && !lexer.front.test(endLexemeType) )
		{
			IDirectiveStatement stmt;

			assure(lexer.front.test(LexemeType.Name), "Expected directive statement name");

			stmt = parseDirectiveStatement();

			assure(stmt, "Directive statement is null");

			if( lexer.front.test(LexemeType.Semicolon) )
			{
				lexer.popFront(); // Skip statements delimeter
			}
			else
			{
				assure(lexer.front.test(endLexemeType), "Expected semicolon as directive statements delimiter");
			}

			statements ~= stmt;
		}

		assure(lexer.front.test(endLexemeType), "Expected CodeBlockEnd, CodeListEnd or RBrace");
		lexer.popFront(); //Skip RBrace

		statement = new CodeBlockStatement( blockLocation, statements, beginLexemeType != LexemeType.CodeBlockBegin );

		return statement;
	}

	IMixedBlockStatement parseMixedBlock()
	{
		log.info( "Start parsing of mixed block" );
		import std.array: array;
		import std.conv: to;

		IMixedBlockStatement statement;

		IStatement[] statements;

		Location loc = this.currentLocation;

		assure(lexer.front.test( LexemeType.MixedBlockBegin ), "Expected MixedBlockBegin");
		lexer.popFront(); //Skip MixedBlockBegin

		while( !lexer.empty && !lexer.front.test(LexemeType.MixedBlockEnd) )
		{
			Location itemLoc = this.currentLocation;

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
					statements ~= new DataFragmentStatement(itemLoc, data);
					lexer.popFront();
					break;
				}
				default:
					assure(false, "Expected code block or data as mixed block content, but found: ", cast(LexemeType) lexer.front.typeIndex );
			}
		}

		assure(lexer.front.test( LexemeType.MixedBlockEnd ), "Expected MixedBlockEnd");
		lexer.popFront(); //Skip MixedBlockEnd

		statement = new MixedBlockStatement(loc, statements);

		return statement;
	}

	IExpression parseExpression()
	{
		import std.array: array;
		import std.conv: to;

		log.info("Start parsing expression");

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

		log.info("Start parsing assoc array literal");
		IExpression expr;
		Location loc = this.currentLocation;

		assure(lexer.front.test(LexemeType.LBrace), "Expected LBrace as beginning of assoc array literal!");

		lexer.popFront(); // Skip LBrace

		IAssocArrayPair[] assocPairs;

		while( !lexer.empty && !lexer.front.test(LexemeType.RBrace) )
		{
			Location aaPairLoc = this.currentLocation;
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
				assure(false, "Expected assoc array key!");
			}

			assure(lexer.front.test(LexemeType.Colon), "Expected colon as assoc array key: value delimiter!");
			lexer.popFront();

			auto valueExpr = parseExpression();

			assure(valueExpr, "Expected assoc array value expression but got null");

			assocPairs ~= new AssocArrayPair(loc, aaKey, valueExpr);

			if( lexer.front.test(LexemeType.RBrace) )
				break;

			assure(lexer.front.test(LexemeType.Comma), "Expected comma as assoc array pairs delimiter!");

			lexer.popFront(); // Skip comma
		}

		assure(lexer.front.test(LexemeType.RBrace), "Expected right brace, closing assoc array literal!");
		lexer.popFront(); // Skip right curly brace

		expr = new AssocArrayLiteralExp(loc, assocPairs);

		return expr;
	}

	IExpression parsePrimaryExp()
	{
		import std.algorithm: equal;
		import std.conv: to;
		import std.array: array;

		IExpression expr;
		Location loc = this.currentLocation;

		log.info( "Parsing of primary expression" );
		switch( lexer.front.typeIndex ) with( LexemeType )
		{
			case Name:
			{
				log.info("Start parsing of name-like expression");

				auto frontValue = lexer.frontValue;

				if( frontValue.save.equal("undef") )
				{
					expr = new UndefExp(loc);
					lexer.popFront();
				}
				else if( frontValue.save.equal("null") )
				{
					expr = new NullExp(loc);
					lexer.popFront();
				}
				else if( frontValue.save.equal("true") )
				{
					expr = new BooleanExp(loc, true);
					lexer.popFront();
				}
				else if( frontValue.save.equal("false") )
				{
					expr = new BooleanExp(loc, false);
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

						assure(lexer.front.test(LexemeType.Name), "Expected identifier expression");

						identName ~= "." ~ lexer.frontValue.save.array.idup;
						lexer.popFront();
					}

					expr = new IdentifierExp( loc, new Identifier(identName) );
				}

				break;
			}
			case Integer:
			{
				log.info("Start parsing of integer literal");
				//log.info("lexer.frontValue.array: ", lexer.frontValue.array);
				expr = new IntegerExp(loc, lexer.frontValue.array.to!IntegerType);
				lexer.popFront();

				break;
			}
			case Float:
			{
				log.info("Start parsing of float literal");
				//log.info("lexer.frontValue.array: ", lexer.frontValue.array);
				expr = new FloatExp(loc, lexer.frontValue.array.to!FloatType);
				lexer.popFront();

				break;
			}
			case String:
			{
				log.info("Start parsing of string literal");
				string escapedStr = parseQuotedString();

				expr = new StringExp(loc, escapedStr);

				break;
			}
			case LParen:
			{
				log.info("Start parsing expression in parentheses");

				lexer.popFront();
				expr = parseExpression();

				assure(lexer.front.test(LexemeType.RParen), "Expected right paren, closing expression!");
				lexer.popFront(); // Skip RParent

				break;
			}
			case LBracket:
			{
				log.info("Start parsing array literal");
				lexer.popFront(); // Skip LBracket

				IExpression[] values;

				while( !lexer.empty && !lexer.front.test(LexemeType.RBracket) )
				{
					expr = parseExpression();

					assure(expr, "Null array element expression found!!!");

					log.info("Array item expression parsed");

					values ~= expr;

					if( lexer.front.test(LexemeType.RBracket) )
					{
						break;
					}

					assure(lexer.front.test(LexemeType.Comma), "Expected Comma as array items delimiter!");

					lexer.popFront();
				}

				assure(lexer.front.test(LexemeType.RBracket), "Expected right bracket, closing array literal!");
				lexer.popFront(); // Skip RBracket

				expr = new ArrayLiteralExp(loc, values);

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
			log.info( "Couldn't parse primary expression. Returning null" );
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
		Location loc = this.currentLocation;

		log.info( "Parsing post expression for primary expression" );

		switch( lexer.front.typeIndex ) with( LexemeType )
		{
			case Dot:
			{
				// Parse member access expression
				assure(false, `Member access expression is not implemented yet!!!`);
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

					assure(arg, "Null call argument expression found!!!");

					argList ~= arg;

					if( lexer.front.test(LexemeType.RParen) )
						break;

					assure(lexer.front.test(LexemeType.Comma), "Expected Comma as call arguments delimeter");

					lexer.popFront();
				}

				assure(lexer.front.test( LexemeType.RParen ), "Expected right paren");
				lexer.popFront();

				expr = new CallExp(loc, preExpr, argList);
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

				assure(indexExpr, "Null index expression found!!!");
				assure(lexer.front.test(LexemeType.RBracket), "Expected right bracket, closing array index expression!!!");
				lexer.popFront(); // Skip RBracket

				expr = new ArrayIndexExp(loc, preExpr, indexExpr);

				// Parse array index expression
				break;
			}
			default:
			{
				log.info( "No post expression found for primary expression" );

				expr = preExpr;
				break;
			}
		}
		return expr;
	}

	} // static if

	static immutable String stringQuotes = `"'`;

	String parseQuotedString()
	{
		import trifle.quoted_string_range: QuotedStringRange;
		import std.array: appender;
		import std.algorithm: canFind;

		alias QuotRange = QuotedStringRange!(typeof(lexer.frontValue), stringQuotes);

		log.info( "Parsing quoted string expression" );

		assure(lexer.front.test(LexemeType.String), "Expected quoted string literal");

		auto strRange = lexer.frontValue.save;
		auto buf = appender!String();

		auto qRange = QuotRange(strRange);
		for( ; !qRange.empty; qRange.popFront() ) {
			buf ~= qRange.front;
		}

		lexer.popFront(); //Skipping String lexeme

		return buf.data;
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

		log.info("parseMulExp");

		IExpression left;
		IExpression right;

		Location loc = currentLocation;
		left = parseUnaryExp();

		lexerRangeLoop:
		while( !lexer.empty )
		{
			Lexeme lex = lexer.front;

			switch( lex.info.typeIndex ) with(LexemeType)
			{
				case Mul, Div, Mod:
				{
					lexer.popFront();
					right = parseUnaryExp();
					assure(
						lex.info.typeIndex in lexToBinaryOpMap,
						"Unexpected binary arithmetic operation lexeme: ",
						cast(LexemeType) lex.info.typeIndex
					);
					left = new BinaryArithmeticExp(loc, lexToBinaryOpMap[lex.info.typeIndex], left, right);
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

		log.info("parseAddExp");

		IExpression left;
		IExpression right;

		Location loc = currentLocation;
		left = parseMulExp();

		lexerRangeLoop:
		while( !lexer.empty )
		{
			Lexeme lex = lexer.front;

			switch( lex.info.typeIndex ) with(LexemeType)
			{
				case Add, Sub, Tilde:
				{
					lexer.popFront();
					right = parseMulExp();
					assure(
						lex.info.typeIndex in lexToBinaryOpMap,
						`Unexpected binary arithmetic operation lexeme: `,
						cast(LexemeType) lex.info.typeIndex
					);
					left = new BinaryArithmeticExp(loc, lexToBinaryOpMap[lex.info.typeIndex], left, right);
					continue;
				}
				default:
				{
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

		log.info("parseUnaryExp");

		IExpression expr;

		Location loc = currentLocation;

		Lexeme lex = lexer.front;

		switch( lex.info.typeIndex ) with(LexemeType)
		{
			case Add:
			{
				lexer.popFront();
				expr = parseUnaryExp();
				expr = new UnaryArithmeticExp(loc, Operator.UnaryPlus, expr);
				break;
			}
			case Sub:
			{
				lexer.popFront();
				expr = parseUnaryExp();
				expr = new UnaryArithmeticExp(loc, Operator.UnaryMin, expr);
				break;
			}
			case Name:
			{
				if( lex.getSlice(lexer.sourceRange).array.equal("not") )
				{
					lexer.popFront();
					expr = parseUnaryExp();
					expr = new LogicalNotExp(loc, expr);
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
		log.info("parseCompareExp");

		IExpression left;
		IExpression right;

		Location loc = currentLocation;

		left = parseAddExp();

		Lexeme lex = lexer.front;

		switch( lex.info.typeIndex ) with(LexemeType)
		{
			case Equal, NotEqual, LT, GT, LTEqual, GTEqual:
			{
				lexer.popFront();
				right = parseAddExp();
				if( lex.info.typeIndex !in lexToCmpOpMap )
				{
					assure(
						lex.info.typeIndex in lexToCmpOpMap,
						"Unexpected binary comparision operation lexeme: ",
						cast(LexemeType) lex.info.typeIndex
					);
				}
				left = new CompareExp(loc, lexToCmpOpMap[lex.info.typeIndex], left, right);
			}
			default:
			{
				break;
			}
		}
		return left;
	}

	IExpression parseLogicalAndExp()
	{
		log.info("parseLogicalAndExp");

		import std.algorithm: equal;

		IExpression e;
		IExpression e2;
		Location loc = this.currentLocation;

		e = parseCompareExp();
		while( lexer.front.test( LexemeType.Name ) && equal( lexer.frontValue, "and" ) )
		{
			lexer.popFront();
			e2 = parseCompareExp();
			e = new BinaryLogicalExp(loc, Operator.And, e, e2);
		}
		return e;
	}

	IExpression parseLogicalOrExp()
	{
		log.info("parseLogicalOrExp");

		import std.algorithm: equal;

		IExpression e;
		IExpression e2;
		Location loc = this.currentLocation;

		e = parseLogicalAndExp();
		while( lexer.front.test( LexemeType.Name ) && equal( lexer.frontValue, "or" ) )
		{
			lexer.popFront();
			e2 = parseLogicalAndExp();
			e = new BinaryLogicalExp(loc, Operator.Or, e, e2);
		}
		return e;
	}


}
