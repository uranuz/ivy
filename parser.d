module declarative.parser;

import std.stdio;
import std.range;

import declarative.lexer, declarative.lexer_tools, declarative.node, declarative.expression, 
	declarative.statement, declarative.common;


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
	
	@property CustLocation currentLocation() //const
	{
		pragma( msg, "lexer.front type:" );
		pragma( msg, typeof(lexer.front) )
		
		return getCustomizedLocation( lexer.front, fileName );
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
		
			assert( 0, "Expected Name, but got: " ~ lexer.frontValue.array.to!string );
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
					
				assert( 0, "Expected Name, but got: " ~ lexer.frontValue.array.to!string );
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
		
		writeln( "parseNamedAttribute: attrName: ", attrName );
		writeln( "parseNamedAttribute: frontValue is: ", lexer.frontValue.array.to!string );
		
		if( attrName.empty || !lexer.front.test( LexemeType.Colon ) || lexer.empty )
		{
			lexer = lexerCopy.save;
			writeln( "parseNamedAttribute(0): lexer restored, LexemeType is: ", 
				cast(LexemeType) lexer.front.info.typeIndex,
				", frontValue is: ", lexer.frontValue.array.to!string
			);
			return null;
		}
		
		lexer.popFront(); //Skip key-value delimeter
		
		IDeclNode val = parseBlockOrExpression();
		
		if( !val )
		{
			lexer = lexerCopy.save;
			writeln( "parseNamedAttribute(1): lexer restored, LexemeType is: ", 
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
		
		assert( lexer.front.test( LexemeType.Name ), "Expected statement name, but got: " ~ lexer.frontValue.array.to!string );
		
		string statementName = parseQualifiedIdentifier();
		writeln("directive statement identifier: ", statementName);
		
		if( statementName.empty )
			return null;
		
		assert( !lexer.front.test( LexemeType.Colon ), "parseDirectiveStatement: unexpected Colon. Maybe it's an assoc array instead of directive section" );;

		IDeclNode[] attrs;
		
		while( !lexer.empty )
		{
			if( lexer.front.test( LexemeType.Semicolon ) )
			{
				lexer.popFront();
				break;
			}
			
			//Try parse named attribute
			IDeclNode attr = parseNamedAttribute();
			
			writeln( "parseDirectiveStatement: parsed named attr, frontValue: ", lexer.frontValue.array.to!string );
			writeln( "parseDirectiveStatement: attr is", ( attr is null ? null : " not" ) ~ " null" );
			
			//If no named attrs detected yet then we try parse unnamed attrs
			if( attr )
			{	//Named attribute parsed, add it to list
				writeln( "Named attribute detected!!!" );
				attrs ~= attr;
			}
			else
			{	//Named attribute was not found will try to parse unnamed one
				attr = parseBlockOrExpression();
				
				if( attr )
				{
					writeln( "Unnamed attribute detected!!!" );
					attrs ~= attr;
				}
				else
					break; 
			}
			
			if( lexer.front.test( LexemeType.Comma ) )
				lexer.popFront(); //Skip optional Comma
		}
		
		stmt = new DirectiveStatement!(config)(loc, statementName, attrs);
		return stmt;

	}
	
	IDeclNode parseBlockOrExpression()
	{
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
				assert( 0, "Parsing raw data block is unimplemented for now!");
				break;
			}
			case RawDataBlock:
			{
				assert( 0, "Parsing raw data block is unimplemented for now!");
				break;
			}
			default:
			{
				result = parseExpression();
				break;
			}
		}
	
		return result;
	}
	
	ICompoundStatement parseCodeBlock()
	{
		import std.conv: to;
		
		ICompoundStatement statement;
		
		IStatement[] statements;
					
		CustLocation blockLocation = this.currentLocation;
		
		if( lexer.front.test( LexemeType.LBrace ) )
		{
			auto lexerCopy = lexer.save();
			lexer.popFront();
			if( lexer.front.test( LexemeType.String ) )
			{
				lexer.popFront();
				assert( lexer.front.test( LexemeType.Colon ), "parseCodeBlock: unexpected Colon found. Maybe it's assoc array" );
				lexer = lexerCopy.save;
			}
			else
			{
				string attrName = parseQualifiedIdentifier();
				assert( attrName.length > 0 && lexer.front.test( LexemeType.Colon ), "parseCodeBlock: unexpected Colon found. Maybe it's assoc array" );
				lexer = lexerCopy.save;
			}
		
		}
		
		assert( lexer.front.test( LexemeType.LBrace ) || lexer.front.test( LexemeType.CodeBlockBegin ), "parseCodeBlock: Expected LBrace or CodeBlockbegin" );
		lexer.popFront();
		
		lexer_loop:
		while( !lexer.empty && !lexer.front.test(LexemeType.CodeBlockEnd) )
		{
			IStatement stmt;

			switch( lexer.front.info.typeIndex ) with( LexemeType )
			{
				case MixedBlockBegin:
				{
					lexer.popFront();
					stmt = parseMixedBlock();
					break;
				}
				case CodeBlockBegin:
				{
					lexer.popFront();
					stmt = parseCodeBlock();
					break;
				}
				case Name:
				{
					stmt = parseDirectiveStatement();
					break;
				}
				case Semicolon:
				{
					lexer.popFront(); //Accidental statement delimeters just should be skipped
					continue lexer_loop;
				}
				default:
					assert( 0, "parseCodeBlock: unexpected type of lexeme: " ~ lexer.frontValue.array.to!string );
			}
			assert( stmt !is null, "parseCodeBlock: statement is null" );
			statements ~= stmt;
		}
		
		lexer.popFront(); //Skip CodeBlockEnd
		
		statement = new CodeBlockStatement!(config)(blockLocation, statements);
		
		return statement;
	}
	
	ICompoundStatement parseMixedBlock()
	{
		import std.conv: to;
		
		ICompoundStatement statement;
		
		IStatement[] statements;
		
		CustLocation loc = this.currentLocation;
		
 		assert( lexer.front.test( LexemeType.MixedBlockBegin ), "parseMixedBlock: Expected MixedBlockBegin" );
 		lexer.popFront();
		
		while( !lexer.empty && !lexer.front.test(LexemeType.MixedBlockEnd) )
		{
			CustLocation itemLoc = this.currentLocation;
			
			if( lexer.front.test( LexemeType.CodeBlockBegin ))
			{
				lexer.popFront();
				statements ~= parseCodeBlock();
			}
			else if( lexer.front.test( LexemeType.Data ) )
			{
				statements ~= new DataFragmentStatement!(config)(itemLoc);
				lexer.popFront();
			}
			else
				assert( 0, "parseMixedBlock: unexpected lexeme type: " ~ (cast(LexemeType) lexer.front.info.typeIndex).to!string );
		}
		
		lexer.popFront(); //Skip MixedBlockEnd
		
		statement = new MixedBlockStatement!(config)(loc, statements);
		
		return statement;
	}

	IExpression parseExpression()
	{
		auto currRangeCopy = lexer.currentRange.save;
		
		auto expr = parseLogicalOrExp();
				
		//Restore currentRange if parser cannot found expression
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
		
		writeln( "parsePrimaryExp: " );
		writeln( "lexemeType: ", cast(LexemeType) lex.info.typeIndex );
		switch( lex.info.typeIndex ) with( LexemeType )
		{
			case Name:
			{
				writeln("case Name: ");
				
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
					//parseName
					//assert(false, "Names parser not implemented yet");
					
					Identifier ident;
					string identName = frontValue.save.array.idup;
					
					lexer.popFront();
					
					while( !lexer.empty )
					{
						if( !lexer.front.test( LexemeType.Dot ) )
							break;
							
						lexer.popFront();
							
						if( !lexer.front.test( LexemeType.Name ) )
							assert( false, "Expected name, but got: " ~ lexer.frontValue.array.to!string );
						
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
							
							assert( arg, "Null call argument expression found!!!" );
							
							argList ~= arg;
							
							if( lexer.front.test( LexemeType.RParen ) )
								break;
							
							assert( lexer.front.test( LexemeType.Comma ), "Expected Comma, but got: " ~ lexer.frontValue.array.to!string );

							lexer.popFront();
						}
						
						
						//Parse function call syntax
						
						assert( lexer.front.test( LexemeType.RParen ), "Expected right paren, but got: " ~ lexer.frontValue.array.to!string );
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
				writeln("case Integer: ");
				//writeln("lexer.frontValue.array: ", lexer.frontValue.array);
				expr = new IntegerExp!(config)(loc, lexer.frontValue.array.to!IntegerType);
				lexer.popFront();
				
				break;
			}
			case Float:
			{
				writeln("case Float: ");
				//writeln("lexer.frontValue.array: ", lexer.frontValue.array);
				expr = new FloatExp!(config)(loc, lexer.frontValue.array.to!FloatType);
				lexer.popFront();
			
				break;
			}
			case String:
			{
				writeln("case String: ");
				
				expr = new StringExp!(config)(loc, lexer.frontValue.array.to!string);
				lexer.popFront();
		
				break;
			}
			case LParen:
			{
				writeln("case LParen: ");
				
				lexer.popFront();
				expr = parseExpression();
				
				assert( lexer.front.test(LexemeType.RParen), "Expected right paren, closing expression!" );
				lexer.popFront();
				
				break;
			}
			case LBracket:
			{
				writeln("case LBracket: ");
				
				lexer.popFront();
				
				IExpression[] values;
				
				while( !lexer.empty && !lexer.front.test( LexemeType.RBracket ) )
				{
					expr = parseExpression();
					
					assert( expr, "Null array element expression found!!!" );
					
					writeln("LEXER: ", cast(LexemeType) lexer.front.info.typeIndex);
					
					values ~= expr;
					
					writeln( "ERROR TEST 1: ", cast(LexemeType) lexer.front.info.typeIndex );
					if( lexer.front.test( LexemeType.RBracket ) )
					{
						//lexer.popFront();
						writeln( "ERROR TEST 2: ", cast(LexemeType) lexer.front.info.typeIndex );
						break;
					}

					assert( lexer.front.test( LexemeType.Comma ),
						"Expected Comma, but got: " 
						~ (cast(LexemeType) lexer.front.info.typeIndex).to!string
						~ " at " ~ this.currentLocation.index.to!string 
					);
					
					lexer.popFront();
				}
				
				assert( lexer.front.test(LexemeType.RBracket), "Expected right bracket, closing array literal!" );
				lexer.popFront();
				
				expr = new ArrayLiteralExp!(config)(loc, values);
			
				break;
			}
			case LBrace:
			{
				writeln("case LBrace: ");
				
				lexer.popFront();
				
				IExpression[] keys;
				IExpression[] values;
				
				while( !lexer.empty && !lexer.front.test( LexemeType.RBrace ) )
				{
					auto keyExpr = parseExpression();
					
					if( !lexer.front.test( LexemeType.Colon ) )
						assert( false,
							"Expected colon, but got: " 
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
						assert( false,
							"Expected comma, but got: " 
							~ (cast(LexemeType) lexer.front.info.typeIndex).to!string
							~ " at " ~ this.currentLocation.index.to!string 
						);
					
					lexer.popFront();
				}
				
				assert( lexer.front.test(LexemeType.RBrace), "Expected right brace, closing assoc array literal!" );
				lexer.popFront();
				
				expr = new AssocArrayLiteralExp!(config)(loc, keys, values);
				
				break;
			}
			default:
			
				break;
		}
		return expr;
	}
	
	static int[int] lexToBinaryOpMap;
	
	shared static this()
	{
		lexToBinaryOpMap = [
			LexemeType.Add: Operator.Add,
			LexemeType.Sub: Operator.Sub,
			LexemeType.Mul: Operator.Mul,
			LexemeType.Div: Operator.Div,
			LexemeType.Mod: Operator.Mod
		];
	}
	
	IExpression parseMulExp()
	{
		writeln("parseMulExp");
		
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
		writeln("parseAddExp");
		
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
					break lexerRangeLoop;
			}
		}
		
		return left;
	}

	IExpression parseUnaryExp()
	{
		writeln("parseUnaryExp");
		
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
				expr = parsePrimaryExp();
				break;
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
		writeln("parseCompareExp");
		
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
		writeln("parseLogicalAndExp");
		
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
		writeln("parseLogicalOrExp");
		
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
