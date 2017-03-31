module ivy.interpreter;

import ivy.node, ivy.node_visitor, ivy.common, ivy.expression;

import ivy.interpreter_data;

// If IvyTotalDebug is defined then enable parser debug
version(IvyTotalDebug) version = IvyInterpreterDebug;

alias TDataNode = DataNode!string;

class IvyInterpretException: IvyException
{
public:
	@nogc @safe this(string msg, string file = __FILE__, size_t line = __LINE__, Throwable next = null) pure nothrow
	{
		super(msg, file, line, next);
	}

}

void interpretError(string msg, string file = __FILE__, size_t line = __LINE__)
{
	throw new IvyInterpretException(msg, file, line);
}

enum FrameSearchMode { get, tryGet, set, setWithParents };

class ExecutionFrame
{
//private:
	CallableObject _callableObj;

	/*
		Type of _dataDict should be Undef or Null if directive call or something that represented
		by this ExecutionFrame haven't it's own data scope and uses parent scope for data.
		In other cases _dataDict should be of AssocArray type for storing local variables
	*/
	TDataNode _dataDict;

	ExecutionFrame _moduleFrame;
	
public:
	this(CallableObject callableObj, ExecutionFrame modFrame)
	{
		_callableObj = callableObj;
		_moduleFrame = modFrame;

		TDataNode[string] emptyDict;
		_dataDict = emptyDict;
	}

	this(CallableObject callableObj, ExecutionFrame modFrame, TDataNode dataDict)
	{
		_callableObj = callableObj;
		_moduleFrame = modFrame;
		_dataDict = dataDict;
	}

	TDataNode getValue( string varName )
	{
		TDataNode* nodePtr = findValue!(FrameSearchMode.get)(varName);
		if( nodePtr is null )
			interpretError( "VariableTable: Cannot find variable with name: " ~ varName );
		return *nodePtr;
	}
	
	bool canFindValue( string varName )
	{
		return cast(bool)( findValue!(FrameSearchMode.tryGet)(varName) );
	}
	
	DataNodeType getDataNodeType( string varName )
	{
		TDataNode* nodePtr = findValue!(FrameSearchMode.get)(varName);
		if( nodePtr is null )
			interpretError( "VariableTable: Cannot find variable with name: " ~ varName );
		return nodePtr.type;
	}

	// Basic method used to search symbols in context
	TDataNode* findLocalValue(FrameSearchMode mode)( string varName )
	{
		debug import std.stdio: writeln;
		import std.conv: text;
		import std.range: empty, front, popFront;
		import std.array: split;

		debug writeln( `Call ExecutionFrame.findLocalValue with varName: `, varName );

		if( varName.empty )
			interpretError( "VariableTable: Variable name cannot be empty" );

		TDataNode* nodePtr = &_dataDict;
		if( _dataDict.type != DataNodeType.AssocArray )
		{
			static if( mode == FrameSearchMode.tryGet ) {
				return null;
			} else {
				interpretError( "VariableTable: cannot find variable: " ~ varName ~ " in execution frame, because callable doesn't have it's on scope!" );
			}
		}

		string[] nameSplitted = varName.split('.');
		while( !nameSplitted.empty )
		{
			if( nodePtr.type == DataNodeType.AssocArray )
			{
				debug writeln( `ExecutionFrame.findLocalValue. Search: `, nameSplitted.front, ` in assoc array` );
				if( TDataNode* tmpNodePtr = nameSplitted.front in nodePtr.assocArray )
				{
					debug writeln( `ExecutionFrame.findLocalValue. Node: `, nameSplitted.front, ` found in assoc array` );
					nodePtr = tmpNodePtr;
				}
				else
				{
					debug writeln( `ExecutionFrame.findLocalValue. Node: `, nameSplitted.front, ` NOT found in assoc array` );
					static if( mode == FrameSearchMode.setWithParents ) {
						nodePtr.assocArray[nameSplitted.front] = (TDataNode[string]).init;
						nodePtr = nameSplitted.front in nodePtr.assocArray;
						debug writeln( `ExecutionFrame.findLocalValue(withParents=true). Creating node: `, nameSplitted.front );
					} else static if( mode == FrameSearchMode.set ) {
						if( nameSplitted.length == 1 ) {
							nodePtr.assocArray[nameSplitted.front] = TDataNode.init;
							debug writeln( `ExecutionFrame.findLocalValue. Creating node: `, nameSplitted.front );
							return nameSplitted.front in nodePtr.assocArray;
						} else {
							interpretError( `Cannot set value with name: ` ~ varName ~ `, because parent node: ` ~ nameSplitted.front.text ~ ` not exist!` );
						}
					} else static if( mode == FrameSearchMode.tryGet ) {
						return null;
					} else {
						if( nameSplitted.length == 1 ) {
							return null;
						} else {
							interpretError( `Cannot find value with name: ` ~ varName ~ `, because parent node: ` ~ nameSplitted.front.text ~ ` not exist!` );
						}
						
					}
				}
			}
			else if( nodePtr.type == DataNodeType.ExecutionFrame )
			{
				debug writeln( `ExecutionFrame.findLocalValue. Search: `, nameSplitted.front, ` in execution frame` );
				if( !nodePtr.execFrame )
				{
					static if( mode == FrameSearchMode.tryGet ) {
						return null;
					} else {
						interpretError( `Cannot find value, because execution frame is null!!!` );
					}
				}

				if( nodePtr.execFrame._dataDict.type != DataNodeType.AssocArray )
				{
					static if( mode == FrameSearchMode.tryGet ) {
						return null;
					} else {
						interpretError( `Cannot find value, because execution frame data dict is not of assoc array type!!!` );
					}
				}
					
				nodePtr = nameSplitted.front in nodePtr.execFrame._dataDict.assocArray;
				debug writeln( `ExecutionFrame.findLocalValue. Node: `, nameSplitted.front, (nodePtr ? ` found` : ` NOT found`) ,` in execution frame` );
			}
			else
			{
				debug writeln( `ExecutionFrame.findLocalValue. Attempt to search: `, nameSplitted.front, `, but current node is not of dict-like type` );
				return null;
			}
			
			nameSplitted.popFront();
			if( nodePtr is null )
			{
				debug writeln( `ExecutionFrame.findlocalValue. Got empty node at end of iteration` );
				return null;
			}
		}

		return nodePtr;
	}

	TDataNode* findValue(FrameSearchMode mode)(string varName)
	{
		debug import std.stdio: writeln;
		debug writeln( `Call ExecutionFrame.findLocalValue with varName: `, varName );

		TDataNode* nodePtr = findLocalValue!(mode)(varName);
		if( nodePtr )
			return nodePtr;
		
		debug writeln( `Call ExecutionFrame.findLocalValue. No varName: `, varName, ` in exec frame. Try to find in module frame` );

		if( _moduleFrame )
			return _moduleFrame.findLocalValue!(mode)(varName);

		debug writeln( `Call ExecutionFrame.findLocalValue. Cannot find: `, varName, ` in module exec frame. Module frame is null!` );
		
		return null;
	}

	void setValue( string varName, TDataNode value )
	{
		debug import std.stdio: writeln;
		debug writeln( `Call ExecutionFrame.setValue with varName: `, varName, ` and value: `, value );

		TDataNode* valuePtr = findValue!(FrameSearchMode.set)(varName);
		if( valuePtr is null )
			interpretError( `Failed to set variable: ` ~ varName );

		*valuePtr = value;
	}

	void setValueWithParents( string varName, TDataNode value )
	{
		debug import std.stdio: writeln;
		debug writeln( `Call ExecutionFrame.setValueWithParents with varName: `, varName, ` and value: `, value );
		
		TDataNode* valuePtr = findValue!(FrameSearchMode.setWithParents)(varName);
		if( valuePtr is null )
			interpretError( `Failed to set variable: ` ~ varName );

		*valuePtr = value;
	}

	bool hasOwnScope() @property
	{
		return _dataDict.type == DataNodeType.AssocArray;
	}
	
	CallableKind callableKind() @property
	{
		return _callableObj._kind;
	}

	override string toString()
	{
		return `<Exec frame for dir object "` ~ _callableObj._name ~ `">`;
	}

}

mixin template BaseNativeDirInterpreterImpl(string symbolName)
{
	import ivy.compiler: DirectiveDefinitionSymbol;

	private __gshared DirAttrsBlock!(false)[] _interpAttrBlocks;
	private __gshared DirectiveDefinitionSymbol _symbol;
	
	shared static this()
	{
		import std.algorithm: map;
		import std.array: array;

		// Get directive description for interpreter
		_interpAttrBlocks = _compilerAttrBlocks.map!( a => a.toInterpreterBlock() ).array;
		// Create symbol for compiler
		_symbol = new DirectiveDefinitionSymbol(symbolName, _compilerAttrBlocks);
	}

	override DirAttrsBlock!(false)[] attrBlocks() @property {
		return _interpAttrBlocks;
	}

	override Symbol compilerSymbol() @property {
		return _symbol;
	}
}

class RenderDirInterpreter: INativeDirectiveInterpreter
{
	override void interpret(Interpreter interp)
	{
		import std.array: appender;
		TDataNode result = interp.getValue("__result__");

		auto renderedResult = appender!string();
		renderDataNode!(DataRenderType.Text)(result, renderedResult);
		interp._stack ~= TDataNode(renderedResult.data);
	}

	private __gshared DirAttrsBlock!(true)[] _compilerAttrBlocks;
	shared static this()
	{
		_compilerAttrBlocks = [
			DirAttrsBlock!true(DirAttrKind.NamedAttr, [
				"__result__": DirValueAttr!(true)("__result__", "any")
			]),
			DirAttrsBlock!true(DirAttrKind.BodyAttr)
		];
	}

	mixin BaseNativeDirInterpreterImpl!("__render__");
}

class IntCtorDirInterpreter: INativeDirectiveInterpreter
{
	override void interpret(Interpreter interp)
	{
		import std.conv: to;
		TDataNode value = interp.getValue("value");
		switch(value.type)
		{
			case DataNodeType.Boolean:
				interp._stack ~= TDataNode(value.boolean? 1: 0);
				break;
			case DataNodeType.Integer:
				interp._stack ~= value;
				break;
			case DataNodeType.String:
				interp._stack ~= TDataNode(value.str.to!long);
				break;
			default:
				interp.loger.error(`Cannot convert value of type: `, value.type, ` to integer`);
				break;
		}
	}

	private __gshared DirAttrsBlock!(true)[] _compilerAttrBlocks = [
		DirAttrsBlock!true( DirAttrKind.ExprAttr, [
			DirValueAttr!(true)("value", "any")
		]),
		DirAttrsBlock!true(DirAttrKind.BodyAttr)
	];

	mixin BaseNativeDirInterpreterImpl!("int");
}

class FloatCtorDirInterpreter: INativeDirectiveInterpreter
{
	override void interpret(Interpreter interp)
	{
		import std.conv: to;
		TDataNode value = interp.getValue("value");
		switch(value.type)
		{
			case DataNodeType.Boolean:
				interp._stack ~= TDataNode(value.boolean? 1.0: 0.0);
				break;
			case DataNodeType.Integer:
				interp._stack ~= TDataNode(value.integer.to!double);
				break;
			case DataNodeType.Floating:
				interp._stack ~= value;
				break;
			case DataNodeType.String:
				interp._stack ~= TDataNode(value.str.to!double);
				break;
			default:
				interp.loger.error(`Cannot convert value of type: `, value.type, ` to integer`);
				break;
		}
	}

	private __gshared DirAttrsBlock!(true)[] _compilerAttrBlocks = [
		DirAttrsBlock!true(DirAttrKind.ExprAttr, [
			DirValueAttr!(true)("value", "any")
		]),
		DirAttrsBlock!true(DirAttrKind.BodyAttr)
	];

	mixin BaseNativeDirInterpreterImpl!("float");
}

class HasDirInterpreter: INativeDirectiveInterpreter
{
	override void interpret(Interpreter interp)
	{
		import std.conv: to;
		TDataNode collection = interp.getValue("collection");
		TDataNode key = interp.getValue("key");
		switch(collection.type)
		{
			case DataNodeType.AssocArray:
				if( key.type != DataNodeType.String ) {
					interp.loger.error(`Expected string as second "has" directive attribute, but got: `, key.type);
				}
				interp._stack ~= TDataNode(cast(bool)(key.str in collection));
				break;
			default:
				interp.loger.error(`Expected assoc array as first "has" directive attribute, but got: `, collection.type);
				break;
		}
	}

	private __gshared DirAttrsBlock!(true)[] _compilerAttrBlocks = [
		DirAttrsBlock!true(DirAttrKind.ExprAttr, [
			DirValueAttr!(true)("collection", "any"),
			DirValueAttr!(true)("key", "any")
		]),
		DirAttrsBlock!true(DirAttrKind.BodyAttr)
	];

	mixin BaseNativeDirInterpreterImpl!("has");
}

class TypeStrDirInterpreter: INativeDirectiveInterpreter
{
	override void interpret(Interpreter interp)
	{
		import std.conv: text;
		TDataNode value = interp.getValue("value");
		interp._stack ~= TDataNode(value.type.text);
	}

	private __gshared DirAttrsBlock!(true)[] _compilerAttrBlocks = [
		DirAttrsBlock!true(DirAttrKind.ExprAttr, [
			DirValueAttr!(true)("value", "any")
		]),
		DirAttrsBlock!true(DirAttrKind.BodyAttr)
	];

	mixin BaseNativeDirInterpreterImpl!("typestr");
}

import ivy.bytecode;

class Interpreter
{
public:
	alias String = string;
	alias TDataNode = DataNode!String;
	alias LogerMethod = void delegate(LogInfo);

	// Stack used to store temporary data during execution.
	// Results of execution of instructions are plcaed there too...
	TDataNode[] _stack;

	// Stack of execution frames with directives or modules local data
	ExecutionFrame[] _frameStack;

	// Global execution frame used for some global built-in data
	ExecutionFrame _globalFrame;

	// Storage for execition frames of imported modules
	ExecutionFrame[string] _moduleFrames;

	// Storage for bytecode code and initial constant data for modules
	ModuleObject[string] _moduleObjects;

	// Loger method for used to send error and debug messages
	LogerMethod _logerMethod;

	this(ModuleObject[string] moduleObjects, string mainModuleName, TDataNode dataDict, LogerMethod logerMethod = null)
	{
		_logerMethod = logerMethod;
		_moduleObjects = moduleObjects;
		loger.internalAssert(mainModuleName in _moduleObjects, `Cannot get main module from module objects!`);

		loger.write(`Iterpreter ctor: passed dataDict: `, dataDict);

		CallableObject rootCallableObj = new CallableObject;
		rootCallableObj._codeObj = _moduleObjects[mainModuleName].mainCodeObject;
		rootCallableObj._kind = CallableKind.Module;
		rootCallableObj._name = "__main__";

		_globalFrame = new ExecutionFrame(null, null);
		loger.write(`Iterpreter ctor 2: _globalFrame._dataDict: `, _globalFrame._dataDict);

		newFrame(rootCallableObj, null, dataDict); // Create entry point module frame
	}

	private void _addNativeDirInterp(string name, INativeDirectiveInterpreter dirInterp)
	{
		loger.internalAssert(name.length && dirInterp, `Directive name is empty or dirInterp is null!`);

		// Add custom native directive interpreters to global scope
		CallableObject dirCallable = new CallableObject();
		dirCallable._name = name;
		dirCallable._dirInterp = dirInterp;
		_globalFrame.setValue(name, TDataNode(dirCallable));
	}

	// Method used to set custom global directive interpreters
	void addDirInterpreters(INativeDirectiveInterpreter[string] dirInterps)
	{
		foreach( name, dirInterp; dirInterps ) {
			_addNativeDirInterp(name, dirInterp);
		}
	}

	version(IvyInterpreterDebug)
		enum isDebugMode = true;
	else
		enum isDebugMode = false;

	static struct LogerProxy {
		mixin LogerProxyImpl!(IvyInterpretException, isDebugMode);
		Interpreter interp;

		void sendLogInfo(LogInfoType logInfoType, string msg) {
			if( interp._logerMethod is null ) {
				return; // There is no loger method, so get out of here
			}

			interp._logerMethod(LogInfo(msg, logInfoType, getShortFuncName(func), file, line));
		}
	}

	LogerProxy loger(string func = __FUNCTION__, string file = __FILE__, int line = __LINE__)	{
		return LogerProxy(func, file, line, this);
	}

	/// Method for setting interpreter's loger method
	void logerMethod(LogerMethod method) @property {
		_logerMethod = method;
	}

	void newFrame(CallableObject callableObj, ExecutionFrame modFrame)
	{
		_frameStack ~= new ExecutionFrame(callableObj, modFrame);
		loger.write(`Enter new execution frame for callable: `, callableObj._name, ` without dataDict`);
	}

	void newFrame(CallableObject callableObj, ExecutionFrame modFrame, TDataNode dataDict)
	{
		_frameStack ~= new ExecutionFrame(callableObj, modFrame, dataDict);
		loger.write(`Enter new execution frame for callable: `, callableObj._name, ` with dataDict: `, dataDict);
	}

	void removeFrame()
	{
		import std.range: back, popBack;
		loger.write(`Exit execution frame for callable: `, _frameStack.back._callableObj._name, ` with dataDict: `, _frameStack.back._dataDict);
		_frameStack.popBack();
		
	}

	ExecutionFrame getModuleFrame(string modName)
	{
		if( modName !in _moduleFrames )
		{
			_moduleFrames[modName] = new ExecutionFrame(null, _globalFrame);
		}

		return _moduleFrames[modName];
	}

	bool canFindValue( string varName )
	{
		return cast(bool)( findValueImpl!(FrameSearchMode.tryGet)(varName, _frameStack[], _globalFrame) );
	}

	TDataNode* findValueImpl(FrameSearchMode mode)( string varName, ExecutionFrame[] frameStackSlice, ExecutionFrame globalFrame )
	{
		import std.range: empty, back, popBack;

		loger.write(`Interpreter.findValueImpl: Starting to search for varName: `, varName);
		loger.internalAssert( !frameStackSlice.empty, `findValueImpl: frameStackSlice is empty` );

		for( ; !frameStackSlice.empty; frameStackSlice.popBack() )
		{
			loger.internalAssert(frameStackSlice.back, `Couldn't find variable value, because execution frame is null!` );
			if( !frameStackSlice.back.hasOwnScope ) {
				loger.write(`Interpreter.findValueImpl: Current level exec frame is noscope. Try find: `, varName, ` in parent`);
				continue; // Let's try to find in parent
			}

			loger.write(`Interpreter.findValueImpl: Trying to search in current execution frame for varName: `, varName);
			if( TDataNode* valuePtr = frameStackSlice.back.findValue!(mode)(varName) ) {
				loger.write(`Interpreter.findValueImpl: varName: `, varName, ` found in current execution frame`);
				return valuePtr;
			} else {
				loger.write(`Interpreter.findValueImpl: varName: `, varName, ` NOT found in current execution frame`);
				break;
			}
		}

		loger.internalAssert(globalFrame, `Couldn't find variable: `, varName, ` value in global frame, because it is null!` );
		loger.internalAssert(globalFrame.hasOwnScope, `Couldn't find variable: `, varName, ` value in global frame, because global frame doesn't have it's own scope!` );

		static if( mode == FrameSearchMode.get || mode == FrameSearchMode.tryGet ) {
			loger.write(`Interpreter.findValueImpl: Trying to search in global frame for varName: `, varName);
			if( TDataNode* valuePtr = globalFrame.findValue!(mode)(varName) ) {
				loger.write(`Interpreter.findValueImpl: varName: `, varName, ` found in global execution frame`);
				return valuePtr;
			}

			loger.write(`Interpreter.findValueImpl: varName: `, varName, ` NOT found in global execution frame`);
		}

		return null;
	}

	TDataNode* findValueLocalImpl(FrameSearchMode mode)( string varName, ExecutionFrame[] frameStackSlice )
	{
		import std.range: empty, back, popBack;

		for( ; !frameStackSlice.empty; frameStackSlice.popBack() )
		{
			loger.internalAssert(frameStackSlice.back, `Couldn't find variable value, because execution frame is null!`);
			if( !frameStackSlice.back.hasOwnScope ) {
				continue; // Let's try to find first parent that have it's own scope
			}

			if( TDataNode* valuePtr = frameStackSlice.back.findLocalValue!(mode)(varName) )
				return valuePtr;
			else
				return null;
		}

		return null;
	}

	void setValueImpl(FrameSearchMode mode)( string varName, TDataNode value, ExecutionFrame[] frameStackSlice, ExecutionFrame globalFrame )
		if( mode == FrameSearchMode.set || mode == FrameSearchMode.setWithParents )
	{
		TDataNode* valuePtr = findValueImpl!(mode)(varName, frameStackSlice[], globalFrame);
		if( valuePtr is null )
			loger.error("Failed to set variable with name: ", varName);
		
		*valuePtr = value;
	}

	TDataNode* findValue(FrameSearchMode mode)( string varName )
	{
		return findValueImpl!(mode)(varName, _frameStack[], _globalFrame);
	}

	TDataNode getValue( string varName )
	{
		TDataNode* valuePtr = findValue!(FrameSearchMode.get)(varName);

		if( valuePtr is null )
		{
			debug {
				import std.stdio: writeln;
				foreach( i, frame; _frameStack[] )
				{
					writeln( `Scope frame lvl `, i, `, _dataDict: `, frame._dataDict );
					if( frame._moduleFrame ) {
						writeln( `Scope frame lvl `, i, `, _moduleFrame._dataDict: `, frame._moduleFrame._dataDict );
					} else {
						writeln( `Scope frame lvl `, i, `, _moduleFrame is null` );
					}
				}
			}

			loger.error("Undefined variable with name '", varName, "'");
		}

		return *valuePtr;
	}

	void setValue( string varName, TDataNode value )
	{
		TDataNode* valuePtr = findValue!(FrameSearchMode.set)(varName);
		if( valuePtr is null )
			loger.error(`Cannot set variable "`, varName, `", because cannot find it. Use setLocalValue to decare new variable!`);

		*valuePtr = value;
	}

	void setValueWithParents( string varName, TDataNode value )
	{
		TDataNode* valuePtr = findValue!(FrameSearchMode.setWithParents)(varName);
		if( valuePtr is null )
			loger.error(`Cannot set variable "`, varName, `", because cannot find it. Use setLocalValueWithParents to decare new variable!`);

		*valuePtr = value;
	}

	void setLocalValue( string varName, TDataNode value )
	{
		TDataNode* valuePtr = findValueLocalImpl!(FrameSearchMode.set)( varName, _frameStack[] );
		
		if( valuePtr is null )
			loger.error(`Failed to set local variable: `, varName);

		*valuePtr = value;
	}

	void setLocalValueWithParents( string varName, TDataNode value )
	{
		TDataNode* valuePtr = findValueLocalImpl!(FrameSearchMode.setWithParents)( varName, _frameStack[] );
		
		if( valuePtr is null )
			loger.error(`Failed to set local variable: `, varName);

		*valuePtr = value;
	}

	TDataNode getModuleConst( size_t index )
	{
		import std.range: back, empty;
		import std.conv: text;
		loger.internalAssert(!_frameStack.empty, `_frameStack is empty`);
		loger.internalAssert(_frameStack.back, `_frameStack.back is null`);
		loger.internalAssert(_frameStack.back._callableObj, `_frameStack.back._callableObj is null`);
		loger.internalAssert(_frameStack.back._callableObj._codeObj, `_frameStack.back._callableObj._codeObj is null`);
		loger.internalAssert(_frameStack.back._callableObj._codeObj._moduleObj, `_frameStack.back._callableObj._codeObj._moduleObj is null`);

		return _frameStack.back._callableObj._codeObj._moduleObj.getConst(index);
	}

	TDataNode getModuleConstCopy( size_t index )
	{
		return deeperCopy( getModuleConst(index) );
	}

	void execLoop()
	{
		import std.range: empty, back, popBack;
		import std.conv: to, text;
		import std.meta: AliasSeq;
		import std.typecons: tuple;

		loger.internalAssert(!_frameStack.empty, `_frameStack is empty`);
		loger.internalAssert(_frameStack.back, `_frameStack.back is null`);
		loger.internalAssert(_frameStack.back._callableObj, `_frameStack.back._callableObj is null`);
		loger.internalAssert(_frameStack.back._callableObj._codeObj, `_frameStack.back._callableObj._codeObj is null`);

		auto codeRange = _frameStack.back._callableObj._codeObj._instrs[];
		size_t pk = 0;

		execution_loop:
		for( ; pk < codeRange.length; )
		{
			Instruction instr = codeRange[pk];
			switch( instr.opcode )
			{
				// Base arithmetic operations execution
				case OpCode.Add, OpCode.Sub, OpCode.Mul, OpCode.Div, OpCode.Mod:
				{
					loger.internalAssert(!_stack.empty, "Cannot execute ", instr.opcode, " instruction. Expected right operand, but exec stack is empty!");
					// Right value was evaluated last so it goes first in the stack
					TDataNode rightVal = _stack.back;
					_stack.popBack();

					loger.internalAssert(!_stack.empty, "Cannot execute " ~ instr.opcode.to!string ~ " instruction. Expected left operand, but exec stack is empty!" );
					TDataNode leftVal = _stack.back;
					loger.internalAssert( ( leftVal.type == DataNodeType.Integer || leftVal.type == DataNodeType.Floating ) && leftVal.type == rightVal.type,
						`Left and right values of arithmetic operation must have the same integer or floating type!` );

					arithm_op_switch:
					switch( instr.opcode )
					{
						foreach( arithmOp; AliasSeq!(
							tuple(OpCode.Add, "+"),
							tuple(OpCode.Sub, "-"),
							tuple(OpCode.Mul, "*"),
							tuple(OpCode.Div, "/"),
							tuple(OpCode.Mod, "%")) )
						{
							case arithmOp[0]: {
								if( leftVal.type == DataNodeType.Integer )
								{
									mixin( `_stack.back = leftVal.integer ` ~ arithmOp[1] ~ ` rightVal.integer;` );
								}
								else
								{
									mixin( `_stack.back = leftVal.floating ` ~ arithmOp[1] ~ ` rightVal.floating;` );
								}
								break arithm_op_switch;
							}
						}
						default:
							loger.internalAssert(false, `This should never happen!`);
					}
					break;
				}

				// Logical binary operations
				case OpCode.And, OpCode.Or, OpCode.Xor:
				{
					loger.internalAssert(!_stack.empty, "Cannot execute ", instr.opcode, " instruction. Expected right operand, but exec stack is empty!" );
					TDataNode rightVal = _stack.back;
					_stack.popBack();

					loger.internalAssert(!_stack.empty, "Cannot execute ", instr.opcode.to!string, " instruction. Expected left operand, but exec stack is empty!");
					TDataNode leftVal = _stack.back;
					loger.internalAssert(leftVal.type == DataNodeType.Boolean && leftVal.type == rightVal.type,
						`Left and right values of arithmetic operation must have boolean type!` );

					logical_op_switch:
					switch( instr.opcode )
					{
						foreach( logicalOp; AliasSeq!(
							tuple(OpCode.And, "&&"),
							tuple(OpCode.Or, "||"),
							tuple(OpCode.Xor, "^^")) )
						{
							case logicalOp[0]: {
								mixin( `_stack.back = leftVal.boolean ` ~ logicalOp[1] ~ ` rightVal.boolean;` );
								break logical_op_switch;
							}
						}
						default:
							loger.internalAssert(false, `This should never happen!`);
					}
					break;
				}

				// Comparision operations
				case OpCode.LT, OpCode.GT, OpCode.LTEqual, OpCode.GTEqual:
				{
					import std.conv: to;
					loger.internalAssert(!_stack.empty, "Cannot execute ", instr.opcode, " instruction. Expected right operand, but exec stack is empty!");
					// Right value was evaluated last so it goes first in the stack
					TDataNode rightVal = _stack.back;
					_stack.popBack();

					loger.internalAssert(!_stack.empty, "Cannot execute ", instr.opcode, " instruction. Expected left operand, but exec stack is empty!");
					TDataNode leftVal = _stack.back;
					loger.internalAssert(leftVal.type == rightVal.type, `Left and right operands of comparision must have the same type`);

					compare_op_switch:
					switch( instr.opcode )
					{
						foreach( compareOp; AliasSeq!(
							tuple(OpCode.LT, "<"),
							tuple(OpCode.GT, ">"),
							tuple(OpCode.LTEqual, "<="),
							tuple(OpCode.GTEqual, ">=")) )
						{
							case compareOp[0]: {
								switch( leftVal.type )
								{
									case DataNodeType.Undef, DataNodeType.Null:
										// Undef and Null are not less or equal to something
										_stack.back = TDataNode(false);
										break;
									case DataNodeType.Integer:
										mixin( `_stack.back = leftVal.integer ` ~ compareOp[1] ~ ` rightVal.integer;` );
										break;
									case DataNodeType.Floating:
										mixin( `_stack.back = leftVal.floating ` ~ compareOp[1] ~ ` rightVal.floating;` );
										break;
									case DataNodeType.String:
										mixin( `_stack.back = leftVal.str ` ~ compareOp[1] ~ ` rightVal.str;` );
										break;
									default:
										loger.internalAssert(false, `Less or greater comparision doesn't support type "`, leftVal.type, `" yet!`);
								}
								break compare_op_switch;
							}
						}
						default:
							loger.internalAssert(false, `This should never happen!`);
					}
					break;
				}

				// Shallow equality comparision
				case OpCode.Equal, OpCode.NotEqual:
				{
					loger.internalAssert(!_stack.empty, "Cannot execute Equal instruction. Expected right operand, but exec stack is empty!");
					// Right value was evaluated last so it goes first in the stack
					TDataNode rightVal = _stack.back;
					_stack.popBack();

					loger.internalAssert(!_stack.empty, "Cannot execute Equal instruction. Expected left operand, but exec stack is empty!");
					TDataNode leftVal = _stack.back;

					if( leftVal.type != rightVal.type )
					{
						_stack.back = TDataNode(instr.opcode == OpCode.NotEqual);
						break;
					}

					cmp_type_switch:
					switch( leftVal.type )
					{
						case DataNodeType.Undef, DataNodeType.Null:
							if( instr.opcode == OpCode.Equal ) {
								_stack.back = TDataNode( leftVal.type == rightVal.type );
							} else {
								_stack.back = TDataNode( leftVal.type != rightVal.type );
							}
							break cmp_type_switch;

						foreach( typeAndField; AliasSeq!(
							tuple(DataNodeType.Boolean, "boolean"),
							tuple(DataNodeType.Integer, "integer"),
							tuple(DataNodeType.Floating, "floating"),
							tuple(DataNodeType.String, "str")) )
						{
							case typeAndField[0]:
								if( instr.opcode == OpCode.Equal ) {
									mixin( `_stack.back = leftVal.` ~ typeAndField[1] ~ ` == rightVal.` ~ typeAndField[1] ~ `;` );
								} else {
									mixin( `_stack.back = leftVal.` ~ typeAndField[1] ~ ` != rightVal.` ~ typeAndField[1] ~ `;` );
								}
								break cmp_type_switch;
						}
						default:
							loger.internalAssert(false, `Equality comparision doesn't support type "`, leftVal.type, `" yet!`);
							break;
					}
					break;
				}

				// Load constant from programme data table into stack
				case OpCode.LoadSubscr:
				{
					import std.utf: toUTFindex, decode;

					loger.write(`OpCode.LoadSubscr. _stack: `, _stack);

					loger.internalAssert(!_stack.empty, "Cannot execute LoadSubscr instruction. Expected index value, but exec stack is empty!");
					TDataNode indexValue = _stack.back;
					_stack.popBack();

					loger.internalAssert(!_stack.empty, "Cannot execute LoadSubscr instruction. Expected aggregate, but exec stack is empty!");
					TDataNode aggr = _stack.back;
					_stack.popBack();
					loger.write(`OpCode.LoadSubscr. aggr: `, aggr);
					loger.write(`OpCode.LoadSubscr. indexValue: `, indexValue);

					loger.internalAssert(aggr.type == DataNodeType.String || aggr.type == DataNodeType.Array || aggr.type == DataNodeType.AssocArray,
						"Cannot execute LoadSubscr instruction. Aggregate value must be string, array or assoc array!");

					switch( aggr.type )
					{
						case DataNodeType.String:
							loger.internalAssert(indexValue.type == DataNodeType.Integer,
								"Cannot execute LoadSubscr instruction. Index value for string aggregate must be integer!");
							
							// Index operation for string in D is little more complicated
							 size_t startIndex = aggr.str.toUTFindex(indexValue.integer); // Get code unit index by index of symbol
							 size_t endIndex = startIndex;
							 aggr.str.decode(endIndex); // decode increases passed index
							 loger.internalAssert(startIndex < aggr.str.length, `String slice start index must be less than str length`);
							 loger.internalAssert(endIndex <= aggr.str.length, `String slice end index must be less or equal to str length`);
							_stack ~= TDataNode( aggr.str[startIndex..endIndex] );
							break;
						case DataNodeType.Array:
							loger.internalAssert(indexValue.type == DataNodeType.Integer,
								"Cannot execute LoadSubscr instruction. Index value for array aggregate must be integer!");
							loger.internalAssert(indexValue.integer < aggr.array.length, `Array index must be less than array length`);
							_stack ~= aggr.array[indexValue.integer];
							break;
						case DataNodeType.AssocArray:
							loger.internalAssert(indexValue.type == DataNodeType.String,
								"Cannot execute LoadSubscr instruction. Index value for assoc array aggregate must be string!");
							loger.internalAssert(indexValue.str in aggr.assocArray, `Assoc array key must be present in assoc array`);
							_stack ~= aggr.assocArray[indexValue.str];
							break;
						default:
							loger.internalAssert(false, `This should never happen`);
					}
					break;
				}

				// Load constant from programme data table into stack
				case OpCode.LoadConst:
				{
					_stack ~= getModuleConst( instr.arg );
					break;
				}

				// Concatenates two arrays or strings and puts result onto stack
				case OpCode.Concat:
				{
					loger.internalAssert(!_stack.empty, "Cannot execute Concat instruction. Expected right operand, but exec stack is empty!");
					TDataNode rightVal = _stack.back;
					_stack.popBack();

					loger.internalAssert(!_stack.empty, "Cannot execute Concat instruction. Expected left operand, but exec stack is empty!");
					TDataNode leftVal = _stack.back;
					loger.internalAssert( ( leftVal.type == DataNodeType.String || leftVal.type == DataNodeType.Array ) && leftVal.type == rightVal.type,
						`Left and right values for concatenation operation must have the same string or array type!`
					);

					if( leftVal.type == DataNodeType.String ) {
						_stack.back = leftVal.str ~ rightVal.str;
					} else {
						_stack.back = leftVal.array ~ rightVal.array;
					}

					break;
				}

				case OpCode.Append:
				{
					loger.write("OpCode.Append _stack: ", _stack);
					loger.internalAssert(!_stack.empty, "Cannot execute Append instruction. Expected right operand, but exec stack is empty!");
					TDataNode rightVal = _stack.back;
					_stack.popBack();

					loger.internalAssert(!_stack.empty, "Cannot execute Append instruction. Expected left operand, but exec stack is empty!");
					TDataNode leftVal = _stack.back;
					_stack.popBack();
					loger.internalAssert(leftVal.type == DataNodeType.Array, "Left operand for Append instruction expected to be array, but got: ", leftVal.type);

					leftVal ~= rightVal;
					_stack ~= leftVal;

					break;
				}

				// Useless unary plus operation
				case OpCode.UnaryPlus:
				{
					loger.internalAssert(!_stack.empty, "Cannot execute UnaryPlus instruction. Operand expected, but exec stack is empty!");
					loger.internalAssert(_stack.back.type == DataNodeType.Integer || _stack.back.type == DataNodeType.Floating,
						`Operand for unary plus operation must have integer or floating type!` );

					// Do nothing for now:)
					break;
				}

				case OpCode.UnaryMin:
				{
					loger.internalAssert(!_stack.empty, "Cannot execute UnaryMin instruction. Operand expected, but exec stack is empty!");
					loger.internalAssert(_stack.back.type == DataNodeType.Integer || _stack.back.type == DataNodeType.Floating,
						`Operand for unary minus operation must have integer or floating type!`);

					if( _stack.back.type == DataNodeType.Integer ) {
						_stack.back = - _stack.back.integer;
					} else {
						_stack.back = - _stack.back.floating;
					}

					break;
				}

				case OpCode.UnaryNot:
				{
					loger.internalAssert(!_stack.empty, "Cannot execute UnaryNot instruction. Operand expected, but exec stack is empty!");
					loger.internalAssert(_stack.back.type == DataNodeType.Boolean, `Operand for unary not operation must have boolean type!`);

					_stack.back = ! _stack.back.boolean;
					break;
				}

				case OpCode.Nop:
				{
					// Doing nothing here... What did you expect? :)
					break;
				}

				// Stores data from stack into context variable
				case OpCode.StoreName:
				{
					loger.write("StoreName _stack: ", _stack);
					loger.internalAssert(!_stack.empty, "Cannot execute StoreName instruction. Expected var value operand, but exec stack is empty!");
					TDataNode varValue = _stack.back;
					_stack.popBack();

					TDataNode varNameNode = getModuleConstCopy( instr.arg );
					loger.internalAssert(varNameNode.type == DataNodeType.String, `Cannot execute StoreName instruction. Variable name const must have string type!`);

					setValue( varNameNode.str, varValue );
					break;
				}

				// Stores data from stack into local context frame variable
				case OpCode.StoreLocalName:
				{
					loger.write("StoreLocalName _stack: ", _stack);
					loger.internalAssert(!_stack.empty, "Cannot execute StoreLocalName instruction. Expected var value operand, but exec stack is empty!");
					TDataNode varValue = _stack.back;
					_stack.popBack();

					TDataNode varNameNode = getModuleConstCopy( instr.arg );
					loger.internalAssert(varNameNode.type == DataNodeType.String, `Cannot execute StoreLocalName instruction. Variable name const must have string type!`);

					setLocalValue( varNameNode.str, varValue );
					break;
				}

				// Loads data from local context frame variable by index of var name in module constants
				case OpCode.LoadName:
				{
					TDataNode varNameNode = getModuleConstCopy( instr.arg );
					loger.internalAssert(varNameNode.type == DataNodeType.String, `Cannot execute LoadName instruction. Variable name operand must have string type!`);

					_stack ~= getValue( varNameNode.str );
					break;
				}

				case OpCode.ImportModule:
				{
					loger.internalAssert(!_stack.empty, "Cannot execute ImportModule instruction. Expected module name operand, but exec stack is empty!");
					loger.internalAssert(_stack.back.type == DataNodeType.String, "Cannot execute ImportModule instruction. Module name operand must be a string!");
					string moduleName = _stack.back.str;
					_stack.popBack();

					loger.write(`ImportModule _moduleObjects: `, _moduleObjects);
					loger.internalAssert(moduleName in _moduleObjects, "Cannot execute ImportModule instruction. No such module object: ", moduleName);

					ExecutionFrame[] baseFrameStack = _frameStack[];

					if( moduleName !in _moduleFrames )
					{
						// Run module here
						ModuleObject modObject = _moduleObjects[moduleName];
						loger.internalAssert(modObject, `Cannot execute ImportModule instruction, because module object "`, moduleName,`" is null!` );
						CodeObject codeObject = modObject.mainCodeObject;
						loger.internalAssert(codeObject, `Cannot execute ImportModule instruction, because main code object for module "`, moduleName, `" is null!` );

						CallableObject callableObj = new CallableObject;
						callableObj._name = moduleName;
						callableObj._kind = CallableKind.Module;
						callableObj._codeObj = codeObject;

						newFrame(callableObj, null); // Create entry point module frame
						_moduleFrames[moduleName] = _frameStack.back; // We need to store module frame into storage

						// Put module frame in frame of the caller
						setValueImpl!(FrameSearchMode.setWithParents)( moduleName, TDataNode(_frameStack.back), baseFrameStack, _globalFrame );

						_stack ~= TDataNode(pk+1);
						codeRange = codeObject._instrs[];
						pk = 0;

						continue execution_loop;
					}
					else
					{
						// If module is already imported then just put reference to it into caller's frame
						setValueImpl!(FrameSearchMode.setWithParents)( moduleName, TDataNode(_moduleFrames[moduleName]), baseFrameStack, _globalFrame );
					}

					break;
				}

				case OpCode.ImportFrom:
				{
					loger.internalAssert(false, "Unimplemented yet!");
					break;
				}

				case OpCode.GetDataRange:
				{
					import std.range: empty, back, popBack;
					import std.algorithm: canFind;
					loger.internalAssert(!_stack.empty, `Expected aggregate type for loop, but empty execution stack found`);
					loger.write(`GetDataRange begin _stack: `, _stack);
					loger.internalAssert(
						[DataNodeType.Array, DataNodeType.AssocArray, DataNodeType.DataNodeRange].canFind(_stack.back.type),
						`Expected array or assoc array as loop aggregate, but got: `, _stack.back.type);

					TDataNode dataRange;
					switch( _stack.back.type )
					{
						case DataNodeType.Array:
						{
							dataRange = new ArrayRange(_stack.back.array);
							break;
						}
						case DataNodeType.AssocArray:
						{
							dataRange = new AssocArrayRange(_stack.back.assocArray);
							break;
						}
						case DataNodeType.DataNodeRange:
						{
							dataRange = _stack.back;
							break;
						}
						default:
							loger.internalAssert(false, `This should never happen!` );
					}
					_stack.popBack(); // Drop aggregate from stack
					_stack ~= dataRange; // Push range onto stack

					break;
				}

				case OpCode.RunLoop:
				{
					loger.write("RunLoop beginning _stack: ", _stack);
					loger.internalAssert(!_stack.empty, `Expected data range, but empty execution stack found` );
					loger.internalAssert(_stack.back.type == DataNodeType.DataNodeRange, `Expected DataNodeRange` );
					auto dataRange = _stack.back.dataRange;
					loger.write("RunLoop dataRange.empty: ", dataRange.empty);
					if( dataRange.empty )
					{
						loger.write("RunLoop. Data range is exaused, so exit loop. _stack is: ", _stack);
						loger.internalAssert(instr.arg < codeRange.length, `Cannot jump after the end of code object`);
						pk = instr.arg;
						_stack.popBack(); // Drop data range from stack as we no longer need it
						break;
					}

					switch( dataRange.aggrType )
					{
						case DataNodeType.Array:
						{
							_stack ~= dataRange.front;
							break;
						}
						case DataNodeType.AssocArray:
						{
							loger.internalAssert(dataRange.front.type == DataNodeType.Array, `Expected array as assoc array key-value pair`);
							TDataNode[] aaPair = dataRange.front.array;
							loger.internalAssert(aaPair.length > 1, `Assoc array pair must have two items`);
							_stack ~= aaPair[0];
							_stack ~= aaPair[1];

							break;
						}
						default:
							loger.internalAssert(false, `Unexpected range aggregate type!`);
					}

					// TODO: For now we just move range forward as take current value from it
					// Maybe should fix it and make it move after loop block finish
					dataRange.popFront();

					loger.write("RunLoop. Iteration init finished. _stack is: ", _stack);
					break;
				}

				case OpCode.Jump:
				{
					loger.internalAssert(instr.arg < codeRange.length, `Cannot jump after the end of code object`);

					pk = instr.arg;
					continue execution_loop;
				}

				case OpCode.JumpIfFalse:
				{
					import std.algorithm: canFind;
					loger.internalAssert(!_stack.empty, `Cannot evaluate logical value, because stack is empty`);
					loger.internalAssert([ DataNodeType.Boolean, DataNodeType.Undef, DataNodeType.Null ].canFind(_stack.back.type),
						`Expected null, undef or boolean in logical context as jump condition`);
					loger.internalAssert(instr.arg < codeRange.length, `Cannot jump after the end of code object`);
					TDataNode condNode = _stack.back;
					_stack.popBack();
					
					if( condNode.type == DataNodeType.Boolean && condNode.boolean )
					{
						break;
					}
					else
					{
						pk = instr.arg;
						continue execution_loop;
					}
				}

				case OpCode.PopTop:
				{
					loger.internalAssert(!_stack.empty, "Cannot pop value from stack, because stack is empty");
					_stack.popBack();
					break;
				}

				// Swaps two top items on the stack 
				case OpCode.SwapTwo:
				{
					loger.internalAssert(_stack.length > 1, "Stack must have at least two items to swap");
					TDataNode tmp = _stack[$-1];
					_stack[$-1] = _stack[$-2];
					_stack[$-2] = tmp;
					break;
				}

				case OpCode.LoadDirective:
				{
					loger.write(`LoadDirective _stack: `, _stack);

					loger.internalAssert(_stack.back.type == DataNodeType.String,
						`Name operand for directive loading instruction should have string type` );
					string varName = _stack.back.str;

					_stack.popBack();

					loger.internalAssert(!_stack.empty, `Expected directive code object, but got empty execution stack!`);
					loger.internalAssert(_stack.back.type == DataNodeType.CodeObject,
						`Code object operand for directive loading instruction should have CodeObject type`);

					CodeObject codeObj = _stack.back.codeObject;
					_stack.popBack(); // Remove code object from stack

					loger.internalAssert(codeObj, `Code object operand for directive loading instruction is null`);
					CallableObject dirObj = new CallableObject;
					dirObj._name = varName;
					dirObj._codeObj = codeObj;

					setLocalValue( varName, TDataNode(dirObj) ); // Put this directive in context
					_stack ~= TDataNode(); // We should return something

					debug {
						import std.stdio: writeln;
						foreach( lvl, frame; _frameStack )
						{
							writeln(`LoadDirective, frameStack lvl `, lvl, ` dataDict: `, frame._dataDict);
							if( frame._moduleFrame ) {
								writeln(`LoadDirective, frameStack lvl `, lvl, ` moduleFrame.dataDict: `, frame._dataDict);
							} else {
								writeln(`LoadDirective, frameStack lvl `, lvl, ` moduleFrame is null`);
							}
						}
					}

					break;
				}

				case OpCode.RunCallable:
				{
					import std.range: empty, popBack, back;

					loger.write("RunCallable stack on init: : ", _stack);

					size_t stackArgCount = instr.arg;
					loger.internalAssert(stackArgCount > 0, "Call must at least have 1 arguments in stack!");
					loger.write("RunCallable stackArgCount: ", stackArgCount );
					loger.internalAssert(stackArgCount <= _stack.length, "Not enough arguments in execution stack");
					loger.write("RunCallable _stack: ", _stack);
					loger.write("RunCallable callable type: ", _stack[ _stack.length - stackArgCount ].type);
					loger.internalAssert(_stack[ _stack.length - stackArgCount ].type == DataNodeType.Callable, `Expected directive object operand in directive call operation`);

					CallableObject callableObj = _stack[ _stack.length - stackArgCount ].callable;
					loger.internalAssert(callableObj, `Callable object is null!` );
					
					DirAttrsBlock!(false)[] attrBlocks = callableObj.attrBlocks;
					loger.write("RunCallable callableObj.attrBlocks: ", attrBlocks);
					loger.internalAssert(attrBlocks[$-1].kind == DirAttrKind.BodyAttr, `Last attr block definition expected to be BodyAttr, but got: `, attrBlocks[$-1].kind);
					bool isNoscope = attrBlocks[$-1].bodyAttr.isNoscope;

					ExecutionFrame moduleFrame;
					if( callableObj._codeObj ) {
						moduleFrame = getModuleFrame( callableObj._codeObj._moduleObj._name );
					} else {
						moduleFrame = getModuleFrame( "__main__" );
					}

					if( isNoscope )
					{
						loger.write("RunCallable creating noscope execution frame...");
						// If directive is noscope we create frame with _dataDict that is Undef
						newFrame( callableObj, moduleFrame, TDataNode() );
					}
					else
					{
						loger.write("RunCallable creating scoped execution frame...");
						newFrame( callableObj, moduleFrame );
					}

					if( stackArgCount > 1 ) // If args count is 1 - it mean that there is no arguments
					{
						size_t blockCounter = 0;
						
						for( size_t i = 0; i < (stackArgCount - 1); )
						{
							loger.internalAssert(!_stack.empty, `Expected integer as arguments block header, but got empty exec stack!`);
							loger.internalAssert(_stack.back.type == DataNodeType.Integer, `Expected integer as arguments block header!`);
							size_t blockArgCount = _stack.back.integer >> _stackBlockHeaderSizeOffset;
							loger.write("blockArgCount: ", blockArgCount);
							DirAttrKind blockType = cast(DirAttrKind)( _stack.back.integer & _stackBlockHeaderTypeMask );
							// Bit between block size part and block type must always be zero
							loger.internalAssert( (_stack.back.integer & _stackBlockHeaderCheckMask) == 0, `Seeems that stack is corrupted` );
							loger.write("blockType: ", blockType);

							_stack.popBack();
							++i; // Block header was eaten, so increase counter

							switch( blockType )
							{
								case DirAttrKind.NamedAttr:
								{
									size_t j = 0;
									while( j < 2 * blockArgCount )
									{
										loger.internalAssert(!_stack.empty, "Execution stack is empty!");
										TDataNode attrValue = _stack.back;
										_stack.popBack(); ++j; // Parallel bookkeeping ;)

										loger.internalAssert(!_stack.empty, "Execution stack is empty!");
										loger.write(`RunCallable debug, _stack is: `, _stack);
										loger.internalAssert(_stack.back.type == DataNodeType.String, "Named attribute name must be string!");
										string attrName = _stack.back.str;
										_stack.popBack(); ++j;

										setLocalValue( attrName, attrValue );
									}
									i += j; // Increase overall processed stack arguments count (2 items per iteration)
									loger.write("_stack after parsing named arguments: ", _stack);
									break;
								}
								case DirAttrKind.ExprAttr:
								{
									size_t currBlockIndex = attrBlocks.length - blockCounter - 2; // 2 is: 1, because of length PLUS 1 for body attr in the end

									loger.write(`Interpret pos arg, currBlockIndex: `, currBlockIndex );
									
									if( currBlockIndex >= attrBlocks.length ) {
										loger.error(`Current attr block index is out of current bounds of declared blocks!`);
									}

									DirAttrsBlock!(false) currBlock = attrBlocks[currBlockIndex];

									loger.write(`Interpret pos arg, attrBlocks: `, attrBlocks);
									loger.write(`Interpret pos arg, currBlock.kind: `, currBlock.kind.to!string);
									if( currBlock.kind != DirAttrKind.ExprAttr ) {
										loger.error(`Expected positional arguments block in block metainfo`);
									}


									for( size_t j = 0; j < blockArgCount; ++j, ++i /* Inc overall processed arg count*/ )
									{
										loger.internalAssert(!_stack.empty, "Execution stack is empty!");
										TDataNode attrValue = _stack.back;
										_stack.popBack();

										loger.internalAssert(j < currBlock.exprAttrs.length, `Unexpected number of attibutes in positional arguments block`);

										setLocalValue( currBlock.exprAttrs[blockArgCount -j -1].name, attrValue );
									}
									loger.write("_stack after parsing positional arguments: ", _stack);
									break;
								}
								default:
									loger.internalAssert(false, "Unexpected arguments block type");
							}

							blockCounter += 1;
						}
					}
					loger.write("_stack after parsing all arguments: ", _stack);

					loger.internalAssert(!_stack.empty, "Expected callable object to call, but found end of execution stack!");
					loger.internalAssert(_stack.back.type == DataNodeType.Callable, `Expected callable object operand in call operation`);
					_stack.popBack(); // Drop callable object from stack

					if( callableObj._codeObj )
					{
						_stack ~= TDataNode(pk+1); // Put next instruction index on the stack to return at
						codeRange = callableObj._codeObj._instrs[]; // Set new instruction range to execute
						pk = 0;
						continue execution_loop;
					}
					else
					{
						loger.internalAssert(callableObj._dirInterp, `Callable object expected to have non null code object or native directive interpreter object!`);
						callableObj._dirInterp.interpret(this); // Run native directive interpreter
						
						if( !isNoscope ) {
							this.removeFrame(); // Drop context from stack after end of execution
						}
					}

					break;
				}

				case OpCode.MakeArray:
				{
					size_t arrayLen = instr.arg;
					TDataNode[] newArray;
					newArray.length = arrayLen; // Preallocating is good ;)
					loger.write("MakeArray _stack: ", _stack);
					loger.write("MakeArray arrayLen: ", arrayLen);
					for( size_t i = arrayLen; i > 0; --i )
					{
						loger.internalAssert(!_stack.empty, `Expected new array element, but got empty stack`);
						// We take array items from the tail, so we must consider it!
						newArray[i-1] = _stack.back;
						_stack.popBack();
					}
					_stack ~= TDataNode(newArray);

					break;
				}

				case OpCode.MakeAssocArray:
				{
					size_t aaLen = instr.arg;
					TDataNode[string] newAssocArray;

					for( size_t i = 0; i < aaLen; ++i )
					{
						loger.internalAssert(!_stack.empty, `Expected assoc array value, but got empty stack` );
						TDataNode val = _stack.back;
						_stack.popBack();

						loger.internalAssert(!_stack.empty, `Expected assoc array key, but got empty stack`);
						loger.internalAssert(_stack.back.type == DataNodeType.String, `Expected string as assoc array key`);
						
						newAssocArray[_stack.back.str] = val;
						_stack.popBack();
					}
					_stack ~= TDataNode(newAssocArray);
					break;
				}

				default:
				{
					loger.internalAssert(false, "Unexpected code of operation: ", instr.opcode);
					break;
				}
			}
			++pk;

			if( pk == codeRange.length ) // Ended with this code object
			{
				loger.write("_stack on code object end: ", _stack);
				loger.write("_frameStack on code object end: ", _frameStack);
				loger.internalAssert(!_frameStack.empty, "Frame stack shouldn't be empty yet'");
				// TODO: Consider case with noscope directive
				this.removeFrame(); // Exit out of this frame

				// If frame stack happens to be empty - it means that we nave done with programme
				if( _frameStack.empty )
					break;

				// Else we expect to have result of directive on the stack
				loger.internalAssert(!_stack.empty, "Expected directive result, but execution stack is empty!" );
				TDataNode result = _stack.back;
				_stack.popBack(); // We saved result - so drop it!

				loger.internalAssert(!_stack.empty, "Expected integer as instruction pointer, but got end of execution stack");
				loger.internalAssert(_stack.back.type == DataNodeType.Integer, "Expected integer as instruction pointer");
				pk = cast(size_t) _stack.back.integer;
				_stack.popBack(); // Drop return address
				codeRange = _frameStack.back._callableObj._codeObj._instrs[]; // Set old instruction range back

				_stack ~= result; // Get result back
			}

		}
	}
}
