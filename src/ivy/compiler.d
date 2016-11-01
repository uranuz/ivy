/// Module implements compilation of Ivy abstract syntax tree into bytecode
module ivy.compiler;

import ivy.node;
import ivy.node_visitor;
import ivy.bytecode;
import ivy.interpreter_data;

class ASTNodeTypeException: Exception
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


class CompilerException: Exception
{
public:
	@nogc @safe this(string msg, string file = __FILE__, size_t line = __LINE__, Throwable next = null) pure nothrow
	{
		super(msg, file, line, next);
	}

}

void compilerError(string msg, string file = __FILE__, size_t line = __LINE__)
{
	throw new CompilerException(msg, file, line);
}

alias TDataNode = DataNode!string;

interface IDirectiveCompiler
{
	void compile( IDirectiveStatement stmt, ByteCodeCompiler compiler );

}

/++
	`Var` directive is defined as list of elements. Each of them could be of following forms:
	- Just name of new variable without any value or type (default value will be set, type is `any`)
		{# var a #}
	- Name with initializer value (type is `any`)
		{# var a: "Example" #}
	- Name with type but without any value (`as` context keyword is used to describe type)
		{# var a as str #}
	- Name with initializer and type
		{# var a: "Example" as str #}

	Multiple variables could be defined using one `var` directive
	{# var
			a
			b: "Example"
			c as str
			d: "Example2" as str
	#}
+/
class VarCompiler: IDirectiveCompiler
{
public:
	override void compile( IDirectiveStatement stmt, ByteCodeCompiler compiler )
	{
		import std.range: empty, back;

		if( !stmt || stmt.name != "var" )
			compilerError( `Expected "var" directive statement!` );
		if( compiler._frameStack.empty )
			compilerError( `Compiler frame stack is empty!` );
		if( !compiler._frameStack.back )
			compilerError( `Compiler's current frame is null!` );

		auto stmtRange = stmt[];
		while( !stmtRange.empty )
		{
			string varName;

			// Exactly setting value in nearest context
			compiler._frameStack.back.add( Symbol(varName) );

			uint constIndex = cast(uint) compiler.addConst( TDataNode(varName) );

			Instruction instr;
			instr.opcode = OpCode.LoadConst;
			instr.args[0] = constIndex;
			compiler.addInstr( instr );

			if( auto kwPair = cast(IKeyValueAttribute) stmtRange.front )
			{
				varName = kwPair.name;
				if( !kwPair.value )
					compilerError( "Expected value for 'var' directive" );

				kwPair.value.accept(compiler); // Compile expression for getting value
				stmtRange.popFront();
			}
			else if( auto nameExpr = cast(INameExpression) stmtRange.front )
			{
				varName = nameExpr.name;
				stmtRange.popFront();
			}
			else
			{
				compilerError( `Expected named attribute or name as variable declarator!` );
			}

			if( !stmtRange.empty )
			{
				if( auto asKwdExpr = cast(INameExpression) stmtRange.front )
				{
					if( asKwdExpr.name == "as" )
					{
						// TODO: Try to find out type of variable after `as` keyword
						// Assuming that there will be no variable with name `as` in programme
						stmtRange.popFront(); // Skip `as` keyword

						if( stmtRange.empty )
							compilerError( `Expected variable type declaration` );

						// For now just skip type expression
						stmtRange.popFront();
					}
				}
			}

			compiler.addInstr( Instruction(OpCode.StoreName) );
		}

		if( !stmtRange.empty )
			compilerError( "Expected end of directive after key-value pair. Maybe ';' is missing" );
	}
}

/++
	`Set` directive is used to set values of existing variables in context.
	It is defined as list of named attributes where key is variable name
	and attr value is new value for variable in context. Example:
	{# set a: "Example" #}

	Multiple variables could be set using one `set` directive
	{# set
			a: "Example"
			b: 10
			c: { s: 10, k: "Example2" }
	#}
+/
class SetInterpreter : IDirectiveCompiler
{
public:
	override void compile( IDirectiveStatement statement, ByteCodeCompiler compiler )
	{
		if( !statement || statement.name != "set"  )
			compilerError( "Expected 'set' directive" );

		auto stmtRange = statement[];

		while( !stmtRange.empty )
		{
			IKeyValueAttribute kwPair = stmtRange.takeFrontAs!IKeyValueAttribute("Key-value pair expected");

			if( !kwPair.value )
				compilerError( "Expected value for 'set' directive" );

			uint constIndex = cast(uint) compiler.addConst( TDataNode( kwPair.name ) );

			Instruction instr;
			instr.opcode = OpCode.LoadConst;
			instr.args[0] = constIndex;
			compiler.addInstr( instr );

			kwPair.value.accept(compiler); //Evaluating expression

			compiler.addInstr( Instruction(OpCode.StoreName) );
		}

		if( !stmtRange.empty )
			compilerError( "Expected end of directive after key-value pair. Maybe ';' is missing" );
	}

}

class IfCompiler: IDirectiveCompiler
{
	override void compile( IDirectiveStatement statement, ByteCodeCompiler compiler )
	{
		if( !statement || statement.name != "if" )
			compilerError( `Expected "if" directive statement!` );

		import std.typecons: Tuple;
		import std.range: back, empty;
		alias IfSect = Tuple!(IExpression, "cond", IStatement, "stmt");

		IfSect[] ifSects;
		IStatement elseBody;

		auto stmtRange = statement[];

		IExpression condExpr = stmtRange.takeFrontAs!IExpression( "Conditional expression expected" );
		IStatement bodyStmt = stmtRange.takeFrontAs!IStatement( "'If' directive body statement expected" );

		ifSects ~= IfSect(condExpr, bodyStmt);

		while( !stmtRange.empty )
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
					compilerError("'else' statement body expected to be the last 'if' attribute. Maybe ';' is missing");
				break;
			}
			else
			{
				compilerError("'elif' or 'else' keyword expected");
			}
		}

		foreach( i, ifSect; ifSects )
		{
			ifSect.cond.accept(compiler);

			// Add conditional jump instruction
			// Remember address of jump instruction
			size_t jumpInstrIndex = compiler.addInstr( Instruction( OpCode.JumpIfFalse ) );

			// Drop condition operand from stack
			compiler.addInstr( Instruction( OpCode.StackPop ) );

			// Add `if body` code
			ifSect.stmt.accept(compiler);

			// Getting address of instruction following after if body
			uint jumpElseIndex = cast(uint) compiler.getInstrCount();

			compiler.setInstrArg0( jumpInstrIndex, jumpElseIndex );
		}

		if( elseBody )
		{
			elseBody.accept(compiler);
		}

		if( !stmtRange.empty )
			compilerError( `Expected end of "if" directive. Maybe ';' is missing` );
	}

}

/*
class ForInterpreter : IDirectiveCompiler
{
public:
	override void compile( IDirectiveStatement statement, ByteCodeCompiler compiler )
	{
		if( !statement || statement.name != "for"  )
			interpretError( "Expected 'for' directive" );

		auto stmtRange = statement[];

		INameExpression varNameExpr = stmtRange.takeFrontAs!INameExpression("For loop variable name expected");

		string varName = varNameExpr.name;
		if( varName.length == 0 )
			interpretError("Loop variable name cannot be empty");

		INameExpression inAttribute = stmtRange.takeFrontAs!INameExpression("Expected 'in' attribute");

		if( inAttribute.name != "in" )
			interpretError( "Expected 'in' keyword" );

		IExpression aggregateExpr = stmtRange.takeFrontAs!IExpression("Expected 'for' aggregate expression");

		// Compile code to calculate aggregate value
		aggregateExpr.accept(compiler);

		ICompoundStatement bodyStmt = stmtRange.takeFrontAs!ICompoundStatement( "Expected loop body statement" );

		if( !stmtRange.empty )
			interpretError( "Expected end of directive after loop body. Maybe ';' is missing" );

		// TODO: Check somehow if aggregate has supported type

		// Issue command to get array length
		compiler._code ~= Instruction( OpCode.GetLength );

		// Prepare counter
		uint zeroConstIndex = cast(uint) compiler._consts.length;
		compiler._consts ~= TDataNode(0);

		Instruction loadZeroInstr;
		loadZeroInstr.args[0] = zeroConstIndex;

		uint oneConstIndex = cast(uint) compiler._consts.length;
		compiler._consts ~= TDataNode(0);

		Instruction loadOneInstr;
		loadOneInstr.args[0] = oneConstIndex;

		compiler._code ~= loadZeroInstr;



		bodyStmt.accept(compiler);
	}

}
*/

// Produces OpCode.Nop
class PassInterpreter : IDirectiveCompiler
{
public:
	override void compile( IDirectiveStatement statement, ByteCodeCompiler compiler )
	{
		compiler.addInstr( Instruction( OpCode.Nop ) );
	}
}

class ExprCompiler: IDirectiveCompiler
{
	override void compile( IDirectiveStatement stmt, ByteCodeCompiler compiler )
	{
		if( !stmt || stmt.name != "expr" )
			compilerError( `Expected "expr" directive statement!` );

		auto stmtRange = stmt[];
		if( stmtRange.empty )
			compilerError( `Expected node as "expr" argument!` );

		stmtRange.front.accept(compiler);
		stmtRange.popFront();

		if( !stmtRange.empty )
			compilerError( `Expected end of "expr" directive. Maybe ';' is missing` );
	}

}

/+
class TextBlockInterpreter: IDirectiveCompiler
{
public:
	override void compile( IDirectiveStatement statement, ByteCodeCompiler compiler )
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

		stmtRange.popFront(); //Skip attribute of directive

		if( !stmtRange.empty )
			interpretError("Expected only one attribute in 'text' directive");

		import std.array: appender;

		auto result = appender!string();

		writeDataNodeLines( interp.opnd, result, 15 );

		string dat = result.data;

		interp.opnd = result.data;
	}

}
+/

import std.stdio;
/// Defines directive using ivy language
class DefCompiler: IDirectiveCompiler
{
	override void compile( IDirectiveStatement statement, ByteCodeCompiler compiler )
	{
		if( !statement || statement.name != "def"  )
			compilerError( "Expected 'def' directive" );

		auto stmtRange = statement[];
		INameExpression defNameExpr = stmtRange.takeFrontAs!INameExpression("Expected name for directive definition");
		AttrubutesDeclaration[] attrDecls;

		CodeObject dirCodeObj = new CodeObject();
		ICompoundStatement bodyStatement;
		bool withNewScope = false;

		while( !stmtRange.empty )
		{
			ICodeBlockStatement attrDefBlockStmt = cast(ICodeBlockStatement) stmtRange.front;
			if( !attrDefBlockStmt )
			{
				break; // Expected to see some attribute declaration
			}

			IDirectiveStatementRange attrDefStmtRange = attrDefBlockStmt[];

			while( !attrDefStmtRange.empty )
			{
				IDirectiveStatement attrDefStmt = attrDefStmtRange.front;
				IAttributeRange attrDefStmtAttrRange = attrDefStmt[];

				DefAttrDeclType attrDeclType;

				switch( attrDefStmt.name )
				{
					case "def.named": {
						attrDeclType = DefAttrDeclType.Named;
						TDataNode data = compileNamedAttrsBlock(attrDefStmtAttrRange);
						attrDecls ~= AttrubutesDeclaration(attrDeclType, data);
						break;
					}
					case "def.expr": {
						attrDeclType = DefAttrDeclType.Expr;


						break;
					}
					case "def.ident": {
						attrDeclType = DefAttrDeclType.Identifier;
						break;
					}
					case "def.kwd": {
						attrDeclType = DefAttrDeclType.Keyword;
						break;
					}
					case "def.result": {
						attrDeclType = DefAttrDeclType.Result;

						break;
					}
					case "def.newScope": {
						withNewScope = true; // Option to create new scope to store data for this directive
						break;
					}
					case "def.body": {
						attrDeclType = DefAttrDeclType.Body;
						if( bodyStatement )
							compilerError( "Multiple body statements are not allowed!!!" );

						if( attrDefStmtAttrRange.empty )
							compilerError( "Expected compound statement as directive body statement, but got end of attributes list!" );

						bodyStatement = cast(ICompoundStatement) attrDefStmtAttrRange.front; // Getting body AST for statement
						if( !bodyStatement )
							compilerError( "Expected compound statement as directive body statement" );

						CodeObject bodyCodeObj;
						{
							// New code object created on compiler frame creation
							compiler.newFrame( compiler.getCurrentModule() );

							// Generating code for def.body
							bodyStatement.accept(compiler);

							// Getting body code object
							bodyCodeObj = compiler.getCurrentCodeObject();

							scope(exit) compiler.exitFrame();
						}

						// Add def.body code object to current module constants list
						uint codeObjIndex = cast(uint) compiler.addConst( TDataNode(bodyCodeObj) );

						// Add instruction to load code object from module constants
						Instruction loadCodeObjInstr;
						loadCodeObjInstr.opcode = OpCode.LoadConst;
						loadCodeObjInstr.args[0] = codeObjIndex;
						compiler.addInstr( loadCodeObjInstr );

						// Add directive name to module constants
						uint dirNameConstIndex = cast(uint) compiler.addConst( TDataNode(defNameExpr.name) );

						// Add instruction to load directive name from consts
						Instruction loadDirNameInstr;
						loadDirNameInstr.opcode = OpCode.LoadConst;
						loadDirNameInstr.args[0] = dirNameConstIndex;
						compiler.addInstr( loadDirNameInstr );

						// Add instruction to create directive object
						Instruction loadDirInstr;
						loadDirInstr.opcode = OpCode.LoadDirective;
						compiler.addInstr( loadDirInstr );

						break;
					}
					default: {
						compilerError( `Unexpected directive attribute definition statement "` ~ attrDefStmt.name ~ `"` );
						break;
					}
				}
				attrDefStmtRange.popFront(); // Going to the next directive statement in code block
			}
			stmtRange.popFront(); // Go to next attr definition directive
		}

		// Here should go commands to compile directive body


	}

	// Method parses attributes of "def.named" directive
	TDataNode compileNamedAttrsBlock(IAttributeRange attrRange)
	{
		TDataNode attrDefs;
		while( !attrRange.empty )
		{
			string attrName;
			string attrType;
			IExpression defaultValueExpr;

			if( auto kwPair = cast(IKeyValueAttribute) attrRange.front )
			{
				attrName = kwPair.name;
				defaultValueExpr = cast(IExpression) kwPair.value;
				if( !defaultValueExpr )
					compilerError( `Expected attribute default value expression!` );

				attrRange.popFront(); // Skip named attribute
			}
			else if( auto nameExpr = cast(INameExpression) attrRange.front )
			{
				attrName = nameExpr.name;
				attrRange.popFront(); // Skip variable name
			}
			else
			{
				// Just get out of there
				break;
			}

			if( !attrRange.empty )
			{
				// Try to parse optional type definition
				if( auto asKwdExpr = cast(INameExpression) attrRange.front )
				{
					if( asKwdExpr.name == "as" )
					{
						// TODO: Try to find out type of attribute after `as` keyword
						// Assuming that there will be no named attribute with name `as` in programme
						attrRange.popFront(); // Skip `as` keyword

						if( attrRange.empty )
							compilerError( `Expected attr type definition, but got end of attrs range!` );

						auto attrTypeExpr = cast(INameExpression) attrRange.front;
						if( !attrTypeExpr )
							compilerError( `Expected attr type definition!` );

						attrType = attrTypeExpr.name; // Getting type of attribute as string (for now)

						attrRange.popFront(); // Skip type expression
					}
				}
			}

			attrDefs[ attrName ] = TDataNode([
				"attrName": TDataNode(attrName),
				"attrType": TDataNode(attrType)
			]);
		}

		return attrDefs;
	}
}

enum SymbolScopeType: ubyte { Global, Local }

struct Symbol
{
	string name;
	SymbolScopeType scopeType;
}

class CompilerFrame
{
	CodeObject _codeObj;
	ModuleObject _moduleObj;
	Symbol[string] _symbols;

public:
	this(ModuleObject moduleObj)
	{
		_codeObj = new CodeObject();
		_moduleObj = moduleObj;
	}

	Symbol* lookup(string name)
	{
		return name in _symbols;
	}

	void add( Symbol symb )
	{
		_symbols[symb.name] = symb;
	}
}


class ByteCodeCompiler: AbstractNodeVisitor
{
private:
	IDirectiveCompiler[string] _dirCompilers;
	CompilerFrame[] _frameStack;

public:
	this(ModuleObject moduleObj)
	{
		_dirCompilers["var"] = new VarCompiler();
		_dirCompilers["expr"] = new ExprCompiler();
		_dirCompilers["if"] = new IfCompiler();
		//_dirCompilers["for"] = new ForCompiler();
		_dirCompilers["def"] = new DefCompiler();

		newFrame(moduleObj);
	}

	void newFrame(ModuleObject moduleObj)
	{
		_frameStack ~= new CompilerFrame(moduleObj);
	}

	void exitFrame()
	{
		import std.range: empty, popBack;
		assert( !_frameStack.empty, "Cannot exit frame, because compiler frame stack is empty!" );

		_frameStack.popBack();
	}

	size_t addInstr( Instruction instr )
	{
		import std.range: empty, back;
		assert( !_frameStack.empty, "Cannot add instruction, because compiler frame stack is empty!" );
		assert( _frameStack.back, "Cannot add instruction, because current compiler frame is null!" );
		assert( _frameStack.back._codeObj, "Cannot add instruction, because current code object is null!" );

		return _frameStack.back._codeObj.addInstr(instr);
	}

	void setInstrArg0( size_t index, uint arg )
	{
		import std.range: empty, back;
		assert( !_frameStack.empty, "Cannot add instruction, because compiler frame stack is empty!" );
		assert( _frameStack.back, "Cannot add instruction, because current compiler frame is null!" );
		assert( _frameStack.back._codeObj, "Cannot add instruction, because current code object is null!" );

		return _frameStack.back._codeObj.setInstrArg0( index, arg );
	}

	size_t getInstrCount()
	{
		import std.range: empty, back;
		assert( !_frameStack.empty, "Cannot add instruction, because compiler frame stack is empty!" );
		assert( _frameStack.back, "Cannot add instruction, because current compiler frame is null!" );
		assert( _frameStack.back._codeObj, "Cannot add instruction, because current code object is null!" );

		return _frameStack.back._codeObj.getInstrCount();
	}

	size_t addConst( TDataNode value )
	{
		import std.range: empty, back;
		assert( !_frameStack.empty, "Cannot add constant, because compiler frame stack is empty!" );
		assert( _frameStack.back, "Cannot add constant, because current compiler frame is null!" );
		assert( _frameStack.back._moduleObj, "Cannot add constant, because current module object is null!" );

		return _frameStack.back._moduleObj.addConst(value);
	}

	ModuleObject getCurrentModule()
	{
		import std.range: empty, back;
		assert( !_frameStack.empty, "Cannot add constant, because compiler frame stack is empty!" );
		assert( _frameStack.back, "Cannot add constant, because current compiler frame is null!" );

		return _frameStack.back._moduleObj;
	}

	CodeObject getCurrentCodeObject()
	{
		import std.range: empty, back;
		assert( !_frameStack.empty, "Cannot add constant, because compiler frame stack is empty!" );
		assert( _frameStack.back, "Cannot add constant, because current compiler frame is null!" );

		return _frameStack.back._codeObj;
	}

	override {
		void visit(IvyNode node) { assert(0); }

		//Expressions
		void visit(IExpression node) { visit( cast(IvyNode) node ); }

		void visit(ILiteralExpression node)
		{
			LiteralType litType;
			uint constIndex;
			switch( node.literalType )
			{
				case LiteralType.Undef:
					constIndex = cast(uint) addConst( TDataNode() ); // Undef is default
					break;
				case LiteralType.Null:
					constIndex = cast(uint) addConst( TDataNode(null) );
					break;
				case LiteralType.Boolean:
					constIndex = cast(uint) addConst( TDataNode( node.toBoolean() ) );
					break;
				case LiteralType.Integer:
					constIndex = cast(uint) addConst( TDataNode( node.toInteger() ) );
					break;
				case LiteralType.Floating:
					constIndex = cast(uint) addConst( TDataNode( node.toFloating() ) );
					break;
				case LiteralType.String:
					constIndex = cast(uint) addConst( TDataNode( node.toStr() ) );
					break;
				case LiteralType.Array:
					assert( false, "Array literal code generation is not implemented yet!" );
					break;
				case LiteralType.AssocArray:
					assert( false, "Assoc array literal code generation is not implemented yet!" );
					break;
				default:
					assert( false, "Expected literal expression node!" );
					break;
			}

			Instruction instr;
			instr.opcode = OpCode.LoadConst;
			instr.args[0] = constIndex;
			addInstr( instr );
		}

		void visit(INameExpression node)
		{
			import std.range: empty, back;

			if( !node )
				compilerError( "Expected name expression!" );
			if( _frameStack.empty )
				compilerError( "Compiler frame stack is empty!" );
			if( !_frameStack.back )
				compilerError( "Compiler current stack item is null!" );

			uint constIndex = cast(uint) addConst( TDataNode( node.name ) );
			if( _frameStack.back.lookup(node.name) )
			{
				// Regular name

				// Load name constant instruction
				Instruction instr;
				instr.opcode = OpCode.LoadConst;
				instr.args[0] = constIndex;
				addInstr( instr );

				// Add name load instruction
				addInstr( Instruction(OpCode.LoadName) );

			}
			else
			{
				// Seems that it's built-in name or data context name
			}
		}

		void visit(IOperatorExpression node) { visit( cast(IExpression) node ); }
		void visit(IUnaryExpression node)
		{
			assert( node.expr, "Expression expected!" );
			node.expr.accept(this);

			OpCode opcode;
			switch( node.operatorIndex )
			{
				case Operator.UnaryPlus:
					opcode = OpCode.UnaryPlus;
					break;
				case Operator.UnaryMin:
					opcode = OpCode.UnaryMin;
					break;
				case Operator.Not:
					opcode = OpCode.UnaryNot;
					break;
				default:
					assert( false, "Unexpected unary operator type!" );
					break;
			}

			addInstr( Instruction(opcode) );
		}
		void visit(IBinaryExpression node)
		{
			// Generate code that evaluates left and right parts of binary expression and get result on the stack
			assert( node.leftExpr, "Left expr expected!" );
			node.leftExpr.accept(this);
			assert( node.rightExpr, "Right expr expected!" );
			node.rightExpr.accept(this);

			OpCode opcode;
			switch( node.operatorIndex )
			{
				case Operator.Add:
					opcode = OpCode.Add;
					break;
				case Operator.Sub:
					opcode = OpCode.Sub;
					break;
				case Operator.Mul:
					opcode = OpCode.Mul;
					break;
				case Operator.Div:
					opcode = OpCode.Div;
					break;
				case Operator.Mod:
					opcode = OpCode.Mod;
					break;
				case Operator.Concat:
					opcode = OpCode.Concat;
					break;
				case Operator.And:
					opcode = OpCode.And;
					break;
				case Operator.Or:
					opcode = OpCode.Or;
					break;
				case Operator.Xor:
					opcode = OpCode.Xor;
					break;
				case Operator.Equal:
					opcode = OpCode.Equal;
					break;
				case Operator.LT:
					opcode = OpCode.LT;
					break;
				case Operator.GT:
					opcode = OpCode.GT;
					break;
				default:
					assert( false, "Unexpected binary operator type!" );
					break;
			}

			addInstr( Instruction(opcode) );
		}

		void visit(IAssocArrayPair node) { visit( cast(IExpression) node ); }

		//Statements
		void visit(IStatement node) { visit( cast(IvyNode) node ); }
		void visit(IKeyValueAttribute node) { visit( cast(IvyNode) node ); }

		void visit(IDirectiveStatement node)
		{
			if( auto comp = node.name in _dirCompilers )
			{
				comp.compile( node, this );
			}
			else
			{
				// First of all I'll be trying to load directive with this into machine stack
				assert( false, `Compiling for inline directive "` ~ node.name ~ `" is not implemented yet!` );
			}
		}

		void visit(IDataFragmentStatement node)
		{
			// Nothing special. Just store this piece of data into table
			uint constIndex = cast(uint) addConst( TDataNode(node.data) );

			Instruction instr;
			instr.opcode = OpCode.LoadConst;
			instr.args[0] = constIndex;
			addInstr( instr );
		}

		void visit(ICompoundStatement node)
		{
			if( !node )
				compilerError( "Compound statement node is null!" );

			auto stmtRange = node[];
			while( !stmtRange.empty )
			{
				stmtRange.front.accept( this );
				stmtRange.popFront();
			}
		}
	}

	// Assembles constants and code chunks into complete module bytecode
	void assemble()
	{
		// TODO: Do it please!
	}

	string toPrettyStr()
	{
		import std.conv;
		import std.range: empty, back;

		string result;

		if( _frameStack.empty )
			return `<Frame stack is empty>`;

		if( !_frameStack.back )
			return `<Current compiler frame is null>`;

		result ~= "CONSTANTS:\r\n";
		foreach( i, con; _frameStack.back._moduleObj._consts )
		{
			result ~= i.text ~ "  " ~ con.toString() ~ "\r\n";
		}
		result ~= "\r\n";

		result ~= "CODE:\r\n";
		foreach( i, instr; _frameStack.back._codeObj._instrs )
		{
			result ~= i.text ~ "  " ~ instr.opcode.text ~ "  " ~ instr.args.to!string ~ "\r\n";
		}

		return result;
	}

}

