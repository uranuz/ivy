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

class ForInterpreter : IDirectiveInterpreter
{
public:
	import std.algorithm : castSwitch;
	
	alias TDataNode = DataNode!string;

	override void interpret(IDirectiveStatement statement, Interpreter interp)
	{
		assert( statement && statement.name == "for", "For statement must exist and it's name must be 'for'!!!" );
		
		auto stmtRange = statement[];
		assert( !stmtRange.empty, "Expected 4 attributes in 'for' directive" );
		
		INameExpression varNameExpr = cast(INameExpression) stmtRange.front; //1
		
		assert( varNameExpr && varNameExpr.name.length > 0, "For variable name expr must not be null or have empty name!!!" );
		string varName = varNameExpr.name;
		
		stmtRange.popFront();
		assert( !stmtRange.empty, "Expected 4 attributes in 'for' directive" );
		
		INameExpression inNameExpr = cast(INameExpression) stmtRange.front; //2
		assert( inNameExpr.name == "in", "For: expected 'in' context keyword" );
		
		stmtRange.popFront();
		assert( !stmtRange.empty, "Expected 4 attributes in 'for' directive" );
		
		IExpression aggregateExpr = cast(IExpression) stmtRange.front; //3
		assert( aggregateExpr, "For: Expected aggregate expression" );
		
		aggregateExpr.accept(interp);
		auto aggr = interp.opnd;
		
		assert( aggr.type == DataNodeType.Array, "For aggregate type must be array!!!" );

		stmtRange.popFront();
		assert( !stmtRange.empty, "Expected 4 attributes in 'for' directive" );
		
		IStatement bodyStmt = cast(IStatement) stmtRange.front; //4
		
		assert( bodyStmt, "For: expected for body statement!!!" );
		
		TDataNode[] results;
		
		foreach( aggrItem; aggr.array )
		{
			assert( !interp.varTable.canFindValue(varName), "For: variable name '" ~ varName ~ "' collides with existing variable!!!" );
			
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
		assert( statement && statement.name == "if", "If statement must exist and it's name must be 'if'!!!" );
		
		import std.typecons: Tuple;
		import std.range: back, empty;
		alias IfSect = Tuple!(IExpression, "cond", IStatement, "stmt");
		
		IfSect[] ifSects;
		IStatement elseSect;
		
		
		class AttrVisitor: AbstractNodeVisitor
		{
		public:
			alias visit = AbstractNodeVisitor.visit;
			
			override void visit(IExpression node)
			{
				if( ifSects.empty )
				{
					ifSects ~= IfSect(node, null);
				}
			}
		
			override void visit(IStatement node)
			{ 
				assert( !elseSect, "No statements allowed after else attribute!!!");
				if( ifSects.empty )
				{
					assert( 0, "Expression conditional expected!!!" );
				}
				else
				{
					//assert( !ifSects.back.stmt, "directive if: Expected elif or else attribute, but statement found!!!" );
					ifSects.back.stmt = node; //Set statement to be executed
				}
			}
			
			override void visit(IKeyValueAttribute node)
			{ 
				if( node.name == "elif" )
				{
					IExpression condExpr = cast(IExpression) node.value;
					assert( condExpr, "Expression conditional expected!!!" );
					ifSects ~= IfSect(condExpr, null);
				}
				else if( node.name == "else" )
				{
					assert( !elseSect, "Multiple else attributes are not allowed!!!" );
					elseSect = cast(IStatement) node.value;
					assert( elseSect, "Else attribute should be a statement!!!" );
				}
				else
				{
					assert( 0, "Unexpected type of named attribute: " ~ node.name );
				}
			}
		}
		
		auto attrVisitor = new AttrVisitor;
		
		foreach( attr; statement )
		{
			attr.accept(attrVisitor);
		}
		
		bool lookElse = true;
		
		writeln( ifSects );
		
		foreach( i, ifSect; ifSects )
		{
			interp.opnd = false;
			ifSect.cond.accept(interp);
			
			assert( interp.opnd.type == DataNodeType.Boolean, "If conditional expression result must be boolean!!!" );
			writeln( "if: section #", i, " is ", interp.opnd.boolean );
			
			if( interp.opnd.boolean )
			{
				lookElse = false;
				ifSect.stmt.accept(interp);
				
				import std.conv: to;
				
				interp.opnd = "if #" ~ to!string(i);
				
				break;
			}
		}
		
		if( lookElse && elseSect )
		{
			elseSect.accept(interp);
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
		assert( statement && statement.name == "expr", "Expr statement must exist and it's name must be 'expr'!!!" );
		
		auto stmtRange = statement[];
		assert( !stmtRange.empty, "Expected 1 attribute in 'expr' directive" );
		
		IExpression expr = cast(IExpression) stmtRange.front;
		assert( expr, "Expr: expected expression!!!" );
		
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
