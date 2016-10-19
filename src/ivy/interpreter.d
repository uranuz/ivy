module ivy.interpreter;

import std.stdio, std.conv;

import ivy.node, ivy.node_visitor, ivy.common, ivy.expression;

import ivy.interpreter_data;

interface IInterpreterContext {}

alias TDataNode = DataNode!string;

interface IDirectiveInterpreter
{
	void interpret(IDirectiveStatement statement, Interpreter interp);
}

interface IInterpretersController: IDirectiveInterpreter
{
	string[] directiveNames() @property;
	//string[] directiveNamespaces() @property;
	void _reindex();
}

interface ICompositeInterpretersController: IInterpretersController
{
	void addInterpreter( string dirName, IDirectiveInterpreter interp );
	void addController( IInterpretersController controller  );

}

mixin template BaseInterpretersControllerImpl()
{
private:
	IDirectiveInterpreter[string] _ownInterps; // AA of own interpreters for this controller
	IInterpretersController[] _controllers; // List of child controllers
	IDirectiveInterpreter[string] _childInterpsIndex; // Index of interpreters contained in child controllers

public:
	override {
		void interpret(IDirectiveStatement statement, Interpreter interp)
		{
			IDirectiveInterpreter dirInterp = _ownInterps.get(statement.name, null);
			if( dirInterp )
			{
				dirInterp.interpret(statement, interp);
				return;
			}

			dirInterp = _childInterpsIndex.get(statement.name, null);
			if( dirInterp )
			{
				dirInterp.interpret(statement, interp);
				return;
			}

			interpretError( `Cannot find interperter for directive: ` ~ statement.name  );
			// TODO: Implement search by namespace
		}

		string[] directiveNames() @property
		{
			return _childInterpsIndex.keys ~ _ownInterps.keys;
		}

		/*
		string[] directiveNamespaces() @property
		{
			return _namespaceCtrlsIndex.keys;
		}
		*/

		void addInterpreter( string dirName, IDirectiveInterpreter interp )
		{
			if( !interp || !dirName.length )
				return;

			_ownInterps[dirName] = interp;
		}

		void addController( IInterpretersController controller )
		{
			_controllers ~= controller;
			foreach( name; controller.directiveNames )
			{
				_childInterpsIndex[name] = controller;
			}
		}

		void _reindex()
		{
			import std.stdio;
			_childInterpsIndex.clear;
			writeln("reindexing controllers count: ", _controllers.length);
			foreach( controller; _controllers )
			{
				controller._reindex();
				writeln("reindexing: ", controller.directiveNames);
				foreach( name; controller.directiveNames )
				{
					_childInterpsIndex[name] = controller;
				}
			}
		}
	}
}

class RootHTMLInterpreter: ICompositeInterpretersController
{
	mixin BaseInterpretersControllerImpl;
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

T expectNode(T)( IvyNode node, string msg = null, string file = __FILE__, string func = __FUNCTION__, int line = __LINE__ )
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

T takeFrontAs(T)( IAttributeRange range, string errorMsg = null, string file = __FILE__, string func = __FUNCTION__, int line = __LINE__ )
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

T testFrontIs(T)( IAttributeRange range, string errorMsg = null, string file = __FILE__, string func = __FUNCTION__, int line = __LINE__ )
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

struct ExecStackFrame
{
	string directive;
	string label;
	InterpreterScope interpScope;

}

class ExecutionStack
{
	/++ Execution stask is special stack that collect information about directives that programme
		entered during execution. Labels for jumping out of directives and pointers to linked contexts
	+/


}


class IvyModule
{
private:
	string _moduleName;
	string _fileName;
	IvyNode _rootNode;

public:
	this( string moduleName, string fileName, IvyNode rootNode )
	{
		_moduleName = moduleName;
		_fileName = fileName;
		_rootNode = rootNode;
	}

	void doImport( Interpreter interp )
	{
		if( !interp )
			interpretError( `Cannot use null interpreter to import module` );

		_rootNode.accept(interp);
	}

}


class IvyRepository
{
	import ivy.lexer_tools: TextForwardRange;

	alias TextRange = TextForwardRange!(string, LocationConfig());

private:
	IvyModule[string] _modules;

public:
	void loadModuleFromFile(string fileName)
	{
		import std.file: read;

		string fileContent = cast(string) std.file.read(fileName);

		import ivy.parser;
		auto parser = new Parser!(TextRange)(fileContent, fileName);

		IvyNode moduleRootNode = parser.parse();
		IvyModule ivyModule = new IvyModule( fileName, fileName, moduleRootNode );
		_modules[ fileName ] = ivyModule;
	}

	IvyModule getModule(string name)
	{
		if( name !in _modules )
		{
			loadModuleFromFile( name );
		}

		if( name in _modules )
		{
			return _modules[name];
		}
		else
		{
			return null;
		}
	}



}

class ExecutionFrame
{
private:
	TDataNode _dataDict;
	
public:
	this()
	{
		TDataNode[string] emptyDict;
		_dataDict = emptyDict;
	}

	TDataNode getValue( string varName )
	{
		auto varValuePtr = findValue(varName);
		if( varValuePtr is null )
			interpretError( "VariableTable: Cannot find variable with name: " ~ varName );
		return *varValuePtr;
	}
	
	bool canFindValue( string varName )
	{
		return cast(bool)( findValue(varName) );
	}
	
	DataNodeType getDataNodeType( string varName )
	{
		auto varValuePtr = findValue(varName);
		if( varValuePtr is null )
			interpretError( "VariableTable: Cannot find variable with name: " ~ varName );
		return varValuePtr.type;
	}

	TDataNode* findValue( string varName )
	{
		import std.range: empty;
		import std.algorithm: splitter;
		if( varName.empty )
			interpretError( "VariableTable: Variable name cannot be empty" );
		auto nameSplitter = varName.splitter('.');
		TDataNode* nodePtr = nameSplitter.front in _dataDict.assocArray;
		if( nodePtr is null )
			return null;
		nameSplitter.popFront();

		while( !nameSplitter.empty  )
		{
			if( nodePtr.type != DataNodeType.AssocArray )
				return null;

			nodePtr = nameSplitter.front in nodePtr.assocArray;
			nameSplitter.popFront();
			if( nodePtr is null )
				return null;
		}

		return nodePtr;
	}

	void setValue( string varName, TDataNode value )
	{
		import std.range: empty;
		import std.algorithm: splitter;
		import std.string: join;
		if( varName.empty )
			interpretError("Variable name cannot be empty!");

		TDataNode* valuePtr = findValue(varName);
		if( valuePtr )
		{
			*valuePtr = value;
		}
		else
		{
			auto splName = splitter(varName, '.');
			string shortName = splName.back;
			splName.popBack(); // Trim actual name

			if( splName.empty )
			{
				writeln( "setValue writing root var: ", shortName );
				_dataDict[shortName] = value;
			}
			else
			{
				// Try to find parent
				TDataNode* parentPtr = findValue(splName.join('.'));
				if( parentPtr is null )
					interpretError( `Cannot create new variable "` ~ varName ~ `", because parent not exists!` );

				if( parentPtr.type != DataNodeType.AssocArray )
					interpretError( `Cannot create new value "` ~ varName ~ `", because parent is not of assoc array type!` );

				(*parentPtr)[shortName] = value;
				writeln( "Checking setValue: ", *parentPtr );
			}

		}
	}
	
	void removeValue( string varName )
	{
		import std.range: empty;
		import std.algorithm: splitter;
		import std.string: join;
		if( varName.empty )
			interpretError("Variable name cannot be empty!");

		auto splName = splitter(varName, '.');
		string shortName = splName.back;
		splName.popBack(); // Trim actual name
		if( splName.empty )
		{
			_dataDict.assocArray.remove( shortName );
		}
		else
		{
			// Try to find parent
			TDataNode* parentPtr = findValue(splName.join('.'));

			if( parentPtr is null )
				interpretError( `Cannot delete variable "` ~ varName ~ `", because parent not exists!` );

			if( parentPtr.type != DataNodeType.AssocArray )
				interpretError( `Cannot delete value "` ~ varName ~ `", because parent is not of assoc array type!` );

			(*parentPtr)[shortName].assocArray.remove(shortName);
		}
	}

}

class Interpreter : AbstractNodeVisitor
{
public:
	alias String = string;
	alias TDataNode = DataNode!String;
	
	InterpreterScope[] scopeStack;
	TDataNode opnd; //Current operand value
	IInterpretersController _dirController; // Root directives controller
	ICompositeInterpretersController _inlineDirController; // Inline directives controller
	IvyRepository _ivyRepository; // Storage for parsed modules

	this(IInterpretersController dirController, ICompositeInterpretersController inlineDirController)
	{
		scopeStack ~= new InterpreterScope;
		_dirController = dirController;
		_inlineDirController = inlineDirController;
		_ivyRepository = new IvyRepository;

		enterScope(); // Create global scope
	}
	
	void enterScope()
	{
		scopeStack ~= new InterpreterScope;
	}
	
	void exitScope()
	{
		import std.range: popBack;
		scopeStack.popBack();
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

	TDataNode* findValue( string varName )
	{
		import std.range: empty, back, popBack;
		if( scopeStack.empty )
			interpretError("Cannot find var value, because scope stack is empty!");

		auto scopeStackSlice = scopeStack[];
		TDataNode* valuePtr;

		for( ; !scopeStackSlice.empty; scopeStackSlice.popBack() )
		{
			valuePtr = scopeStack.back.findValue(varName);
			if( valuePtr !is null )
				break;
		}

		return valuePtr;
	}

	TDataNode getValue( string varName )
	{
		import std.range: empty, popBack, back;
		
		if( scopeStack.empty )
			interpretError("Cannot get var value, because scope stack is empty!");
			
		TDataNode* valuePtr = findValue(varName);

		if( valuePtr is null )
			interpretError( "Undefined variable with name '" ~ varName ~ "'" );
		
		return *valuePtr;
	}
	
	void setValue( string varName, TDataNode value )
	{
		import std.range: empty;
		if( scopeStack.empty )
			interpretError("Cannot set var value, because scope stack is empty!");

		TDataNode* valuePtr = findValue(varName);
		if( valuePtr is null )
			interpretError( `Cannot set variable "` ~ varName ~ `", because cannot find it. Use setLocalValue to decare new variable!` );

		*valuePtr = value;
	}

	void setLocalValue( string varName, TDataNode value )
	{
		import std.range: empty, popBack, back;
		import std.algorithm: splitter;

		if( scopeStack.empty )
			interpretError("Cannot set local var value, because scope stack is empty!");

		scopeStack.back.setValue(varName, value);
	}
	
	bool hasLocalValue( string varName )
	{
		import std.range: empty, popBack, back;
		
		if( scopeStack.empty )
			return false;
		
		return scopeStack.back.canFindValue( varName );
	}
	
	void removeLocalValue( string varName )
	{
		import std.range: empty, popBack, back;
		
		if( scopeStack.empty )
			interpretError("Cannot remove local value, because scope stack is empty!");
		
		return scopeStack.back.removeValue( varName );
	}
	
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
		void visit(IvyNode node)
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
					writeln( "Interpret assoc array element" );
					TDataNode[string] dataNodes;
					foreach( child; node.children )
					{
						child.accept(this);
						assert( opnd.type == DataNodeType.Array && opnd.array.length == 2,
							`Assoc array pair is expected to be array of 2 elements`
						);
						assert( opnd.array[0].type == DataNodeType.String, `Assoc array key should be a string` );
						dataNodes[ opnd.array[0].str ] = opnd.array[1];
					}

					opnd = dataNodes;
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
			
			//makeDataPromotions(leftOpnd, rightOpnd);
			
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

		void visit(IAssocArrayPair node)
		{
			writeln( typeof(node).stringof ~ " visited" );
			writeln( "Assoc array pair key: ", node.key );
			node.value.accept(this);
			opnd = [TDataNode(node.key), opnd];
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
			writeln( "Available directives: ", _dirController.directiveNames );
			writeln( "Available inline directives: ", _inlineDirController.directiveNames );

			_dirController.interpret( node, this );
		}
		
		void visit(IDataFragmentStatement node)
		{ 
			writeln( typeof(node).stringof ~ " visited" );
			
			opnd = node.data;
		}

		
		void visit(ICompoundStatement node)
		{
			writeln( typeof(node).stringof ~ " visited" );

			if( node.isList )
			{
				TDataNode[] nodes;

				foreach( stmt; node )
				{
					if( stmt )
					{
						stmt.accept(this);
						nodes ~= opnd;
					}
				}

				opnd = nodes;
			}
			else
			{
				foreach( stmt; node )
				{
					if( stmt )
					{
						stmt.accept(this);
					}
				}
				// Opnd automagicaly gets last value, we hope
			}
		}
		
	}
}

class IvyMachine
{
private:
	ProgrammeObject _prog;
	TDataNode[] _stack;
	ExecutionFrame[] _frameStack;


public:
	this( ProgrammeObject progObj )
	{
		_prog = progObj;

	}

	void execLoop()
	{
		import std.range: empty, back, popBack;

		auto codeRange = _prog.code[];
		size_t pk = 0;

		for( ; pk < codeRange.length; ++pk )
		{
			Instruction instr = codeRange[pk];
			switch( instr.code )
			{
				// Base arithmetic operations execution
				case OpCode.Add, OpCode.Sub, OpCode.Mul, OpCode.Div, OpCode.Mod:
				{
					// Right value was evaluated last so it goes first in the stack
					TDataNode rightVal = _stack.back;
					_stack.popBack();
					TDataNode leftVal = _stack.back;
					assert( ( leftVal.type == DataNodeType.Integer || leftVal == DataNodeType.Floating ) && leftVal.type == rightVal.type,
						`Left and right values of arithmetic operation must have the same integer or floating type!`
					);

					import std.meta: AliasSeq;

					switch( instr.code )
					{
						foreach( arithmOp; AliasSeq!([OpCode.Add, "+"], [OpCode.Sub, "-"], [OpCode.Mul, "*"], [OpCode.Div, "/"], [OpCode.Mod, "%"]) )
						{
							case arithmOp[0]:
							{
								if( leftVal.type == DataNodeType.Integer )
								{
									mixin( ` _stack.back = leftVal.integer ` ~ arithmOp[1] ~ ` rightVal.integer;` );
								}
								else
								{
									mixin( ` _stack.back = leftVal.floating ` ~ arithmOp[1] ~ ` rightVal.floating;` );
								}
								break;
							}
						}
						default:
							assert(false, `This should never happen!` );
					}
					break;
				}

				// Logical binary operations
				case OpCode.And, OpCode.Or, OpCode.Xor:
				{
					assert( false, `Unimplemented operation!` );
					break;
				}

				// Comparision operations
				case OpCode.LT, OpCode.GT, OpCode.Equal, OpCode.NotEqual, LTEqual, GTEqual:
				{
					assert( false, `Unimplemented operation!` );
					break;
				}

				// Load constant from programme data table into stack
				case OpCode.LoadConst:
				{
					size_t constIndex = instr.args[0];
					import std.conv;
					assert( constIndex < _prog.data.length, `Cannot load const with index: `, constIndx.text );
					_stack ~= _prog.data[constIndex];
					break;
				}

				// Concatenates two arrays or strings and puts result onto stack
				case OpCode.Concat:
				{
					TDataNode rightVal = _stack.back;
					_stack.popBack();
					TDataNode leftVal = _stack.back;
					assert( ( leftVal.type == DataNodeType.String || leftVal == DataNodeType.Array ) && leftVal.type == rightVal.type,
						`Left and right values for concatenation operation must have the same string or array type!`
					);

					if( leftVal.type == DataNodeType.String )
					{
						_stack.back = leftVal.str ~ rightVal.str;
					}
					else
					{
						_stack.back = leftVal.array ~ rightVal.array;
					}

					break;
				}

				// Useless unary plus operation
				case OpCode.UnaryPlus:
				{
					assert( _stack.back.type == DataNodeType.Integer || _stack.back.type == DataNodeType.Floating,
						`Operand for unary plus operation must have integer or floating type!` );

					// Do nothing for now:)
					break;
				}

				case OpCode.UnaryMin:
				{
					assert( _stack.back.type == DataNodeType.Integer || _stack.back.type == DataNodeType.Floating,
						`Operand for unary minus operation must have integer or floating type!` );

					if( leftVal.type == DataNodeType.Integer )
					{
						_stack.back = - _stack.back.integer;
					}
					else
					{
						_stack.back = - _stack.back.floating;
					}

					break;
				}

				case OpCode.UnaryNot:
				{
					assert( _stack.back.type == DataNodeType.Boolean,
						`Operand for unary minus operation must have boolean type!` );

					_stack.back = ! _stack.back.boolean;
					break;
				}

				case OpCode.Nop:
				{
					// Doing nothing here... What did you expect? :)
					break;
				}

				// Stores data from stack into local context frame variable
				case OpCode.StoreLocal:
				{
					assert( _stack.back.type == DataNodeType.String,
						`Variable name operand must have string type!` );

					string varName = _stack.back.str;
					_stack.back.popBack(); // Remove var name from stack

					_frameStack.back.setValue( varName, _stack.back );
					_stack.popBack(); // Remove var value from stack
					break;
				}

				// Loads data from local context frame variable
				case OpCode.LoadLocal:
				{
					assert( _stack.back.type == DataNodeType.String,
						`Variable name operand must have string type!` );

					// Replacing variable name with variable value
					_stack.back = _frameStack.back.getValue( _stack.back.str );
					break;
				}

				case OpCode.CallDirective:
				{
					assert( false, "Unimplemented yet!" );
					break;
				}

				case OpCode.ImportModule:
				{
					assert( false, "Unimplemented yet!" );
					break;
				}

				case OpCode.ImportFrom:
				{
					assert( false, "Unimplemented yet!" );
					break;
				}

				default:
				{
					assert( false, "Unexpected code of operation" );
					break;
				}
			}

		}
	}
}
