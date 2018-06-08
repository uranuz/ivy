module ivy.interpreter.interpreter;

import ivy.common;
import ivy.directive_stuff;
import ivy.code_object;
import ivy.interpreter.data_node;
import ivy.interpreter.data_node_types;
import ivy.interpreter.execution_frame;

// If IvyTotalDebug is defined then enable parser debug
version(IvyTotalDebug) version = IvyInterpreterDebug;

interface INativeDirectiveInterpreter
{
	import ivy.interpreter.interpreter: Interpreter;
	import ivy.compiler.symbol_table: Symbol;
	void interpret(Interpreter interp);

	DirAttrsBlock!(false)[] attrBlocks() @property;

	Symbol compilerSymbol() @property;
}

alias TDataNode = DataNode!string;

class IvyInterpretException: IvyException
{
public:
	@nogc @safe this(string msg, string file = __FILE__, size_t line = __LINE__, Throwable next = null) pure nothrow
	{
		super(msg, file, line, next);
	}
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

	// Loger method used to send error and debug messages
	LogerMethod _logerMethod;

	size_t _pk; // Programme counter

	this(ModuleObject[string] moduleObjects, string mainModuleName, TDataNode dataDict, LogerMethod logerMethod = null)
	{
		import std.range: back;

		_logerMethod = logerMethod;
		_moduleObjects = moduleObjects;
		loger.internalAssert(mainModuleName in _moduleObjects, `Cannot get main module from module objects!`);

		loger.write(`Passed dataDict: `, dataDict);

		CallableObject rootCallableObj = new CallableObject;
		rootCallableObj._codeObj = _moduleObjects[mainModuleName].mainCodeObject;
		rootCallableObj._kind = CallableKind.Module;
		rootCallableObj._name = "__main__";
		loger.write(`CallableObj._codeObj._moduleObj: `, rootCallableObj._codeObj._moduleObj._name);

		TDataNode globalDataDict;
		globalDataDict["__scopeName__"] = "__global__"; // Allocating dict
		_globalFrame = new ExecutionFrame(null, null, globalDataDict, _logerMethod, false);
		_moduleFrames["__global__"] = _globalFrame; // We need to add entry point module frame to storage manually
		loger.write(`_globalFrame._dataDict: `, _globalFrame._dataDict);

		newFrame(rootCallableObj, null, dataDict, false); // Create entry point module frame
		_moduleFrames[mainModuleName] = _frameStack.back; // We need to add entry point module frame to storage manually
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

	// Method used to add extra global data into interpreter
	// Consider not to bloat it to much ;)
	void addExtraGlobals(TDataNode[string] extraGlobals)
	{
		foreach( string name, TDataNode dataNode; extraGlobals ) {
			// Take a copy of it just like with consts
			_globalFrame.setValue(name, dataNode);
		}
	}

	version(IvyInterpreterDebug)
		enum isDebugMode = true;
	else
		enum isDebugMode = false;

	static struct LogerProxy {
		mixin LogerProxyImpl!(IvyInterpretException, isDebugMode);
		Interpreter interp;

		string sendLogInfo(LogInfoType logInfoType, string msg)
		{
			import std.algorithm: map, canFind;
			import std.array: join;
			import std.conv: text;

			string modFileName;
			size_t modLineIndex;
			if( ModuleObject modObj = interp.currentModule ) {
				modFileName = modObj.fileName;
			}

			if( CodeObject codeObj = interp.currentCodeObject ) {
				modLineIndex = codeObj.getInstrLine(interp._pk);
			}

			// Put name of module and line where event occured
			msg = "Ivy module: " ~ modFileName ~ ":" ~ modLineIndex.text ~ "\n" ~ msg;

			debug {
				if( [LogInfoType.error, LogInfoType.internalError].canFind(logInfoType) )
				{
					// Give additional debug data if error occured
					string execFrameList = interp._frameStack.map!( (frame) => frame._callableObj._name ).join("\n");
					string dataStack = interp._stack.map!( (it) => it.toDebugString() ).join("\n");
					msg ~= "Exec stack:\n" ~ execFrameList ~ "\n\nData stack:\n" ~ dataStack;
				}
			}

			if( interp._logerMethod !is null ) {
				interp._logerMethod(LogInfo(
					msg,
					logInfoType,
					getShortFuncName(func),
					file,
					line,
					modFileName,
					modLineIndex
				));
			}
			return msg;
		}
	}

	ModuleObject currentModule()
	{
		if( CodeObject codeObj = currentCodeObject ) {
			return codeObj._moduleObj;
		}
		return null;
	}

	CodeObject currentCodeObject()
	{
		import std.range: empty, back;
		if(
			_frameStack.empty
			|| (_frameStack.back is null)
			|| (_frameStack.back._callableObj is null)
		) {
			return null;
		}
		return _frameStack.back._callableObj._codeObj;
	}

	LogerProxy loger(string func = __FUNCTION__, string file = __FILE__, int line = __LINE__)	{
		return LogerProxy(func, file, line, this);
	}

	/// Method for setting interpreter's loger method
	void logerMethod(LogerMethod method) @property {
		_logerMethod = method;
	}

	void newFrame(CallableObject callableObj, ExecutionFrame modFrame, TDataNode dataDict, bool isNoscope)
	{
		_frameStack ~= new ExecutionFrame(callableObj, modFrame, dataDict, _logerMethod, isNoscope);
		loger.write(`Enter new execution frame for callable: `, callableObj._name, ` with dataDict: `, dataDict, `, and modFrame `, (modFrame? `is not null`: `is null`));
	}

	ExecutionFrame currentFrame() @property
	{
		import std.range: empty, back, popBack;

		auto frameStackSlice = _frameStack[];
		for( ; !frameStackSlice.empty; frameStackSlice.popBack() )
		{
			if( frameStackSlice.back.hasOwnScope ) {
				return frameStackSlice.back;
			}
		}
		loger.internalAssert(false, `Cannot get current execution frame`);
		return null;
	}

	void removeFrame()
	{
		import std.range: back, popBack;
		loger.write(`Exit execution frame for callable: `, _frameStack.back._callableObj._name, ` with dataDict: `, _frameStack.back._dataDict);
		_frameStack.popBack();

	}

	bool canFindValue(string varName) {
		return !findValue!(FrameSearchMode.tryGet)(varName).node.isUndef;
	}

	FrameSearchResult findValue(FrameSearchMode mode)(string varName)
	{
		import std.range: empty, back, popBack;

		loger.write(`Starting to search for varName: `, varName);
		ExecutionFrame[] frameStackSlice = _frameStack[];
		loger.internalAssert( !frameStackSlice.empty, `frameStackSlice is empty` );

		FrameSearchResult result;
		for( ; !frameStackSlice.empty; frameStackSlice.popBack() )
		{
			loger.internalAssert(frameStackSlice.back, `Couldn't find variable value, because execution frame is null!` );

			loger.write(`Trying to search in current execution frame for varName: `, varName);
			result = frameStackSlice.back.findValue!(mode)(varName);

			if( !frameStackSlice.back.hasOwnScope && result.node.isUndef ) {
				loger.write(`Current level exec frame is noscope. Try find: `, varName, ` in parent`);
				continue; // Let's try to find in parent
			}

			if( !result.node.isUndef || (result.node.isUndef && result.allowUndef) ) {
				loger.write(`varName: `, varName, ` found in current execution frame`);
				return result;
			}

			loger.write(`varName: `, varName, ` NOT found in current execution frame`);
			break;
		}

		loger.internalAssert(_globalFrame, `Couldn't find variable: `, varName, ` value in global frame, because it is null!` );
		loger.internalAssert(_globalFrame.hasOwnScope, `Couldn't find variable: `, varName, ` value in global frame, because global frame doesn't have it's own scope!` );

		static if( mode == FrameSearchMode.get || mode == FrameSearchMode.tryGet ) {
			loger.write(`Trying to search in global frame for varName: `, varName);
			result = _globalFrame.findValue!(mode)(varName);
			if( !result.node.isUndef ) {
				loger.write(`varName: `, varName, ` found in global execution frame`);
				return result;
			}

			loger.write(`varName: `, varName, ` NOT found in global execution frame`);
		}

		return result;
	}

	FrameSearchResult findValueLocal(FrameSearchMode mode)(string varName)
	{
		import std.range: empty, back, popBack;

		loger.write(`Call findValueLocal for: ` ~ varName);

		ExecutionFrame[] frameStackSlice = _frameStack[];
		FrameSearchResult result;
		for( ; !frameStackSlice.empty; frameStackSlice.popBack() )
		{
			loger.internalAssert(frameStackSlice.back, `Couldn't find variable value, because execution frame is null!`);

			result = frameStackSlice.back.findLocalValue!(mode)(varName);
			if( !result.node.isUndef ) {
				loger.write(`varName: `, varName, ` found in current execution frame`);
				return result;
			}

			loger.write(`varName: `, varName, ` NOT found in current execution frame`);
			break;
		}

		return result;
	}

	TDataNode getValue(string varName)
	{
		FrameSearchResult result = findValue!(FrameSearchMode.get)(varName);
		if( result.node.isUndef && !result.allowUndef )
		{
			debug {
				foreach( i, frame; _frameStack[] )
				{
					loger.write(`Scope frame lvl `, i, `, _dataDict: `, frame._dataDict);
					if( frame._moduleFrame ) {
						loger.write(`Scope frame lvl `, i, `, _moduleFrame._dataDict: `, frame._moduleFrame._dataDict);
					} else {
						loger.write(`Scope frame lvl `, i, `, _moduleFrame is null`);
					}
				}
			}

			loger.error("Undefined variable with name '", varName, "'");
		}

		return result.node;
	}

	private void _assignNodeAttribute(ref TDataNode parent, ref TDataNode value, string varName)
	{
		import std.array: split;
		import std.range: back;
		string attrName = varName.split(`.`).back;
		switch( parent.type )
		{
			case DataNodeType.AssocArray:
				parent.assocArray[attrName] = value;
				break;
			case DataNodeType.ClassNode:
				if( !parent.classNode ) {
					loger.error(`Cannot assign attribute, because class node is null`);
				}
				parent.classNode.__setAttr__(value, attrName);
				break;
			default:
				loger.error(`Cannot assign atribute of node with type: `, parent.type);
		}
	}

	void setValue(string varName, TDataNode value)
	{
		loger.write(`Call for: ` ~ varName);
		FrameSearchResult result = findValue!(FrameSearchMode.set)(varName);
		_assignNodeAttribute(result.parent, value, varName);
	}

	void setValueWithParents(string varName, TDataNode value)
	{
		loger.write(`Call for: ` ~ varName);
		FrameSearchResult result = findValue!(FrameSearchMode.setWithParents)(varName);
		_assignNodeAttribute(result.parent, value, varName);
	}

	void setLocalValue(string varName, TDataNode value)
	{
		loger.write(`Call for: ` ~ varName);
		FrameSearchResult result = findValueLocal!(FrameSearchMode.set)(varName);
		_assignNodeAttribute(result.parent, value, varName);
	}

	void setLocalValueWithParents(string varName, TDataNode value)
	{
		loger.write(`Call for: ` ~ varName);
		FrameSearchResult result = findValueLocal!(FrameSearchMode.setWithParents)(varName);
		_assignNodeAttribute(result.parent, value, varName);
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

	bool evalAsBoolean(ref TDataNode value)
	{
		switch(value.type)
		{
			case DataNodeType.Undef, DataNodeType.Null: return false;
			case DataNodeType.Boolean: return value.boolean;
			case DataNodeType.Integer, DataNodeType.Floating, DataNodeType.DateTime:
				// Considering numbers just non-empty there. Not try to interpret 0 or 0.0 as logical false,
				// because in many cases they could be treated as significant values
				// DateTime and Boolean are not empty too, because we cannot say what value should be treated as empty
				return true;
			case DataNodeType.String: return !!value.str.length;
			case DataNodeType.Array: return !!value.array.length;
			case DataNodeType.AssocArray: return !!value.assocArray.length;
			case DataNodeType.DataNodeRange:
				return !!value.dataRange && !value.dataRange.empty;
			case DataNodeType.ClassNode:
				// Basic check for ClassNode for emptyness is that it should not be null reference
				// If some interface method will be introduced to check for empty then we shall consider to check it too
				return value.classNode !is null;
			default:
				loger.error(`Cannot evaluate type: `, value.type, ` in logical context!`);
				break;
		}
		assert(false);
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
		execution_loop:
		for( _pk = 0; _pk < codeRange.length; )
		{
			Instruction instr = codeRange[_pk];
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
						`Left and right values of arithmetic operation must have the same integer or floating type! But got: `, leftVal.type, ` and `, rightVal.type );

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
							tuple(DataNodeType.String, "str"),
							tuple(DataNodeType.DateTime, "dateTime")) )
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
					import std.algorithm: canFind;

					loger.write(`OpCode.LoadSubscr. _stack: `, _stack);

					loger.internalAssert(!_stack.empty, "Cannot execute LoadSubscr instruction. Expected index value, but exec stack is empty!");
					TDataNode indexValue = _stack.back;
					_stack.popBack();

					loger.internalAssert(!_stack.empty, "Cannot execute LoadSubscr instruction. Expected aggregate, but exec stack is empty!");
					TDataNode aggr = _stack.back;
					_stack.popBack();
					loger.write(`OpCode.LoadSubscr. aggr: `, aggr);
					loger.write(`OpCode.LoadSubscr. indexValue: `, indexValue);

					loger.internalAssert(
						[DataNodeType.String, DataNodeType.Array, DataNodeType.AssocArray, DataNodeType.ClassNode].canFind(aggr.type),
						"Cannot execute LoadSubscr instruction. Aggregate value must be string, array, assoc array or class node!");

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
							loger.internalAssert(indexValue.str in aggr.assocArray,
								`Assoc array key "`, indexValue.str, `" must be present in assoc array`);
							_stack ~= aggr.assocArray[indexValue.str];
							break;
						case DataNodeType.ClassNode:
							if( indexValue.type == DataNodeType.Integer ) {
								_stack ~= aggr.classNode[indexValue.integer];
							} else if( indexValue.type == DataNodeType.String ) {
								_stack ~= aggr.classNode[indexValue.str];
							} else {
								loger.error("Cannot execute LoadSubscr instruction. Index value for class node must be string or integer!");
							}
							break;
						default:
							loger.internalAssert(false, `Cannot execute LoadSubscr instruction. Unexpected aggregate type`);
					}
					break;
				}

				// Load data node slice for array-like nodes onto stack
				case OpCode.LoadSlice:
				{
					import std.utf: toUTFindex, decode;
					import std.algorithm: canFind;

					loger.write(`OpCode.LoadSlice. _stack: `, _stack);

					loger.internalAssert(!_stack.empty, "Cannot execute LoadSlice instruction. Expected index value, but exec stack is empty!");
					TDataNode endValue = _stack.back;
					_stack.popBack();

					loger.internalAssert(!_stack.empty, "Cannot execute LoadSlice instruction. Expected index value, but exec stack is empty!");
					TDataNode beginValue = _stack.back;
					_stack.popBack();

					loger.internalAssert(!_stack.empty, "Cannot execute LoadSlice instruction. Expected aggregate, but exec stack is empty!");
					TDataNode aggr = _stack.back;
					_stack.popBack();
					loger.write(`OpCode.LoadSlice. aggr: `, aggr);
					loger.write(`OpCode.LoadSlice. beginValue: `, beginValue);
					loger.write(`OpCode.LoadSlice. endValue: `, endValue);

					loger.internalAssert(
						[DataNodeType.String, DataNodeType.Array, DataNodeType.ClassNode].canFind(aggr.type),
						"Cannot execute LoadSlice instruction. Aggregate value must be string, array, assoc array or class node!");
					
					loger.internalAssert(beginValue.type == DataNodeType.Integer,
						"Cannot execute LoadSlice instruction. Begin value of slice must be integer!");

					loger.internalAssert(endValue.type == DataNodeType.Integer,
						"Cannot execute LoadSlice instruction. End value of slice must be integer!");

					size_t startIndex; size_t endIndex; size_t len;
					if( [DataNodeType.String, DataNodeType.Array].canFind(aggr.type) )
					{
						if( aggr.type == DataNodeType.String )
						{
							startIndex = aggr.str.toUTFindex(beginValue.integer); // Get code unit index by index of symbol
							endIndex = endValue.integer;
							len = aggr.str.length;
							aggr.str.decode(endIndex); // decode increases passed index
						} else {
							startIndex = beginValue.integer;
							startIndex = endValue.integer;
							len = aggr.array.length;
						}
						// For slice we shall correct indexes if they are out of range
						if( startIndex > len ) {
							startIndex = len;
						}
						if( endIndex > len ) {
							startIndex = len;
						}
						if( startIndex > endIndex ) {
							startIndex = endIndex;
						}
					}

					switch( aggr.type )
					{
						case DataNodeType.String:
							_stack ~= TDataNode( aggr.str[startIndex..endIndex] );
							break;
						case DataNodeType.Array:
							_stack ~= aggr.array[beginValue.integer..endValue.integer];
							break;
						case DataNodeType.ClassNode:
							// Class node must have it's own range checks
							_stack ~= TDataNode(aggr.classNode[beginValue.integer..endValue.integer]);
							break;
						default:
							loger.internalAssert(false, `Cannot execute LoadSlice instruction. Unexpected aggregate type`);
					}
					break;
				}

				// Set property of object, array item or class object with writeable attribute
				// by passed property name or index
				case OpCode.StoreSubscr:
				{
					import std.algorithm: canFind;

					loger.write(`OpCode.StoreSubscr. _stack: `, _stack);

					loger.internalAssert(!_stack.empty, "Cannot execute StoreSubscr instruction. Expected index value, but exec stack is empty!");
					TDataNode indexValue = _stack.back;
					_stack.popBack();
					
					loger.internalAssert(!_stack.empty, "Cannot execute StoreSubscr instruction. Expected value to set, but exec stack is empty!");
					TDataNode value = _stack.back;
					_stack.popBack();

					loger.internalAssert(!_stack.empty, "Cannot execute StoreSubscr instruction. Expected aggregate, but exec stack is empty!");
					TDataNode aggr = _stack.back;
					_stack.popBack();

					// Do not support setting individual characters of strings for now and maybe forever... Who knowns how it turns...
					loger.internalAssert(
						[DataNodeType.Array, DataNodeType.AssocArray, DataNodeType.ClassNode].canFind(aggr.type),
						"Cannot execute StoreSubscr instruction. Aggregate value must be array, assoc array or class node!");

					switch( aggr.type )
					{
						case DataNodeType.Array:
							loger.internalAssert(indexValue.type == DataNodeType.Integer,
								"Cannot execute StoreSubscr instruction. Index value for array aggregate must be integer!");
							loger.internalAssert(indexValue.integer < aggr.array.length, `Array index must be less than array length`);
							aggr[indexValue.integer] = value;
							break;
						case DataNodeType.AssocArray:
							loger.internalAssert(indexValue.type == DataNodeType.String,
								"Cannot execute StoreSubscr instruction. Index value for assoc array aggregate must be string!");
							aggr[indexValue.str] = value;
							break;
						case DataNodeType.ClassNode:
							if( indexValue.type == DataNodeType.Integer ) {
								aggr[indexValue.integer] = value;
							} else if( indexValue.type == DataNodeType.String ) {
								aggr[indexValue.str] = value;
							} else {
								loger.error("Cannot execute StoreSubscr instruction. Index value for class node must be string or integer!");
							}
							break;
						default:
							loger.internalAssert(false, `Cannot execute StoreSubscr instruction. Unexpected aggregate type`);
					}
					break;
				}

				// Load constant from programme data table into stack
				case OpCode.LoadConst:
				{
					_stack ~= getModuleConstCopy(instr.arg);
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
					loger.internalAssert(!_stack.empty,
						"Cannot execute Append instruction. Expected right operand, but exec stack is empty!");
					TDataNode rightVal = _stack.back;
					_stack.popBack();

					loger.internalAssert(!_stack.empty,
						"Cannot execute Append instruction. Expected left operand, but exec stack is empty!");
					loger.internalAssert(_stack.back.type == DataNodeType.Array,
						"Left operand for Append instruction expected to be array, but got: ", _stack.back.type);

					_stack.back ~= rightVal;

					break;
				}

				case OpCode.Insert:
				{
					import std.array: insertInPlace;

					loger.write("OpCode.Insert _stack: ", _stack);
					loger.internalAssert(!_stack.empty, "Cannot execute Insert instruction. Expected right operand, but exec stack is empty!");
					TDataNode positionNode = _stack.back;
					_stack.popBack();
					import std.algorithm: canFind;
					loger.internalAssert(
						[DataNodeType.Integer, DataNodeType.Null, DataNodeType.Undef].canFind(positionNode.type),
						"Cannot execute Insert instruction. Position argument expected to be an integer or empty (for append), but got: ", positionNode.type
					);

					loger.internalAssert(!_stack.empty, "Cannot execute Insert instruction. Expected left operand, but exec stack is empty!");
					TDataNode valueNode = _stack.back;
					_stack.popBack();

					loger.internalAssert(!_stack.empty, "Cannot execute Insert instruction. Expected left operand, but exec stack is empty!");
					TDataNode listNode = _stack.back;
					loger.internalAssert(
						listNode.type == DataNodeType.Array,
						"Cannot execute Insert instruction. Aggregate must be an array, but got: ", listNode.type
					);
					size_t pos;
					if( positionNode.type != DataNodeType.Integer ) {
						pos = listNode.array.length; // Do append
					} else if( positionNode.integer >= 0 ) {
						pos = positionNode.integer;
					} else {
						// Indexing from back if negative
						pos = listNode.array.length + positionNode.integer;
					}
					loger.internalAssert(
						pos >= 0 && pos <= listNode.array.length,
						"Cannot execute Insert instruction. Computed position is wrong: ", pos);
					listNode.array.insertInPlace(pos, valueNode);
					break;
				}

				case OpCode.InsertMass:
				{
					loger.write("OpCode.InsertMass _stack: ", _stack);
					loger.internalAssert(!_stack.empty, "Cannot execute ListInsert instruction. Expected right operand, but exec stack is empty!");
					assert(false, `Not implemented yet!`);
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

					_stack.back = !evalAsBoolean(_stack.back);
					break;
				}

				case OpCode.Nop:
				{
					// Doing nothing here... What did you expect? :)
					break;
				}

				// Stores data from stack into local context frame variable
				case OpCode.StoreName, OpCode.StoreLocalName, OpCode.StoreNameWithParents:
				{
					loger.write(instr.opcode, " _stack: ", _stack);
					loger.internalAssert(!_stack.empty, "Cannot execute ", instr.opcode, " instruction. Expected var value operand, but exec stack is empty!");
					TDataNode varValue = _stack.back;
					_stack.popBack();

					TDataNode varNameNode = getModuleConstCopy(instr.arg);
					loger.internalAssert(varNameNode.type == DataNodeType.String, `Cannot execute `, instr.opcode, ` instruction. Variable name const must have string type!`);


					switch(instr.opcode) {
						case OpCode.StoreName: setValue(varNameNode.str, varValue); break;
						case OpCode.StoreLocalName: setLocalValue(varNameNode.str, varValue); break;
						case OpCode.StoreNameWithParents: setValueWithParents(varNameNode.str, varValue); break;
						default: loger.internalAssert(false, `Unexpected 'store name' instruction kind`);
					}
					break;
				}

				// Loads data from local context frame variable by index of var name in module constants
				case OpCode.LoadName:
				{
					TDataNode varNameNode = getModuleConstCopy(instr.arg);
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

						TDataNode dataDict;
						dataDict["__scopeName__"] = moduleName;
						newFrame(callableObj, null, dataDict, false); // Create entry point module frame
						_moduleFrames[moduleName] = _frameStack.back; // We need to store module frame into storage
						_stack ~= TDataNode(_frameStack.back); // Put module root frame into execution frame (it will be stored with StoreName)

						// Preparing to run code object in newly created frame
						_stack ~= TDataNode(_pk+1);
						codeRange = codeObject._instrs[];
						_pk = 0;

						continue execution_loop;
					}
					else
					{
						_stack ~= TDataNode(_moduleFrames[moduleName]); // Put module root frame into execution frame
						// As long as module returns some value at the end of execution, so put fake value there for consistency
						_stack ~= TDataNode();
					}

					break;
				}

				case OpCode.FromImport:
				{
					import std.algorithm: map;
					import std.array: array;

					loger.internalAssert(!_stack.empty, "Cannot execute FromImport instruction, because exec stack is empty!");
					loger.internalAssert(_stack.back.type == DataNodeType.Array, "Cannot execute FromImport instruction. Expected list of symbol names");
					string[] symbolNames = _stack.back.array.map!( it => it.str ).array;
					_stack.popBack();

					loger.internalAssert(!_stack.empty, "Cannot execute FromImport instruction, because exec stack is empty!");
					loger.internalAssert(_stack.back.type == DataNodeType.ExecutionFrame, "Cannot execute FromImport instruction. Expected execution frame argument");

					ExecutionFrame moduleFrame = _stack.back.execFrame;
					loger.internalAssert(moduleFrame, "Cannot execute FromImport instruction, because module frame argument is null");
					_stack.popBack();

					foreach( name; symbolNames ) {
						setValue( name, moduleFrame.getValue(name) );
					}
					break;
				}

				case OpCode.GetDataRange:
				{
					import std.range: empty, back, popBack;
					import std.algorithm: canFind;
					loger.internalAssert(!_stack.empty, `Expected aggregate type for loop, but empty execution stack found`);
					loger.write(`GetDataRange begin _stack: `, _stack);
					loger.internalAssert([
							DataNodeType.Array,
							DataNodeType.AssocArray,
							DataNodeType.DataNodeRange,
							DataNodeType.ClassNode
						].canFind(_stack.back.type),
						`Expected array or assoc array as loop aggregate, but got: `,
						_stack.back.type
					);

					TDataNode dataRange;
					switch( _stack.back.type )
					{
						case DataNodeType.Array:
						{
							dataRange = new ArrayRange(_stack.back.array);
							break;
						}
						case DataNodeType.ClassNode:
						{
							loger.internalAssert(_stack.back.classNode, "Aggregate class node for loop is null!");
							dataRange = TDataNode(_stack.back.classNode[]);
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
						_pk = instr.arg;
						loger.internalAssert(_stack.back.type == DataNodeType.DataNodeRange, "RunLoop. Expected DataNodeRange to drop");
						_stack.popBack(); // Drop data range from stack as we no longer need it
						break;
					}

					_stack ~= dataRange.front;
					// TODO: For now we just move range forward as take current value from it
					// Maybe should fix it and make it move after loop block finish
					dataRange.popFront();

					loger.write("RunLoop. Iteration init finished. _stack is: ", _stack);
					break;
				}

				case OpCode.Jump:
				{
					loger.internalAssert(instr.arg < codeRange.length, `Cannot jump after the end of code object`);

					_pk = instr.arg;
					continue execution_loop;
				}

				case OpCode.JumpIfTrue, OpCode.JumpIfFalse, OpCode.JumpIfTrueOrPop, OpCode.JumpIfFalseOrPop:
				{
					import std.algorithm: canFind;
					loger.internalAssert(!_stack.empty, `Cannot evaluate logical value, because stack is empty`);

					loger.internalAssert(instr.arg < codeRange.length, `Cannot jump after the end of code object`);
					bool jumpCond = evalAsBoolean(_stack.back); // This is actual condition to test
					if( [OpCode.JumpIfFalse, OpCode.JumpIfFalseOrPop].canFind(instr.opcode) ) {
						jumpCond = !jumpCond; // Invert condition if False family is used
					}

					if( [OpCode.JumpIfTrue, OpCode.JumpIfFalse].canFind(instr.opcode) || !jumpCond ) {
						// Drop condition from _stack on JumpIfTrue, JumpIfFalse anyway
						// But for JumpIfTrueOrPop, JumpIfFalseOrPop drop it only if jumpCond is false
						_stack.popBack();
					}

					if( jumpCond )
					{
						_pk = instr.arg;
						continue execution_loop;
					}
					break;
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
						foreach( lvl, frame; _frameStack )
						{
							loger.write(`LoadDirective, frameStack lvl `, lvl, ` dataDict: `, frame._dataDict);
							if( frame._moduleFrame ) {
								loger.write(`LoadDirective, frameStack lvl `, lvl, ` moduleFrame.dataDict: `, frame._dataDict);
							} else {
								loger.write(`LoadDirective, frameStack lvl `, lvl, ` moduleFrame is null`);
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
					loger.write("RunCallable callable type: ", _stack[_stack.length - stackArgCount].type);
					loger.internalAssert(_stack[_stack.length - stackArgCount].type == DataNodeType.Callable,
						`Expected directive object operand in directive call operation`);

					CallableObject callableObj = _stack[_stack.length - stackArgCount].callable;
					loger.internalAssert(callableObj, `Callable object is null!` );
					loger.write("RunCallable name: ", callableObj._name);

					DirAttrsBlock!(false)[] attrBlocks = callableObj.attrBlocks;
					loger.write("RunCallable callableObj.attrBlocks: ", attrBlocks);

					bool isNoscope = false;
					if( attrBlocks.length > 0 )
					{
						loger.internalAssert(attrBlocks[$-1].kind == DirAttrKind.BodyAttr,
							`Last attr block definition expected to be BodyAttr, but got: `, attrBlocks[$-1].kind);
						isNoscope = attrBlocks[$-1].bodyAttr.isNoscope;
					}

					string moduleName = callableObj._codeObj? callableObj._codeObj._moduleObj._name: "__global__";
					ExecutionFrame moduleFrame = _moduleFrames.get(moduleName, null);
					loger.internalAssert( moduleFrame, `Module frame with name: `, moduleFrame, ` of callable: `, callableObj._name, ` does not exist!` );

					loger.write("RunCallable creating execution frame...");
					TDataNode dataDict;
					dataDict["__scopeName__"] = callableObj._name; // Allocating scope
					newFrame(callableObj, moduleFrame, dataDict, isNoscope);

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
						_stack ~= TDataNode(_pk+1); // Put next instruction index on the stack to return at
						codeRange = callableObj._codeObj._instrs[]; // Set new instruction range to execute
						_pk = 0;
						continue execution_loop;
					}
					else
					{
						loger.internalAssert(callableObj._dirInterp, `Callable object expected to have non null code object or native directive interpreter object!`);
						callableObj._dirInterp.interpret(this); // Run native directive interpreter

						this.removeFrame(); // Drop frame from stack after end of execution
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
					newAssocArray[`__mentalModuleMagic_0451__`] = 451;
					newAssocArray.remove(`__mentalModuleMagic_0451__`);

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

				case OpCode.MarkForEscape: {
					loger.internalAssert(!_stack.empty, "Cannot execute MarkForEscape instruction. Expected operand for mark, but exec stack is empty!");
					_stack.back.escapeState = cast(NodeEscapeState) instr.arg;
					break;
				}

				default:
				{
					loger.internalAssert(false, "Unexpected code of operation: ", instr.opcode);
					break;
				}
			}
			++_pk;

			if( _pk == codeRange.length ) // Ended with this code object
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
				_pk = cast(size_t) _stack.back.integer;
				_stack.popBack(); // Drop return address
				codeRange = _frameStack.back._callableObj._codeObj._instrs[]; // Set old instruction range back

				_stack ~= result; // Get result back
			}

		}
	}
}
