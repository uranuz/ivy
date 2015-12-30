module declarative.parser;

import std.range: empty;
import std.conv;
import std.stdio;

import declarative.parse_tools;
import declarative.lexer;
import declarative.node;

struct Parser(LexerT)
{
	static LexemeType[] compareOperators = [
		LexemeType.Eq, LexemeType.NE, LexemeType.LT, LexemeType.LTEq, 
		LexemeType.GT, LexemeType.GTEq
	];
	
	alias String = LexerT.String;
	enum ToolConfig config = LexerT.config;
	alias Node = declarative.node.Node!(String, config);
	alias ParserFuncType = Node function(ref LexerT lexer);
	alias LexemeT = Lexeme!(String, config);
	
	LexerT.String str;
	LexerT lexer;
	
	static ParserFuncType[String] statementParsers;
	
	shared static this()
	{
		statementParsers = [
			"if": &parseIf,
			"for": &parseFor,
			"set": &parseSet,
			"macro": &parseMacro
		];
	}
	
	struct TokRule
	{
		LexemeType type;
		String name;
	}
	
	this(String str)
	{
		lexer = LexerT(str);
	}
	
	static parseAssignTarget(ref LexerT lexer, bool withTuple = true, 
		bool nameOnly = false, TokRule[] extraEndRules = null)
	{
		Node target;
		
		if( nameOnly )
		{
			auto lex = lexer.expect(LexemeType.Name);
			target = Node( "name", ["name": lex.value], lex );
			target.setAttr("ctx", "store");
		}
		else
		{
			if( withTuple )
				target = parseTuple(lexer, true, true, extraEndRules);
			else
				target = parsePrimary(lexer);
				
			target.setAttr("ctx", "store");
		}
		
// 		if( !target.getAttr("canAssign").boolean )
// 			assert( false, "Target is not assignable!!!" );
			
		return target;
	}
	
	static Node parseTuple(ref LexerT lexer, bool simplified = false, bool withCondExpr = true, TokRule[] extraEndRules = null, bool explicitParenthesis = false )
	{
		alias ParseMethod = Node function(ref LexerT lexer);
		
		LexemeT firstLex = lexer.front;
		
		ParseMethod parse;
				
		if( simplified )
		{
			parse = &parsePrimary;
		}
		else if( withCondExpr )
		{
			parse = (ref LexerT lexer) => parseExpression(lexer, true);
		}
		else
		{
			parse = (ref LexerT lexer) => parseExpression(lexer, false);
		}
		
		Node[] args;
		bool isTuple = false;
		while( true )
		{
			if( args.length )
			{
				lexer.expect(LexemeType.Comma);
			}
			if( isTupleEnd(lexer, extraEndRules) )
				break;
			args ~= parse(lexer);
			if( lexer.front.type == LexemeType.Comma )
				isTuple = true;
			else
				break;
		}
		
		if( !isTuple )
				if( args.length > 0 )
					return args[0];
		
		if( !explicitParenthesis )
			assert( false, "Expected an expression, got" );
		
		Node node = Node( "tuple", ["items": args], firstLex);
		node.setAttr("ctx", "load");
		node.setAttr("canAssign", false); //TODO: Fix me
		
		return node;
	}
	
	static LexemeType[] tupleEndLexemes = [
		LexemeType.VariableEnd,
		LexemeType.BlockEnd,
		LexemeType.RParen
	];
	
	static bool isTupleEnd(ref LexerT lexer, TokRule[] endRules)
	{
		import std.algorithm: canFind;
		
		LexemeT lex = lexer.front;
		
		if( tupleEndLexemes.canFind(lex.type) )
		{
			return true;
		}
//  		else if( endRules is not None )
//  			return self.stream.current.test_any(extra_end_rules)
		return false;
	}
	
	static Node parseSet(ref LexerT lexer)
	{
		lexer.popFront();
		LexemeT firstLex = lexer.front;
		Node target = parseAssignTarget(lexer);
		
		writeln("parseSet: 1. lexer.front = ", lexer.front);
		if( lexer.skipIf(LexemeType.Assign) )
		{
			writeln("parseSet: 2. lexer.front = ", lexer.front);
			Node expr = parseTuple(lexer);
			return Node("assign", ["target": target, "node": expr], firstLex);
		}
		writeln("parseSet: 3");
		Node body_ = parseStatements(lexer, [TokRule(LexemeType.Name, "endset")], true);
		
		return Node( "assignBlock", ["target": target, "body": body_], firstLex );
	}
	
	static Node parseFor(ref LexerT lexer)
	{
		lexer.expect(LexemeType.Name, "for");
		Node target = parseAssignTarget(lexer, true, false, [TokRule(LexemeType.Name, "in")]);
		lexer.expect(LexemeType.Name, "in");
		Node iter = parseTuple(lexer, false, false, [TokRule(LexemeType.Name, "recursive")]);
		Node test;
		if( lexer.skipIf(LexemeType.Name, "if") )
			test = parseExpression(lexer);
		Node recursive = lexer.skipIf(LexemeType.Name, "recursive");
		Node body_ = parseStatements(lexer, [TokRule(LexemeType.Name, "endfor"), TokRule(LexemeType.Name, "else")]);
		writeln("parseFor: lexer.front = ", lexer.front);
		lexer.popFront();
		Node else_;
// 		if( lexer.front.value != "endfor" )
// 			else_ = parseStatements(lexer, [TokRule(LexemeType.Name, "endfor")], true);
		return Node( "for", ["target": target, "iter": iter, "body": body_, "else": else_, "test": test, "recursive": recursive ] );
	}
	
	static Node parseIf(ref LexerT lexer)
	{
		LexemeT startLex = lexer.front;
		lexer.expect(LexemeType.Name, "if");
		Node node = Node( "if", ["test": null], startLex );
		while( true )
		{
			node["test"] = parseTuple(lexer, false, false);
			node["body"] = parseStatements(lexer, 
				[TokRule(LexemeType.Name, "elif"), TokRule(LexemeType.Name, "else"), TokRule(LexemeType.Name, "endif")]);
			lexer.popFront();
			LexemeT lex = lexer.front;
			
			if( lexer.front.test(LexemeType.Name, "elif") )
			{
				Node new_node = Node( "if", ["test": null], lex );
				node["else_"] = [new_node];
				node = new_node;
				continue;
			}
			else if( lexer.front.test(LexemeType.Name, "else") )
			{
				node["else_"] = parseStatements(lexer, [TokRule(LexemeType.Name, "endif")], true);
			}
			else
			{
				node["else_"] = (Node[]).init;
			}
			break;
		}
		return node;
	}
	
	static Node parseMacro(ref LexerT lexer)
	{
		lexer.expect(LexemeType.Name, "macro");
		Node node = Node( "macro", ["name": parseAssignTarget(lexer, true, true).name ] );
		parseSignature(lexer, node);
		node["body"] = parseStatements(lexer, [TokRule(LexemeType.Name, "endmacro")], true);
		
		return node;
	}
	
	static void parseSignature(ref LexerT lexer, ref Node node)
	{
		lexer.expect(LexemeType.LParen);
		Node[] args;
		Node[] defaults;
		while( lexer.front.type != LexemeType.RParen )
		{
			if( !args.empty )
				lexer.expect(LexemeType.Comma);
			
			Node arg = parseAssignTarget(lexer, true, true);
// 			arg.set_ctx('param')
			if( lexer.skipIf(LexemeType.Assign) )
				defaults ~= parseExpression(lexer);
			args ~= arg;
		}
		lexer.expect(LexemeType.RParen);
		node["args"] = args;
		node["defaults"] = defaults;
	}
	
	static Node parseCall(ref LexerT lexer, ref Node node)
	{
		Node[] args;
		Node[] kwArgs;
		Node dynArgs;
		Node dynKwArgs;
		
		bool requireComma = false;
		
		void ensure(bool expr)
		{
			if( !expr )
				assert( false, "Invalid syntax for function call expression" );
		}
		
		while( lexer.front.type != LexemeType.RParen )
		{
			if( requireComma )
			{
				lexer.expect(LexemeType.Comma);
				if( lexer.front.type == LexemeType.RParen )
					break;
			}
			if( lexer.front.type == LexemeType.Mul )
			{
				ensure( dynArgs.empty && dynKwArgs.empty );
				lexer.popFront();
				dynArgs = parseExpression(lexer);
			}
			else if( lexer.front.type == LexemeType.Pow )
			{
				ensure( dynKwArgs.empty );
				lexer.popFront();
				dynKwArgs = parseExpression(lexer);
			}
			else
			{
				ensure( dynArgs.empty && dynKwArgs.empty );
				if( lexer.front.type == LexemeType.Name && 
					lexer.next.type == LexemeType.Assign )
				{
					Node key = lexer.front.value;
					lexer.popFrontN(2);
					Node value = parseExpression(lexer);
					kwArgs ~= Node( "keyword", ["key": key, "value": value] );
				}
				else
				{
					ensure( kwArgs.empty );
					args ~= parseExpression(lexer);
				}
			}
			requireComma = true;
		}
		lexer.expect(LexemeType.RParen);
// 		if node is None:
// 			return args, kwargs, dyn_args, dyn_kwargs
		return Node( "call", ["node": node, "args": Node(args), "kwargs": Node(kwArgs), "dyn_args": dynArgs, "dyn_kwargs": dynKwArgs] );
	}
	
	static Node parseStatements(ref LexerT lexer, TokRule[] endTokens = null, bool dropNeedle = false)
	{
		//the first token may be a colon for python compatibility
		lexer.skipIf(LexemeType.Colon);

		lexer.expect(LexemeType.BlockEnd);
		Node result = subparse(lexer, endTokens);
		
		if( lexer.front.type == LexemeType.EOF )
			assert( false, "EOF found too early!!!");
			
		if( dropNeedle )
			lexer.popFront();
		
		return result;
	}
	
	static Node parseExpression(ref LexerT lexer, bool withCondExpr = true)
	{
		if( withCondExpr )
		{
			return parseCondExpr(lexer);
		}
		writeln("parseExpression 1: lexer.front = ", lexer.front);
		scope(exit) writeln("parseExpression 2: lexer.front = ", lexer.front);
		return parseOr(lexer);
	}
	
	static Node parseCondExpr(ref LexerT lexer)
	{
		LexemeT firstLex = lexer.front;
		
		Node expr1 = parseOr(lexer);
		Node expr2;
		Node expr3;
		while( lexer.skipIf(LexemeType.Name, "if") )
		{
			expr2 = parseOr(lexer);
			if( lexer.skipIf(LexemeType.Name, "else") )
			{
				expr3 = parseCondExpr(lexer);
			}
			else
			{
				expr3 = null;
			}
			expr1 = Node( "condExpr", ["test": expr2, "expr1": expr1, "expr2": expr3], firstLex );
		}
		return expr1;
	}
	
	static Node parseOr(ref LexerT lexer)
	{
		LexemeT firstLex = lexer.front;
		Node left = parseAnd(lexer);
		Node right;
		while( lexer.skipIf(LexemeType.Name, "or") )
		{
			right = parseAnd(lexer);
			left = Node( "or", ["left": left, "right": right], firstLex);
		}
		
		return left;
	}
	
	static Node parseAnd(ref LexerT lexer)
	{
		LexemeT firstLex = lexer.front;
		Node left = parseNot(lexer);
		Node right;
		while( lexer.skipIf(LexemeType.Name, "and") )
		{
			right = parseNot(lexer);
			left = Node( "and", ["left":left, "right": right], firstLex );
		}
		
		return left;
	}
	
	static Node parseNot(ref LexerT lexer)
	{
		auto lex = lexer.front;
		if( lex.test(LexemeType.Name, "not") )
		{
			lexer.popFront();
			return Node( "not", ["not": parseNot(lexer)], lex);
		}
		return parseCompare(lexer);
	}
	
	static Node parseCompare(ref LexerT lexer)
	{
		import std.algorithm: canFind;
		
		Node expr = parseAdd(lexer);
		Node[] ops;
		
		LexemeType lexType;
		LexemeT compareLex = lexer.front;
		
		while( true )
		{
			LexemeT lex = lexer.front;
			lexType = lex.type;
			if( compareOperators.canFind(lexType) )
			{
				lexer.popFront(); //skip operator
				ops ~= Node( "operand", ["op": Node(lex.value), "expr": parseAdd(lexer)], lex );
			}
			else if( lexer.skipIf(LexemeType.Name, "in") )
			{
				ops ~= Node( "operand", ["op": Node("in"), "expr": parseAdd(lexer)], lex );
			}
			else if( lexer.front.test(LexemeType.Name, "not") && 
				lexer.next.test(LexemeType.Name, "in")  )
			{
				lexer.popFrontN(2);
				ops ~= Node( "operand", ["op": Node("notin"), "expr": parseAdd(lexer)], lex);
			}
			else
				break;
		}
		if( ops.empty )
			return expr;
		return Node( "compare", ["expr": expr, "ops": Node(ops)], compareLex);
	}
	
	static Node parseAdd(ref LexerT lexer)
	{
		Node left = parseSub(lexer);
		Node right;
		while( lexer.front.type == LexemeType.Add )
		{
			lexer.popFront();
			right = parseSub(lexer);
			left = Node( "add", ["left": left, "right": right] );
		}
		return left;
	}
	
	static Node parseSub(ref LexerT lexer)
	{
		Node left = parseConcat(lexer);
		Node right;
		while( lexer.front.type == LexemeType.Sub )
		{
			lexer.popFront();
			right = parseConcat(lexer);
			left = Node( "sub", ["left": left, "right": right] );
		}
		return left;
	}
	
	static Node parseConcat(ref LexerT lexer)
	{
		Node[] args = [ parseMul(lexer) ];
		while( lexer.front.type == LexemeType.Tilde )
		{
			lexer.popFront();
			args ~= parseMul(lexer);
		}
		
		if( args.length == 1 )
			return args[0];
		return Node( "concat", ["nodes": Node(args)] );
	}
	
	static Node parseMul(ref LexerT lexer)
	{
		Node left = parseDiv(lexer);
		Node right;
		while( lexer.front.type == LexemeType.Mul )
		{
			lexer.popFront();
			right = parseDiv(lexer);
			left = Node( "mul", ["left": left, "right": right] );
		}
		return left;
	}
	
	static Node parseDiv(ref LexerT lexer)
	{
		Node left = parseFloorDiv(lexer);
		Node right;
		while( lexer.front.type == LexemeType.Div )
		{
			lexer.popFront();
			right = parseFloorDiv(lexer);
			left = Node( "div", ["left": left, "right": right] );
		}
		return left;
	}
	
	static Node parseFloorDiv(ref LexerT lexer)
	{
		Node left = parseMod(lexer);
		Node right;
		while( lexer.front.type == LexemeType.FloorDiv )
		{
			lexer.popFront();
			right = parseMod(lexer);
			left = Node( "floorDiv", ["left": left, "right": right] );
		}
		return left;
	}
	
	static Node parseMod(ref LexerT lexer)
	{
		Node left = parsePow(lexer);
		Node right;
		while( lexer.front.type == LexemeType.Mod )
		{
			lexer.popFront();
			right = parsePow(lexer);
			left = Node( "mod", ["left": left, "right": right] );
		}
		return left;
	}
	
	static Node parsePow(ref LexerT lexer)
	{
		Node left = parseUnary(lexer);
		Node right;
		while( lexer.front.type == LexemeType.Pow )
		{
			lexer.popFront();
			right = parseUnary(lexer);
			left = Node( "pow", ["left": left, "right": right] );
		}
		return left;
	}
	
	static Node parseUnary(ref LexerT lexer, bool withFilter = true)
	{
		LexemeType lexType = lexer.front.type;
		Node node;
		if( lexType == LexemeType.Sub )
		{
			lexer.popFront();
			node = Node( "neg", ["node": parseUnary(lexer, false)] );
		}
		else if( lexType == LexemeType.Add )
		{
			lexer.popFront();
			node = Node( "pos", ["node": parseUnary(lexer, false)] );
		}
		else
			node = parsePrimary(lexer);
// 		node = parsePostfix(node);
// 		if( withFilter )
// 			node = parseFilterExpr(node);
		return node;
	}
	
// 	static Node parsePostfix(ref LexerT lexer, ref Node node)
// 	{
// 		LexemeType lexType
// 		while( true )
// 		{
// 			lexType = lexer.front.type;
// 			if( lexType == LexemeType.Dot || lexType ==  )
// 		}
// 	}
	
	static Node parsePrimary(ref LexerT lexer)
	{
		import std.algorithm: canFind;
		Node node;
		
		auto lex = lexer.front;
		if( lex.type == LexemeType.Name )
		{
			if( ["True", "true"].canFind(lex.value) )
				node = Node( "const", ["value": true], lex );
			else if( ["False", "false"].canFind(lex.value) )
				node = Node( "const", ["value": false], lex);
			else if( ["none", "None"].canFind(lex.value) )
				node = Node( "const", ["value": Node(null)], lex);
			else 
				node = Node( "name", ["value": lex.value], lex);
			lexer.popFront();
		}
		else if( lex.type == LexemeType.String )
		{
			LexemeT firstLex = lex;
			String buf;
			while( !lexer.empty && lexer.front.type == LexemeType.String )
			{
				buf ~= lexer.front.value;
				lexer.popFront();
			}
			
			node = Node( "const", ["value": buf], firstLex);
// 			lexer.popFront();
		}
		else if( lex.type == LexemeType.Integer || lex.type == LexemeType.Float )
		{
			if( lex.type == LexemeType.Integer )
				node = Node( "const", ["value": lex.value.to!long], lex );
			else
				node = Node( "const", ["value": lex.value.to!double], lex );
			lexer.popFront();
		}
		else if( lex.type == LexemeType.LParen )
		{
			lexer.popFront(); //skip paren
			node = parseTuple(lexer, false, true, null, true );
			lexer.expect(LexemeType.RParen);
		}
		else if( lex.type == LexemeType.LBracket )
		{
			node = parseList(lexer);
		}
		else if( lex.type == LexemeType.LBrace )
		{
			node = parseDict(lexer);
		}
		else
			assert( false, "Unexpected lexeme" );
		
		return node;
	}
	
	static Node parseList(ref LexerT lexer)
	{
		LexemeT firstLex = lexer.expect(LexemeType.LBracket);
		Node[] items;
		
		while( lexer.front.type != LexemeType.RBracket )
		{
			if( !items.empty )
				lexer.expect(LexemeType.Comma);
			
			if( lexer.front.type == LexemeType.RBracket )
				break;
			items ~= parseExpression(lexer);
		}
		lexer.expect( LexemeType.RBracket );
		
		return Node( "list", ["items": items], firstLex);
	}
	
	static Node parseDict(ref LexerT lexer)
	{
		LexemeT startLex = lexer.front;
		writeln("parseDict: 1");
		lexer.expect(LexemeType.LBrace);
		Node[] items;
		
		while( lexer.front.type != LexemeType.RBrace )
		{
			if( !items.empty )
				lexer.expect(LexemeType.Comma);
			if( lexer.front.type == LexemeType.RBrace )
				break;
			LexemeT pairLex = lexer.front;
			Node key = parseExpression(lexer);
			writeln("parseDict: 2. lexer.front = ", lexer.front);
			lexer.expect(LexemeType.Colon);
			writeln("parseDict: 3. lexer.front = ", lexer.front);
			Node value = parseExpression(lexer);
			items ~= Node( "pair", ["key": key, "value": value], pairLex );
// 			lexer.popFront();
			writeln("parseDict: 4. lexer.front = ", lexer.front);
		}
		writeln("parseDict: 5. lexer.front = ", lexer.front);
		lexer.expect( LexemeType.RBrace );
		return Node( "dict", ["items": items], startLex );
	}
	
	static Node subparse(ref LexerT lexer, TokRule[] endTokens = null)
	{
		Node[] body_;
		Node[] dataBuffer;
		
		LexemeT lex;
		
		void flushData()
		{
			if( !dataBuffer.empty )
			{
				body_ ~= Node( "output", ["nodes": dataBuffer[]], lex );
				dataBuffer = null;
			}
		}
		
		while( !lexer.empty )
		{
			lex = lexer.front;
			
			if( lex.type == LexemeType.Data  )
			{
				if( !lex.value.empty )
					dataBuffer ~= Node( "templateData", ["data": lex.value], lex );
				
				lexer.popFront();
			}
			else if( lex.type == LexemeType.VariableBegin )
			{
				lexer.popFront();
				dataBuffer ~= parseTuple(lexer, false, true);
				lexer.expect(LexemeType.VariableEnd);
			}
			else if( lex.type == LexemeType.BlockBegin )
			{
				flushData();
				lexer.popFront();
				writeln();
				writeln("subparse: lexer.front.value = ", `"` ~ lexer.front.value ~ `"`);
				writeln("subparse: endTokens = ", endTokens);
				if( !endTokens.empty )
				{
					foreach( tok; endTokens )
					{
						if( lexer.front.test( tok.type, tok.name ) )
							return Node(body_);
					}
				}
				Node rv = parseStatement(lexer);
				if( rv.type == NodeType.Array )
					body_ ~= rv.array;
				else
					body_ ~= rv;
				writeln("subparse: lexer.front = ", lexer.front);
// 				writeln("subparse: lexer.next = ", lexer.next);
				lexer.expect(LexemeType.BlockEnd);
			}
			else
				assert( false, "Unexpected something!!" );
		}
		
		flushData();
		
		return Node(body_);
	}
	
	static Node parseStatement(ref LexerT lexer)
	{
		auto lex = lexer.front;
		
		scope(exit)
			writeln("parseStatement exit: lexer.front = ", lexer.front);
		
		if( lexer.empty )
			assert( false, "Expected statement but end of input found!!!");
		
		if( lex.type != LexemeType.Name )
			assert( false, "Statement word expected!!!" );
		
		writeln("parseStatement start: lexer.value = ", `"` ~ lex.value ~ `"`);
		
		if( lex.value in statementParsers )
			return statementParsers[lex.value](lexer);
		
		
		
		assert( false, "Cannot parse statement!!!" );
	}
	
	Node parse()
	{
		Node result = Node( "template", ["body": subparse(lexer)] );
		return result;
	}
}

import std.stdio;
import std.exception;
import core.exception;

void main()
{
	alias MyParser = Parser!(Lexer!(string));
	
	MyParser parser;
	
try {

// string tpl = 
// `
// {% if value %}
// 	{% set vasya = {2: 1, "names" : ["Vasya", "Petya", "Vova", "Gosha"] } %}
// 	{% for item in items %}
// 		vova is {{ petya }}
// 	{% endfor %}
// {% endif %}
// 
// `;

string tpl = 
`
{% if (5 + 3 * 7, "petya") %}
	Привет, Вовчик!
{% endif %}

`;

	parser = MyParser(tpl);
} catch(AssertError e) {
	foreach( lex; parser.lexer.lexemes )
		writeln(lex);
		
// 	writeln("parser.lexer.front = ", parser.lexer.front);
// 	writeln("parser.lexer.next = ", parser.lexer.next);

}

auto tree = parser.parse();
	writeln(tree);
	
}