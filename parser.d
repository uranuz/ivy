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
	
/+
	void parse()
	{
	
		while( !lexer.empty )
		{
			LexemeT lex = lexer.front;
			
			if( lex.info.typeIndex == LexemeType.CodeBlockBegin )
			{
				parseCodeBlockContent();
			
			}
			else if( lex.info.typeIndex == LexemeType.MixedBlockBegin )
			{
				parseDataBlockContent();
			
			}
			
		
		
			lexer.popFront();
		}
	
	}

	
	Statements parseStatements()
	{
		LexemeT lex = lexer.front;
		
		if( lex.info.typeIndex == LexemeType.Name  )
		{
			
		
		}
		else
		{
			parseExpression()
		
		}
	
	}
+/

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
		
		if( attrName.empty || !lexer.front.test( LexemeType.Assign ) || lexer.empty )
		{
			lexer = lexerCopy.save;
			writeln( "parseNamedAttribute(0): lexer restored, LexemeType is: ", 
				cast(LexemeType) lexer.front.info.typeIndex,
				", frontValue is: ", lexer.frontValue.array.to!string
			);
			return null;
		}
		
		lexer.popFront(); //Skip key-value delimeter
		
		IExpression expr = parseExpression();
		
		if( !expr )
		{
			lexer = lexerCopy.save;
			writeln( "parseNamedAttribute(1): lexer restored, LexemeType is: ", 
				cast(LexemeType) lexer.front.info.typeIndex,
				", frontValue is: ", lexer.frontValue.array.to!string
			);
			return null;
		}
		
		return new KeyValueAttribute!(config)(loc, attrName, expr);
	}
	
	IStatement parseStatementBody()
	{
		bool isBlockDetected = 
			lexer.front.test( LexemeType.LBrace ) 
			|| lexer.front.test( LexemeType.CodeBlockBegin ) 
			|| lexer.front.test( LexemeType.MixedBlockBegin )
			|| lexer.front.test( LexemeType.ExprBlockBegin );
		
		IStatement statement;
		
		IStatement[] statements;
		
		if( isBlockDetected )
		{
			int blockTypeIndex = lexer.front.info.typeIndex;
			lexer.popFront();
			
			writeln( "parseStatementBody: block statement detected: ", cast(LexemeType) blockTypeIndex );
			
			switch( blockTypeIndex ) with( LexemeType )
			{
				case LBrace:
				{
					//parseCodeOrDataBlock() depending on current parser state
					assert(0, "Default block is not implemented yet!!!");
					
					break;
				}
				
				case CodeBlockBegin:
				{
					IStatement stmt;
					
					while( !lexer.empty && !lexer.front.test(CodeBlockEnd) )
					{
						stmt = parseDeclarativeStatement();
						assert( stmt !is null, "parseStatementBody: declarative statement is null" );
						statements ~= stmt;
					}
					
					break;
				}
				
				case MixedBlockBegin:
				{
					assert(0, "Data block is not implemented yet!!!");
					
					
					// while( !lexer.empty && !lexer.front.test(MixedBlockEnd) )
					// {
						// if( lexer.front.test())
						
						// stmt = parseDeclarativeStatement();
						// assert( stmt !is null, "parseStatementBody: declarative statement is null" );
					// }
					break;
				}
				case ExprBlockBegin:
				{
				
					break;
				}
				default:
					assert(0, "Undefined block type found!!!");
			}
		
		}
		else
		{
			//expr = parseExpression();
			
		}
		
		return statement;
	}
	
	IExpression parseExpressionBlock()
	{
		IExpression expr;
	
		return expr;
	}
	
	ICompoundStatement parseCodeBlock()
	{
		ICompoundStatement statement;
		
		return statement;
	}
	
	ICompoundStatement parseMixedBlock()
	{
		ICompoundStatement statement;
		
		return statement;
	}
	
	IDeclarationSection parseDeclarationSection()
	{
		import std.array: array;
		import std.conv: to;
		
		CustLocation loc = this.currentLocation;
		
		IDeclarationSection section;
		
		assert( lexer.front.test( LexemeType.Name ), "Expected statement name!!!" );
		
		string sectionName = parseQualifiedIdentifier();
		writeln("section identifier: ", sectionName);
		
		if( sectionName.empty )
			return null;
		
		IExpression[] unnamedAttrs;
		IKeyValueAttribute[] namedAttrs;
		
		bool isUnnamedAfterNamed = false;
		
		while( !lexer.empty )
		{
			auto lexerCopy = lexer.save;
			
			
			if( lexer.front.test( LexemeType.Semicolon ) )
				break;
			
			IExpression attr;
			
			//Try parse named attribute
			IKeyValueAttribute namedAttr = parseNamedAttribute();
			
			writeln( "parseStatement: parsed named attr, frontValue: ", lexer.frontValue.array.to!string );
			writeln( "parseStatement: attr is", ( namedAttr is null ? null : " not" ) ~ " null" );
			
			//If no named attrs detected yet then we try parse unnamed attrs
			if( namedAttr )
			{	//Named attribute parsed, add it to list
				writeln( "Named attribute detected!!!" );
				namedAttrs ~= namedAttr;
			}
			else
			{	//Named attribute was not found will try to parse unnamed one
				attr = parseExpression();
				
				if( attr )
				{
					writeln( "Unnamed attribute detected!!!" );
					
					
					if( !unnamedAttrs.empty )
					{
						isUnnamedAfterNamed = true;
						writeln( "Found unnamed attr after named, possibly it's main body!!!" );
						lexer = lexerCopy.save; //Restore lexer range to original at current step
						break; //Exit loop after this situation detected
					}
					unnamedAttrs ~= attr;
					
				}
			}
			
			if( !namedAttr && !attr )
				break; //If no more attributes parsed then exit loop
			
			if( lexer.front.test( LexemeType.Comma ) )
				lexer.popFront(); //Skip optional Comma
		}
		
		//For single statement body we must use colon to separate it from attributes list
		//But for block statement it's made optional in order to simplify syntax
		
		bool isBodySepFound = false;
		
		if( lexer.front.test( LexemeType.Colon ) )
		{
			isBodySepFound = true;
			lexer.popFront();
		}
		
		IStatement sectionBody = parseStatementBody();
		

		section = new DeclarationSection!(config)(loc, sectionName, cast(IDeclNode[]) unnamedAttrs, namedAttrs, sectionBody);
		
		return section;	
	}
	
	
	

	IDeclarativeStatement parseDeclarativeStatement()
	{
		import std.array: array;
		import std.conv: to;
		
		IDeclarativeStatement stmt = null;
		CustLocation loc = this.currentLocation;
		
		
		
		IDeclarationSection mainSection = parseDeclarationSection();
		
		
		IDeclarationSection[] sections;
		
		// //Parse extended statement bodies
		// while( !lexer.empty )
		// {
			// //Find special lexeme that signals about start of extension body
			// //Extention body cannot have it's own extension bodies,
			// //but can have attribute list
		// }
		
		stmt = new DeclarativeStatement!(config)(loc, mainSection, sections);
		
		return stmt;
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
					left = new BinaryArithmeticExp!(config)(loc, lex.info.typeIndex, left, right);
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
					left = new BinaryArithmeticExp!(config)(loc, lex.info.typeIndex, left, right);
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
				Operator[int] mapping = [
					Equal: Operator.Equal, 
					NotEqual: Operator.NotEqual,
					LT: Operator.LT, 
					GT: Operator.GT,  
					LTEqual: Operator.LTEqual, 
					GTEqual: Operator.GTEqual
				];
				
				lexer.popFront();
				right = parseAddExp();
				left = new CompareExp!(config)(loc, mapping[lex.info.typeIndex], left, right);
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
	
	
/+
	StatementArguments parseStatementArguments()
	{
		while( !lexer.empty )
		{
			IExpression expr = parseExpression();
			
			if( !expr )
			{
				break;
			}
		
		}
		
		while( !lexer.empty )
		{
			ArgumentKeyValuePair expr = parseArgumentKeyValuePair();
			
			if( !expr )
			{
				break;
			}
		}
	}
+/
	
}
