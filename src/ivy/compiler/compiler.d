/// Module implements compilation of Ivy abstract syntax tree into bytecode
module ivy.compiler.compiler;

import ivy.common;
import ivy.bytecode;
import ivy.code_object: ModuleObject, CodeObject;
import ivy.directive_stuff;
import ivy.parser.node;
import ivy.parser.node_visitor;
import ivy.compiler.common;
import ivy.compiler.symbol_table: Symbol, SymbolTableFrame, DirectiveDefinitionSymbol, SymbolKind;
import ivy.compiler.module_repository: CompilerModuleRepository;
import ivy.compiler.directives;
import ivy.interpreter.data_node;

// If IvyTotalDebug is defined then enable compiler debug
version(IvyTotalDebug) version = IvyCompilerDebug;

interface IDirectiveCompiler
{
	void compile(IDirectiveStatement stmt, ByteCodeCompiler compiler);
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
		throw new ASTNodeTypeException(shortFuncName ~ "[" ~ line.to!string ~ "]: Expected " ~ shortObjName ~ ":  " ~ msg, file, line);

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
		throw new ASTNodeTypeException(longMsg, file, line);

	T typedAttr = cast(T) range.front;
	if( !typedAttr )
		throw new ASTNodeTypeException(longMsg, file, line);

	range.popFront();

	return typedAttr;
}

alias TDataNode = DataNode!string;

class ByteCodeCompiler: AbstractNodeVisitor
{
	alias LogerMethod = void delegate(LogInfo);
private:

	// Dictionary of native compilers for directives
	IDirectiveCompiler[string] _dirCompilers;

	// Dictionary maps module name to it's root symbol table frame
	SymbolTableFrame[string] _modulesSymbolTables;

	// Storage for global compiler's symbols (INativeDirectiveInterpreter's info for now)
	SymbolTableFrame _globalSymbolTable;

	// Compiler's storage for parsed module ASTs
	CompilerModuleRepository _moduleRepo;

	// Dictionary with module objects that compiler produces
	ModuleObject[string] _moduleObjects;

	// Current stack of symbol table frames
	SymbolTableFrame[] _symbolTableStack;

	// Current stack of code objects that compiler produces
	CodeObject[] _codeObjStack;

	string _mainModuleName;

	LogerMethod _logerMethod;


public:
	this(CompilerModuleRepository moduleRepo, SymbolTableFrame[string] symbolTables, string mainModuleName, LogerMethod logerMethod = null)
	{
		_logerMethod = logerMethod;
		_moduleRepo = moduleRepo;
		_modulesSymbolTables = symbolTables;
		_globalSymbolTable = new SymbolTableFrame(null, _logerMethod);

		// Add core directives set:
		_dirCompilers["var"] = new VarCompiler();
		_dirCompilers["set"] = new SetCompiler();
		_dirCompilers["expr"] = new ExprCompiler();
		_dirCompilers["if"] = new IfCompiler();
		_dirCompilers["for"] = new ForCompiler();
		_dirCompilers["repeat"] = new RepeatCompiler();
		_dirCompilers["def"] = new DefCompiler();
		_dirCompilers["import"] = new ImportCompiler();
		_dirCompilers["from"] = new FromImportCompiler();
		_dirCompilers["at"] = new AtCompiler();
		_dirCompilers["insert"] = new InsertCompiler();

		_mainModuleName = mainModuleName;
		enterModuleScope(mainModuleName);
		enterNewCodeObject( newModuleObject(mainModuleName) );
	}

	mixin NodeVisitWrapperImpl!();

	version(IvyCompilerDebug)
		enum isDebugMode = true;
	else
		enum isDebugMode = false;

	static struct LogerProxy {
		mixin LogerProxyImpl!(IvyCompilerException, isDebugMode);
		ByteCodeCompiler compiler;

		void sendLogInfo(LogInfoType logInfoType, string msg) {
			if( compiler._logerMethod is null ) {
				return; // There is no loger method, so get out of here
			}
			compiler._logerMethod(LogInfo(
				msg,
				logInfoType,
				getShortFuncName(func),
				file,
				line,
				compiler._currentLocation.fileName,
				compiler._currentLocation.lineIndex
			));
		}
	}

	LogerProxy loger(string func = __FUNCTION__, string file = __FILE__, int line = __LINE__)	{
		return LogerProxy(func, file, line, this);
	}

	void addDirCompilers(IDirectiveCompiler[string] dirCompilers)
	{
		foreach( name, dirCompiler; dirCompilers ) {
			_dirCompilers[name] = dirCompiler;
		}
	}

	void addGlobalSymbols(Symbol[] symbols)
	{
		foreach(symb; symbols) {
			_globalSymbolTable.add(symb);
		}
	}

	void enterModuleScope( string moduleName )
	{
		loger.write(`Enter method`);
		loger.write(`_modulesSymbolTables: `, _modulesSymbolTables);
		if( auto table = moduleName in _modulesSymbolTables )
		{
			loger.internalAssert(*table, `Cannot enter module sybol table frame, because it is null`);
			_symbolTableStack ~= *table;
		}
		else
		{
			loger.error(`Cannot enter module symbol table, because module "` ~ moduleName ~ `" not found!`);
		}
		loger.write(`Exit method`);
	}

	void enterScope( size_t sourceIndex )
	{
		import std.range: empty, back;
		loger.internalAssert(!_symbolTableStack.empty, `Cannot enter nested symbol table, because symbol table stack is empty`);

		SymbolTableFrame childFrame = _symbolTableStack.back.getChildFrame(sourceIndex);
		loger.internalAssert(childFrame, `Cannot enter child symbol table frame, because it's null`);

		_symbolTableStack ~= childFrame;
	}

	void exitScope()
	{
		import std.range: empty, popBack;
		loger.internalAssert(!_symbolTableStack.empty, "Cannot exit frame, because compiler symbol table stack is empty!");

		_symbolTableStack.popBack();
	}

	ModuleObject newModuleObject(string moduleName)
	{
		if( moduleName in _moduleObjects )
			loger.error(`Cannot create new module object "` ~ moduleName ~ `", because it already exists!`);

		ModuleObject newModObj = new ModuleObject(moduleName, null);
		_moduleObjects[moduleName] = newModObj;
		return newModObj;
	}

	size_t enterNewCodeObject(ModuleObject moduleObj)
	{
		import std.range: back;
		_codeObjStack ~= new CodeObject(moduleObj);
		return this.addConst( TDataNode(_codeObjStack.back) );
	}

	size_t enterNewCodeObject()
	{
		import std.range: back;
		_codeObjStack ~= new CodeObject( this.currentModule() );
		return this.addConst( TDataNode(_codeObjStack.back) );
	}

	void exitCodeObject()
	{
		import std.range: empty, popBack;
		loger.internalAssert(!_codeObjStack.empty, "Cannot exit frame, because compiler code object stack is empty!" );

		_codeObjStack.popBack();
	}

	size_t addInstr(Instruction instr)
	{
		import std.range: empty, back;
		loger.internalAssert(!_codeObjStack.empty, "Cannot add instruction, because compiler code object stack is empty!");
		loger.internalAssert(_codeObjStack.back, "Cannot add instruction, because current compiler code object is null!");

		return _codeObjStack.back.addInstr(instr);
	}

	size_t addInstr(OpCode opcode)
	{
		import std.range: empty, back;
		loger.internalAssert(!_codeObjStack.empty, "Cannot add instruction, because compiler code object stack is empty!");
		loger.internalAssert(_codeObjStack.back, "Cannot add instruction, because current compiler code object is null!");

		return _codeObjStack.back.addInstr( Instruction(opcode) );
	}

	size_t addInstr(OpCode opcode, size_t arg)
	{
		import std.range: empty, back;
		loger.internalAssert(!_codeObjStack.empty, "Cannot add instruction, because compiler code object stack is empty!");
		loger.internalAssert(_codeObjStack.back, "Cannot add instruction, because current compiler code object is null!");

		return _codeObjStack.back.addInstr( Instruction(opcode, arg) );
	}

	void setInstrArg(size_t index, size_t arg)
	{
		import std.range: empty, back;
		loger.internalAssert(!_codeObjStack.empty, "Cannot add instruction, because compiler code object stack is empty!");
		loger.internalAssert(_codeObjStack.back, "Cannot add instruction, because current compiler code object is null!");

		return _codeObjStack.back.setInstrArg( index, arg );
	}

	size_t getInstrCount()
	{
		import std.range: empty, back;
		loger.internalAssert(!_codeObjStack.empty, "Cannot add instruction, because compiler code object stack is empty!");
		loger.internalAssert(_codeObjStack.back, "Cannot add instruction, because current compiler code object is null!");

		return _codeObjStack.back.getInstrCount();
	}

	size_t addConst(TDataNode value)
	{
		import std.range: empty, back;
		loger.internalAssert(!_codeObjStack.empty, "Cannot add constant, because compiler code object stack is empty!");
		loger.internalAssert(_codeObjStack.back, "Cannot add constant, because current compiler code object is null!");
		loger.internalAssert(_codeObjStack.back._moduleObj, "Cannot add constant, because current module object is null!");

		return _codeObjStack.back._moduleObj.addConst(value);
	}

	ModuleObject currentModule() @property
	{
		import std.range: empty, back;
		loger.internalAssert(!_codeObjStack.empty, "Cannot get current module object, because compiler code object stack is empty!");
		loger.internalAssert(_codeObjStack.back, "Cannot get current module object, because current compiler code object is null!");

		return _codeObjStack.back._moduleObj;
	}

	CodeObject currentCodeObject() @property
	{
		import std.range: empty, back;
		loger.internalAssert(!_codeObjStack.empty, "Cannot get current code object, because compiler code object stack is empty!");

		return _codeObjStack.back;
	}

	Symbol symbolLookup(string name)
	{
		import std.range: empty, back;
		loger.internalAssert(!_symbolTableStack.empty, `Cannot look for symbol, because symbol table stack is empty`);
		loger.internalAssert(_symbolTableStack.back, `Cannot look for symbol, current symbol table frame is null`);

		Symbol symb = _symbolTableStack.back.lookup(name);
		debug {
			loger.write(`symbolLookup, _symbolTableStack symbols:`);
			foreach( lvl, table; _symbolTableStack[] ) {
				loger.write(`	symbols lvl`, lvl, `: `, table._symbols);
				if( table._moduleFrame ) {
					loger.write(`	module symbols lvl`, lvl, `: `, table._moduleFrame._symbols);
				} else {
					loger.write(`	module frame lvl`, lvl, ` is null`);
				}
			}
		}

		if( symb ) {
			return symb;
		}

		loger.internalAssert(_globalSymbolTable, `Compiler's global symbol table is null`);
		symb = _globalSymbolTable.lookup(name);

		if( !symb ) {
			loger.error( `Cannot find symbol "` ~ name ~ `"` );
		}

		return symb;
	}

	ModuleObject mainModule() @property
	{
		loger.internalAssert( _mainModuleName in _moduleObjects, `Cannot get main module object` );
		return _moduleObjects[_mainModuleName];
	}

	ModuleObject getOrCompileModule(string moduleName)
	{
		if( moduleName !in _moduleObjects )
		{
			// Initiate module object compilation on demand
			IvyNode moduleNode = _moduleRepo.getModuleTree(moduleName);
			loger.internalAssert(moduleNode, `Module node is null`);

			loger.write(`Entering new code object`);
			enterNewCodeObject( newModuleObject(moduleName) );
			loger.write(`Entering module scope`);
			enterModuleScope(moduleName);
			loger.write(`Starting compiling module AST`);
			moduleNode.accept(this);
			loger.write(`Finished compiling module AST`);

			scope(exit)
			{
				loger.write(`Exiting compiler scopes`);
				this.exitScope();
				this.exitCodeObject();
				loger.write(`Compiler scopes exited`);
			}
		}

		loger.write(`Exiting method`);
		return _moduleObjects[moduleName];
	}


	void _visit(IvyNode node) { assert(0); }

	//Expressions
	void _visit(IExpression node) { visit( cast(IvyNode) node ); }

	void _visit(ILiteralExpression node)
	{
		LiteralType litType;
		size_t constIndex;
		switch( node.literalType )
		{
			case LiteralType.Undef:
				constIndex = addConst( TDataNode.makeUndef() );
				break;
			case LiteralType.Null:
				constIndex = addConst( TDataNode(null) );
				break;
			case LiteralType.Boolean:
				constIndex = addConst( TDataNode(node.toBoolean()) );
				break;
			case LiteralType.Integer:
				constIndex = addConst( TDataNode(node.toInteger()) );
				break;
			case LiteralType.Floating:
				constIndex = addConst( TDataNode(node.toFloating()) );
				break;
			case LiteralType.String:
				constIndex = addConst( TDataNode(node.toStr()) );
				break;
			case LiteralType.Array:
				uint arrayLen = 0;
				foreach( IvyNode elem; node.children )
				{
					elem.accept(this);
					++arrayLen;
				}
				addInstr(OpCode.MakeArray, arrayLen);
				return; // Return in order to not add extra instr
			case LiteralType.AssocArray:
				uint aaLen = 0;
				foreach( IvyNode elem; node.children )
				{
					IAssocArrayPair aaPair = cast(IAssocArrayPair) elem;
					if( !aaPair )
						loger.error("Expected assoc array pair!");

					addInstr(OpCode.LoadConst, addConst( TDataNode(aaPair.key) ));

					if( !aaPair.value )
						loger.error("Expected assoc array value!");
					aaPair.value.accept(this);

					++aaLen;
				}
				addInstr(OpCode.MakeAssocArray, aaLen);
				return;
			default:
				loger.internalAssert(false, "Expected literal expression node!");
				break;
		}

		addInstr(OpCode.LoadConst, constIndex);
	}

	void _visit(INameExpression node)
	{
		size_t constIndex = addConst( TDataNode(node.name) );
		// Load name constant instruction
		addInstr( OpCode.LoadName, constIndex );
	}

	void _visit(IOperatorExpression node) { visit( cast(IExpression) node ); }
	void _visit(IUnaryExpression node)
	{
		loger.internalAssert( node.expr, "Expression expected!" );
		node.expr.accept(this);

		OpCode opcode;
		switch( node.operatorIndex )
		{
			case Operator.UnaryPlus: opcode = OpCode.UnaryPlus; break;
			case Operator.UnaryMin: opcode = OpCode.UnaryMin; break;
			case Operator.Not: opcode = OpCode.UnaryNot; break;
			default:
				loger.internalAssert( false, "Unexpected unary operator type!" );
		}

		addInstr(opcode);
	}
	void _visit(IBinaryExpression node)
	{
		import std.range: back;
		import std.conv: to;

		// Generate code that evaluates left and right parts of binary expression and get result on the stack
		loger.internalAssert( node.leftExpr, "Left expr expected!" );
		loger.internalAssert( node.rightExpr, "Right expr expected!" );

		switch( node.operatorIndex )
		{
			case Operator.And, Operator.Or:
			{
				node.leftExpr.accept(this);
				size_t jumpInstrIndex = addInstr(
					node.operatorIndex == Operator.And? OpCode.JumpIfFalseOrPop: OpCode.JumpIfTrueOrPop
				);
				node.rightExpr.accept(this);

				setInstrArg(jumpInstrIndex, _codeObjStack.back._instrs.length);
				return;
			}
			default:
				break; // Check out other operators
		}

		node.leftExpr.accept(this);
		node.rightExpr.accept(this);

		OpCode opcode;
		switch( node.operatorIndex )
		{
			case Operator.Add: opcode = OpCode.Add; break;
			case Operator.Sub: opcode = OpCode.Sub; break;
			case Operator.Mul: opcode = OpCode.Mul; break;
			case Operator.Div: opcode = OpCode.Div; break;
			case Operator.Mod: opcode = OpCode.Mod; break;
			case Operator.Concat: opcode = OpCode.Concat; break;
			case Operator.Equal: opcode = OpCode.Equal; break;
			case Operator.NotEqual: opcode = OpCode.NotEqual; break;
			case Operator.LT: opcode = OpCode.LT; break;
			case Operator.GT: opcode = OpCode.GT; break;
			case Operator.LTEqual: opcode = OpCode.LTEqual; break;
			case Operator.GTEqual: opcode = OpCode.GTEqual; break;
			default:
				loger.internalAssert( false, "Unexpected binary operator type: ", (cast(Operator) node.operatorIndex) );
		}

		addInstr(opcode);
	}

	void _visit(IAssocArrayPair node) { visit( cast(IExpression) node ); }

	//Statements
	void _visit(IStatement node) { visit( cast(IvyNode) node ); }
	void _visit(IKeyValueAttribute node) { visit( cast(IvyNode) node ); }

	void _visit(IDirectiveStatement node)
	{
		import std.range: empty, front, popFront;

		if( auto comp = node.name in _dirCompilers ) {
			comp.compile(node, this);
		}
		else
		{
			auto attrRange = node[];

			Symbol symb = this.symbolLookup( node.name );
			if( symb.kind != SymbolKind.DirectiveDefinition )
				loger.error(`Expected directive definition symbol kind`);

			DirectiveDefinitionSymbol dirSymbol = cast(DirectiveDefinitionSymbol) symb;
			loger.internalAssert(dirSymbol, `Directive definition symbol is null`);

			DirAttrsBlock!(true)[] dirAttrBlocks = dirSymbol.dirAttrBlocks[]; // Getting slice of list

			// Add instruction to load directive object from context by name
			addInstr(OpCode.LoadName, addConst( TDataNode(node.name) ));

			// Keeps count of stack arguments actualy used by this call. First is directive object
			size_t stackItemsCount = 1;
			bool isNoescape = false;

			loger.write(`Entering directive attrs blocks loop`);
			while( !dirAttrBlocks.empty )
			{
				final switch( dirAttrBlocks.front.kind )
				{
					case DirAttrKind.NamedAttr:
					{
						size_t argCount = 0;
						bool[string] argsSet;

						DirAttrsBlock!(true) namedAttrsDef = dirAttrBlocks.front;
						while( !attrRange.empty )
						{
							IKeyValueAttribute keyValueAttr = cast(IKeyValueAttribute) attrRange.front;
							if( !keyValueAttr ) {
								break; // We finished with key-value attributes
							}

							if( keyValueAttr.name !in namedAttrsDef.namedAttrs )
								loger.error(`Unexpected named attribute "` ~ keyValueAttr.name ~ `"`);

							if( keyValueAttr.name in argsSet )
								loger.error(`Duplicate named attribute "` ~ keyValueAttr.name ~ `" detected`);

							// Add name of named argument into stack
							addInstr(OpCode.LoadConst, addConst( TDataNode(keyValueAttr.name) ));
							++stackItemsCount;

							// Compile value expression (it should put result value on the stack)
							keyValueAttr.value.accept(this);
							++stackItemsCount;

							++argCount;
							argsSet[keyValueAttr.name] = true;
							attrRange.popFront();
						}

						foreach( name, attrDecl; namedAttrsDef.namedAttrs )
						{
							if( name !in argsSet )
							{
								IExpression defVal = namedAttrsDef.namedAttrs[name].defaultValueExpr;

								if( defVal )
								{
									// Add name of named argument into stack
									addInstr(OpCode.LoadConst, addConst( TDataNode(name) ));
									++stackItemsCount;

									// Generate code to set default values
									defVal.accept(this);
									++stackItemsCount;
									++argCount;
								}
							}
						}

						// Add instruction to load value that consists of number of pairs in block and type of block
						size_t blockHeader = ( argCount << _stackBlockHeaderSizeOffset ) + DirAttrKind.NamedAttr;
						addInstr(OpCode.LoadConst, addConst( TDataNode(blockHeader) ));
						++stackItemsCount; // We should count args block header
						break;
					}
					case DirAttrKind.ExprAttr:
					{
						size_t argCount = 0;

						auto exprAttrDefs = dirAttrBlocks.front.exprAttrs[];
						while( !attrRange.empty )
						{
							IExpression exprAttr = cast(IExpression) attrRange.front;
							if( !exprAttr ) {
								break; // We finished with positional attributes
							}

							if( exprAttrDefs.empty ) {
								loger.error(`Got more positional arguments than expected!`);
							}

							exprAttr.accept(this);
							++stackItemsCount;
							++argCount;

							attrRange.popFront(); exprAttrDefs.popFront();
						}

						while( !exprAttrDefs.empty )
						{
							IExpression defVal = exprAttrDefs.front.defaultValueExpr;
							if( !defVal )
								loger.error(`Positional attribute is not passed explicitly and has no default value`);

							defVal.accept(this);
							++stackItemsCount;
							++argCount;
							exprAttrDefs.popFront();
						}

						// Add instruction to load value that consists of number of positional arguments in block and type of block
						size_t blockHeader = ( argCount << _stackBlockHeaderSizeOffset ) + DirAttrKind.ExprAttr;
						addInstr(OpCode.LoadConst, addConst( TDataNode(blockHeader) ));
						++stackItemsCount; // We should count args block header
						break;
					}
					case DirAttrKind.IdentAttr:
					{
						loger.internalAssert( false );
						// TODO: We should take number of identifiers passed in directive definition
						while( !attrRange.empty )
						{
							IExpression identAttr = cast(INameExpression) attrRange.front;
							if( !identAttr ) {
								break;
							}

							attrRange.popFront();
						}
						break;
					}
					case DirAttrKind.KwdAttr:
					{
						loger.internalAssert( false );
						DirAttrsBlock!(true) kwdDef = dirAttrBlocks.front;
						INameExpression kwdAttr = attrRange.takeFrontAs!INameExpression(`Expected keyword attribute`);
						if( kwdDef.keyword != kwdAttr.name )
							loger.error(`Expected "` ~ kwdDef.keyword ~ `" keyword attribute`);
						break;
					}
					case DirAttrKind.BodyAttr:
						isNoescape = dirAttrBlocks.front.bodyAttr.isNoescape;
						break;
				}
				dirAttrBlocks.popFront();
			}
			loger.write(`Exited directive attrs blocks loop`);

			if( !attrRange.empty ) {
				loger.error(`Not all directive attributes processed correctly. Seems that there are unexpected attributes or missing ;`);
			}

			// After all preparations add instruction to call directive
			addInstr(OpCode.RunCallable, stackItemsCount);
			if( isNoescape ) {
				addInstr(OpCode.MarkForEscape, NodeEscapeState.Safe);
			}
		}
	}

	void _visit(IDataFragmentStatement node)
	{
		// Nothing special. Just store this piece of data into table and output then
		addInstr(OpCode.LoadConst, addConst( TDataNode(node.data) ));
	}

	void _visit(ICompoundStatement node) {
		loger.internalAssert( false, `Shouldn't fall into this!` );
	}

	void _visit(ICodeBlockStatement node)
	{
		if( !node )
			loger.error( "Code block statement node is null!" );

		if( node.isListBlock )
		{
			TDataNode emptyArray = TDataNode[].init;
			addInstr(OpCode.LoadConst, addConst(emptyArray));
		}

		auto stmtRange = node[];
		while( !stmtRange.empty )
		{
			stmtRange.front.accept(this);
			stmtRange.popFront();

			if( node.isListBlock ) {
				addInstr(OpCode.Append); // Append result to result array
			} else if( !stmtRange.empty ) {
				addInstr(OpCode.PopTop);
			}
		}
	}

	void _visit(IMixedBlockStatement node)
	{
		if( !node )
			loger.error( "Mixed block statement node is null!" );

		TDataNode emptyArray = TDataNode[].init;
		addInstr(OpCode.LoadConst, addConst(emptyArray));

		auto stmtRange = node[];
		while( !stmtRange.empty )
		{
			stmtRange.front.accept(this);
			stmtRange.popFront();

			addInstr(OpCode.Append); // Append result to result array
		}
	}

	ModuleObject[string] moduleObjects() @property {
		return _moduleObjects;
	}

	// Runs main compiler phase starting from main module
	void run()
	{
		// We create __render__ invocation on the result of module execution !!!
		IvyNode mainModuleAST = _moduleRepo.getModuleTree(_mainModuleName);

		/++
		// Load __render__ directive
		addInstr(OpCode.LoadName, addConst( TDataNode("__render__") ));

		// Add name for key-value argument
		addInstr(OpCode.LoadConst, addConst( TDataNode("__result__") ));
		+/

		mainModuleAST.accept(this);

		/++
		// In order to make call to __render__ creating block header for one positional argument
		// which is currently at the TOP of the execution stack
		size_t blockHeader = (1 << _stackBlockHeaderSizeOffset) + DirAttrKind.NamedAttr;
		addInstr(OpCode.LoadConst, addConst( TDataNode(blockHeader) )); // Add argument block header

		// Stack layout is:
		// TOP: argument block header
		// TOP - 1: Current result argument
		// TOP - 2: Current result var name argument
		// TOP - 3: Callable object for __render__
		addInstr(OpCode.RunCallable, 4);
		+/
	}

	string toPrettyStr()
	{
		import std.conv;
		import std.range: empty, back;

		string result;

		foreach( modName, modObj; _moduleObjects )
		{
			result ~= "\r\nMODULE " ~ modName ~ "\r\n";
			result ~= "\r\nCONSTANTS\r\n";
			foreach( i, con; modObj._consts ) {
				result ~= i.text ~ "  " ~ con.toString() ~ "\r\n";
			}

			result ~= "\r\nCODE\r\n";
			foreach( i, con; modObj._consts )
			{
				if( con.type == DataNodeType.CodeObject )
				{
					if( !con.codeObject ) {
						result ~= "\r\nCode object " ~ i.text ~ " is null\r\n";
					}
					else
					{
						result ~= "\r\nCode object " ~ i.text ~ "\r\n";
						foreach( k, instr; con.codeObject._instrs ) {
							result ~= k.text ~ "  " ~ instr.opcode.text ~ "  " ~ instr.arg.text ~ "\r\n";
						}
					}
				}
			}
			result ~= "\r\nEND OF MODULE " ~ modName ~ "\r\n";
		}

		return result;
	}
}