module ivy.interpreter.interpreter;

// If IvyTotalDebug is defined then enable parser debug
version(IvyTotalDebug) version = IvyInterpreterDebug;


class Interpreter
{
	import ivy.types.code_object: CodeObject;
	import ivy.types.module_object: ModuleObject;
	import ivy.types.callable_object: CallableObject;
	import ivy.types.data: IvyDataType, IvyData;
	import ivy.interpreter.execution_frame: ExecutionFrame;
	import ivy.interpreter.exec_stack: ExecStack;
	import ivy.interpreter.directive.iface: IDirectiveInterpreter;
	import ivy.interpreter.module_objects_cache: ModuleObjectsCache;
	import ivy.interpreter.directive.factory: InterpreterDirectiveFactory;
	import ivy.types.data.async_result: AsyncResult, AsyncResultState;
	import ivy.loger: LogInfo, LogerProxyImpl, LogInfoType;
	import ivy.bytecode: Instruction, OpCode;
	import ivy.types.symbol.dir_attr: DirAttr;

public:
	alias LogerMethod = void delegate(LogInfo);

	// Stack of execution frames with directives or modules local data
	ExecutionFrame[] _frameStack;

	// Global execution frame used for some global built-in data
	ExecutionFrame _globalFrame;

	// Storage for execution frames of imported modules
	ExecutionFrame[string] _moduleFrames;

	// Storage for bytecode code and initial constant data for modules
	ModuleObjectsCache _moduleObjCache;

	InterpreterDirectiveFactory _directiveFactory;

	ExecStack _stack;

	// Loger method used to send error and debug messages
	LogerMethod _logerMethod;

	size_t _pk; // Programme counter
	Instruction[] _codeRange; // Current code range we executing

	this(
		ModuleObjectsCache moduleObjCache,
		InterpreterDirectiveFactory directiveFactory,
		string mainModuleName,
		IvyData dataDict,
		LogerMethod logerMethod = null
	) {
		import std.range: back;

		_logerMethod = logerMethod;
		_moduleObjCache = moduleObjCache;
		_directiveFactory = directiveFactory;
		log.internalAssert(moduleObjCache.get(mainModuleName), `Cannot get main module from module objects!`);

		log.write(`Passed dataDict: `, dataDict);

		CallableObject rootCallableObj = new CallableObject(moduleObjCache.get(mainModuleName).mainCodeObject);

		//IvyData globalDataDict;
		//globalDataDict["_ivyMethod"] = "__global__"; // Allocating dict
		_globalFrame = new ExecutionFrame(null, null, _logerMethod);
		_moduleFrames["__global__"] = _globalFrame; // We need to add entry point module frame to storage manually
		//log.write(`_globalFrame._dataDict: `, _globalFrame._dataDict);

		//dataDict["_ivyMethod"] = "__main__"; // Allocating a dict if it's not
		//dataDict["_ivyModule"] = mainModuleName;
		newFrame(rootCallableObj, null); // Create entry point module frame
		this._stack.addStackBlock();
		_moduleFrames[mainModuleName] = this._frameStack.back; // We need to add entry point module frame to storage manually

		this._addDirInterpreters(directiveFactory.interps);
	}

	private void _addNativeDirInterp(string name, IDirectiveInterpreter dirInterp)
	{
		log.internalAssert(name.length && dirInterp, `Directive name is empty or direxecInterp is null!`);

		// Add custom native directive interpreters to global scope
		_globalFrame.setValue(name, IvyData(new CallableObject(name, dirInterp)));
	}

	// Method used to set custom global directive interpreters
	void _addDirInterpreters(IDirectiveInterpreter[string] dirInterps)
	{
		foreach( name, dirInterp; dirInterps ) {
			this._addNativeDirInterp(name, dirInterp);
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

	static struct LogerProxy
	{
		import ivy.interpreter.exception: IvyInterpretException;

		mixin LogerProxyImpl!(IvyInterpretException, isDebugMode);
		Interpreter interp;

		string sendLogInfo(LogInfoType logInfoType, string msg)
		{
			import ivy.loger: getShortFuncName;

			import std.algorithm: map, canFind;
			import std.array: join;
			import std.conv: text;

			// Put name of module and line where event occured
			msg = "Ivy module: " ~ interp.currentModule.symbol.name ~ ":" ~ interp.currentInstrLine().text
				~ ", OpCode: " ~ interp.currentOpCode().text ~ "\n" ~ msg;

			debug {
				if( [LogInfoType.error, LogInfoType.internalError].canFind(logInfoType) )
				{
					// Give additional debug data if error occured
					string dataStack = interp._stack._stack.map!(
						(it) => `<div style="padding: 8px; border-bottom: 1px solid gray;">` ~ it.toHTMLDebugString() ~ `</div>`
					).join("\n");
					string callStack = interp.callStackInfo.map!(
						(it) => `<div style="padding: 8px; border-bottom: 1px solid gray;">` ~ it ~ `</div>`
					).join("\n");
					msg ~= "\n\n<h3 style=\"color: darkgreen;\">Call stack (most recent call last):</h3>\n" ~ callStack 
						~ "\n\n<h3 style=\"color: darkgreen;\">Data stack:</h3>\n" ~ dataStack;
				}
			}

			if( interp._logerMethod !is null ) {
				interp._logerMethod(LogInfo(
					msg,
					logInfoType,
					getShortFuncName(func),
					file,
					line,
					interp.currentModule.symbol.name,
					interp.currentInstrLine()
				));
			}
			return msg;
		}
	}

	ModuleObject currentModule() @property
	{
		if( CodeObject codeObject = this.currentCodeObject ) {
			return codeObject.moduleObject;
		}
		return null;
	}

	CallableObject currentCallable() @property {
		return this.currentFrame.callable;
	}

	CodeObject currentCodeObject()
	{
		CallableObject callable = this.currentCallable;
		if( !callable.isNative ) {
			return callable.codeObject;
		}
		return null;
	}

	CallableObject[] callableStack()
	{
		import std.algorithm: map;
		import std.array: array;
		return this._frameStack.map!( (frame) => frame.callable )().array();
	}

	string[] callStackInfo()
	{
		string[] res;
		foreach( callable; this.callableStack() )
		{
			if( callable.isNative ) {
				res ~= `Directive interp: ` ~ callable.symbol.name;
			} else {
				res ~= `Module: ` ~ callable.codeObject.moduleObject.fileName ~ `, Directive: ` ~ callable.symbol.name;
			}
		}
		return res;
	}

	size_t currentInstrLine()
	{
		if( CodeObject codeObject = this.currentCodeObject ) {
			return codeObject.getInstrLine(this._pk);
		}
		return 0;
	}

	OpCode currentOpCode()
	{
		if( CodeObject codeObject = this.currentCodeObject ) {
			if( this._pk < codeObject._instrs.length ) {
				return cast(OpCode) codeObject._instrs[this._pk].opcode;
			}
		}
		return OpCode.InvalidCode;
	}


	LogerProxy log(string func = __FUNCTION__, string file = __FILE__, int line = __LINE__)	{
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
		log.internalAssert(!this._frameStack.empty, `Execution frame stack is empty!`);

		foreach_reverse( frame; this._frameStack )
		{
			if( frame.hasOwnScope ) {
				return frame;
			}
		}
		log.internalAssert(false, `Cannot get current independent execution frame!`);
		return null;
	}

	/++ Returns nearest execution frame from _frameStack +/
	ExecutionFrame currentFrame() @property
	{
		import std.range: empty, back;
		log.internalAssert(!this._frameStack.empty, "Execution frame stack is empty!");
		return this._frameStack.back;
	}

	void newFrame(CallableObject callable, ExecutionFrame modFrame)
	{
		this._frameStack ~= new ExecutionFrame(callable, modFrame, this._logerMethod);
		log.write(`Enter new execution frame for callable: `, callable.symbol.name);
	}

	void removeFrame()
	{
		import std.range: empty, back, popBack;
		log.internalAssert(!this._frameStack.empty, `Execution frame stack is empty!`);
		this._stack.removeStackBlock();
		this._frameStack.popBack();
	}

	static struct FrameSearchRes
	{
		ExecutionFrame frame;
		IvyData* node;
	}

	// Returns execution frame for variable
	FrameSearchRes findValue(bool globalSearch = false)(string varName)
	{
		import std.range: back;
		log.write(`Starting to search for variable: `, varName);

		IvyData* node;
		for( size_t i = this._frameStack.length; i > 0; --i )
		{
			ExecutionFrame frame = this._frameStack[i-1];

			static if( globalSearch ) {
				node = frame.findGlobalValue(varName);
			} else {
				node = frame.findValue(varName);
			}
			
			if( node !is null ) {
				return FrameSearchRes(frame, node);
			} else if( frame.hasOwnScope() ) {
				break;
			}
		}

		static if( globalSearch )
		{
			node = this._globalFrame.findGlobalValue(varName);
			if( node !is null ) {
				return FrameSearchRes(this._globalFrame, node);
			}
		}
		// By default store vars in local frame
		return FrameSearchRes(this._frameStack.back, null);
	}

	ExecutionFrame findVarFrame(bool globalSearch)(string varName)
	{
		log.write(`Searching frame for variable: ` ~ varName);
		
		FrameSearchRes res = this.findValue!globalSearch(varName);
		log.internalAssert(res.frame !is null, `Expected frame to store variable`);
		return res.frame;
	}

	IvyData getValue(string varName)
	{
		FrameSearchRes res = this.findValue!(/*globalSearch=*/false)(varName);
		if( res.node is null ) {
			log.error("Undefined variable with name '", varName, "'");
		}
		return *res.node;
	}

	IvyData getGlobalValue(string varName)
	{
		FrameSearchRes res = this.findValue!(/*globalSearch=*/true)(varName);
		if( res.node is null ) {
			log.error("Undefined variable with name '", varName, "'");
		}
		return *res.node;
	}

	void setValue(string varName, IvyData value)
	{
		this.findVarFrame!(/*globalSearch=*/false)(varName).setValue(varName, value);
	}

	void setGlobalValue(string varName, IvyData value)
	{
		this.findVarFrame!(/*globalSearch=*/true)(varName).setGlobalValue(varName, value);
	}

	IvyData getModuleConst( size_t index )
	{
		ModuleObject moduleObject = this.currentModule;
		log.internalAssert(moduleObject !is null, `Unable to get current module object`);

		return moduleObject.getConst(index);
	}

	IvyData getModuleConstCopy( size_t index )
	{
		return deeperCopy( getModuleConst(index) );
	}

	AsyncResult execLoop() 
	{
		CodeObject codeObject = this.currentCodeObject;
		log.internalAssert(codeObject !is null, `Expected current code object to run`);
		this._pk = 0;
		this._codeRange = codeObject._instrs[];
		AsyncResult fResult = new AsyncResult;

		try {
			execLoopImpl(fResult);
		} catch( Throwable ex ) {
			fResult.reject(ex);
		}
		return fResult;
	}

	void execLoopImpl(AsyncResult fResult, size_t exitFrames = 1)
	{
		import std.range: empty, back, popBack;
		import std.conv: to, text;
		import std.meta: AliasSeq;
		import std.typecons: tuple;

		execution_loop:
		while( this._pk <= this._codeRange.length )
		{
			if( this._pk >= this._codeRange.length ) // Ended with this code object
			{
				log.write("this._stack on code object end: ", this._stack);
				log.write("this._frameStack on code object end: ", this._frameStack);
				log.internalAssert(!this._frameStack.empty, "Frame stack shouldn't be empty yet'");

				// Else we expect to have result of directive on the stack
				log.internalAssert(this._stack.length == 1, "Frame stack should contain 1 item now! But there is: ", this._stack);
				if( this._frameStack.length == exitFrames ) {
					// If there is the last frame it means that it is the last module frame.
					// We need to leave frame here for case when we want to execute specific function of module
					fResult.resolve(this._stack.back());
					return;
				}
				IvyData result = this._stack.popBack();
				this.removeFrame(); // Exit out of this frame

				IvyData instrNode = this._stack.popBack();
				log.internalAssert(instrNode.type == IvyDataType.Integer, "Expected integer as instruction pointer");
				this._pk = cast(size_t) instrNode.integer;

				CodeObject codeObject = this.currentCodeObject;
				log.internalAssert(codeObject !is null && !codeObject._instrs.empty, `Expected non-empty code object`);

				this._codeRange = codeObject._instrs[]; // Set old instruction range back
				this._stack.push(result); // Get result back
				continue;
			} // if
			
			Instruction instr = this._codeRange[this._pk];
			switch( instr.opcode )
			{
				// Base arithmetic operations execution
				case OpCode.Add:
				case OpCode.Sub:
				case OpCode.Mul:
				case OpCode.Div:
				case OpCode.Mod:
				{
					// Right value was evaluated last so it goes first in the stack
					IvyData rightVal = this._stack.popBack();

					IvyData leftVal = this._stack.back;
					log.internalAssert( ( leftVal.type == IvyDataType.Integer || leftVal.type == IvyDataType.Floating ) && leftVal.type == rightVal.type,
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
									mixin( `this._stack.back = leftVal.integer ` ~ arithmOp[1] ~ ` rightVal.integer;` );
								}
								else
								{
									mixin( `this._stack.back = leftVal.floating ` ~ arithmOp[1] ~ ` rightVal.floating;` );
								}
								break arithm_op_switch;
							}
						}
						default:
							log.internalAssert(false, `This should never happen!`);
					}
					break;
				}

				// Comparision operations
				case OpCode.LT:
				case OpCode.GT:
				case OpCode.LTEqual:
				case OpCode.GTEqual:
				{
					import std.conv: to;
					// Right value was evaluated last so it goes first in the stack
					IvyData rightVal = this._stack.popBack();

					IvyData leftVal = this._stack.back;
					log.internalAssert(leftVal.type == rightVal.type, `Left and right operands of comparision must have the same type`);

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
									case IvyDataType.Undef: case IvyDataType.Null:
										// Undef and Null are not less or equal to something
										this._stack.back = IvyData(false);
										break;
									case IvyDataType.Integer:
										mixin( `this._stack.back = leftVal.integer ` ~ compareOp[1] ~ ` rightVal.integer;` );
										break;
									case IvyDataType.Floating:
										mixin( `this._stack.back = leftVal.floating ` ~ compareOp[1] ~ ` rightVal.floating;` );
										break;
									case IvyDataType.String:
										mixin( `this._stack.back = leftVal.str ` ~ compareOp[1] ~ ` rightVal.str;` );
										break;
									default:
										log.internalAssert(false, `Less or greater comparision doesn't support type "`, leftVal.type, `" yet!`);
								}
								break compare_op_switch;
							}
						}
						default:
							log.internalAssert(false, `This should never happen!`);
					}
					break;
				}

				// Shallow equality comparision
				case OpCode.Equal:
				case OpCode.NotEqual:
				{
					// Right value was evaluated last so it goes first in the stack
					IvyData rightVal = this._stack.popBack();
					IvyData leftVal = this._stack.popBack();

					this._stack.push(instr.opcode == OpCode.Equal? leftVal == rightVal: leftVal != rightVal);
					break;
				}

				// Load constant from programme data table into stack
				case OpCode.LoadSubscr:
				{
					import std.utf: toUTFindex, decode;
					import std.algorithm: canFind;

					log.write(`OpCode.LoadSubscr. this._stack: `, this._stack);

					IvyData indexValue = this._stack.popBack();

					IvyData aggr = this._stack.popBack();
					log.write(`OpCode.LoadSubscr. aggr: `, aggr);
					log.write(`OpCode.LoadSubscr. indexValue: `, indexValue);

					switch( aggr.type )
					{
						case IvyDataType.String:
						{
							log.internalAssert(indexValue.type == IvyDataType.Integer,
								"Cannot execute LoadSubscr instruction. Index value for string aggregate must be integer!", indexValue);

							// Index operation for string in D is little more complicated
							size_t startIndex = aggr.str.toUTFindex(indexValue.integer); // Get code unit index by index of symbol
							size_t endIndex = startIndex;
							aggr.str.decode(endIndex); // decode increases passed index
							log.internalAssert(startIndex < aggr.str.length, `String slice start index must be less than str length`);
							log.internalAssert(endIndex <= aggr.str.length, `String slice end index must be less or equal to str length`);
							this._stack.push(aggr.str[startIndex..endIndex]);
							break;
						}
						case IvyDataType.Array:
						{
							log.internalAssert(indexValue.type == IvyDataType.Integer,
								"Cannot execute LoadSubscr instruction. Index value for array aggregate must be integer!");
							log.internalAssert(indexValue.integer < aggr.array.length, `Array index must be less than array length`);
							this._stack.push(aggr.array[indexValue.integer]);
							break;
						}
						case IvyDataType.AssocArray:
						{
							log.internalAssert(indexValue.type == IvyDataType.String,
								"Cannot execute LoadSubscr instruction. Index value for assoc array aggregate must be string!");
							log.internalAssert(indexValue.str in aggr.assocArray,
								`Assoc array key "`, indexValue.str, `" must be present in assoc array`);
							this._stack.push(aggr.assocArray[indexValue.str]);
							break;
						}
						case IvyDataType.ClassNode:
						{
							this._stack.push(aggr.classNode[indexValue]);
							break;
						}
						case IvyDataType.Callable:
						{
							log.internalAssert(indexValue.type == IvyDataType.String,
								"Cannot execute LoadSubscr instruction. Index value for callable aggregate must be string!");
							if( indexValue.str == `moduleName` ) {
								this._stack.push(aggr.callable.moduleName);
							} else {
								log.internalAssert(false, `Unexpected property "` ~ indexValue.str ~ `" for callable object`);
							}
							break;
						}
						default:
							log.internalAssert(
								false, "Unexpected type of aggregate " ~ aggr.type.text ~ " for LoadSubscr instruction!");
					}
					break;
				}

				// Load data node slice for array-like nodes onto stack
				case OpCode.LoadSlice:
				{
					import std.utf: toUTFindex, decode;
					import std.algorithm: canFind;

					log.write(`OpCode.LoadSlice. this._stack: `, this._stack);

					IvyData endValue = this._stack.popBack();
					IvyData beginValue = this._stack.popBack();
					IvyData aggr = this._stack.popBack();

					log.write(`OpCode.LoadSlice. aggr: `, aggr);
					log.write(`OpCode.LoadSlice. beginValue: `, beginValue);
					log.write(`OpCode.LoadSlice. endValue: `, endValue);

					log.internalAssert(
						[IvyDataType.String, IvyDataType.Array, IvyDataType.ClassNode].canFind(aggr.type),
						"Cannot execute LoadSlice instruction. Aggregate value must be string, array, assoc array or class node!");
					
					log.internalAssert(beginValue.type == IvyDataType.Integer,
						"Cannot execute LoadSlice instruction. Begin value of slice must be integer!");

					log.internalAssert(endValue.type == IvyDataType.Integer,
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
							this._stack.push(aggr.str[startIndex..endIndex]);
							break;
						case IvyDataType.Array:
							this._stack.push(aggr.array[beginValue.integer..endValue.integer]);
							break;
						case IvyDataType.ClassNode:
							// Class node must have it's own range checks
							this._stack.push(aggr.classNode[beginValue.integer..endValue.integer]);
							break;
						default:
							log.internalAssert(false, `Cannot execute LoadSlice instruction. Unexpected aggregate type`);
					}
					break;
				}

				// Set property of object, array item or class object with writeable attribute
				// by passed property name or index
				case OpCode.StoreSubscr:
				{
					import std.algorithm: canFind;

					log.write(`OpCode.StoreSubscr. this._stack: `, this._stack);

					IvyData indexValue = this._stack.popBack();
					IvyData value = this._stack.popBack();
					IvyData aggr = this._stack.popBack();

					switch( aggr.type )
					{
						case IvyDataType.Array:
							log.internalAssert(indexValue.type == IvyDataType.Integer,
								"Cannot execute StoreSubscr instruction. Index value for array aggregate must be integer!");
							log.internalAssert(indexValue.integer < aggr.array.length, `Array index must be less than array length`);
							aggr[indexValue.integer] = value;
							break;
						case IvyDataType.AssocArray:
							log.internalAssert(indexValue.type == IvyDataType.String,
								"Cannot execute StoreSubscr instruction. Index value for assoc array aggregate must be string!");
							aggr[indexValue.str] = value;
							break;
						case IvyDataType.ClassNode:
							if( indexValue.type == IvyDataType.Integer ) {
								aggr[indexValue.integer] = value;
							} else if( indexValue.type == IvyDataType.String ) {
								aggr[indexValue.str] = value;
							} else {
								log.error("Cannot execute StoreSubscr instruction. Index value for class node must be string or integer!");
							}
							break;
						default:
							log.internalAssert(false, `Cannot execute StoreSubscr instruction. Unexpected aggregate type`);
					}
					break;
				}

				// Load constant from programme data table into stack
				case OpCode.LoadConst:
				{
					this._stack.push(getModuleConstCopy(instr.arg));
					break;
				}

				// Concatenates two arrays or strings and puts result onto stack
				case OpCode.Concat:
				{
					IvyData rightVal = this._stack.popBack();

					IvyData leftVal = this._stack.back;
					log.internalAssert( ( leftVal.type == IvyDataType.String || leftVal.type == IvyDataType.Array ) && leftVal.type == rightVal.type,
						`Left and right values for concatenation operation must have the same string or array type!`
					);

					if( leftVal.type == IvyDataType.String ) {
						this._stack.back = leftVal.str ~ rightVal.str;
					} else {
						this._stack.back = leftVal.array ~ rightVal.array;
					}

					break;
				}

				case OpCode.Append:
				{
					log.write("OpCode.Append this._stack: ", this._stack);
					IvyData rightVal = this._stack.popBack();

					log.internalAssert(this._stack.back.type == IvyDataType.Array,
						"Left operand for Append instruction expected to be array, but got: ", this._stack.back.type);

					this._stack.back ~= rightVal;

					break;
				}

				case OpCode.Insert:
				{
					import std.array: insertInPlace;

					log.write("OpCode.Insert this._stack: ", this._stack);
					IvyData positionNode = this._stack.popBack();
					import std.algorithm: canFind;
					log.internalAssert(
						[IvyDataType.Integer, IvyDataType.Null, IvyDataType.Undef].canFind(positionNode.type),
						"Cannot execute Insert instruction. Position argument expected to be an integer or empty (for append), but got: ", positionNode.type
					);

					IvyData valueNode = this._stack.popBack();

					IvyData listNode = this._stack.back;
					log.internalAssert(
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
					log.internalAssert(
						pos >= 0 && pos <= listNode.array.length,
						"Cannot execute Insert instruction. Computed position is wrong: ", pos);
					listNode.array.insertInPlace(pos, valueNode);
					break;
				}

				case OpCode.InsertMass:
				{
					log.write("OpCode.InsertMass this._stack: ", this._stack);
					assert(false, `Not implemented yet!`);
				}

				// Useless unary plus operation
				case OpCode.UnaryPlus:
				{
					log.internalAssert(this._stack.back.type == IvyDataType.Integer || this._stack.back.type == IvyDataType.Floating,
						`Operand for unary plus operation must have integer or floating type!` );

					// Do nothing for now:)
					break;
				}

				case OpCode.UnaryMin:
				{
					log.internalAssert(this._stack.back.type == IvyDataType.Integer || this._stack.back.type == IvyDataType.Floating,
						`Operand for unary minus operation must have integer or floating type!`);

					if( this._stack.back.type == IvyDataType.Integer ) {
						this._stack.back = - this._stack.back.integer;
					} else {
						this._stack.back = - this._stack.back.floating;
					}

					break;
				}

				case OpCode.UnaryNot:
				{
					this._stack.back = !this._stack.back.toBoolean();
					break;
				}

				case OpCode.Nop:
				{
					// Doing nothing here... What did you expect? :)
					break;
				}

				// Stores data from stack into local context frame variable
				case OpCode.StoreGlobalName:
				case OpCode.StoreName:
				{
					log.write(instr.opcode, " this._stack: ", this._stack);
					IvyData varValue = this._stack.popBack();

					IvyData varNameNode = getModuleConstCopy(instr.arg);
					log.internalAssert(varNameNode.type == IvyDataType.String, `Cannot execute `, instr.opcode, ` instruction. Variable name const must have string type!`);


					switch(instr.opcode) {
						case OpCode.StoreGlobalName: setGlobalValue(varNameNode.str, varValue); break;
						case OpCode.StoreName: this.setValue(varNameNode.str, varValue); break;
						default: log.internalAssert(false, `Unexpected 'store name' instruction kind`);
					}
					break;
				}

				// Loads data from local context frame variable by index of var name in module constants
				case OpCode.LoadName:
				{
					IvyData varNameNode = this.getModuleConstCopy(instr.arg);
					log.internalAssert(varNameNode.type == IvyDataType.String, `Cannot execute LoadName instruction. Variable name operand must have string type!`);

					this._stack.push(this.getGlobalValue(varNameNode.str));
					break;
				}

				case OpCode.StoreAttr:
				{
					import std.conv: text;

					IvyData attrVal = this._stack.popBack();
					IvyData attrName = this._stack.popBack();
					IvyData aggrNode = this._stack.popBack();
					log.internalAssert(attrName.type == IvyDataType.String, `Attribute name must be a string`);
					final switch( aggrNode.type )
					{
						case IvyDataType.Undef:
						case IvyDataType.Null:
						case IvyDataType.Boolean:
						case IvyDataType.Integer:
						case IvyDataType.Floating:
						case IvyDataType.String:
						case IvyDataType.Array:
						case IvyDataType.CodeObject:
						case IvyDataType.Callable:
						case IvyDataType.DataNodeRange:
						case IvyDataType.AsyncResult:
						case IvyDataType.ModuleObject:
							log.internalAssert(false, `Unable to set attribute of value with type: "` ~ aggrNode.type.text);
							break;
						case IvyDataType.AssocArray:
						{
							aggrNode.assocArray[attrName.str] = attrVal;
							break;
						}
						case IvyDataType.ClassNode:
						{
							aggrNode.classNode.__setAttr__(attrVal, attrName.str);
							break;
						}
						case IvyDataType.ExecutionFrame:
							log.internalAssert(false, `Unable to set attribute of value with type: "` ~ aggrNode.type.text);
							break;
					}
					break;
				}

				// 
				case OpCode.LoadAttr:
				{
					import std.conv: text;

					IvyData attrName = this._stack.popBack();
					IvyData aggr = this._stack.popBack();
					log.internalAssert(attrName.type == IvyDataType.String, `Attribute name must be a string`);

					final switch( aggr.type )
					{
						case IvyDataType.Undef:
						case IvyDataType.Null:
						case IvyDataType.Boolean:
						case IvyDataType.Integer:
						case IvyDataType.Floating:
						case IvyDataType.String:
							log.internalAssert(false, `No attributes for primitive value of type: ` ~ aggr.type.text);
							break;
						case IvyDataType.AssocArray:
						{
							IvyData* valPtr = attrName.str in aggr;
							this._stack.push(valPtr is null? IvyData(null): *valPtr);
							break;
						}
						case IvyDataType.ClassNode:
						{
							this._stack.push(aggr.classNode.__getAttr__(attrName.str));
							break;
						}
						case IvyDataType.ExecutionFrame:
						{
							this._stack.push(aggr.execFrame.getValue(attrName.str));
							break;
						}
						case IvyDataType.Array:
						case IvyDataType.CodeObject:
						case IvyDataType.Callable:
						case IvyDataType.DataNodeRange:
						case IvyDataType.AsyncResult:
						case IvyDataType.ModuleObject:
							log.internalAssert(false, `No attributes for value of type: ` ~ aggr.type.text);
							break;
					}
					break;
				}

				case OpCode.ImportModule:
				{
					IvyData modNameNode = this._stack.popBack();
					log.internalAssert(modNameNode.type == IvyDataType.String, "Cannot execute ImportModule instruction. Module name operand must be a string!");
					string moduleName = modNameNode.str;

					log.internalAssert(this._moduleObjCache.get(moduleName), "Cannot execute ImportModule instruction. No such module object: ", moduleName);

					if( moduleName !in this._moduleFrames )
					{
						// Run module here
						ModuleObject moduleObject = this._moduleObjCache.get(moduleName);
						log.internalAssert(moduleObject, `Cannot execute ImportModule instruction, because module object "`, moduleName,`" is null!` );
						CodeObject codeObject = moduleObject.mainCodeObject;
						log.internalAssert(codeObject !is null, `Cannot execute ImportModule instruction, because main code object for module "`, moduleName, `" is null!` );

						CallableObject callable = new CallableObject(codeObject);

						IvyData dataDict = [
							"_ivyMethod": moduleName,
							"_ivyModule": moduleName
						];
						this.newFrame(callable, null, dataDict, false); // Create entry point module frame
						this._moduleFrames[moduleName] = this._frameStack.back; // We need to store module frame into storage

						// Put module root frame into previous execution frame`s stack block (it will be stored with StoreGlobalName)
						this._stack.push(this._frameStack.back);
						// Decided to put return address into parent frame`s stack block instead of current
						this._stack.push(_pk+1);

						this._stack.addStackBlock(); // Add new stack block for execution frame

						// Preparing to run code object in newly created frame
						this._codeRange = codeObject._instrs[];
						this._pk = 0;

						continue execution_loop; // Skip _pk increment
					}
					else
					{
						// Put module root frame into previous execution frame (it will be stored with StoreGlobalName)
						this._stack.push(this._moduleFrames[moduleName]); 
						// As long as module returns some value at the end of execution, so put fake value there for consistency
						this._stack.push(IvyData());
					}

					break;
				}

				case OpCode.FromImport:
				{
					IvyData importListNode = this._stack.popBack();
					IvyData modFrameNode = this._stack.popBack();

					log.internalAssert(importListNode.type == IvyDataType.Array, "Cannot execute FromImport instruction. Expected list of symbol names");
					log.internalAssert(modFrameNode.type == IvyDataType.ExecutionFrame, "Cannot execute FromImport instruction. Expected execution frame argument");
					ExecutionFrame moduleFrame = modFrameNode.execFrame;

					foreach( name; importListNode.array ) {
						this.setValue(name, moduleFrame.getValue(name));
					}
					break;
				}

				case OpCode.GetDataRange:
				{
					import ivy.types.data.range.array: ArrayRange;
					import ivy.types.data.range.assoc_array: AssocArrayRange;
					
					import std.range: empty, back, popBack;
					import std.algorithm: canFind;
					log.write(`GetDataRange begin this._stack: `, this._stack);
					log.internalAssert([
							IvyDataType.Array,
							IvyDataType.AssocArray,
							IvyDataType.DataNodeRange,
							IvyDataType.ClassNode
						].canFind(this._stack.back.type),
						`Expected array or assoc array as loop aggregate, but got: `,
						this._stack.back.type
					);

					IvyData dataRange;
					switch( this._stack.back.type )
					{
						case IvyDataType.Array:
						{
							dataRange = new ArrayRange(this._stack.back.array);
							break;
						}
						case IvyDataType.ClassNode:
						{
							dataRange = IvyData(this._stack.back.classNode[]);
							break;
						}
						case IvyDataType.AssocArray:
						{
							dataRange = new AssocArrayRange(this._stack.back.assocArray);
							break;
						}
						case IvyDataType.DataNodeRange:
						{
							dataRange = this._stack.back;
							break;
						}
						default:
							log.internalAssert(false, `This should never happen!` );
					}
					this._stack.popBack(); // Drop aggregate from stack
					this._stack.push(dataRange); // Push range onto stack

					break;
				}

				case OpCode.RunLoop:
				{
					log.write("RunLoop beginning this._stack: ", this._stack);
					log.internalAssert(this._stack.back.type == IvyDataType.DataNodeRange, `Expected DataNodeRange` );
					auto dataRange = this._stack.back.dataRange;
					log.write("RunLoop dataRange.empty: ", dataRange.empty);
					if( dataRange.empty )
					{
						log.write("RunLoop. Data range is exaused, so exit loop. this._stack is: ", this._stack);
						log.internalAssert(instr.arg < this._codeRange.length, `Cannot jump after the end of code object`);
						this._pk = instr.arg;
						log.internalAssert(this._stack.back.type == IvyDataType.DataNodeRange, "RunLoop. Expected DataNodeRange to drop");
						this._stack.popBack(); // Drop data range from stack as we no longer need it
						break;
					}

					this._stack.push(dataRange.front);
					// TODO: For now we just move range forward as take current value from it
					// Maybe should fix it and make it move after loop block finish
					dataRange.popFront();

					log.write("RunLoop. Iteration init finished. this._stack is: ", this._stack);
					break;
				}

				case OpCode.Jump:
				{
					log.internalAssert(instr.arg < this._codeRange.length, `Cannot jump after the end of code object`);

					this._pk = instr.arg;
					continue execution_loop; // Skip _pk increment
				}

				case OpCode.JumpIfTrue:
				case OpCode.JumpIfFalse:
				case OpCode.JumpIfTrueOrPop:
				case OpCode.JumpIfFalseOrPop:
				{
					import std.algorithm: canFind;

					log.internalAssert(instr.arg < this._codeRange.length, `Cannot jump after the end of code object`);
					bool jumpCond = this._stack.back.toBoolean(); // This is actual condition to test
					if( [OpCode.JumpIfFalse, OpCode.JumpIfFalseOrPop].canFind(instr.opcode) ) {
						jumpCond = !jumpCond; // Invert condition if False family is used
					}

					if( [OpCode.JumpIfTrue, OpCode.JumpIfFalse].canFind(instr.opcode) || !jumpCond ) {
						// Drop condition from this._stack on JumpIfTrue, JumpIfFalse anyway
						// But for JumpIfTrueOrPop, JumpIfFalseOrPop drop it only if jumpCond is false
						this._stack.popBack();
					}

					if( jumpCond )
					{
						this._pk = instr.arg;
						continue execution_loop; // Skip _pk increment
					}
					break;
				}

				case OpCode.Return:
				{
					// Set instruction index at the end of code object in order to finish 
					this._pk = this._codeRange.length;
					IvyData result = this._stack.back;
					// Erase all from the current stack
					this._stack.popBackN(this._stack.length);
					this._stack.push(result); // Put result on the stack
					continue execution_loop; // Skip _pk increment
				}

				case OpCode.PopTop:
				{
					this._stack.popBack();
					break;
				}

				// Swaps two top items on the stack
				case OpCode.SwapTwo:
				{
					log.internalAssert(this._stack.length > 1, "Stack must have at least two items to swap");
					IvyData tmp = this._stack[$-1];
					this._stack[$-1] = this._stack[$-2];
					this._stack[$-2] = tmp;
					break;
				}

				case OpCode.DubTop: {
					log.internalAssert(!this._stack.empty, "Stack must have item to duplicate");
					this._stack.push(this._stack.back);
					break;
				}

				case OpCode.LoadDirective:
				{
					import ivy.types.call_spec: CallSpec;

					CallSpec callSpec = CallSpec(instr.arg);
					log.internalAssert(callSpec.posAttrsCount == 0, `Positional default attribute values are not expected`);

					IvyData codeObjNode = this._stack.popBack();
					log.internalAssert(codeObjNode.type == IvyDataType.CodeObject, `Expected CodeObject to load`);
					
					CodeObject codeObject = codeObjNode.codeObject;

					// Get dict of default attr values from stack if exists
					// We shall not check for odd values here, because we believe compiler can handle it
					IvyData[string] defaults = callSpec.hasKwAttrs? this._stack.popBack().assocArray: null;

					/*
					IvyData[string] defaults;
					foreach( size_t num; 0 .. callSpec.posAttrsCount )
					{
						// Passing over callable symbol attrs that match positions of stack args (in reverse order)
						DirAttr attr = attrSymbols[callSpec.posAttrsCount - num - 1];
						defaults[attr.name] = this._stack.back();
					}

					if( kwAttrs )
					{
						foreach( size_t idx; callSpec.posAttrsCount .. attrSymbols.length )
						{
							DirAttr attr = attrSymbols[idx];
							if( IvyData* valPtr = attr.name in kwArgs ) {
								defaults[attr.name] = *valPtr;
							}
						}
					}
					*/

					this.setValue(codeObject.symbol.name, IvyData(new CallableObject(codeObject, defaults))); // Put this directive in context
					this._stack.push(IvyData()); // We should return something
					break;
				}

				case OpCode.RunCallable:
				{
					import ivy.types.call_spec: CallSpec;
					
					log.write("RunCallable stack on init: : ", this._stack);
					CallSpec callSpec = CallSpec(instr.arg);

					IvyData callableNode = this._stack.popBack();
					log.internalAssert(callableNode.type == IvyDataType.Callable, `Expected callable object to run, but got: `, callableNode);

					CallableObject callable = callableNode.callable;
					DirAttr[] attrSymbols = callable.symbol.attrs;
					size_t callableAttrCount = attrSymbols.length;

					IvyData[string] kwAttrs;
					if( callSpec.hasKwAttrs )
					{
						IvyData kwAttrsNode = this._stack.popBack();
						log.internalAssert(kwAttrsNode.type == IvyDataType.AssocArray, `Expected assoc array of keyword attributes`);
						kwAttrs = kwAttrsNode.assocArray;
					}

					this.log.internalAssert(
						stackAttrCount > callableAttrCount,
						"Attrs count passed through execution stack: ",
						stackAttrCount,
						" is more than callable`s attrs count: ",
						callableAttrCount,
						", but should be less or equal"
					);

					log.internalAssert(
						stackAttrCount <= this._stack.length,
						"Not enough items in execution stack. Required: ",
						stackAttrCount,
						", but got: ",
						this._stack.length
					);

					log.write("RunCallable name: ", callable.symbol.name);
					this.newFrame(callable, this._getModuleFrame(callable));

					foreach( size_t num; 0..callableAttrCount )
					{
						// Проходим по символам аттрибутов с конца
						size_t attrIndex = callableAttrCount - num - 1;
						DirAttr attr = attrSymbols[attrIndex];
						if( attrIndex < stackAttrCount )
						{
							// Индекс аттрибута меньше числа аттрибутов в стеке
							// Т.е. значение следует брать из стека
							this.setValue(attr.name, this._stack.popBack());
						}
						else
						{
							// Иначе нужно пытаться получить значение по-умолчанию
							auto defValPtr = attr.name in callable.defaults;
							this.log.internalAssert(
								defValPtr !is null,
								`Expected value for attr: `,
								attr.name,
								`, that has no default value`
							);
							this.setValue(attr.name, deeperCopy(*defValPtr));
						}
					}


					log.write("this._stack after parsing all arguments: ", this._stack);
					if( this._doCall(callable) ) {
						continue execution_loop;
					}
					break;
				}

				case OpCode.Await: {
					IvyData aResultNode = this._stack.popBack();
					log.internalAssert(
						aResultNode.type == IvyDataType.AsyncResult,
						`Expected AsyncResult operand`
					);
					AsyncResult aResult = aResultNode.asyncResult;
					log.internalAssert(
						aResult.state != AsyncResultState.pending,
						`Async operations in server-side interpreter are fake and not supported`
					);
					aResult.then(
						(IvyData data) {
							this._stack.push([
								`isError`: IvyData(false),
								`data`: data
							]);
						},
						(Throwable error) {
							IvyData ivyError = errorToIvyData(error);
							ivyError[`isError`] = true;
							this._stack.push(ivyError);
						}
					);
					break;
				}

				case OpCode.MakeArray:
				{
					IvyData[] newArray;
					newArray.length = instr.arg; // Preallocating is good ;)
					for( size_t i = instr.arg; i > 0; --i ) {
						// We take array items from the tail, so we must consider it!
						newArray[i-1] = this._stack.popBack();
					}
					this._stack.push(newArray);
					break;
				}

				case OpCode.MakeAssocArray:
				{
					IvyData[string] res;
					for( size_t i = 0; i < instr.arg; ++i )
					{
						IvyData val = this._stack.popBack();
						IvyData key = this._stack.popBack();

						log.internalAssert(key.type == IvyDataType.String, `Expected string as assoc array key`);

						res[key.str] = val;
					}
					this._stack.push(res);
					break;
				}

				case OpCode.MarkForEscape: {
					this._stack.back.escapeState = cast(NodeEscapeState) instr.arg;
					break;
				}

				default:
				{
					log.internalAssert(false, "Unexpected code of operation: ", instr.opcode);
					break;
				}
			} // switch
			++this._pk;

		} // execution_loop:

		log.internalAssert(false, `Failed to get result of execution`);
	} // void execLoop()

	ExecutionFrame _getModuleFrame(CallableObject callable)
	{
		ExecutionFrame moduleFrame = _moduleFrames.get(callable.moduleName, null);
		log.internalAssert( moduleFrame, `Module frame with name: `, moduleFrame, ` of callable: `, callable.symbol.name, ` does not exist!` );
		return moduleFrame;
	}

	bool _doCall(CallableObject callable)
	{
		if( !callable.isNative )
		{
			this._stack.push(this._pk + 1); // Put next instruction index on the stack to return at
			this._stack.addStackBlock();
			this._codeRange = callable.codeObject._instrs[]; // Set new instruction range to execute
			this._pk = 0;
			return true; // Skip _pk increment
		}
		else
		{
			this._stack.addStackBlock();
			callable.dirInterp.interpret(this); // Run native directive interpreter

			// Else we expect to have result of directive on the stack
			log.internalAssert(this._stack.length, "Stack should contain 1 item empty now!");

			// If frame stack contains last frame - it means that we nave done with programme
			if( this._frameStack.length == exitFrames ) {
				fResult.resolve(this._stack.back());
				return;
			}
			IvyData result = this._stack.popBack();
			this.removeFrame(); // Drop frame from stack after end of execution
			this._stack.push(result); // Get result back
			return false;
		}
	}

	AsyncResult runModuleDirective(string name, IvyData args = IvyData())
	{
		import std.exception: enforce;
		import std.algorithm: canFind;
		enforce([
			IvyDataType.Undef, IvyDataType.Null, IvyDataType.AssocArray
		].canFind(args.type), `Expected Undef, Null or AssocArray as list of directive arguments`);

		log.internalAssert(this.currentFrame, `Could not get module frame!`);

		// Find desired directive by name in current module frame
		IvyData callableNode = this.currentFrame.getValue(name);
		log.internalAssert(callableNode.type == IvyDataType.Callable, `Expected Callable!`);

		log.internalAssert(this._stack.length < 2, `Expected 0 or 1 items in stack!`);
		if( this._stack.length == 1 ) {
			this._stack.popBack(); // Drop old result from stack
		}
		this._stack.push(callableNode);
		this._stack.push(args);

		this._pk = 0;
		this._codeRange = [Instruction(OpCode.Call)];
		AsyncResult fResult = new AsyncResult();
		try {
			this.execLoopImpl(fResult, 2);
		} catch( Throwable ex ) {
			fResult.reject(ex);
		}
		return fResult;
	}

	DirAttr[string] getDirAttrs(string name, string[] attrNames = null)
	{
		import std.range: empty;
		import std.algorithm: canFind;
		ExecutionFrame frame = this.currentFrame;

		IvyData callableNode = frame.getValue(name);
		log.internalAssert(callableNode.type == IvyDataType.Callable, `Expected Callable!`);
		CallableObject callable = callableNode.callable;
		DirAttr[] attrs = callable.symbol.attrs;
		DirAttr[string] res;

		foreach( attr; attrs )
		{
			if( !attrNames.empty && attrNames.canFind(attr.name) ) {
				continue;
			}
			if( auto defValPtr = attr.name in callable.defaults ) {
				res[attr.name] = defValPtr;
			}
		}

		return res;
	}
}
