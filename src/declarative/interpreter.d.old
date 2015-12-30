module jinjed.interpreter;

struct Context(String)
{
	Context* parent;
	Node[String] names;
	void setLocal(String name, ref Node node)
	{
		names[name] = node;
	}
}


struct Interpreter(String) {

	alias Node
	alias IterpreterFunc = Node function(ref Context ctx, ref Node node);
	
	static IterpreterFunc[String] iterpreters;
	
	shared static this()
	{
		iterpreters = [
			"output": &execStatements,
			"if": &execIf
		];
	}
	
	void execNode(ref Context ctx, ref Node node)
	{
		if( !node.name.empty )
		{
			//Literal node
		}
		else
		{
			if( node.name in iterpreters )
			{
				return interpreters[node.name](ctx, node);
			}
		}
	}

	static Node asString(ref Node node)
	{
		import std.conv;
		
		if( node.type == NodeType.Null )
			return Node("");
		else if( node.type == NodeType.Boolean )
			return Node(node.boolean ? "true" : "false");
		else if( node.type == NodeType.Integer )
			return Node( node.integer.to!String );
		else if( node.type == NodeType.Floating )
			return Node( node.floating.to!String );
		else if( node.type == NodeType.String )
			return Node( node.str );
		else if( node.type == NodeType.Array )
		{
			String tmp = "[";
			foreach( i, el; node.array )
			{
				tmp ~= ( i > 0 : ", " : "" ) ~ asString(el);
			}
			tmp ~= "]";
			
			return Node(tmp);
		}
		else if( node.type == NodeType.Dict )
		{
			String tmp = "{";
			size_t i = 0;
			foreach( key, val; node.array )
			{
				tmp ~= ( i > 0 : ", " : "" ) ~ key ~ ": " ~ asString(el);
				i++;
			}
			tmp ~= "}";
			
			return Node(tmp);
		}
		assert( false, `Unexpected node type!!!` );
	}
	
// 	static String concatArray(Node[] nodes)
// 	{
// 		String str;
// 		foreach( ref node; nodes )
// 		{
// 			str ~= asString(node);
// 		}
// 		return str;
// 	}

	static Node execStatements(ref Context ctx, ref Node node)
	{
		assert( node.name == "output", `Expected "output" node as statements list!!!` );
		
		
		assert( "nodes" in node, `Expected "nodes" field in statements list!!!` );
		
		Node nodes = output["node"];
		assert( nodes.type == NodeType.Array, `Statements list node must be of "array" type!!!` );
		
		String result;
		
		foreach( stmt; nodes.array )
			result ~= asString( execNode(ctx, stmt) );

		return Node(result);
	}
	
	static Node execExpression(ref Context ctx, ref Node node)
	{
		
	}
	
	static Node execBooleanExpression(ref Context ctx, ref Node node)
	{
		if( node.type == NodeType.Null )
			return Node(false);
		else if( node.type == NodeType.Boolean )
			return node;
		else if( node.type == NodeType.String )
		{
			return Node( !node.str.empty );
		}
		else if( node.type == NodeType.Integer )
		{
			return Node( node.integer != 0 );
		}
		else if( node.type == NodeType.Floating )
		{
			return Node( node.floating != 0.0 );
		}
		else if( node.type == NodeType.Array )
		{
			return Node( !node.array.empty )
		}
		else if( node.type == NodeType.Dict )
		{
			return execBooleanExpression( ctx, execNode(ctx, node) );
		}
	}
	

	static Node execIf(ref Context ctx, ref Node node)
	{
		assert( node.name == "if" && node.type == LexemeType.Dict, `Expected "if" node of type "Dict"` );
		
		assert( "test" in node, `Expected "test" field in "if" node!!!` );
		
		Node test = execBooleanExpression( ctx, node["test"] );
		Node body_ = execStatements( ctx, node["body"] );
		Node else_ = execStatements( ctx, node["else_"] );
		
		assert( test.type == NodeType.Boolean, `Expected "test" field of boolean type in "if" statement` );
		
		if( test.boolean )
		{
			return body_;
		}
		else 
		{
			return else_;
		}
	}

	static Node calcBinary(string op)(ref Node left, ref Node right)
		if( op == "+" || op == "-" || op == "*" )
	{
		Node result;
		
		if( left.type == NodeType.Integer && right.type == NodeType.Integer )
		{
			mixin( `result = left.integer ` ~ op ~ ` right.integer;` );
		}
		else if( left.type == NodeType.Floating && right.type == NodeType.Floating )
		{
			mixin( `result = left.floating ` ~ op ~ ` right.floating;` );
		}
		else if( left.type == NodeType.Integer && right.type == NodeType.Floating )
		{
			mixin( `result = (cast(double) left.integer) ` ~ op ~ ` right.floating;` );
		}
		else if( left.type == NodeType.Floating && right.type == NodeType.Integer )
		{
			mixin( `result = left.floating ` ~ op ~ ` (cast(double) right.integer);` );
		}
		else
			assert( false, `"` ~ op ~ `" binary operation is implemented for "integer" and "floating" only!!!` );
		
		return result;
	}

	static Node calcBinary(string op)(ref Node left, ref Node right)
		if( op == "/" )
	{
		Node result;
		
		if( left.type == NodeType.Integer && right.type == NodeType.Integer )
		{
			result = (cast(double) left.integer) / (cast(double) right.integer);
		}
		else if( left.type == NodeType.Floating && right.type == NodeType.Floating )
		{
			result = left.floating / right.floating;
		}
		else if( left.type == NodeType.Integer && right.type == NodeType.Floating )
		{
			result = (cast(double) left.integer) / right.floating;
		}
		else if( left.type == NodeType.Floating && right.type == NodeType.Integer )
		{
			result = left.floating / (cast(double) right.integer);
		}
		else
			assert( false, `"/" binary operation is implemented for "integer" and "floating" only!!!` );
		
		return result;
	}

	static Node calcBinary(string op)(ref Node left, ref Node right)
		if( op == "//" )
	{
		Node result;
		
		if( left.type == NodeType.Integer && right.type == NodeType.Integer )
		{
			result = left.integer / right.integer);
		}
		else if( left.type == NodeType.Floating && right.type == NodeType.Floating )
		{
			result = cast(long) left.floating / right.floating;
		}
		else if( left.type == NodeType.Integer && right.type == NodeType.Floating )
		{
			result = cast(long) left.integer / right.floating;
		}
		else if( left.type == NodeType.Floating && right.type == NodeType.Integer )
		{
			result = cast(long) left.floating / right.integer;
		}
		else
			assert( false, `"/" binary operation is implemented for "integer" and "floating" only!!!` );
		
		return result;
	}

	static Node calcBinary(string op)(ref Node left, ref Node right)
		if( op == "or" )
	{
		Node result;
		
		if( left.type == NodeType.Boolean && right.type == NodeType.Boolean )
		{
			result = left.boolean || right.boolean;
		}
		else
			assert( false, `"or" binary operation is implemented for "boolean" only!!!` );
		
		return result;
	}

	static Node calcBinary(string op)(ref Node left, ref Node right)
		if( op == "and" )
	{
		Node result;
		
		if( left.type == NodeType.Boolean && right.type == NodeType.Boolean )
		{
			result = left.boolean && right.boolean;
		}
		else
			assert( false, `"and" binary operation is implemented for "boolean" only!!!` );
		
		return result;
	}

	static Node execBinary(ref Context ctx, ref Node binExpr)
	{
		assert( !!("left" in binExpr) && !!("right" in binExpr) && !!("operator" in binExpr),
			`Expected "left", "right", "operator" fields in binary expression node!!!`
		);
		
		
		Node left = execNode(ctx, binExpr["left"]);
		Node right = execNode(ctx, binExpr["right"]);
		Node operator = execNode(ctx, binExpr["operator"]);
		
		Node result;
		
		assert( operator.type == NodeType.String, "Operator node must be of string type!!!" );
		
		alias Ops = TypeTuple!("+", "-", "*", "/", "//", "**", "%", "and", "or")
		
		switch( operator.str)
		{
			foreach( op; Ops )
			{
				case op: {
					result = calcBinary!(op)(left, right);
					break;
				}
			}
			default: {
				assert( false, `Unexpected binary operator!!!` )
				break;
			}
		}
		
		return result;
	}

	static Node calcUnary(string op)(ref Node node)
		if( op == "+" )
	{
		if( node.type == NodeType.Integer || node.type == NodeType.Floating )
		{
			return node;
		}
		else
			assert(false, `"+" unary operation is implemented for "integer" and "floating" only!!!`);
	}

	static Node calcUnary(string op)(ref Node node)
		if( op == "-" )
	{
		if( node.type == NodeType.Integer)
		{
			return Node( -node.integer );
		}
		else if( node.type == NodeType.Floating )
		{
			return Node( -node.floating );
		}
		else
			assert(false, `"-" unary operation is implemented for "integer" and "floating" only!!!`);
	}

	static Node calcUnary(string op)(ref Node node)
		if( op == "not" )
	{
		if( node.type == NodeType.Boolean)
		{
			return Node( !node.boolean );
		}
		else
			assert(false, `"-" unary operation is implemented for "boolean" only!!!`);
	}

	static Node execUnary(ref Context ctx, ref Node unaryExpr)
	{
		assert( !!("node" in unaryExpr) && !!("operator" in unaryExpr),
			`Expected "node" and "operator" fields in unary expression node!!!`
		);
		
		Node node = unaryExpr["node"];
		Node operator = unaryExpr["operator"];
		
		assert( operator.type == NodeType.String, "Operator node must be of string type!!!" );
		
		switch( operator.str)
		{
			case "+": {
				result = calcUnary!("+")(left, right);
				break;
			} case "-": {
				result = calcUnary!("-")(left, right);
				break;
			} case "not": {
				result = calcUnary!("not")(left, right);
				break;
			} default: {
				assert( false, `Unexpected unary operator!!!` );
				break;
			}
		}
	}


	static Node execFor(ref Context ctx, ref Node node)
	{
		Node result;
		
		
		
		for()
	}

	Node execSet(ref Context ctx, ref Node node)
	{
		

	}

	String execCall(ref Context ctx, ref Node node)
	{
		
	}

}