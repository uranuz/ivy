module declarative.interpreter;

import std.stdio, std.conv;

import declarative.node, declarative.node_visitor, declarative.common, declarative.expression;

import declarative.interpreter_data;

interface IInterpreterContext {}

class VariableTable
{
	alias TDataNode = DataNode!string;
	
private:
	TDataNode[string] _vars;
	
public:
	TDataNode getValue( string varName )
	{
		auto varValuePtr = varName in _vars;
		assert( varValuePtr, "VariableTable: Cannot find variable with name: " ~ varName );
		return *varValuePtr;
	}
	
	bool canFindValue( string varName )
	{
		return cast(bool)( varName in _vars );
	}
	
	DataNodeType getDataNodeType( string varName )
	{
		auto varValuePtr = varName in _vars;
		assert( varValuePtr, "VariableTable: Cannot find variable with name: " ~ varName );
		return varValuePtr.type;
	}
	
	void setValue( string varName, TDataNode value )
	{
		_vars[varName] = value;
	}
	
	void removeValue( string varName )
	{
		_vars.remove( varName );
	}

}

interface IDirectiveInterpreter
{
	void interpret(IDirectiveStatement statement, Interpreter interp);

}

static IDirectiveInterpreter[string] dirInterpreters;

shared static this()
{
	dirInterpreters["for"] = new ForInterpreter();
	dirInterpreters["if"] = new IfInterpreter();
	dirInterpreters["expr"] = new ExprInterpreter();
	dirInterpreters["pass"] = new PassInterpreter();

}

class ASTNodeTypeException: Exception
{
public:
	pure nothrow @nogc @safe this(string msg, string file = __FILE__, size_t line = __LINE__, Throwable next = null)
	{
		super(msg, file, line, next);
	}

}

class InterpretException: Exception
{
public:
	pure nothrow @nogc @safe this(string msg, string file = __FILE__, size_t line = __LINE__, Throwable next = null)
	{
		super(msg, file, line, next);
	}

}

T expectNode(T)( IDeclNode node, string msg = null, string file = __FILE__, string func = __FUNCTION__, int line = __LINE__ )
{
	import std.algorithm: splitter;
	import std.range: retro, take, join;
	import std.array: array;
	import std.conv: to;

	string shortFuncName = func.splitter('.').retro.take(2).array.retro.join(".");
	enum shortObjName = T.stringof.splitter('.').retro.take(2).array.retro.join(".");
	
	T typedNode = cast(T) node;
	if( !typedNode )
		throw new ASTNodeTypeException( shortFuncName ~ "[" ~ line.to!string ~ "]: Expected " ~ shortObjName ~ ":  " ~ msg, file, line );
	
	return typedNode;
}

T takeFrontAs(T)( IAttributesRange range, string errorMsg = null, string file = __FILE__, string func = __FUNCTION__, int line = __LINE__ )
{
	import std.algorithm: splitter;
	import std.range: retro, take, join;
	import std.array: array;
	import std.conv: to;

	static immutable shortObjName = T.stringof.splitter('.').retro.take(2).array.retro.join(".");
	string shortFuncName = func.splitter('.').retro.take(2).array.retro.join(".");
	string longMsg = shortFuncName ~ "[" ~ line.to!string ~ "]: Expected " ~ shortObjName ~ ":  " ~ errorMsg;
	
	if( range.empty )
		throw new ASTNodeTypeException( longMsg, file, line );
	
	T typedAttr = cast(T) range.front;
	if( !typedAttr )
		throw new ASTNodeTypeException( longMsg, file, line );
	
	range.popFront();
	
	return typedAttr;
}

void interpretError(string msg, string file = __FILE__, size_t line = __LINE__)
{
	throw new InterpretException(msg, file, line);
}

class ForInterpreter : IDirectiveInterpreter
{
public:
	import std.algorithm : castSwitch;
	
	alias TDataNode = DataNode!string;

	override void interpret(IDirectiveStatement statement, Interpreter interp)
	{
		if( !statement || statement.name != "for"  )
			interpretError( "Expected 'for' directive" );
		
		auto stmtRange = statement[];

		INameExpression varNameExpr = stmtRange.takeFrontAs!INameExpression("For loop variable name expected");
		
		string varName = varNameExpr.name;
		if( varName.length == 0 )
			interpretError("Loop variable name cannot be empty");
		
		INameExpression inNameExpr = stmtRange.takeFrontAs!INameExpression("Expected 'in' keyword");
		
		if( inNameExpr.name != "in" )
			interpretError( "Expected 'in' keyword" );
		
		IExpression aggregateExpr = stmtRange.takeFrontAs!IExpression("Expected loop aggregate expression");
		
		aggregateExpr.accept(interp);
		auto aggr = interp.opnd;
		
		if( aggr.type != DataNodeType.Array ) 
			interpretError( "Aggregate type must be array" );

		IStatement bodyStmt = stmtRange.takeFrontAs!IStatement( "Expected loop body statement" );
		
		TDataNode[] results;
		
		foreach( aggrItem; aggr.array )
		{
			if( interp.varTable.canFindValue(varName) )
				interpretError( "For loop variable name '" ~ varName ~ "' already exists" );
			
			interp.varTable.setValue(varName, aggrItem);
			bodyStmt.accept(interp);
			interp.varTable.removeValue(varName);
			results ~= interp.opnd;
		}
		
		interp.opnd = results;
	}

}

class IfInterpreter : IDirectiveInterpreter
{
public:
	override void interpret(IDirectiveStatement statement, Interpreter interp)
	{
		if( !statement || statement.name != "if"  )
			interpretError( "Expected 'if' directive" );
		
		import std.typecons: Tuple;
		import std.range: back, empty;
		alias IfSect = Tuple!(IExpression, "cond", IStatement, "stmt");
		
		IfSect[] ifSects;
		IStatement elseBody;
		
		auto stmtRange = statement[];
		
		IExpression condExpr = stmtRange.takeFrontAs!IExpression( "Conditional expression expected" );
		IStatement bodyStmt = stmtRange.takeFrontAs!IStatement( "'If' directive body statement expected" );
		
		ifSects ~= IfSect(condExpr, bodyStmt);
		
		for( ; stmtRange.empty; stmtRange.popFront() )
		{
			INameExpression keywordExpr = stmtRange.takeFrontAs!INameExpression("'elif' or 'else' keyword expected");
			if( keywordExpr.name == "elif" )
			{
				condExpr = stmtRange.takeFrontAs!IExpression( "'elif' conditional expression expected" );
				bodyStmt = stmtRange.takeFrontAs!IStatement( "'elif' body statement expected" );
				
				ifSects ~= IfSect(condExpr, bodyStmt);
			}
			else if( keywordExpr.name == "else" )
			{
				elseBody = stmtRange.takeFrontAs!IStatement( "'else' body statement expected" );
				if( !stmtRange.empty )
					interpretError("'else' statement body expected to be the last 'if' attribute. Maybe ';' is missing");
			}
			else
			{
				interpretError("'elif' or 'else' keyword expected");
			}
		}
		
		bool lookElse = true;
		
		foreach( i, ifSect; ifSects )
		{
			interp.opnd = false;
			ifSect.cond.accept(interp);
			
			auto cond = interp.opnd;
			
			if( cond.type != DataNodeType.Boolean )
				interpretError( "Conditional expression type must be boolean" );
				
			if( cond.boolean )
			{
				lookElse = false;
				ifSect.stmt.accept(interp);
				
				import std.conv: to;
				
				interp.opnd = "if #" ~ to!string(i);
				break;
			}
		
		}
		
		if( lookElse && elseBody )
		{
			elseBody.accept(interp);
			interp.opnd = "else";
		}
	}
}

/+
class ASTVisitingRange(T)
{
private:
	IAttributesRange _attrRange;
	T _currItem;

public:
	this(IAttributesRange attrRange)
	{
		_attrRange = attrRange;
	}
	
	@property T front()
	{
		_attrRange.front.accept(this);
		return _currItem;
	}
	
	void popFront()
	{
		_attrRange.popFront();
	}
	
	bool empty()
	{
		return _attrRange.empty;
	}
	
	import std.meta;
	
	private static string generateVisitOverloads()
	{
		string result;
		
		string[] nodeTypes = [ 
			"IDeclNode", "IExpression", "ILiteralExpression", "IOperatorExpression", 
			"IUnaryExpression", "IBinaryExpression", "IStatement", "INameExpression",
			"IKeyValueAttribute", "IDirectiveStatement", "ICompoundStatement"
		];
		
		import std.algorithm: canFind;
		import std.algorithm: remove;
		if( nodeTypes.canFind( T.stringof ) )
			nodeTypes = nodeTypes.remove( T.stringof );
			
		foreach( nodeType; nodeTypes )
		{
			result ~= "	public override void visit(" ~ nodeType ~ " node) { _currItem = null; }\r\n";
		}
		
		result ~= "	public override void visit(" ~ T.stringof ~ " node) { _currItem = cast(T) _attrRange.front; }\r\n";
		
		return result;
	}
	
	mixin(generateVisitOverloads());
}
+/


class PassInterpreter : IDirectiveInterpreter
{
public:
	override void interpret(IDirectiveStatement statement, Interpreter interp)
	{
	
	}

}

class ExprInterpreter : IDirectiveInterpreter
{
public:
	override void interpret(IDirectiveStatement statement, Interpreter interp)
	{
		if( !statement || statement.name != "expr"  )
			interpretError( "Expected 'expr' directive" );
		
		auto stmtRange = statement[];
		
		IExpression expr = stmtRange.takeFrontAs!IExpression("Expression expected");

		expr.accept(interp);
	}

}


class Interpreter : AbstractNodeVisitor
{
public:
	alias TDataNode = DataNode!string;
	
	VariableTable varTable;
	TDataNode opnd; //Current operand value
	
	this()
	{
		varTable = new VariableTable;
	}

	public override {
		void visit(IDeclNode node)
		{
			writeln( typeof(node).stringof ~ " visited" );
			if( node )
				writeln( "Decl node kind: ", node.kind() );
		}
		
		//Expressions
		void visit(IExpression node)
		{
			writeln( typeof(node).stringof ~ " visited" );
		}
		
		void visit(ILiteralExpression node)
		{
			assert( node, "Interpreter.visit: ILiteralExpression node is null");
			
			writeln( "Interpreting literal type: ", node.literalType );
			
			switch( node.literalType ) with(LiteralType)
			{
				case NotLiteral:
				{
					assert( 0, "Incorrect AST node. ILiteralExpression cannot have NotLiteral literalType property!!!" );
					break;
				}
				case Null:
				{
					opnd = null;
					break;
				}
				case Boolean:
				{
					opnd = node.toBoolean();
					break;
				}
				case Integer:
				{
					opnd = node.toInteger();
					break;
				}
				case Floating:
				{
					opnd = node.toFloating();
					break;
				}
				case String:
				{
					assert( 0, "Not implemented yet!");
					break;
				}
				case Array:
				{
					TDataNode[] dataNodes;
					foreach( child; node.children )
					{
						writeln( "Interpret array element" );
						child.accept(this);
						dataNodes ~= opnd;
					}
					
					writeln( "Array elements interpreted" );
					opnd.array = dataNodes;
					//assert( 0, "Not implemented yet!");
					break;
				}
				case AssocArray:
				{
					assert( 0, "Not implemented yet!");
					break;
				}
				default:
					assert( 0 , "Unexpected LiteralType" );
			}
			
			import std.conv: to;
			
			writeln( typeof(node).stringof ~ " visited: " ~ node.literalType.to!string );
		}
		
		void visit(IOperatorExpression node)
		{
			writeln( typeof(node).stringof ~ " visited" );
		}
		
		void visit(IUnaryExpression node)
		{
			import std.conv : to;
			
			writeln( typeof(node).stringof ~ " visited" );
			
			IExpression operandExpr = node.expr;
			int op = node.operatorIndex;
			
			assert( operandExpr, "Unary operator operand shouldn't be null ast object!!!" );
			
			with(Operator)
				assert( op == UnaryPlus || op == UnaryMin || op == Not, "Incorrect unary operator " ~ (cast(Operator) op).to!string  );
			
			opnd = TDataNode.init;
			operandExpr.accept(this); //This must interpret child nodes

			switch(op) with(Operator)
			{
				case UnaryPlus:
				{
					assert( 
						opnd.type == DataNodeType.Integer || opnd.type == DataNodeType.Floating, 
						"Unsupported UnaryPlus operator for type: " ~ opnd.type.to!string
					);
					
					break;
				}
				case UnaryMin:
				{
					assert( 
						opnd.type == DataNodeType.Integer || opnd.type == DataNodeType.Floating, 
						"Unsupported UnaryMin operator for type: " ~ opnd.type.to!string
					);
					
					if( opnd.type == DataNodeType.Integer )
					{
						opnd = -opnd.integer;
					}
					else if( opnd.type == DataNodeType.Floating )
					{
						opnd = -opnd.floating;
					}
					
					break;
				}
				case Not:
				{
					assert( 
						opnd.type == DataNodeType.Boolean, 
						"Unsupported Not operator for type: " ~ opnd.type.to!string
					);
					
					if( opnd.type == DataNodeType.Boolean )
					{
						opnd = !opnd.boolean;
					}
					
					break;
				}
				default:
					assert(0);
			}
		}
		
		void visit(IBinaryExpression node)
		{
			writeln( typeof(node).stringof ~ " visited" );
			
			IExpression leftExpr = node.leftExpr;
			IExpression rightExpr = node.rightExpr;;
			int op = node.operatorIndex;
			
			assert( leftExpr && rightExpr, "Binary operator operands shouldn't be null ast objects!!!" );
			
			with(Operator)
				assert( 
					op == Add || op == Sub || op == Mul || op == Div || op == Mod || //Arithmetic
					op == And || op == Or || op == Xor || //Boolean
					op == Equal || op == NotEqual || op == LT || op == GT || op == LTEqual || op == GTEqual,  //Comparision
					"Incorrect binary operator " ~ (cast(Operator) op).to!string 
				);
			
			opnd = TDataNode.init;
			leftExpr.accept(this);
			TDataNode leftOpnd = opnd;
			
			opnd = TDataNode.init;
			rightExpr.accept(this);
			TDataNode rightOpnd = opnd;
			
			assert( leftOpnd.type == rightOpnd.type, "Operands tags in binary expr must match!!!" );
			
			switch(op) with(Operator)
			{
				case Add:
				{
					assert( 
						leftOpnd.type == DataNodeType.Integer || leftOpnd.type == DataNodeType.Floating, 
						"Unsupported Add operator for type: " ~ leftOpnd.type.to!string
					);
					
					if( leftOpnd.type == DataNodeType.Integer )
					{
						opnd = leftOpnd.integer + rightOpnd.integer;
					}
					else if( leftOpnd.type == DataNodeType.Floating )
					{
						opnd = leftOpnd.floating + rightOpnd.floating;
					}
					
					break;
				}
				case Sub:
				{
					assert( 
						leftOpnd.type == DataNodeType.Integer || leftOpnd.type == DataNodeType.Floating, 
						"Unsupported Sub operator for type: " ~ leftOpnd.type.to!string
					);
					
					if( leftOpnd.type == DataNodeType.Integer )
					{
						opnd = leftOpnd.integer - rightOpnd.integer;
					}
					else if( leftOpnd.type == DataNodeType.Floating )
					{
						opnd = leftOpnd.floating - rightOpnd.floating;
					}
					
					break;
				}
				case Mul:
				{
					assert( 
						leftOpnd.type == DataNodeType.Integer || leftOpnd.type == DataNodeType.Floating, 
						"Unsupported Mul operator for type: " ~ leftOpnd.type.to!string
					);
					
					if( leftOpnd.type == DataNodeType.Integer )
					{
						opnd = leftOpnd.integer * rightOpnd.integer;
					}
					else if( leftOpnd.type == DataNodeType.Floating )
					{
						opnd = leftOpnd.floating * rightOpnd.floating;
					}
					
					break;
				}
				case Div:
				{
					assert( 
						leftOpnd.type == DataNodeType.Integer || leftOpnd.type == DataNodeType.Floating, 
						"Unsupported Sub operator for type: " ~ leftOpnd.type.to!string
					);
					
					if( leftOpnd.type == DataNodeType.Integer )
					{
						opnd = leftOpnd.integer / rightOpnd.integer;
					}
					else if( leftOpnd.type == DataNodeType.Floating )
					{
						opnd = leftOpnd.floating / rightOpnd.floating;
					}
					
					break;
				}
				case Mod:
				{
					assert( 
						leftOpnd.type == DataNodeType.Integer || leftOpnd.type == DataNodeType.Floating, 
						"Unsupported Mod operator for type: " ~ leftOpnd.type.to!string
					);
					
					if( leftOpnd.type == DataNodeType.Integer )
					{
						opnd = leftOpnd.integer % rightOpnd.integer;
					}
					else if( leftOpnd.type == DataNodeType.Floating )
					{
						opnd = leftOpnd.floating % rightOpnd.floating;
					}
					
					break;
				}
				case And:
				{
					assert( 
						leftOpnd.type == DataNodeType.Boolean, 
						"Unsupported And operator for type: " ~ leftOpnd.type.to!string
					);
					
					if( leftOpnd.type == DataNodeType.Boolean )
					{
						opnd = leftOpnd.boolean && rightOpnd.boolean;
					}

					break;
				}
				case Or:
				{
					assert( 
						leftOpnd.type == DataNodeType.Boolean, 
						"Unsupported Or operator for type: " ~ leftOpnd.type.to!string
					);
					
					if( leftOpnd.type == DataNodeType.Boolean )
					{
						opnd = leftOpnd.boolean || rightOpnd.boolean;
					}

					break;
				}
				case Xor:
				{
					assert( 
						leftOpnd.type == DataNodeType.Boolean, 
						"Unsupported Xor operator for type: " ~ leftOpnd.type.to!string
					);
					
					if( leftOpnd.type == DataNodeType.Boolean )
					{
						opnd = leftOpnd.boolean ^^ rightOpnd.boolean;
					}

					break;
				}
				case Equal:
				{
					assert( 
						leftOpnd.type == DataNodeType.Boolean ||
						leftOpnd.type == DataNodeType.Integer ||
						leftOpnd.type == DataNodeType.Floating ||
						leftOpnd.type == DataNodeType.String,
						"Unsupported Equal operator for type: " ~ leftOpnd.type.to!string
					);
					
					if( leftOpnd.type == DataNodeType.Boolean )
					{
						opnd = leftOpnd.boolean == rightOpnd.boolean;
					}
					else if( leftOpnd.type == DataNodeType.Integer )
					{
						opnd = leftOpnd.integer == rightOpnd.integer;
					}
					else if( leftOpnd.type == DataNodeType.Floating )
					{
						opnd = leftOpnd.floating == rightOpnd.floating;
					}
					else if( leftOpnd.type == DataNodeType.String )
					{
						opnd = leftOpnd.str == rightOpnd.str;
					}

					break;
				}
				case NotEqual:
				{
					assert( 
						leftOpnd.type == DataNodeType.Boolean ||
						leftOpnd.type == DataNodeType.Integer ||
						leftOpnd.type == DataNodeType.Floating ||
						leftOpnd.type == DataNodeType.String,
						"Unsupported NotEqual operator for type: " ~ leftOpnd.type.to!string
					);
					
					if( leftOpnd.type == DataNodeType.Boolean )
					{
						opnd = leftOpnd.boolean != rightOpnd.boolean;
					}
					else if( leftOpnd.type == DataNodeType.Integer )
					{
						opnd = leftOpnd.integer != rightOpnd.integer;
					}
					else if( leftOpnd.type == DataNodeType.Floating )
					{
						opnd = leftOpnd.floating != rightOpnd.floating;
					}
					else if( leftOpnd.type == DataNodeType.String )
					{
						opnd = leftOpnd.str != rightOpnd.str;
					}

					break;
				}
				case LT:
				{
					assert( 
						leftOpnd.type == DataNodeType.Boolean ||
						leftOpnd.type == DataNodeType.Integer ||
						leftOpnd.type == DataNodeType.Floating ||
						leftOpnd.type == DataNodeType.String,
						"Unsupported LT operator for type: " ~ leftOpnd.type.to!string
					);
					
					if( leftOpnd.type == DataNodeType.Boolean )
					{
						opnd = leftOpnd.boolean < rightOpnd.boolean;
					}
					else if( leftOpnd.type == DataNodeType.Integer )
					{
						opnd = leftOpnd.integer < rightOpnd.integer;
					}
					else if( leftOpnd.type == DataNodeType.Floating )
					{
						opnd = leftOpnd.floating < rightOpnd.floating;
					}
					else if( leftOpnd.type == DataNodeType.String )
					{
						opnd = leftOpnd.str < rightOpnd.str;
					}

					break;
				}
				case GT:
				{
					assert( 
						leftOpnd.type == DataNodeType.Boolean ||
						leftOpnd.type == DataNodeType.Integer ||
						leftOpnd.type == DataNodeType.Floating ||
						leftOpnd.type == DataNodeType.String,
						"Unsupported LT operator for type: " ~ leftOpnd.type.to!string
					);
					
					if( leftOpnd.type == DataNodeType.Boolean )
					{
						opnd = leftOpnd.boolean > rightOpnd.boolean;
					}
					else if( leftOpnd.type == DataNodeType.Integer )
					{
						opnd = leftOpnd.integer > rightOpnd.integer;
					}
					else if( leftOpnd.type == DataNodeType.Floating )
					{
						opnd = leftOpnd.floating > rightOpnd.floating;
					}
					else if( leftOpnd.type == DataNodeType.String )
					{
						opnd = leftOpnd.str > rightOpnd.str;
					}

					break;
				}
				default:
					assert(0);
			}
		}
		
		
		//Statements
		void visit(IStatement node)
		{
			writeln( typeof(node).stringof ~ " visited" );
		}
		
		void visit(IKeyValueAttribute node)
		{
			writeln( typeof(node).stringof ~ " visited" );
			writeln( "Key-value attribute name: ", node.name );
			node.value.accept(this);
		}

		void visit(IDirectiveStatement node)
		{
			writeln( typeof(node).stringof ~ " visited" );
			writeln( "Directive statement name: ", node.name );
			if ( node.name in dirInterpreters )
			{
				dirInterpreters[node.name].interpret(node, this);
			}
			else
			{
				writeln( "Interpreter for directive: ", node.name, " is not found!!!" );
			}
		}
		
		void visit(ICompoundStatement node)
		{
			writeln( typeof(node).stringof ~ " visited" );
			foreach( child; node.children )
			{
				if( child )
					child.accept(this);
			}
		}
		
	}
}
