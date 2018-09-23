module ivy.interpreter.interpreter;

import ivy.common;
import ivy.directive_stuff;
import ivy.code_object;
import ivy.interpreter.data_node;
import ivy.interpreter.data_node_types;
import ivy.interpreter.execution_frame;
import ivy.interpreter.exec_stack;
import ivy.interpreter.common;

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

import ivy.bytecode;

class Interpreter
{
public:
	alias LogerMethod = void delegate(LogInfo);

	// Stack of execution frames with directives or modules local data
	ExecutionFrame[] _frameStack;

	// Global execution frame used for some global built-in data
	ExecutionFrame _globalFrame;

	// Storage for execition frames of imported modules
	ExecutionFrame[string] _moduleFrames;

	// Storage for bytecode code and initial constant data for modules
	ModuleObject[string] _moduleObjects;

	ExecStack _stack;

	// Loger method used to send error and debug messages
	LogerMethod _logerMethod;

	size_t _pk; // Programme counter
	Instruction[] _codeRange; // Current code range we executing

	this(ModuleObject[string] moduleObjects, string mainModuleName, IvyData dataDict, LogerMethod logerMethod = null)
	{
		import std.range: back;

		_logerMethod = logerMethod;
		_moduleObjects = moduleObjects;
		loger.internalAssert(mainModuleName in _moduleObjects, `Cannot get main module from module objects!`);

		loger.write(`Passed dataDict: `, dataDict);

		CallableObject rootCallableObj = new CallableObject(
			"__main__", _moduleObjects[mainModuleName].mainCodeObject, CallableKind.Module
		);

		IvyData globalDataDict;
		globalDataDict["__scopeName__"] = "__global__"; // Allocating dict
		_globalFrame = new ExecutionFrame(null, null, globalDataDict, _logerMethod, false);
		_moduleFrames["__global__"] = _globalFrame; // We need to add entry point module frame to storage manually
		loger.write(`_globalFrame._dataDict: `, _globalFrame._dataDict);

		dataDict["__scopeName__"] = "__main__"; // Allocating a dict if it's not
		newFrame(rootCallableObj, null, dataDict, false); // Create entry point module frame
		_stack.addStackBlock();
		_moduleFrames[mainModuleName] = _frameStack.back; // We need to add entry point module frame to storage manually
	}

	private void _addNativeDirInterp(string name, INativeDirectiveInterpreter dirInterp)
	{
		loger.internalAssert(name.length && dirInterp, `Directive name is empty or direxecInterp is null!`);

		// Add custom native directive interpreters to global scope
		_globalFrame.setValue(name, IvyData(new CallableObject(name, dirInterp)));
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
	void addExtraGlobals(IvyData[string] extraGlobals)
	{
		foreach( string name, IvyData dataNode; extraGlobals ) {
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
					string dataStack = interp._stack._stack.map!( (it) => it.toDebugString() ).join("\n");
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

	/++ Returns nearest independent execution frame that is not marked `noscope`+/
	ExecutionFrame independentFrame() @property
	{
		import std.range: empty;
		loger.internalAssert(!_frameStack.empty, `Execution frame stack is empty!`);

		foreach_reverse( frame; _frameStack )
		{
			if( frame.hasOwnScope ) {
				return frame;
			}
		}
		loger.internalAssert(false, `Cannot get current independent execution frame!`);
		return null;
	}

	/++ Returns nearest execution frame from _frameStack +/
	ExecutionFrame currentFrame() @property
	{
		import std.range: empty, back;
		loger.internalAssert(!_frameStack.empty, "Execution frame stack is empty!");
		return _frameStack.back;
	}

	void newFrame(CallableObject callableObj, ExecutionFrame modFrame, IvyData dataDict, bool isNoscope)
	{
		_frameStack ~= new ExecutionFrame(callableObj, modFrame, dataDict, _logerMethod, isNoscope);
		loger.write(`Enter new execution frame for callable: `, callableObj._name, ` with dataDict: `, dataDict, `, and modFrame `, (modFrame? `is not null`: `is null`));
	}

	void removeFrame()
	{
		import std.range: empty, back, popBack;
		loger.internalAssert(!_frameStack.empty, `Execution frame stack is empty!`);
		loger.write(`Exit execution frame for callable: `, _frameStack.back._callableObj._name, ` with dataDict: `, _frameStack.back._dataDict);
		_stack.removeStackBlock();
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

	IvyData getValue(string varName)
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

	private void _assignNodeAttribute(ref IvyData parent, ref IvyData value, string varName)
	{
		import std.array: split;
		import std.range: back;
		string attrName = varName.split(`.`).back;
		switch( parent.type )
		{
			case IvyDataType.AssocArray:
				parent.assocArray[attrName] = value;
				break;
			case IvyDataType.ClassNode:
				if( !parent.classNode ) {
					loger.error(`Cannot assign attribute, because class node is null`);
				}
				parent.classNode.__setAttr__(value, attrName);
				break;
			default:
				loger.error(`Cannot assign atribute of node with type: `, parent.type);
		}
	}

	void setValue(string varName, IvyData value)
	{
		loger.write(`Call for: ` ~ varName);
		FrameSearchResult result = findValue!(FrameSearchMode.set)(varName);
		_assignNodeAttribute(result.parent, value, varName);
	}

	void setValueWithParents(string varName, IvyData value)
	{
		loger.write(`Call for: ` ~ varName);
		FrameSearchResult result = findValue!(FrameSearchMode.setWithParents)(varName);
		_assignNodeAttribute(result.parent, value, varName);
	}

	void setLocalValue(string varName, IvyData value)
	{
		loger.write(`Call for: ` ~ varName);
		FrameSearchResult result = findValueLocal!(FrameSearchMode.set)(varName);
		_assignNodeAttribute(result.parent, value, varName);
	}

	void setLocalValueWithParents(string varName, IvyData value)
	{
		loger.write(`Call for: ` ~ varName);
		FrameSearchResult result = findValueLocal!(FrameSearchMode.setWithParents)(varName);
		_assignNodeAttribute(result.parent, value, varName);
	}

	IvyData getModuleConst( size_t index )
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

	IvyData getModuleConstCopy( size_t index )
	{
		return deeperCopy( getModuleConst(index) );
	}

	bool evalAsBoolean(ref IvyData value)
	{
		switch(value.type)
		{
			case IvyDataType.Undef, IvyDataType.Null: return false;
			case IvyDataType.Boolean: return value.boolean;
			case IvyDataType.Integer, IvyDataType.Floating, IvyDataType.DateTime:
				// Considering numbers just non-empty there. Not try to interpret 0 or 0.0 as logical false,
				// because in many cases they could be treated as significant values
				// DateTime and Boolean are not empty too, because we cannot say what value should be treated as empty
				return true;
			case IvyDataType.String: return !!value.str.length;
			case IvyDataType.Array: return !!value.array.length;
			case IvyDataType.AssocArray: return !!value.assocArray.length;
			case IvyDataType.DataNodeRange:
				return !!value.dataRange && !value.dataRange.empty;
			case IvyDataType.ClassNode:
				// Basic check for ClassNode for emptyness is that it should not be null reference
				// If some interface method will be introduced to check for empty then we shall consider to check it too
				return value.classNode !is null;
			default:
				loger.error(`Cannot evaluate type: `, value.type, ` in logical context!`);
				break;
		}
		assert(false);
	}

	IvyData execLoop() 
	{
		import std.range: empty, back, popBack;

		loger.internalAssert(!_frameStack.empty, `_frameStack is empty`);
		loger.internalAssert(_frameStack.back, `_frameStack.back is null`);
		loger.internalAssert(_frameStack.back._callableObj, `_frameStack.back._callableObj is null`);
		loger.internalAssert(_frameStack.back._callableObj._codeObj, `_frameStack.back._callableObj._codeObj is null`);
		_pk = 0;
		_codeRange = _frameStack.back._callableObj._codeObj._instrs[];

		return execLoopImpl();
	}

	IvyData execLoopImpl(size_t exitFrames = 1)
	{
		import std.range: empty, back, popBack;
		import std.conv: to, text;
		import std.meta: AliasSeq;
		import std.typecons: tuple;

		execution_loop:
		while( _pk <= _codeRange.length )
		{
			if( _pk >= _codeRange.length ) // Ended with this code object
			{
				loger.write("_stack on code object end: ", _stack);
				loger.write("_frameStack on code object end: ", _frameStack);
				loger.internalAssert(!_frameStack.empty, "Frame stack shouldn't be empty yet'");

				// Else we expect to have result of directive on the stack
				loger.internalAssert(_stack.length == 1, "Frame stack should contain 1 item now! But there is: ", _stack);
				if( this._frameStack.length == exitFrames ) {
					// If there is the last frame it means that it is the last module frame.
					// We need to leave frame here for case when we want to execute specific function of module
					return _stack.back();
				}
				IvyData result = _stack.popBack();
				this.removeFrame(); // Exit out of this frame

				loger.internalAssert(_stack.back.type == IvyDataType.Integer, "Expected integer as instruction pointer, but got: ", _stack.back.type);
				_pk = cast(size_t) _stack.back.integer;
				_stack.popBack(); // Drop return address

				loger.internalAssert(!_frameStack.back._callableObj._codeObj._instrs.empty, "Code object to return is empty!");
				_codeRange = _frameStack.back._callableObj._codeObj._instrs[]; // Set old instruction range back
				_stack ~= result; // Get result back
				continue;
			} // if
			
			Instruction instr = _codeRange[_pk];
			switch( instr.opcode )
			{
				// Base arithmetic operations execution
				case OpCode.Add, OpCode.Sub, OpCode.Mul, OpCode.Div, OpCode.Mod:
				{
					// Right value was evaluated last so it goes first in the stack
					IvyData rightVal = _stack.popBack();

					IvyData leftVal = _stack.back;
					loger.internalAssert( ( leftVal.type == IvyDataType.Integer || leftVal.type == IvyDataType.Floating ) && leftVal.type == rightVal.type,
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
								if( leftVal.type == IvyDataType.Integer )
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
					// Right value was evaluated last so it goes first in the stack
					IvyData rightVal = _stack.popBack();

					IvyData leftVal = _stack.back;
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
									case IvyDataType.Undef, IvyDataType.Null:
										// Undef and Null are not less or equal to something
										_stack.back = IvyData(false);
										break;
									case IvyDataType.Integer:
										mixin( `_stack.back = leftVal.integer ` ~ compareOp[1] ~ ` rightVal.integer;` );
										break;
									case IvyDataType.Floating:
										mixin( `_stack.back = leftVal.floating ` ~ compareOp[1] ~ ` rightVal.floating;` );
										break;
									case IvyDataType.String:
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
					// Right value was evaluated last so it goes first in the stack
					IvyData rightVal = _stack.popBack();
					IvyData leftVal = _stack.popBack();

					_stack ~= IvyData( instr.opcode == OpCode.Equal? leftVal == rightVal: leftVal != rightVal );
					break;
				}

				// Load constant from programme data table into stack
				case OpCode.LoadSubscr:
				{
					import std.utf: toUTFindex, decode;
					import std.algorithm: canFind;

					loger.write(`OpCode.LoadSubscr. _stack: `, _stack);

					IvyData indexValue = _stack.popBack();

					IvyData aggr = _stack.popBack();
					loger.write(`OpCode.LoadSubscr. aggr: `, aggr);
					loger.write(`OpCode.LoadSubscr. indexValue: `, indexValue);

					loger.internalAssert(
						[IvyDataType.String, IvyDataType.Array, IvyDataType.AssocArray, IvyDataType.ClassNode].canFind(aggr.type),
						"Cannot execute LoadSubscr instruction. Aggregate value must be string, array, assoc array or class node!");

					switch( aggr.type )
					{
						case IvyDataType.String:
							loger.internalAssert(indexValue.type == IvyDataType.Integer,
								"Cannot execute LoadSubscr instruction. Index value for string aggregate must be integer!");

							// Index operation for string in D is little more complicated
							 size_t startIndex = aggr.str.toUTFindex(indexValue.integer); // Get code unit index by index of symbol
							 size_t endIndex = startIndex;
							 aggr.str.decode(endIndex); // decode increases passed index
							 loger.internalAssert(startIndex < aggr.str.length, `String slice start index must be less than str length`);
							 loger.internalAssert(endIndex <= aggr.str.length, `String slice end index must be less or equal to str length`);
							_stack ~= IvyData( aggr.str[startIndex..endIndex] );
							break;
						case IvyDataType.Array:
							loger.internalAssert(indexValue.type == IvyDataType.Integer,
								"Cannot execute LoadSubscr instruction. Index value for array aggregate must be integer!");
							loger.internalAssert(indexValue.integer < aggr.array.length, `Array index must be less than array length`);
							_stack ~= aggr.array[indexValue.integer];
							break;
						case IvyDataType.AssocArray:
							loger.internalAssert(indexValue.type == IvyDataType.String,
								"Cannot execute LoadSubscr instruction. Index value for assoc array aggregate must be string!");
							loger.internalAssert(indexValue.str in aggr.assocArray,
								`Assoc array key "`, indexValue.str, `" must be present in assoc array`);
							_stack ~= aggr.assocArray[indexValue.str];
							break;
						case IvyDataType.ClassNode:
							if( indexValue.type == IvyDataType.Integer ) {
								_stack ~= aggr.classNode[indexValue.integer];
							} else if( indexValue.type == IvyDataType.String ) {
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

					IvyData endValue = _stack.popBack();
					IvyData beginValue = _stack.popBack();
					IvyData aggr = _stack.popBack();

					loger.write(`OpCode.LoadSlice. aggr: `, aggr);
					loger.write(`OpCode.LoadSlice. beginValue: `, beginValue);
					loger.write(`OpCode.LoadSlice. endValue: `, endValue);

					loger.internalAssert(
						[IvyDataType.String, IvyDataType.Array, IvyDataType.ClassNode].canFind(aggr.type),
						"Cannot execute LoadSlice instruction. Aggregate value must be string, array, assoc array or class node!");
					
					loger.internalAssert(beginValue.type == IvyDataType.Integer,
						"Cannot execute LoadSlice instruction. Begin value of slice must be integer!");

					loger.internalAssert(endValue.type == IvyDataType.Integer,
						"Cannot execute LoadSlice instruction. End value of slice must be integer!");

					size_t startIndex; size_t endIndex; size_t len;
					if( [IvyDataType.String, IvyDataType.Array].canFind(aggr.type) )
					{
						if( aggr.type == IvyDataType.String )
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
						case IvyDataType.String:
							_stack ~= IvyData( aggr.str[startIndex..endIndex] );
							break;
						case IvyDataType.Array:
							_stack ~= aggr.array[beginValue.integer..endValue.integer];
							break;
						case IvyDataType.ClassNode:
							// Class node must have it's own range checks
							_stack ~= IvyData(aggr.classNode[beginValue.integer..endValue.integer]);
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

					IvyData indexValue = _stack.popBack();
					IvyData value = _stack.popBack();
					IvyData aggr = _stack.popBack();

					// Do not support setting individual characters of strings for now and maybe forever... Who knowns how it turns...
					loger.internalAssert(
						[IvyDataType.Array, IvyDataType.AssocArray, IvyDataType.ClassNode].canFind(aggr.type),
						"Cannot execute StoreSubscr instruction. Aggregate value must be array, assoc array or class node!");

					switch( aggr.type )
					{
						case IvyDataType.Array:
							loger.internalAssert(indexValue.type == IvyDataType.Integer,
								"Cannot execute StoreSubscr instruction. Index value for array aggregate must be integer!");
							loger.internalAssert(indexValue.integer < aggr.array.length, `Array index must be less than array length`);
							aggr[indexValue.integer] = value;
							break;
						case IvyDataType.AssocArray:
							loger.internalAssert(indexValue.type == IvyDataType.String,
								"Cannot execute StoreSubscr instruction. Index value for assoc array aggregate must be string!");
							aggr[indexValue.str] = value;
							break;
						case IvyDataType.ClassNode:
							if( indexValue.type == IvyDataType.Integer ) {
								aggr[indexValue.integer] = value;
							} else if( indexValue.type == IvyDataType.String ) {
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
					IvyData rightVal = _stack.popBack();

					IvyData leftVal = _stack.back;
					loger.internalAssert( ( leftVal.type == IvyDataType.String || leftVal.type == IvyDataType.Array ) && leftVal.type == rightVal.type,
						`Left and right values for concatenation operation must have the same string or array type!`
					);

					if( leftVal.type == IvyDataType.String ) {
						_stack.back = leftVal.str ~ rightVal.str;
					} else {
						_stack.back = leftVal.array ~ rightVal.array;
					}

					break;
				}

				case OpCode.Append:
				{
					loger.write("OpCode.Append _stack: ", _stack);
					IvyData rightVal = _stack.popBack();

					loger.internalAssert(_stack.back.type == IvyDataType.Array,
						"Left operand for Append instruction expected to be array, but got: ", _stack.back.type);

					_stack.back ~= rightVal;

					break;
				}

				case OpCode.Insert:
				{
					import std.array: insertInPlace;

					loger.write("OpCode.Insert _stack: ", _stack);
					IvyData positionNode = _stack.popBack();
					import std.algorithm: canFind;
					loger.internalAssert(
						[IvyDataType.Integer, IvyDataType.Null, IvyDataType.Undef].canFind(positionNode.type),
						"Cannot execute Insert instruction. Position argument expected to be an integer or empty (for append), but got: ", positionNode.type
					);

					IvyData valueNode = _stack.popBack();

					IvyData listNode = _stack.back;
					loger.internalAssert(
						listNode.type == IvyDataType.Array,
						"Cannot execute Insert instruction. Aggregate must be an array, but got: ", listNode.type
					);
					size_t pos;
					if( positionNode.type != IvyDataType.Integer ) {
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
					assert(false, `Not implemented yet!`);
				}

				// Useless unary plus operation
				case OpCode.UnaryPlus:
				{
					loger.internalAssert(_stack.back.type == IvyDataType.Integer || _stack.back.type == IvyDataType.Floating,
						`Operand for unary plus operation must have integer or floating type!` );

					// Do nothing for now:)
					break;
				}

				case OpCode.UnaryMin:
				{
					loger.internalAssert(_stack.back.type == IvyDataType.Integer || _stack.back.type == IvyDataType.Floating,
						`Operand for unary minus operation must have integer or floating type!`);

					if( _stack.back.type == IvyDataType.Integer ) {
						_stack.back = - _stack.back.integer;
					} else {
						_stack.back = - _stack.back.floating;
					}

					break;
				}

				case OpCode.UnaryNot:
				{
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
					IvyData varValue = _stack.popBack();

					IvyData varNameNode = getModuleConstCopy(instr.arg);
					loger.internalAssert(varNameNode.type == IvyDataType.String, `Cannot execute `, instr.opcode, ` instruction. Variable name const must have string type!`);


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
					IvyData varNameNode = getModuleConstCopy(instr.arg);
					loger.internalAssert(varNameNode.type == IvyDataType.String, `Cannot execute LoadName instruction. Variable name operand must have string type!`);

					_stack ~= getValue( varNameNode.str );
					break;
				}

				case OpCode.ImportModule:
				{
					loger.internalAssert(_stack.back.type == IvyDataType.String, "Cannot execute ImportModule instruction. Module name operand must be a string!");
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

						CallableObject callableObj = new CallableObject(moduleName, codeObject, CallableKind.Module);

						IvyData dataDict = ["__scopeName__": moduleName];
						newFrame(callableObj, null, dataDict, false); // Create entry point module frame
						_moduleFrames[moduleName] = _frameStack.back; // We need to store module frame into storage

						// Put module root frame into previous execution frame`s stack block (it will be stored with StoreName)
						_stack ~= IvyData(_frameStack.back);
						// Decided to put return address into parent frame`s stack block instead of current
						_stack ~= IvyData(_pk+1);

						_stack.addStackBlock(); // Add new stack block for execution frame

						// Preparing to run code object in newly created frame
						_codeRange = codeObject._instrs[];
						_pk = 0;

						continue execution_loop; // Skip _pk increment
					}
					else
					{
						// Put module root frame into previous execution frame (it will be stored with StoreName)
						_stack ~= IvyData(_moduleFrames[moduleName]); 
						// As long as module returns some value at the end of execution, so put fake value there for consistency
						_stack ~= IvyData();
					}

					break;
				}

				case OpCode.FromImport:
				{
					import std.algorithm: map;
					import std.array: array;

					loger.internalAssert(_stack.back.type == IvyDataType.Array, "Cannot execute FromImport instruction. Expected list of symbol names");
					string[] symbolNames = _stack.back.array.map!( it => it.str ).array;
					_stack.popBack();

					loger.internalAssert(_stack.back.type == IvyDataType.ExecutionFrame, "Cannot execute FromImport instruction. Expected execution frame argument");

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
					loger.write(`GetDataRange begin _stack: `, _stack);
					loger.internalAssert([
							IvyDataType.Array,
							IvyDataType.AssocArray,
							IvyDataType.DataNodeRange,
							IvyDataType.ClassNode
						].canFind(_stack.back.type),
						`Expected array or assoc array as loop aggregate, but got: `,
						_stack.back.type
					);

					IvyData dataRange;
					switch( _stack.back.type )
					{
						case IvyDataType.Array:
						{
							dataRange = new ArrayRange(_stack.back.array);
							break;
						}
						case IvyDataType.ClassNode:
						{
							loger.internalAssert(_stack.back.classNode, "Aggregate class node for loop is null!");
							dataRange = IvyData(_stack.back.classNode[]);
							break;
						}
						case IvyDataType.AssocArray:
						{
							dataRange = new AssocArrayRange(_stack.back.assocArray);
							break;
						}
						case IvyDataType.DataNodeRange:
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
					loger.internalAssert(_stack.back.type == IvyDataType.DataNodeRange, `Expected DataNodeRange` );
					auto dataRange = _stack.back.dataRange;
					loger.write("RunLoop dataRange.empty: ", dataRange.empty);
					if( dataRange.empty )
					{
						loger.write("RunLoop. Data range is exaused, so exit loop. _stack is: ", _stack);
						loger.internalAssert(instr.arg < _codeRange.length, `Cannot jump after the end of code object`);
						_pk = instr.arg;
						loger.internalAssert(_stack.back.type == IvyDataType.DataNodeRange, "RunLoop. Expected DataNodeRange to drop");
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
					loger.internalAssert(instr.arg < _codeRange.length, `Cannot jump after the end of code object`);

					_pk = instr.arg;
					continue execution_loop; // Skip _pk increment
				}

				case OpCode.JumpIfTrue, OpCode.JumpIfFalse, OpCode.JumpIfTrueOrPop, OpCode.JumpIfFalseOrPop:
				{
					import std.algorithm: canFind;

					loger.internalAssert(instr.arg < _codeRange.length, `Cannot jump after the end of code object`);
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
						continue execution_loop; // Skip _pk increment
					}
					break;
				}

				case OpCode.Return:
				{
					// Set instruction index at the end of code object in order to finish 
					_pk = _codeRange.length;
					IvyData result = _stack.back;
					// Erase all from the current stack
					_stack.popBackN(_stack.length);
					_stack ~= result; // Put result on the stack
					continue execution_loop; // Skip _pk increment
				}

				case OpCode.PopTop:
				{
					_stack.popBack();
					break;
				}

				// Swaps two top items on the stack
				case OpCode.SwapTwo:
				{
					loger.internalAssert(_stack.length > 1, "Stack must have at least two items to swap");
					IvyData tmp = _stack[$-1];
					_stack[$-1] = _stack[$-2];
					_stack[$-2] = tmp;
					break;
				}

				case OpCode.LoadDirective:
				{
					import std.conv: text;
					
					size_t stackArgCount = instr.arg;
					loger.internalAssert(stackArgCount > 1, "Directive load must have at least 2 items in stack!");
					loger.internalAssert(stackArgCount <= _stack.length, "Not enough arguments in execution stack");

					IvyData codeObjNode = _stack[_stack.length - stackArgCount];
					IvyData varNameNode = _stack[_stack.length - stackArgCount + 1];
					loger.internalAssert(codeObjNode.type == IvyDataType.CodeObject, `Expected CodeObject`, codeObjNode, `   `, varNameNode);
					loger.internalAssert(varNameNode.type == IvyDataType.String, `Expected String as directive name`);
					CodeObject codeObj = codeObjNode.codeObject;
					loger.internalAssert(codeObj, `Code object operand for directive loading instruction is null`);

					if( stackArgCount > 2 )
					{
						size_t stackArgsProcessed = 2;
						foreach( ref attrBlock; codeObj._attrBlocks )
						{
							size_t blockArgCount;
							DirAttrKind blockType;
							switch( attrBlock.kind ) {
								case DirAttrKind.NamedAttr, DirAttrKind.ExprAttr:
									IvyData blockHeader = _stack.popBack(); // Get block header
									++stackArgsProcessed;
									loger.internalAssert(blockHeader.type == IvyDataType.Integer, `Expected integer as arguments block header!`);
									blockArgCount = blockHeader.integer >> _stackBlockHeaderSizeOffset;
									blockType = cast(DirAttrKind)(blockHeader.integer & _stackBlockHeaderTypeMask);
									// Bit between block size part and block type must always be zero
									loger.internalAssert((blockHeader.integer & _stackBlockHeaderCheckMask) == 0, `Seeems that stack is corrupted`);
									break;
								default: break;
							}

							
							switch( attrBlock.kind )
							{
								case DirAttrKind.NamedAttr: {
									bool[string] passedArgs;
									
									foreach( k; 0..blockArgCount )
									{
										IvyData attrValueNode = _stack.popBack(); ++stackArgsProcessed;

										IvyData attrNameNode = _stack.popBack(); ++stackArgsProcessed;
										loger.internalAssert(attrNameNode.type == IvyDataType.String, "Named attribute name must be string!");
										loger.internalAssert(attrNameNode.str !in passedArgs, "Duplicate named argument detected!");
										loger.internalAssert(attrNameNode.str in attrBlock.namedAttrs, "Unexpected argument detected!");

										attrBlock.namedAttrs[attrNameNode.str].defaultValue = attrValueNode;
										passedArgs[attrNameNode.str] = true;
									}
									loger.internalAssert(passedArgs.length == blockArgCount, `Processed and required default arguments doesn't match!`);
									break;
								}
								case DirAttrKind.ExprAttr:
								{
									foreach( j; 0..blockArgCount )
									{
										// Set last items with default values from stack
										attrBlock.exprAttrs[attrBlock.exprAttrs.length - 1 - j].defaultValue = this._stack.popBack();
										++stackArgsProcessed;
									}
									break;
								}
								default: break;
							}
						}
						loger.internalAssert(stackArgsProcessed == stackArgCount, `Processed and required stack arguments doesn't match!`, ` processed`, stackArgsProcessed, ` required: `, stackArgCount);
					}

					loger.internalAssert(_stack.popBack().type == IvyDataType.String, `Expected String as directive name`);
					loger.internalAssert(_stack.popBack().type == IvyDataType.CodeObject, `Expected CodeObject`);

					setLocalValue(
						varNameNode.str,
						IvyData(new CallableObject(
							varNameNode.str,
							codeObjNode.codeObject
						))
					); // Put this directive in context
					_stack ~= IvyData(); // We should return something
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

					IvyData callableNode = _stack[_stack.length - stackArgCount];
					loger.write("RunCallable callable type: ", callableNode.type);
					loger.internalAssert(callableNode.type == IvyDataType.Callable, `Expected Callable operand`);

					CallableObject callableObj = callableNode.callable;
					loger.internalAssert(callableObj, `Callable object is null!` );
					loger.write("RunCallable name: ", callableObj._name);

					DirAttrsBlock!(false)[] attrBlocks = callableObj.attrBlocks;
					loger.write("RunCallable callableObj.attrBlocks: ", attrBlocks);

					loger.write("RunCallable creating execution frame...");
					IvyData dataDict;
					dataDict["__scopeName__"] = callableObj._name; // Allocating scope
					newFrame(callableObj, _getModuleFrame(callableObj), dataDict, callableObj.isNoscope);

					if( stackArgCount > 1 ) // If args count is 1 - it mean that there is no arguments
					{
						size_t stackArgsProcessed = 0;
						foreach( attrBlock; callableObj.attrBlocks )
						{
							// Getting args block metainfo
							size_t blockArgCount;
							DirAttrKind blockType;
							switch( attrBlock.kind ) {
								case DirAttrKind.NamedAttr, DirAttrKind.ExprAttr:
									IvyData blockHeader = _stack.popBack(); // Get block header
									++stackArgsProcessed;
									loger.internalAssert(blockHeader.type == IvyDataType.Integer, `Expected integer as arguments block header!`);
									blockArgCount = blockHeader.integer >> _stackBlockHeaderSizeOffset;
									loger.write("blockArgCount: ", blockArgCount);
									blockType = cast(DirAttrKind)( blockHeader.integer & _stackBlockHeaderTypeMask );
									// Bit between block size part and block type must always be zero
									loger.internalAssert( (blockHeader.integer & _stackBlockHeaderCheckMask) == 0, `Seeems that stack is corrupted` );
									loger.write("blockType: ", blockType);
									break;
								default: break;
							}

							switch( attrBlock.kind )
							{
								case DirAttrKind.NamedAttr:
								{
									bool[string] passedArgs;
									
									foreach( k; 0..blockArgCount )
									{
										IvyData attrValueNode = _stack.popBack(); ++stackArgsProcessed;
										loger.write(`RunCallable debug, _stack is: `, _stack);

										IvyData attrNameNode = _stack.popBack(); ++stackArgsProcessed;
										loger.internalAssert(attrNameNode.type == IvyDataType.String, "Named attribute name must be string!");
										loger.internalAssert(attrNameNode.str !in passedArgs, "Duplicate named argument detected!");
										loger.internalAssert(attrNameNode.str in attrBlock.namedAttrs, "Unexpected argument detected!");

										setLocalValue(attrNameNode.str, attrValueNode);
										passedArgs[attrNameNode.str] = true;
									}

									foreach( attrName, namedAttr; attrBlock.namedAttrs )
									{
										if( attrName in passedArgs ) {
											continue; // Attribute already passes to directive
										}
										// Do deep copy of default value
										setLocalValue(attrName, deeperCopy(namedAttr.defaultValue));
									}
									break;
								}
								case DirAttrKind.ExprAttr:
								{
									foreach( j; 0..attrBlock.exprAttrs.length )
									{
										size_t backIndex = attrBlock.exprAttrs.length - 1 - j;
										auto exprAttr = attrBlock.exprAttrs[backIndex];
										if( backIndex < blockArgCount )
										{
											IvyData attrValue = this._stack.popBack(); ++stackArgsProcessed;
											setLocalValue(exprAttr.name, attrValue);
										}
										else {
											setLocalValue(exprAttr.name, exprAttr.defaultValue);
										}
									}
									break;
								}
								default: break;
							}
						}
					}
					loger.write("_stack after parsing all arguments: ", _stack);

					loger.internalAssert(_stack.back.type == IvyDataType.Callable, `Expected callable object operand in call operation, but got: `, _stack);
					_stack.popBack(); // Drop callable object from stack

					if( callableObj._codeObj )
					{
						_stack ~= IvyData(_pk+1); // Put next instruction index on the stack to return at
						_stack.addStackBlock();
						_codeRange = callableObj._codeObj._instrs[]; // Set new instruction range to execute
						_pk = 0;
						continue execution_loop; // Skip _pk increment
					}
					else
					{
						loger.internalAssert(callableObj._dirInterp, `Callable object expected to have non null code object or native directive interpreter object!`);
						_stack.addStackBlock();
						callableObj._dirInterp.interpret(this); // Run native directive interpreter

						// Else we expect to have result of directive on the stack
						loger.internalAssert(_stack.length, "Stack should contain 1 item empty now!");

						// If frame stack contains last frame - it means that we nave done with programme
						if( this._frameStack.length == exitFrames ) {
							return _stack.back();
						}
						IvyData result = _stack.popBack();
						this.removeFrame(); // Drop frame from stack after end of execution
						_stack ~= result; // Get result back
					}

					break;
				}

				case OpCode.MakeArray:
				{
					size_t arrayLen = instr.arg;
					IvyData[] newArray;
					newArray.length = arrayLen; // Preallocating is good ;)
					loger.write("MakeArray _stack: ", _stack);
					loger.write("MakeArray arrayLen: ", arrayLen);
					for( size_t i = arrayLen; i > 0; --i ) {
						// We take array items from the tail, so we must consider it!
						newArray[i-1] = _stack.popBack();
					}
					_stack ~= IvyData(newArray);

					break;
				}

				case OpCode.MakeAssocArray:
				{
					size_t aaLen = instr.arg;
					IvyData[string] newAssocArray;
					newAssocArray[`__mentalModuleMagic_0451__`] = 451;
					newAssocArray.remove(`__mentalModuleMagic_0451__`);

					for( size_t i = 0; i < aaLen; ++i )
					{
						IvyData val = _stack.back;
						_stack.popBack();

						loger.internalAssert(_stack.back.type == IvyDataType.String, `Expected string as assoc array key`);

						newAssocArray[_stack.back.str] = val;
						_stack.popBack();
					}
					_stack ~= IvyData(newAssocArray);
					break;
				}

				case OpCode.MarkForEscape: {
					_stack.back.escapeState = cast(NodeEscapeState) instr.arg;
					break;
				}

				default:
				{
					loger.internalAssert(false, "Unexpected code of operation: ", instr.opcode);
					break;
				}
			} // switch
			++_pk;

		} // execution_loop:

		assert(false, `Failed to get result of execution`);
	} // void execLoop()

	ExecutionFrame _getModuleFrame(CallableObject callableObj) {
		string moduleName = callableObj._codeObj? callableObj._codeObj._moduleObj._name: "__global__";
		ExecutionFrame moduleFrame = _moduleFrames.get(moduleName, null);
		loger.internalAssert( moduleFrame, `Module frame with name: `, moduleFrame, ` of callable: `, callableObj._name, ` does not exist!` );
		return moduleFrame;
	}

	IvyData runModuleDirective(string name, IvyData args = IvyData())
	{
		import std.exception: enforce;
		import std.algorithm: canFind;
		enforce([
			IvyDataType.Undef, IvyDataType.Null, IvyDataType.AssocArray
		].canFind(args.type), `Expected Undef, Null or AssocArray as list of directive arguments`);

		loger.internalAssert(this.currentFrame, `Could not get module frame!`);

		// Find desired directive by name in current module frame
		IvyData callableNode = this.currentFrame.getValue(name);
		loger.internalAssert(callableNode.type == IvyDataType.Callable, `Expected Callable!`);

		loger.internalAssert(_stack.length < 2, `Expected 0 or 1 items in stack!`);
		if( _stack.length == 1 ) {
			_stack.popBack(); // Drop old result from stack
		}

		_stack ~= callableNode;
		size_t stackItemsCount = 1; // Pass callable at least

		// Put params into stack
		foreach( attrBlock; callableNode.callable.attrBlocks )
		{
			switch( attrBlock.kind )
			{
				case DirAttrKind.ExprAttr:
				{
					size_t argCount = 0;
					if( args.type == IvyDataType.AssocArray )
					{
						foreach( exprAttr; attrBlock.exprAttrs )
						{
							if( auto valuePtr = exprAttr.name in args.assocArray ) {
								_stack ~= *valuePtr; ++stackItemsCount; ++argCount;
							}
						}
					}

					// Add instruction to load value that consists of number of positional arguments in block and type of block
					size_t blockHeader = ( argCount << _stackBlockHeaderSizeOffset ) + DirAttrKind.ExprAttr;
					_stack ~= IvyData(blockHeader);
					++stackItemsCount; // We should count args block header
					break;
				}
				case DirAttrKind.NamedAttr:
				{
					size_t argCount = 0;
					if( args.type == IvyDataType.AssocArray )
					{
						foreach( attrName, namedAttr; attrBlock.namedAttrs )
						{
							if( auto valuePtr = attrName in args.assocArray )
							{
								_stack ~= IvyData(attrName); ++stackItemsCount;
								_stack ~= *valuePtr; ++stackItemsCount;
								++argCount;
							}
						}
					}

					// Add instruction to load value that consists of number of positional arguments in block and type of block
					size_t blockHeader = ( argCount << _stackBlockHeaderSizeOffset ) + DirAttrKind.NamedAttr;
					_stack ~= IvyData(blockHeader);
					++stackItemsCount; // We should count args block header
					break;
				}
				default: break;
			}
		}
		_pk = 0;
		_codeRange = [Instruction(OpCode.RunCallable, stackItemsCount)];
		return this.execLoopImpl(2);
	}
}
