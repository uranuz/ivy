module declarative.interpreter;

import std.stdio, std.conv;

import declarative.node, declarative.node_visitor, declarative.common, declarative.expression;

import declarative.interpreter_data;

interface IInterpreterContext {}

alias TDataNode = DataNode!string;



interface IDirectiveInterpreter
{
	void interpret(IDirectiveStatement statement, Interpreter interp);

}

class BlockScope
{
private:
	
}

static IDirectiveInterpreter[string] dirInterpreters;

shared static this()
{
	dirInterpreters["for"] = new ForInterpreter();
	dirInterpreters["if"] = new IfInterpreter();
	dirInterpreters["expr"] = new ExprInterpreter();
	dirInterpreters["pass"] = new PassInterpreter();
	dirInterpreters["var"] = new VarInterpreter();
	dirInterpreters["set"] = new SetInterpreter();
	dirInterpreters["text"] = new TextBlockInterpreter();

}

class ASTNodeTypeException: Exception
{
public:
	@nogc @safe this(string msg, string file = __FILE__, size_t line = __LINE__, Throwable next = null) pure nothrow
	{
		super(msg, file, line, next);
	}

}

class InterpretException: Exception
{
public:
	@nogc @safe this(string msg, string file = __FILE__, size_t line = __LINE__, Throwable next = null) pure nothrow
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

T testFrontIs(T)( IAttributesRange range, string errorMsg = null, string file = __FILE__, string func = __FUNCTION__, int line = __LINE__ )
{
	if( range.empty )
		return false;
	
	T typedNode = cast(T) range.front;
	
	return typedNode !is null;
}

void interpretError(string msg, string file = __FILE__, size_t line = __LINE__)
{
	throw new InterpretException(msg, file, line);
}

auto unindent(Range)(Range source, size_t firstIndent, size_t firstIndentStyle)
{
	while( !source.empty )
	{
		
	}
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

		ICompoundStatement bodyStmt = stmtRange.takeFrontAs!ICompoundStatement( "Expected loop body statement" );

		if( !stmtRange.empty )
			interpretError( "Expected end of directive after loop body. Maybe ';' is missing" );

		TDataNode[] results;
		
		foreach( aggrItem; aggr.array )
		{
			if( interp.canFindValue(varName) )
				interpretError( "For loop variable name '" ~ varName ~ "' already exists" );
			
			interp.setValue(varName, aggrItem);
			bodyStmt.accept(interp);
			results ~= interp.opnd;
		}
		
		Location bodyStmtLoc = bodyStmt.location;
		size_t bodyFirstIndent = bodyStmtLoc.firstIndent;
		IndentStyle bodyFirstIndentStyle = bodyStmtLoc.firstIndentStyle;
		
		
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

class PassInterpreter : IDirectiveInterpreter
{
public:
	override void interpret(IDirectiveStatement statement, Interpreter interp)
	{
		interp.opnd = TDataNode.init;
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

class SetInterpreter : IDirectiveInterpreter
{
public:
	override void interpret(IDirectiveStatement statement, Interpreter interp)
	{
		if( !statement || statement.name != "set"  )
			interpretError( "Expected 'set' directive" );
		
		auto stmtRange = statement[];
		
		IKeyValueAttribute kwPair = stmtRange.takeFrontAs!IKeyValueAttribute("Key-value pair expected");
		
		if( !stmtRange.empty )
			interpretError( "Expected end of directive after key-value pair. Maybe ';' is missing" );
		
		if( !interp.canFindValue( kwPair.name ) )
			interpretError( "Undefined identifier '" ~ kwPair.name ~ "'" );
		
		if( !kwPair.value )
			interpretError( "Expected value for 'set' directive" );
		
		kwPair.value.accept(interp); //Evaluating expression
		interp.setValue(kwPair.name, interp.opnd);
		
		interp.opnd = TDataNode.init; //Doesn't return value
	}

}

class VarInterpreter : IDirectiveInterpreter
{
public:
	override void interpret(IDirectiveStatement statement, Interpreter interp)
	{
		if( !statement || statement.name != "var"  )
			interpretError( "Expected 'var' directive" );
		
		writeln( "VarInterpreter: attrs list:" );
		foreach( stmt; statement )
		{
			writeln( "stmt.kind: ", stmt.kind );
		
		}
		writeln( "VarInterpreter: attrs list end^" );
		
		auto stmtRange = statement[];
		
		IKeyValueAttribute kwPair = stmtRange.takeFrontAs!IKeyValueAttribute("Key-value pair expected");
		
		if( !stmtRange.empty )
			interpretError( "Expected end of directive after key-value pair. Maybe ';' is missing" );
		
		if( kwPair.name.length > 0 )
		
		if( !kwPair.value )
			interpretError( "Expected value for 'var' directive" );
		
		kwPair.value.accept(interp); //Evaluating expression
		interp.setValue(kwPair.name, interp.opnd);
		
		interp.opnd = TDataNode.init; //Doesn't return value
	}

}




class TextBlockInterpreter: IDirectiveInterpreter
{
public:
	override void interpret(IDirectiveStatement statement, Interpreter interp)
	{
		if( !statement || statement.name != "text"  )
			interpretError( "Expected 'var' directive" );
			
		auto stmtRange = statement[];
		
		if( stmtRange.empty )
			throw new ASTNodeTypeException("Expected compound statement or expression, but got end of directive");
			
		interp.opnd = TDataNode.init;
		
		if( auto expr = cast(IExpression) stmtRange.front )
		{
			expr.accept(interp);
		}
		else if( auto block = cast(ICompoundStatement) stmtRange.front )
		{
			block.accept(interp);
		}
		else
			new ASTNodeTypeException("Expected compound statement or expression");

		string str;
		
		final switch( interp.opnd.type ) with(DataNodeType)
		{
			case Null: 
				str = null; 
				break;
			case Boolean: 
				str = interp.opnd.boolean ? "true" : "false";
				break;
			case Integer:
				str = interp.opnd.integer.to!string;
				break;
			case Floating:
				str = interp.opnd.floating.to!string;
				break;
			case String:
				str = interp.opnd.str;
				break;
			case Array:
			{
				writeln( "TextBlock: array data:" );
				writeln( interp.opnd.array );
				
				foreach( el; interp.opnd.array )
				{
					import std.conv: to;
					writeln("TextBlock array element type: ", el.type);
					
					if( el.type == DataNodeType.String )
						str ~= el.str;
					else if( el.type == DataNodeType.Array )
					{						
						foreach( innerEl; el.array )
						{
							if( innerEl.type == String )
								str ~= innerEl.str;
							else							
								str ~= innerEl.toString();
						}
					}
					else
						interpretError("Unexpected type of data");
				}
				break;
			}
			case AssocArray:
			{
				interpretError("Assoc array string conversion not implemented yet");
				break;	
			}
			case ClassObject:
			{
				interpretError("Class object string conversion not implemented yet");
				break;
			}				
		}
		
		interp.opnd = str;
	}

}

class InterpreterScope
{
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

class Interpreter : AbstractNodeVisitor
{
public:
	alias String = string;
	alias TDataNode = DataNode!String;
	
	InterpreterScope[] scopeStack;
	TDataNode opnd; //Current operand value
	
	AbstractNodeVisitor typeChecker;
	
	this(AbstractNodeVisitor typeCheckerVisitor)
	{
		typeChecker = typeCheckerVisitor;
		scopeStack ~= new InterpreterScope;
	}
	
	void enterScope()
	{
		//scopeStack ~= new InterpreterScope;
	}
	
	void exitScope()
	{
		import std.range: popBack;
		//scopeStack.popBack();
	}
	
	bool canFindValue( string varName )
	{
		import std.range: empty, popBack, back;
		
		if( scopeStack.empty )
			return false;
			
		auto scopeStackSlice = scopeStack[];
		
		for( ; !scopeStackSlice.empty; scopeStackSlice.popBack() )
		{
			if( scopeStack.back.canFindValue(varName) )
				return true;
		}
		
		return false;
	}
	
	TDataNode getValue( string varName )
	{
		import std.range: empty, popBack, back;
		
		if( scopeStack.empty )
			interpretError("Cannot get var value, because scope stack is empty!");
			
		auto scopeStackSlice = scopeStack[];
		
		for( ; !scopeStackSlice.empty; scopeStackSlice.popBack() )
		{
			if( scopeStack.back.canFindValue(varName) )
				return scopeStack.back.getValue(varName);
		}
		
		interpretError("Undefined variable with name '" ~ varName ~ "'");
		assert(0);
	}
	
	void setValue( string varName, TDataNode value )
	{
		import std.range: empty, popBack, back;
		
		if( scopeStack.empty )
			interpretError("Cannot set var value, because scope stack is empty!");
		
		scopeStack.back.setValue( varName, value );
	}
	
	/+
	DataNodeType getCommonTypeFor( ref const(TDataNode) left, ref const(TDataNode) right )
	{
		import std.algorithm: canFind;
		
		if( left.type == right.type )
			return left.type;
		
		DataNodetype[2] types = [ left.type, right.type ];
		
		with(DataNodeType)
		{
			if( types.canFind(Floating, Integer) )
			{
				return Floating;
			}
			else if( types.canFind(Null, Boolean) )
			{
				return Boolean;
			}
		}

		assert(0);
	}
	+/
	
	void makeDataPromotions( ref TDataNode left, ref TDataNode right )
	{
		import std.conv: to;
		
		if( left.type == right.type )
			return;
		
		with( DataNodeType )
		{
			if( left.type == Integer && right.type == Floating )
			{
				left = left.integer.to!double;
			}
			else if( left.type == Floating && right.type == Integer )
			{
				left = right.integer.to!double;
			}
			else if( left.type == Null && right.type == Boolean )
			{
				left = false;
			}
			else if( left.type == Boolean && right.type == Null )
			{
				right = false;
			}
		}
		
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
					opnd = node.toStr();
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
		
		void visit(INameExpression node)
		{
			writeln( typeof(node).stringof ~ " visited" );
			
			auto varName = node.name;
			
			if( !canFindValue(varName) )
				interpretError( "Undefined identifier '" ~ node.name ~ "'" );
			
			opnd = getValue(node.name);
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
					op == Concat || //Concat
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
			
			makeDataPromotions(leftOpnd, rightOpnd);
			
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
				case Concat:
				{
					assert( 
						leftOpnd.type == DataNodeType.String,
						"Unsupported Concat operator for type: " ~ leftOpnd.type.to!string
					);
					
					if( leftOpnd.type == DataNodeType.String )
					{
						opnd = leftOpnd.str ~ rightOpnd.str;
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
		
		void visit(IDataFragmentStatement node)
		{ 
			writeln( typeof(node).stringof ~ " visited" );
			
			opnd = node.data;
		}
		
		void visit(ICompoundStatement node)
		{
			writeln( typeof(node).stringof ~ " visited" );
			
			enterScope();
			
			TDataNode[] nodes;
			
			foreach( stmt; node )
			{
				if( stmt )
				{
					stmt.accept(this);
					string str = opnd.toString();
					nodes ~= opnd;
				}
			}
			
			opnd = nodes;
			
			string result = opnd.toString();
			writeln(result);
			
			exitScope();
		}
		
	}
}