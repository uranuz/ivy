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
import ivy.interpreter.data_node;
import ivy.compiler.def_analyze_mixin: DefAnalyzeMixin;
import ivy.compiler.directive.factory: DirectiveCompilerFactory;
import ivy.compiler.node_visit_mixin: NodeVisitMixin;
import ivy.compiler.errors: IvyCompilerException;
import ivy.compiler.symbol_collector: CompilerSymbolsCollector;
import ivy.interpreter.module_objects_cache: ModuleObjectsCache;
import ivy.interpreter.directive_factory: InterpreterDirectiveFactory;

// If IvyTotalDebug is defined then enable compiler debug
version(IvyTotalDebug) version = IvyCompilerDebug;

enum JumpKind {
	Break = 1,
	Continue = 0
}

class ByteCodeCompiler: AbstractNodeVisitor
{
public:
	import std.typecons: Tuple;
	alias LogerMethod = void delegate(LogInfo);
	alias JumpTableItem = Tuple!(JumpKind, "jumpKind", size_t, "instrIndex");

	mixin DefAnalyzeMixin;

private:
	// Storage or factory containing compilers for certain directives
	DirectiveCompilerFactory _compilerFactory;

	InterpreterDirectiveFactory _directiveFactory;

	// Dictionary maps module name to it's root symbol table frame
	public CompilerSymbolsCollector _symbolsCollector;

	// Storage for global compiler's symbols (INativeDirectiveInterpreter's info for now)
	SymbolTableFrame _globalSymbolTable;

	// Compiler's storage for parsed module ASTs
	CompilerModuleRepository _moduleRepo;

	// Object implementing storage of compiled ModuleObject's
	ModuleObjectsCache _moduleObjCache;

	size_t[][ ubyte[16] ][string] _moduleConstHashes; // Mapping moduleName -> constHash -> constIndex (list)

	// Current stack of code objects that compiler produces
	CodeObject[] _codeObjStack;

	LogerMethod _logerMethod;

	// Stack of jump tables used to set.
	// Stack item contains kind of jump and source instruction index from where to jump
	public JumpTableItem[][] _jumpTableStack;


public:
	this(
		CompilerModuleRepository moduleRepo,
		CompilerSymbolsCollector symbolsCollector,
		DirectiveCompilerFactory compilerFactory,
		InterpreterDirectiveFactory directiveFactory,
		ModuleObjectsCache moduleObjCache,
		LogerMethod logerMethod = null
	) {
		_logerMethod = logerMethod; // First of all set loger method in order to not miss any log messages

		// Some internal checks goes here...
		this.loger.internalAssert(moduleRepo, `Expected module repository`);
		this.loger.internalAssert(symbolsCollector, `Expected symbols collector`);
		this.loger.internalAssert(compilerFactory, `Expected compiler factory`);
		this.loger.internalAssert(directiveFactory, `Expected directive factory`);
		this.loger.internalAssert(moduleObjCache, `Expected module objects cache`);

		_moduleRepo = moduleRepo;
		_symbolsCollector = symbolsCollector;
		_compilerFactory = compilerFactory;
		_directiveFactory = directiveFactory;
		_moduleObjCache = moduleObjCache;

		_globalSymbolTable = new SymbolTableFrame(null, _logerMethod);
		_addGlobalSymbols();
	}

	mixin NodeVisitMixin!();

	version(IvyCompilerDebug)
		enum isDebugMode = true;
	else
		enum isDebugMode = false;

	static struct LogerProxy {
		mixin LogerProxyImpl!(IvyCompilerException, isDebugMode);
		ByteCodeCompiler compiler;

		string sendLogInfo(LogInfoType logInfoType, string msg)
		{
			if( compiler._logerMethod !is null )
			{
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
			return msg;
		}
	}

	LogerProxy loger(string func = __FUNCTION__, string file = __FILE__, int line = __LINE__)	{
		return LogerProxy(func, file, line, this);
	}

	private void _addGlobalSymbols()
	{
		foreach(symb; _directiveFactory.symbols) {
			_globalSymbolTable.add(symb);
		}
	}

	ModuleObject newModuleObject(string moduleName)
	{
		if( ModuleObject moduleObj = _moduleObjCache.get(moduleName) )
			loger.error(`Cannot create new module object "` ~ moduleName ~ `", because it already exists!`);

		ModuleObject newModObj = new ModuleObject(moduleName, moduleName);
		_moduleObjCache.add(newModObj);
		return newModObj;
	}

	size_t enterNewModuleCodeObject(string moduleName)
	{
		import std.range: back, empty;
		loger.internalAssert(!moduleName.empty, "Expected module name!");
		_codeObjStack ~= new CodeObject(moduleName, newModuleObject(moduleName));
		return this.addConst( IvyData(_codeObjStack.back) );
	}

	size_t enterNewCodeObject(string name)
	{
		import std.range: back, empty;
		loger.internalAssert(!name.empty, "Expected code object name!");
		_codeObjStack ~= new CodeObject(name, this.currentModule());
		return this.addConst( IvyData(_codeObjStack.back) );
	}

	void exitCodeObject()
	{
		import std.range: empty, popBack;
		loger.internalAssert(!_codeObjStack.empty, "Cannot exit frame, because compiler code object stack is empty!");

		_codeObjStack.popBack();
	}

	size_t addInstr(Instruction instr)
	{
		import std.range: empty, back;
		loger.internalAssert(!_codeObjStack.empty, "Cannot add instruction, because compiler code object stack is empty!");
		loger.internalAssert(_codeObjStack.back, "Cannot add instruction, because current compiler code object is null!");

		return _codeObjStack.back.addInstr(instr, _currentLocation.lineIndex);
	}

	size_t addInstr(OpCode opcode) {
		return addInstr(Instruction(opcode));
	}

	size_t addInstr(OpCode opcode, size_t arg) {
		return addInstr(Instruction(opcode, arg));
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

	size_t addConst(IvyData value)
	{
		import std.range: empty, back;
		import std.digest.md: md5Of;
		loger.internalAssert(!_codeObjStack.empty, "Cannot add constant, because compiler code object stack is empty!");
		loger.internalAssert(_codeObjStack.back, "Cannot add constant, because current compiler code object is null!");
		loger.internalAssert(_codeObjStack.back._moduleObj, "Cannot add constant, because current module object is null!");
		ModuleObject mod = _codeObjStack.back._moduleObj;
		if( mod.name !in _moduleConstHashes ) {
			_moduleConstHashes[mod.name] = null;
		}
		ubyte[16] valHash = md5Of(value.toString());
		if( valHash !in _moduleConstHashes[mod.name] ) {
			_moduleConstHashes[mod.name][valHash] = null;
		}
		foreach( size_t constIndex; _moduleConstHashes[mod.name][valHash] ) {
			if( mod._consts[constIndex] == value ) {
				return constIndex; // Constant is already here. Return it's index
			}
		}
		size_t newIndex = _codeObjStack.back._moduleObj.addConst(value);
		_moduleConstHashes[mod.name][valHash] ~= newIndex;
		return newIndex;
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
		Symbol symb = _symbolsCollector.symbolLookup(name);

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

	ModuleObject getOrCompileModule(string moduleName)
	{
		if( ModuleObject moduleObj = _moduleObjCache.get(moduleName) ) {
			return moduleObj;
		}
		else
		{
			// Initiate module object compilation on demand
			IvyNode moduleNode = _moduleRepo.getModuleTree(moduleName);
			loger.internalAssert(moduleNode, `Module node is null`);

			loger.write(`Entering new code object`);
			enterNewModuleCodeObject(moduleName);
			loger.write(`Entering module scope`);
			_symbolsCollector.enterModuleScope(moduleName);
			loger.write(`Starting compiling module AST`);
			moduleNode.accept(this);
			loger.write(`Finished compiling module AST`);

			scope(exit)
			{
				loger.write(`Exiting compiler scopes`);
				_symbolsCollector.exitScope();
				this.exitCodeObject();
				loger.write(`Compiler scopes exited`);
			}
		}
		return _moduleObjCache.get(moduleName);
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
				constIndex = addConst( IvyData.makeUndef() );
				break;
			case LiteralType.Null:
				constIndex = addConst( IvyData(null) );
				break;
			case LiteralType.Boolean:
				constIndex = addConst( IvyData(node.toBoolean()) );
				break;
			case LiteralType.Integer:
				constIndex = addConst( IvyData(node.toInteger()) );
				break;
			case LiteralType.Floating:
				constIndex = addConst( IvyData(node.toFloating()) );
				break;
			case LiteralType.String:
				constIndex = addConst( IvyData(node.toStr()) );
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

					addInstr(OpCode.LoadConst, addConst( IvyData(aaPair.key) ));

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
		size_t constIndex = addConst( IvyData(node.name) );
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

		auto comp = _compilerFactory.get(node.name);
		if( comp !is null ) {
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

			DirAttrsBlock[] dirAttrBlocks = dirSymbol.dirAttrBlocks[]; // Getting slice of list

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

						DirAttrsBlock namedAttrsDef = dirAttrBlocks.front;
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
							addInstr(OpCode.LoadConst, addConst( IvyData(keyValueAttr.name) ));
							++stackItemsCount;

							// Compile value expression (it should put result value on the stack)
							keyValueAttr.value.accept(this);
							++stackItemsCount;

							++argCount;
							argsSet[keyValueAttr.name] = true;
							attrRange.popFront();
						}

						// Add instruction to load value that consists of number of pairs in block and type of block
						size_t blockHeader = ( argCount << _stackBlockHeaderSizeOffset ) + DirAttrKind.NamedAttr;
						addInstr(OpCode.LoadConst, addConst( IvyData(blockHeader) ));
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
							// TODO: Just skip positional args that has no default value - fix it in the future!
							exprAttrDefs.popFront();
						}

						// Add instruction to load value that consists of number of positional arguments in block and type of block
						size_t blockHeader = ( argCount << _stackBlockHeaderSizeOffset ) + DirAttrKind.ExprAttr;
						addInstr(OpCode.LoadConst, addConst( IvyData(blockHeader) ));
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
						DirAttrsBlock kwdDef = dirAttrBlocks.front;
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

			// Add instruction to load directive object from context by name
			addInstr(OpCode.LoadName, addConst( IvyData(node.name) ));

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
		addInstr(OpCode.LoadConst, addConst( IvyData(node.data) ));
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
			IvyData emptyArray = IvyData[].init;
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
				addInstr(OpCode.PopTop); // For each item except last drop result
			}
		}
	}

	void _visit(IMixedBlockStatement node)
	{
		if( !node )
			loger.error( "Mixed block statement node is null!" );

		IvyData emptyArray = IvyData[].init;
		addInstr(OpCode.LoadConst, addConst(emptyArray));

		auto stmtRange = node[];
		while( !stmtRange.empty )
		{
			stmtRange.front.accept(this);
			stmtRange.popFront();

			addInstr(OpCode.Append); // Append result to result array
		}
	}

	// Runs main compiler phase starting from main module
	void run(string moduleName)
	{
		// Add core directives set:
		_symbolsCollector.enterModuleScope(moduleName);
		enterNewModuleCodeObject(moduleName);
		_moduleRepo.getModuleTree(moduleName).accept(this);
		_clearTemporaries();
	}

	void clearCache()
	{
		// Clear dependency objects
		_symbolsCollector.clearCache();
		_moduleObjCache.clearCache();

		_clearTemporaries();
	}

	void _clearTemporaries()
	{
		_moduleRepo.clearCache();
		_moduleConstHashes.clear();
		_jumpTableStack.length = 0;
		_codeObjStack.length = 0;
	}
}