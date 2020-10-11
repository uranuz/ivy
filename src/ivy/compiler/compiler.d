/// Module implements compilation of Ivy abstract syntax tree into bytecode
module ivy.compiler.compiler;

// If IvyTotalDebug is defined then enable compiler debug
version(IvyTotalDebug) version = IvyCompilerDebug;

import ivy.ast.iface.visitor: AbstractNodeVisitor;

enum JumpKind
{
	Break = 1,
	Continue = 0
}

class ByteCodeCompiler: AbstractNodeVisitor
{
	import ivy.ast.iface;
	import ivy.ast.consts: LiteralType, Operator;

	import ivy.bytecode: Instruction, OpCode;

	import ivy.types.data: IvyData, NodeEscapeState;

	import ivy.types.code_object: CodeObject;
	import ivy.types.module_object: ModuleObject;

	import ivy.types.symbol.iface: IIvySymbol, ICallableSymbol;
	import ivy.types.symbol.directive: DirectiveSymbol;
	import ivy.types.symbol.module_: ModuleSymbol;
	import ivy.types.symbol.dir_attr: DirAttr;

	import ivy.compiler.module_repository: CompilerModuleRepository;
	import ivy.compiler.symbol_table: SymbolTableFrame;
	import ivy.compiler.directive.factory: DirectiveCompilerFactory;
	import ivy.compiler.node_visit_mixin: NodeVisitMixin;
	import ivy.compiler.errors: IvyCompilerException;
	import ivy.compiler.symbol_collector: CompilerSymbolsCollector;
	import ivy.interpreter.module_objects_cache: ModuleObjectsCache;
	import ivy.interpreter.directive.factory: InterpreterDirectiveFactory;
	import ivy.log: LogInfo, LogProxyImpl, LogInfoType;
	
public:
	import std.typecons: Tuple;
	alias LogerMethod = void delegate(LogInfo);

	static struct JumpTableItem
	{
		JumpKind jumpKind;
		size_t instrIndex;
	}

private:
	// Storage or factory containing compilers for certain directives
	DirectiveCompilerFactory _compilerFactory;

	// Dictionary maps module name to it's root symbol table frame
	public CompilerSymbolsCollector _symbolsCollector;

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
		ModuleObjectsCache moduleObjCache,
		LogerMethod logerMethod = null
	) {
		_logerMethod = logerMethod; // First of all set loger method in order to not miss any log messages

		// Some internal checks goes here...
		this.log.internalAssert(moduleRepo, `Expected module repository`);
		this.log.internalAssert(symbolsCollector, `Expected symbols collector`);
		this.log.internalAssert(compilerFactory, `Expected compiler factory`);
		this.log.internalAssert(moduleObjCache, `Expected module objects cache`);

		_moduleRepo = moduleRepo;
		_symbolsCollector = symbolsCollector;
		_compilerFactory = compilerFactory;
		_moduleObjCache = moduleObjCache;
	}

	mixin NodeVisitMixin!();

	version(IvyCompilerDebug)
		enum isDebugMode = true;
	else
		enum isDebugMode = false;

	static struct LogerProxy {
		mixin LogProxyImpl!(IvyCompilerException, isDebugMode);
		ByteCodeCompiler compiler;

		string sendLogInfo(LogInfoType logInfoType, string msg)
		{
			import ivy.log.utils: getShortFuncName;

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

	LogerProxy log(string func = __FUNCTION__, string file = __FILE__, int line = __LINE__)	{
		return LogerProxy(func, file, line, this);
	}

	/++
		Run compilation starting from specified entry-point module
	+/
	void run(string moduleName)
	{
		getOrCompileModule(moduleName);
		_clearTemporaries();
	}

	ModuleObject getOrCompileModule(string moduleName)
	{
		if( ModuleObject moduleObject = _moduleObjCache.get(moduleName) ) {
			return moduleObject;
		}
		log.write(`Compiled module not found in cache, so try to compile`);
		IvyNode moduleNode = _moduleRepo.getModuleTree(moduleName);

		log.write(`Entering module scope`);
		ModuleSymbol symb = _symbolsCollector.enterModuleScope(moduleName);

		log.write(`Entering new module object`);
		enterNewModuleObject(symb);
		
		scope(exit)
		{
			this.exitCodeObject();
			log.write(`Exited module object`);
			log.write(`Exiting compiler scopes`);
			_symbolsCollector.exitScope();
			log.write(`Exited module scope`);
		}
		
		log.write(`Starting compiling module AST: ` ~ moduleName);
		moduleNode.accept(this);
		log.write(`Finished compiling module AST`);
		return _moduleObjCache.get(moduleName);
	}

	void enterNewModuleObject(ModuleSymbol symbol)
	{
		log.internalAssert(symbol !is null, `Expected module symbol`);
		if( _moduleObjCache.get(symbol.name) )
			log.error(`Cannot create new module object "`, symbol.name, `", because it already exists!`);

		ModuleObject moduleObject = new ModuleObject(symbol);
		_moduleObjCache.add(moduleObject);

		_codeObjStack ~= moduleObject.mainCodeObject;
	}

	size_t enterNewCodeObject(DirectiveSymbol symbol)
	{
		CodeObject codeObject = new CodeObject(symbol, this.currentModule());
		_codeObjStack ~= codeObject;
		return this.addConst( IvyData(codeObject) );
	}

	void exitCodeObject()
	{
		import std.range: empty, popBack;
		log.internalAssert(!_codeObjStack.empty, "Cannot exit frame, because compiler code object stack is empty!");

		_codeObjStack.popBack();
	}

	ModuleObject currentModule() @property {
		return this.currentCodeObject.moduleObject;
	}

	CodeObject currentCodeObject() @property
	{
		import std.range: empty, back;
		log.internalAssert(!this._codeObjStack.empty, "Compiler code object stack is empty!");

		return this._codeObjStack.back;
	}

	IIvySymbol symbolLookup(string name) {
		return _symbolsCollector.symbolLookup(name);
	}

	size_t addInstr(Instruction instr) {
		return this.currentCodeObject.addInstr(instr, _currentLocation.lineIndex);
	}

	size_t addInstr(OpCode opcode) {
		return addInstr(Instruction(opcode));
	}

	size_t addInstr(OpCode opcode, size_t arg) {
		return addInstr(Instruction(opcode, arg));
	}

	void setInstrArg(size_t index, size_t arg) {
		this.currentCodeObject.setInstrArg(index, arg);
	}

	size_t getInstrCount() {
		return this.currentCodeObject.getInstrCount();
	}

	size_t addConst(IvyData value)
	{
		import std.digest.md: md5Of;
		ModuleObject mod = this.currentModule;
		log.internalAssert(mod !is null, `Cannot add const to current module`);
		if( mod.name !in _moduleConstHashes ) {
			_moduleConstHashes[mod.name] = null;
		}
		ubyte[16] valHash = md5Of(value.toString());
		if( valHash !in _moduleConstHashes[mod.name] ) {
			_moduleConstHashes[mod.name][valHash] = null;
		}
		foreach( size_t constIndex; _moduleConstHashes[mod.name][valHash] )
		{
			if( mod._consts[constIndex] == value ) {
				return constIndex; // Constant is already here. Return it's index
			}
		}
		size_t newIndex = mod.addConst(value);
		_moduleConstHashes[mod.name][valHash] ~= newIndex;
		return newIndex;
	}

	void clearCache()
	{
		_clearTemporaries();

		// Clear dependency objects
		_symbolsCollector.clearCache();
		_moduleObjCache.clearCache();
	}

	void _clearTemporaries()
	{
		_moduleRepo.clearCache();
		_moduleConstHashes.clear();
		_jumpTableStack.length = 0;
		_codeObjStack.length = 0;
	}


	void _visit(IvyNode node) { assert(0); }

	//Expressions
	void _visit(IExpression node) { visit( cast(IvyNode) node ); }

	void _visit(ILiteralExpression node)
	{
		size_t constIndex;
		switch( node.literalType )
		{
			case LiteralType.Undef:
				constIndex = addConst( IvyData() );
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
						log.error("Expected assoc array pair!");

					addInstr(OpCode.LoadConst, addConst( IvyData(aaPair.key) ));

					if( !aaPair.value )
						log.error("Expected assoc array value!");
					aaPair.value.accept(this);

					++aaLen;
				}
				addInstr(OpCode.MakeAssocArray, aaLen);
				return;
			default:
				log.internalAssert(false, "Expected literal expression node!");
				break;
		}

		addInstr(OpCode.LoadConst, constIndex);
	}

	void _visit(INameExpression node)
	{
		import std.array: split;
		import std.range: empty, front, popFront;

		string[] varPath = split(node.name, '.');

		// Load variable from execution frame...
		addInstr(OpCode.LoadName, addConst( IvyData(varPath.front) ));
		varPath.popFront(); // Drop var name

		// If there is more parts in var path then treat them as attr getters
		while( !varPath.empty )
		{
			// Load attr name const...
			addInstr(OpCode.LoadConst, addConst( IvyData(varPath.front) ));
			varPath.popFront(); // Drop attr name...

			addInstr(OpCode.LoadAttr);
		}
	}

	void _visit(IOperatorExpression node) { visit( cast(IExpression) node ); }
	void _visit(IUnaryExpression node)
	{
		log.internalAssert( node.expr, "Expression expected!" );
		node.expr.accept(this);

		OpCode opcode;
		switch( node.operatorIndex )
		{
			case Operator.UnaryPlus: opcode = OpCode.UnaryPlus; break;
			case Operator.UnaryMin: opcode = OpCode.UnaryMin; break;
			case Operator.Not: opcode = OpCode.UnaryNot; break;
			default:
				log.internalAssert( false, "Unexpected unary operator type!" );
		}

		addInstr(opcode);
	}
	void _visit(IBinaryExpression node)
	{
		import std.range: back;
		import std.conv: to;

		// Generate code that evaluates left and right parts of binary expression and get result on the stack
		log.internalAssert( node.leftExpr, "Left expr expected!" );
		log.internalAssert( node.rightExpr, "Right expr expected!" );

		switch( node.operatorIndex )
		{
			case Operator.And, Operator.Or:
			{
				// Instructions to evaluate left value...
				node.leftExpr.accept(this);
				// Add instruction to jump after the right tree if it shouldn't be evaluated
				// If operator is And then we shouldn't evaluate right tree if result is False
				// If operator is Or then we shouldn't evaluate right tree if result if True
				size_t jumpInstrIndex = addInstr(
					node.operatorIndex == Operator.And? OpCode.JumpIfFalseOrPop: OpCode.JumpIfTrueOrPop
				);

				// Instructions to evaluate all right tree of And/ Or...
				node.rightExpr.accept(this);

				// Set possition where to jump if right tree evaluation needs to be skipped
				setInstrArg(jumpInstrIndex, currentCodeObject.instrs.length);
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
				log.internalAssert( false, "Unexpected binary operator type: ", (cast(Operator) node.operatorIndex) );
		}

		addInstr(opcode);
	}

	void _visit(IAssocArrayPair node) { visit( cast(IExpression) node ); }

	//Statements
	void _visit(IStatement node) { visit( cast(IvyNode) node ); }
	void _visit(IKeyValueAttribute node) { visit( cast(IvyNode) node ); }

	void _visit(IDirectiveStatement node)
	{
		import ivy.types.call_spec: CallSpec;

		import std.range: empty, front, popFront;

		if( auto comp = this._compilerFactory.get(node.name) ) {
			comp.compile(node, this);
			return;
		}
		auto attrRange = node[];

		ICallableSymbol symb = cast(ICallableSymbol) this.symbolLookup(node.name);
		log.internalAssert(symb, `Expected callable symbol`);

		DirAttr[] attrs = symb.attrs[]; // Getting slice of list

		bool[string] attrsSet;

		size_t posAttrCount = 0;
		size_t kwAttrCount = 0;

		while( !attrRange.empty )
		{
			if( IKeyValueAttribute keyValueAttr = cast(IKeyValueAttribute) attrRange.front )
			{
				log.internalAssert(posAttrCount == 0, `Keyword attributes cannot be before positional in directive call`);
				DirAttr attr = symb.getAttr(keyValueAttr.name);

				if( attr.name in attrsSet )
					log.error(`Duplicate named attribute "` ~ attr.name ~ `" detected`);

				// Add name of named argument into stack
				addInstr(OpCode.LoadConst, addConst( IvyData(attr.name) ));

				// Compile value expression (it should put result value on the stack)
				keyValueAttr.value.accept(this);

				attrsSet[attr.name] = true;
				attrRange.popFront();
				++kwAttrCount;
			}
			else if( IExpression exprAttr = cast(IExpression) attrRange.front )
			{
				log.internalAssert(!attrs.empty, `No more attrs expected for directive call`);

				attrsSet[attrs.front.name] = true;
				attrs.popFront();

				exprAttr.accept(this);
				attrRange.popFront();

				++posAttrCount;
			}
			else
			{
				log.error(`Expected key-value pair or expression as directive attribute. Maybe there is missing semicolon ;`);
			}
		}

		if( kwAttrCount > 0 )
		{
			// Put instruction to add keyword attribute if exists
			addInstr(OpCode.MakeAssocArray, kwAttrCount);
		}

		// Add instruction to load directive object from context by name
		addInstr(OpCode.LoadName, addConst( IvyData(node.name) ));

		// After all preparations add instruction to call directive
		addInstr(OpCode.RunCallable, CallSpec(posAttrCount, kwAttrCount > 0).encode());
		if( symb.bodyAttrs.isNoscope ) {
			addInstr(OpCode.MarkForEscape, NodeEscapeState.Safe);
		}
	}

	void _visit(IDataFragmentStatement node)
	{
		// Nothing special. Just store this piece of data into table and output then
		addInstr(OpCode.LoadConst, addConst( IvyData(node.data) ));
	}

	void _visit(ICompoundStatement node) {
		log.internalAssert( false, `Shouldn't fall into this!` );
	}

	void _visit(ICodeBlockStatement node)
	{
		if( !node )
			log.error( "Code block statement node is null!" );

		if( node.isListBlock ) {
			addInstr(OpCode.MakeArray);
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
			log.error( "Mixed block statement node is null!" );

		addInstr(OpCode.MakeArray);

		auto stmtRange = node[];
		while( !stmtRange.empty )
		{
			stmtRange.front.accept(this);
			stmtRange.popFront();

			addInstr(OpCode.Append); // Append result to result array
		}
	}

}