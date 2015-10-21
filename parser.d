module declarative.parser;

import std.stdio;
import std.range;

import declarative.lexer, declarative.lexer_tools, declarative.node, declarative.expression, 
	declarative.declaration, declarative.common;


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
			else if( lex.info.typeIndex == LexemeType.DataBlockBegin )
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
	
	IExpression parseExpression()
	{
		return parseLogicalOrExp();
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

void printNodesRecursive(IDeclNode node, int indent = 0)
{
	import std.range: repeat;
	import std.conv: to;
	
	if( node )
	{
		writeln( '\t'.repeat(indent), node.kind() );
		
		foreach( child; node.children )
		{
			child.printNodesRecursive(indent+1);
		}
	}
	else
		writeln( '\t'.repeat(indent), "Node is null!" );
}

void main()
{
		
	alias TextRange = TextForwardRange!(string, LocationConfig());
	
	auto parser = new Parser!(TextRange)(
` [ ( 10 + 20 * ( 67 - 22 ) ) ] + [ 100 * 100, 15 ] - [ 16.6 - 7 ] + { "aaa": "bbb" } ~ doIt(  checkIt( [] + {} ) + 15 ) ;`, "source.tpl");
	
	
	//try {
		parser.lexer.popFront();
		auto expr = parser.parseExpression();
		
		writeln;
		writeln("Recursive printing of nodes:");
		
		expr.printNodesRecursive();

	//} catch(Throwable) {}
	
	writeln;
	writeln("List of lexemes:");
	
	import std.array: array;
	
	foreach( lex; parser.lexer.lexemes )
	{
		writeln( cast(LexemeType) lex.info.typeIndex, "  content: ", lex.getSlice(parser.lexer.sourceRange).array );
	}

}
