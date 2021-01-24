module ivy.interpreter.interpreter;

// If IvyTotalDebug is defined then enable parser debug
version(IvyTotalDebug) version = IvyInterpreterDebug;

struct InterpDirAttr
{
	import ivy.types.data: IvyData;
	import ivy.types.symbol.dir_attr: DirAttr;

	DirAttr attr;
	IvyData defaultValue;
}

class Interpreter
{
	import ivy.types.code_object: CodeObject;
	import ivy.types.module_object: ModuleObject;
	import ivy.types.iface.callable_object: ICallableObject;
	import ivy.types.callable_object: CallableObject;
	import ivy.types.data: IvyDataType, IvyData;
	import ivy.types.data.decl_class: DeclClass;
	import ivy.types.decl_class_factory: DeclClassFactory;
	import ivy.types.call_spec: CallSpec;
	import ivy.types.data.utils: deeperCopy;
	import ivy.interpreter.execution_frame: ExecutionFrame;
	import ivy.interpreter.exec_stack: ExecStack;
	import ivy.interpreter.directive.iface: IDirectiveInterpreter;
	import ivy.interpreter.module_objects_cache: ModuleObjectsCache;
	import ivy.interpreter.directive.factory: InterpreterDirectiveFactory;
	import ivy.types.data.async_result: AsyncResult, AsyncResultState;
	import ivy.bytecode: Instruction, OpCode;
	import ivy.types.symbol.dir_attr: DirAttr;
	import ivy.types.symbol.global: GLOBAL_SYMBOL_NAME;
	import ivy.interpreter.directive.global: globalCallable;
	import ivy.log: LogInfo;

public:
	alias LogerMethod = void delegate(LogInfo);

	// Stack of execution frames with directives or modules local data
	ExecutionFrame[] _frameStack;

	// Storage for execution frames of imported modules
	ExecutionFrame[string] _moduleFrames;

	// Storage for bytecode code and initial constant data for modules
	ModuleObjectsCache _moduleObjCache;

	InterpreterDirectiveFactory _directiveFactory;

	DeclClassFactory _declClassFactory;

	ExecStack _stack;

	// LogWriter method used to send error and debug messages
	LogerMethod _logerMethod;

	size_t _pk; // Programme counter
	Instruction[] _codeRange; // Current code range we executing

	this(
		ModuleObjectsCache moduleObjCache,
		InterpreterDirectiveFactory directiveFactory,
		LogerMethod logerMethod = null
	) {
		this._moduleObjCache = moduleObjCache;
		this._directiveFactory = directiveFactory;
		this._declClassFactory = new DeclClassFactory;
		this._logerMethod = logerMethod;

		this.log.internalAssert(this._moduleObjCache !is null, "Expected module objects cache");
		this.log.internalAssert(this._directiveFactory !is null, "Expected directive factory");

		// Add global execution frame. Do not add it to _frameStack!
		this._moduleFrames[GLOBAL_SYMBOL_NAME] = new ExecutionFrame(globalCallable);

		// Add custom native directive interpreters to global scope
		foreach( dirInterp; directiveFactory.interps ) {
			this.globalFrame.setValue(dirInterp.symbol.name, IvyData(new CallableObject(dirInterp)));
		}
	}

	AsyncResult execLoop() 
	{
		AsyncResult fResult = new AsyncResult;
		CodeObject codeObject = this.currentCodeObject;
		this.log.internalAssert(codeObject !is null, "Expected current code object to run");

		this._codeRange = codeObject.instrs[];
		this.setJump(0);
		try {
			this.execLoopImpl(fResult);
		} catch(Throwable ex) {
			debug {
				import std.stdio: writeln;
				import std.array: join;
				writeln("ERROR: ", this.callStackInfo.join("\n\n"));
			}
			fResult.reject(ex);
		}
		return fResult;
	}

	void execLoopImpl(AsyncResult fResult, size_t exitFrames = 1)
	{
		while( true )
		{
			while( this._pk < this._codeRange.length )
				this.execLoopBody();

			// We expect to have only the result of directive on the stack
			this.log.internalAssert(this._stack.length == 1, "Exec stack should contain 1 item now");

			// If there is the last frame it means that it is the last module frame.
			// We need to leave frame here for case when we want to execute specific function of module
			if( this._frameStack.length <= exitFrames )
				break;

			IvyData result = this._stack.pop(); // Take result
			this.removeFrame(); // Exit out of this frame

			CodeObject codeObject = this.currentCodeObject;
			this.log.internalAssert(codeObject !is null, "Expected code object");

			this._codeRange = codeObject.instrs[]; // Set old instruction range back
			this.setJump(this._stack.pop().integer);
			this._stack.push(result); // Put result back
		}

		fResult.resolve(this._stack.back);
	}

	void execLoopBody()
	{
		import std.range: empty, back, popBack;
		import std.conv: to, text;
		import std.algorithm: canFind;

		Instruction instr = this._codeRange[this._pk];
		final switch( instr.opcode )
		{
			case OpCode.InvalidCode: {
				this.log.internalError("Invalid code of operation");
				break;
			}
			case OpCode.Nop: break;

			// Load constant from programme data table into stack
			case OpCode.LoadConst:
			{
				this._stack.push(this.getModuleConstCopy(instr.arg));
				break;
			}

			case OpCode.PopTop:
			{
				this._stack.pop();
				break;
			}

			// Swaps two top items on the stack
			case OpCode.SwapTwo:
			{
				IvyData top = this._stack.pop();
				IvyData beforeTop = this._stack.pop();
				this._stack.push(top);
				this._stack.push(beforeTop);
				break;
			}

			case OpCode.DubTop: {
				this._stack.push(this._stack.back);
				break;
			}

			// Useless unary plus operation
			case OpCode.UnaryPlus:
			{
				this.log.internalAssert(
					[IvyDataType.Integer, IvyDataType.Floating].canFind(this._stack.back.type),
					"Operand for unary plus operation must have integer or floating type!" );

				// Do nothing for now:)
				break;
			}

			case OpCode.UnaryMin:
			{
				this.log.internalAssert(
					[IvyDataType.Integer, IvyDataType.Floating].canFind(this._stack.back.type),
					"Operand for unary minus operation must have integer or floating type!");

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

			// Base arithmetic operations execution
			case OpCode.Add:
			case OpCode.Sub:
			case OpCode.Mul:
			case OpCode.Div:
			case OpCode.Mod:
			{
				// Right value was evaluated last so it goes first in the stack
				IvyData right = this._stack.pop();
				IvyData left = this._stack.pop();
				IvyData res;

				this.log.internalAssert(
					left.type == right.type,
					"Operands of arithmetic operation must have the same type!");


				switch( left.type )
				{
					case IvyDataType.Integer:
						res = this._doBinaryOp(instr.opcode, left.integer, right.integer);
						break;
					case IvyDataType.Floating:
						res = this._doBinaryOp(instr.opcode, left.floating, right.floating);
						break;
					default:
						this.log.error("Unexpected types of operands");
						break;
				}

				this._stack.push(res);
				break;
			}

			// Shallow equality comparision
			case OpCode.Equal:
			case OpCode.NotEqual:
			{
				this._stack.push(this._doBinaryOp(instr.opcode, this._stack.pop(), this._stack.pop()));
				break;
			}

			// Comparision operations
			case OpCode.LT:
			case OpCode.GT:
			case OpCode.LTEqual:
			case OpCode.GTEqual:
			{
				// Right value was evaluated last so it goes first in the stack
				IvyData right = this._stack.pop();
				IvyData left = this._stack.pop();
				IvyData res;
				this.log.internalAssert(
					left.type == right.type,
					"Operands of less or greather comparision must have the same type");

				switch( left.type )
				{
					case IvyDataType.Undef:
					case IvyDataType.Null:
						// Undef and Null are not less or equal to something
						res = false;
						break;
					case IvyDataType.Integer:
						res = this._doBinaryOp(instr.opcode, left.integer, right.integer);
						break;
					case IvyDataType.Floating:
						res = this._doBinaryOp(instr.opcode, left.floating, right.floating);
						break;
					case IvyDataType.String:
						res = this._doBinaryOp(instr.opcode, left.str, right.str);
						break;
					default:
						this.log.internalError("Less or greater comparisions doesn't support type ", left.type, " yet!");
				}
				this._stack.push(res);
				break;
			}

			// Stores data from stack into local context frame variable
			case OpCode.StoreName:
			case OpCode.StoreGlobalName:
			{
				IvyData varValue = this._stack.pop();
				string varName = getModuleConstCopy(instr.arg).str;

				switch(instr.opcode) {
					case OpCode.StoreName: this.setValue(varName, varValue); break;
					case OpCode.StoreGlobalName: this.setGlobalValue(varName, varValue); break;
					default: this.log.internalError("Unexpected instruction opcode");
				}
				break;
			}

			// Loads data from local context frame variable by index of var name in module constants
			case OpCode.LoadName:
			{
				string varName = this.getModuleConstCopy(instr.arg).str;
				this._stack.push(this.getGlobalValue(varName));
				break;
			}

			case OpCode.StoreAttr:
			{
				IvyData attrVal = this._stack.pop();
				string attrName = this._stack.pop().str;
				IvyData aggr = this._stack.pop();
				final switch( aggr.type )
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
					case IvyDataType.ExecutionFrame:
						this.log.internalError("Unable to set attribute of value with type: ", aggr.type);
						break;
					case IvyDataType.AssocArray:
					{
						aggr[attrName] = attrVal;
						break;
					}
					case IvyDataType.ClassNode:
					{
						aggr.classNode.__setAttr__(attrVal, attrName);
						break;
					}
				}
				break;
			}

			// 
			case OpCode.LoadAttr:
			{
				string attrName = this._stack.pop().str;
				IvyData aggr = this._stack.pop();

				final switch( aggr.type )
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
						this.log.internalError("Unable to get attribute of value with type: ", aggr.type);
						break;
					case IvyDataType.AssocArray:
					{
						IvyData* valPtr = attrName in aggr;
						this._stack.push(valPtr is null? IvyData(): *valPtr);
						break;
					}
					case IvyDataType.ClassNode:
					{
						this._stack.push(aggr.classNode.__getAttr__(attrName));
						break;
					}
					case IvyDataType.ExecutionFrame:
					{
						this._stack.push(aggr.execFrame.getValue(attrName));
						break;
					}
				}
				break;
			}

			case OpCode.MakeArray:
			{
				IvyData[] newArray = [IvyData()];

				newArray.length = instr.arg; // Preallocating is good ;)
				for( size_t i = instr.arg; i > 0; --i ) {
					// We take array items from the tail, so we must consider it!
					newArray[i-1] = this._stack.pop();
				}
				this._stack.push(newArray);
				break;
			}

			case OpCode.MakeAssocArray:
			{
				IvyData[string] res;
				for( size_t i = 0; i < instr.arg; ++i )
				{
					IvyData val = this._stack.pop();
					string key = this._stack.pop().str;

					res[key] = val;
				}
				this._stack.push(res);
				break;
			}

			case OpCode.MakeClass:
			{
				DeclClass baseClass = (instr.arg? cast(DeclClass) this._stack.pop().classNode: null);
				IvyData[string] classDataDict = this._stack.pop().assocArray;
				string className = this._stack.pop().str;

				this._stack.push(this._declClassFactory.makeClass(className, classDataDict, baseClass));
				break;
			}

			// Set property of object, array item or class object with writeable attribute
			// by passed property name or index
			case OpCode.StoreSubscr:
			{
				IvyData index = this._stack.pop();
				IvyData value = this._stack.pop();
				IvyData aggr = this._stack.pop();

				switch( aggr.type )
				{
					case IvyDataType.Array:
						this.log.internalAssert(
							index.integer < aggr.length,
							"Index is out of bounds of array");
						aggr[index.integer] = value;
						break;
					case IvyDataType.AssocArray:
						aggr[index.str] = value;
						break;
					case IvyDataType.ClassNode: {
						switch( index.type )
						{
							case IvyDataType.Integer:
								aggr[index.integer] = value;
								break;
							case IvyDataType.String:
								aggr[index.str] = value;
								break;
							default:
								this.log.error("Index for class node must be string or integer!");
								break;
						}
						break;
					}
					default:
						this.log.error("Unexpected aggregate type");
				}
				break;
			}

			// Load constant from programme data table into stack
			case OpCode.LoadSubscr:
			{
				import std.utf: toUTFindex, decode;

				IvyData index = this._stack.pop();
				IvyData aggr = this._stack.pop();

				switch( aggr.type )
				{
					case IvyDataType.String:
					{
						// Index operation for string in D is little more complicated
						string aggrStr = aggr.str;
						size_t startIndex = aggrStr.toUTFindex(index.integer); // Get code unit index by index of symbol
						size_t endIndex = startIndex;

						aggrStr.decode(endIndex); // decode increases passed index
						this.log.internalAssert(
							startIndex < aggr.length,
							"String slice start index must be less than str length");
						this.log.internalAssert(
							endIndex <= aggr.length,
							"String slice end index must be less or equal to str length");
						this._stack.push(aggrStr[startIndex..endIndex]);
						break;
					}
					case IvyDataType.Array:
					{
						this.log.internalAssert(
							index.integer < aggr.array.length,
							"Array index must be less than array length");
						this._stack.push(aggr.array[index.integer]);
						break;
					}
					case IvyDataType.AssocArray:
					{
						auto valPtr = index.str in aggr.assocArray;
						this.log.internalAssert(
							valPtr !is null,
							"Key in associative array is not found: ", index);
						this._stack.push(*valPtr);
						break;
					}
					case IvyDataType.ClassNode:
					{
						this._stack.push(aggr.classNode[index]);
						break;
					}
					default:
						this.log.internalError("Unexpected type of aggregate: ", aggr.type);
				}
				break;
			}

			// Load data node slice for array-like nodes onto stack
			case OpCode.LoadSlice:
			{
				size_t end = this._stack.pop().integer;
				size_t begin = this._stack.pop().integer;
				IvyData aggr = this._stack.pop();

				switch( aggr.type )
				{
					case IvyDataType.String:
					{
						import std.utf: toUTFindex, decode;

						size_t startIndex = aggr.str.toUTFindex(begin); // Get code unit index by index of symbol
						size_t endIndex = end;
						aggr.str.decode(endIndex); // decode increases passed index

						this._stack.push(aggr.str[startIndex..endIndex]);
						break;
					}
					case IvyDataType.Array:
						this._stack.push(aggr.array[begin..end]);
						break;
					case IvyDataType.ClassNode:
						// Class node must have it's own range checks
						this._stack.push(aggr.classNode[begin..end]);
						break;
					default:
						this.log.internalError("Unexpected aggregate type");
				}
				break;
			}

			// Concatenates two arrays or strings and puts result onto stack
			case OpCode.Concat:
			{
				IvyData right = this._stack.pop();
				IvyData left = this._stack.pop();

				this.log.internalAssert(
					left.type == right.type,
					"Left and right operands for concatenation operation must have the same type!");

				switch( left.type )
				{
					case IvyDataType.String:
						this._stack.push(left.str ~ right.str);
						break;
					case IvyDataType.Array:
						this._stack.push(left.array ~ right.array);
						break;
					default:
						this.log.internalError("Unexpected type of operand");
				}
				break;
			}

			case OpCode.Append:
			{
				IvyData value = this._stack.pop();
				this._stack.back.array ~= value;
				break;
			}

			case OpCode.Insert:
			{
				import std.array: insertInPlace;

				IvyData posNode = this._stack.pop();
				IvyData value = this._stack.pop();
				IvyData[] aggr = this._stack.back.array;

				size_t pos;
				switch( posNode.type )
				{
					case IvyDataType.Integer:
						pos = posNode.integer;
						break;
					case IvyDataType.Undef:
					case IvyDataType.Null:
						pos = aggr.length; // Act like append
						break;
					default:
						this.log.internalError("Position argument expected to be an integer or empty (for append), but got: ", posNode);
				}
				this.log.internalAssert(
					pos <= aggr.length,
					"Insert position is wrong: ", pos);
				aggr.insertInPlace(pos, value);
				break;
			}

			// Flow control opcodes
			case OpCode.JumpIfTrue:
			case OpCode.JumpIfFalse:
			case OpCode.JumpIfTrueOrPop:
			case OpCode.JumpIfFalseOrPop:
			{
				// This is actual condition to test
				bool jumpCond = (
					instr.opcode == OpCode.JumpIfTrue || instr.opcode == OpCode.JumpIfTrueOrPop
				) == this._stack.back.toBoolean();

				if( 
					instr.opcode == OpCode.JumpIfTrue || instr.opcode == OpCode.JumpIfFalse || !jumpCond
				) {
					// In JumpIfTrue, JumpIfFalse we should drop condition from stack anyway
					// But for JumpIfTrueOrPop, JumpIfFalseOrPop drop it only if jumpCond is false
					this._stack.pop();
				}

				if( jumpCond )
				{
					this.setJump(instr.arg);
					return; // Skip _pk increment
				}
				break;
			}

			case OpCode.Jump:
			{
				this.setJump(instr.arg);
				return; // Skip _pk increment
			}

			case OpCode.Return:
			{
				// Set instruction index at the end of code object in order to finish 
				this.setJump(this._codeRange.length);
				IvyData result = this._stack.back;
				// Erase all from the current stack
				this._stack.popN(this._stack.length);
				this._stack.push(result); // Put result on the stack
				return; // Skip _pk increment
			}

			case OpCode.GetDataRange:
			{
				import ivy.types.data.range.array: ArrayRange;
				import ivy.types.data.range.assoc_array: AssocArrayRange;

				IvyData aggr = this._stack.pop();
				IvyData res;
				switch( aggr.type )
				{
					case IvyDataType.Array:
					{
						res = new ArrayRange(aggr.array);
						break;
					}
					case IvyDataType.AssocArray:
					{
						res = new AssocArrayRange(aggr.assocArray);
						break;
					}
					case IvyDataType.ClassNode:
					{
						res = aggr.classNode[];
						break;
					}
					case IvyDataType.DataNodeRange:
					{
						res = aggr;
						break;
					}
					default:
						this.log.internalError("Expected iterable aggregate, but got: ", aggr);
				}
				this._stack.push(res); // Push range onto stack
				break;
			}

			case OpCode.RunLoop:
			{
				auto dataRange = this._stack.back.dataRange;
				if( dataRange.empty )
				{
					this._stack.pop(); // Drop data range when iteration finished
					// Jump to instruction after loop
					this.setJump(instr.arg);
					break;
				}

				this._stack.push(dataRange.front);
				dataRange.popFront();
				break;
			}

			case OpCode.ImportModule:
			{
				if( this.runImportModule(this._stack.pop().str) )
					return; // Skip _pk increment
				break;
			}

			case OpCode.FromImport:
			{
				IvyData[] importList = this._stack.pop().array;
				ExecutionFrame moduleFrame = this._stack.pop().execFrame;

				foreach( nameNode; importList )
				{
					string name = nameNode.str;
					this.setValue(name, moduleFrame.getValue(name));
				}
				break;
			}

			case OpCode.LoadFrame:
			{
				this._stack.push(this.currentFrame);
				break;
			}

			case OpCode.MakeCallable:
			{
				CallSpec callSpec = CallSpec(instr.arg);
				this.log.internalAssert(
					callSpec.posAttrsCount == 0,
					"Positional default attribute values are not expected");

				CodeObject codeObject = this._stack.pop().codeObject;

				// Get dict of default attr values from stack if exists
				// We shall not check for odd values here, because we believe compiler can handle it
				IvyData[string] defaults = callSpec.hasKwAttrs? this._stack.pop().assocArray: null;

				this._stack.push(new CallableObject(codeObject, defaults));
				break;
			}

			case OpCode.RunCallable:
			{
				this.log.write("RunCallable stack on init: : ", this._stack);
				if( this.runCallableNode(this._stack.pop(), CallSpec(instr.arg)) )
					return; // Skip _pk increment
				break;
			}

			case OpCode.Await: {
				import ivy.types.data.utils: errorToIvyData;

				AsyncResult aResult = this._stack.pop().asyncResult;
				this.log.internalAssert(
					aResult.state != AsyncResultState.pending,
					"Async operations in server-side interpreter are fake and actually not supported");
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

			case OpCode.MarkForEscape: {
				import ivy.types.data: NodeEscapeState;
				this._stack.back.escapeState = cast(NodeEscapeState) instr.arg;
				break;
			}
		} // switch

		++this._pk;
	} // execLoopBody


	auto log(string func = __FUNCTION__, string file = __FILE__, int line = __LINE__)
	{
		import ivy.interpreter.log_proxy: InterpreterLogProxy;
		return InterpreterLogProxy(func, file, line, this);
	}

	/// Method for setting interpreter's loger method
	void logerMethod(LogerMethod method) @property {
		_logerMethod = method;
	}

	ExecutionFrame globalFrame() @property {
		return this._moduleFrames[GLOBAL_SYMBOL_NAME];
	}

	// Method used to add extra global data into interpreter
	// Consider not to bloat it to much ;)
	void addExtraGlobals(IvyData[string] extraGlobals)
	{
		foreach( string name, IvyData dataNode; extraGlobals ) {
			this.globalFrame.setValue(name, dataNode);
		}
	}

	/++ Returns nearest execution frame from _frameStack +/
	ExecutionFrame currentFrame() @property
	{
		import std.range: empty, back;

		this.log.internalAssert(!this._frameStack.empty, "Execution frame stack is empty!");
		return this._frameStack.back;
	}

	/++ Returns nearest independent execution frame that is not marked `noscope`+/
	ExecutionFrame independentFrame() @property
	{
		import std.range: empty;
		this.log.internalAssert(!this._frameStack.empty, "Execution frame stack is empty!");

		for( size_t i = this._frameStack.length; i > 0; --i )
		{
			ExecutionFrame frame = this._frameStack[i-1];
			if( frame.hasOwnScope ) {
				return frame;
			}
		}
		this.log.internalError("Cannot get current independent execution frame!");
		assert(false);
	}

	ICallableObject currentCallable() @property {
		return this.currentFrame.callable;
	}

	CodeObject currentCodeObject()
	{
		ICallableObject callable = this.currentCallable;
		if( !callable.isNative ) {
			return callable.codeObject;
		}
		return null;
	}

	ModuleObject currentModule() @property
	{
		CodeObject codeObject = this.currentCodeObject;
		if( codeObject ) {
			return codeObject.moduleObject;
		}
		return null;
	}

	void setJump(size_t instrIndex)
	{
		this.log.internalAssert(
			instrIndex <= this._codeRange.length,
			"Cannot jump after the end of code object");
		this._pk = instrIndex;
	}

	OpCode currentOpCode()
	{
		if( this._pk < this._codeRange.length ) {
			return cast(OpCode) this._codeRange[this._pk].opcode;
		}
		return OpCode.InvalidCode;
	}

	size_t currentInstrLine()
	{
		if( CodeObject codeObject = this.currentCodeObject ) {
			return codeObject.getInstrLine(this._pk);
		}
		return 0;
	}

	string[] callStackInfo()
	{
		string[] res;
		for( size_t i = this._frameStack.length; i > 0; --i )
		{
			ICallableObject callable = this._frameStack[i-1].callable;
			res ~= "Module: " ~ callable.moduleSymbol.name ~ ", Directive: " ~ callable.symbol.name;
		}
		return res;
	}

	IvyData getModuleConst(size_t index)
	{
		ModuleObject moduleObject = this.currentModule;
		log.internalAssert(moduleObject !is null, "Unable to get current module object");

		return moduleObject.getConst(index);
	}

	IvyData getModuleConstCopy(size_t index)
	{
		import ivy.types.data.utils: deeperCopy;

		return deeperCopy( getModuleConst(index) );
	}

	auto _doBinaryOp(T)(OpCode opcode, T left, T right)
	{
		import std.traits: isNumeric;

		switch( opcode )
		{
			static if( isNumeric!T )
			{
				// Arithmetic
				case OpCode.Add: return left + right;
				case OpCode.Sub: return left - right;
				case OpCode.Mul: return left * right;
				case OpCode.Div: return left / right;
				case OpCode.Mod: return left % right;
			}

			// Equality comparision
			case OpCode.Equal: return left == right;
			case OpCode.NotEqual: return left != right;

			static if( isNumeric!T )
			{
				// General comparision
				case OpCode.LT: return left < right;
				case OpCode.GT: return left > right;
				case OpCode.LTEqual: return left <= right;
				case OpCode.GTEqual: return left >= right;
			}
			default: this.log.internalError("Unexpected code of binary operation");
		}
		assert(false);
	}

	void newFrame(ICallableObject callable, IvyData[string] dataDict = null)
	{
		import ivy.types.symbol.consts: SymbolKind;
		string symbolName = callable.symbol.name;

		this._frameStack ~= new ExecutionFrame(callable, dataDict);
		this._stack.addStackBlock();
		this.log.write("Enter new execution frame for callable: ", symbolName);

		if( callable.symbol.kind == SymbolKind.module_ )
		{
			this.log.internalAssert(symbolName != GLOBAL_SYMBOL_NAME, "Cannot create module name with name: ", GLOBAL_SYMBOL_NAME);
			this._moduleFrames[symbolName] = this.currentFrame;
		}
	}

	void removeFrame()
	{
		import std.range: empty, back, popBack;
		this.log.internalAssert(!this._frameStack.empty, "Execution frame stack is empty!");
		this._stack.removeStackBlock();
		this._frameStack.popBack();
	}

	ExecutionFrame findValueFrame(string varName) {
		return this.findValueFrameImpl!false(varName);
	}

	ExecutionFrame findValueFrameGlobal(string varName) {
		return this.findValueFrameImpl!true(varName);
	}

	// Returns execution frame for variable
	ExecutionFrame findValueFrameImpl(bool globalSearch = false)(string varName)
	{
		import std.range: back;
		this.log.write("Starting to search for variable: ", varName);

		for( size_t i = this._frameStack.length; i > 0; --i )
		{
			ExecutionFrame frame = this._frameStack[i-1];

			if( frame.hasValue(varName) ) {
				return frame;
			}

			static if( globalSearch )
			{
				ExecutionFrame modFrame = this._getModuleFrame(frame.callable);
				if( modFrame.hasValue(varName) ) {
					return modFrame;
				}
			}

			if( frame.hasOwnScope ) {
				break;
			}
		}

		static if( globalSearch )
		{
			if( this.globalFrame.hasValue(varName) ) {
				return this.globalFrame;
			}
		}
		// By default store vars in local frame
		return this._frameStack.back;
	}

	IvyData getValue(string varName) {
		return this.findValueFrame(varName).getValue(varName);
	}

	IvyData getGlobalValue(string varName) {
		return this.findValueFrameGlobal(varName).getValue(varName);
	}

	void setValue(string varName, IvyData value) {
		this.findValueFrame(varName).setValue(varName, value);
	}

	void setGlobalValue(string varName, IvyData value) {
		this.findValueFrameGlobal(varName).setValue(varName, value);
	}

	ExecutionFrame _getModuleFrame(ICallableObject callable)
	{
		string moduleName = callable.moduleSymbol.name;
		ExecutionFrame moduleFrame = this._moduleFrames.get(moduleName, null);
		this.log.internalAssert(
			moduleFrame !is null,
			"Module frame with name: ", moduleFrame, " of callable: ", callable.symbol.name, " does not exist!");
		return moduleFrame;
	}

	IvyData[string] _extractCallArgs(
		ICallableObject callable,
		IvyData[string] kwAttrs = null,
		CallSpec callSpec = CallSpec()
	) {
		DirAttr[] attrSymbols = callable.symbol.attrs;
		IvyData[string] defaults = callable.defaults;

		if( callSpec.hasKwAttrs )
			kwAttrs = this._stack.pop().assocArray;

		this.log.internalAssert(
			callSpec.posAttrsCount <= attrSymbols.length,
			"Positional parameters count is more than expected arguments count");

		IvyData[string] callArgs;

		// Getting positional arguments from stack (in reverse order)
		for( size_t idx = callSpec.posAttrsCount; idx > 0; --idx ) {
			callArgs[attrSymbols[idx - 1].name] = this._stack.pop();
		}

		// Getting named parameters from kwArgs
		for( size_t idx = callSpec.posAttrsCount; idx < attrSymbols.length; ++idx )
		{
			DirAttr attr = attrSymbols[idx];
			if( IvyData* valPtr = attr.name in kwAttrs ) {
				callArgs[attr.name] = *valPtr;
			}
			else
			{
				// We should get default value if no value is passed from outside
				IvyData* defValPtr = attr.name in defaults;
				this.log.internalAssert(
					defValPtr !is null,
					"Expected value for attr: ",
					attr.name,
					", that has no default value"
				);
				callArgs[attr.name] = deeperCopy(*defValPtr);
			}
		}

		// Set "context-variable" for callables that has it...
		if( auto thisArgPtr = "this" in kwAttrs )
			callArgs["this"] =  *thisArgPtr;
		else if( callable.context.type != IvyDataType.Undef )
			callArgs["this"] = callable.context;

		this.log.write("this._stack after parsing all arguments: ", this._stack);

		return callArgs;
	}

	bool runCallableNode(IvyData callableNode, CallSpec callSpec)
	{
		ICallableObject callable;
		if( callableNode.type == IvyDataType.ClassNode )
		{
			// If class node passed there, then we shall get callable from it by calling "__call__"
			callable = callableNode.classNode.__call__();
		}
		else
		{
			// Else we expect that callable passed here
			callable = callableNode.callable;
		}

		return this._runCallableImpl(callable, null, callSpec); // Skip _pk increment
	}

	bool runCallable(ICallableObject callable, IvyData[string] kwAttrs = null) {
		return this._runCallableImpl(callable, kwAttrs); // Skip _pk increment
	}

	bool _runCallableImpl(ICallableObject callable, IvyData[string] kwAttrs = null, CallSpec callSpec = CallSpec())
	{
		this.log.write("RunCallable name: ", callable.symbol.name);

		IvyData[string] callArgs = this._extractCallArgs(callable, kwAttrs, callSpec);

		this._stack.push(this._pk + 1); // Put next instruction index on the stack to return at

		this.newFrame(callable, callArgs);

		// Set new instruction range to execute
		this._codeRange = callable.isNative? [Instruction(OpCode.Nop)]: callable.codeObject.instrs[];
		this.setJump(0);

		if( callable.isNative )
		{
			// Run native directive interpreter
			callable.dirInterp.interpret(this);
			return false;
		}
		return true; // Skip _pk increment
	}

	bool runImportModule(string moduleName)
	{
		ModuleObject moduleObject = this._moduleObjCache.get(moduleName);
		ExecutionFrame moduleFrame = this._moduleFrames.get(moduleName, null);

		this.log.internalAssert(moduleObject !is null, "No such module object: ", moduleName);
		if( moduleFrame )
		{
			// Module is imported already. Just push it's frame onto stack
			this._stack.push(moduleFrame); 
			return false;
		}
		return this.runCallable(new CallableObject(moduleObject.mainCodeObject));
	}

	AsyncResult importModule(string moduleName)
	{
		AsyncResult fResult = new AsyncResult();
		try {
			this.runImportModule(moduleName);
			this.execLoopImpl(fResult, 1);
		} catch( Throwable ex ) {
			fResult.reject(ex);
		}
		return fResult;
	}

	AsyncResult execModuleDirective(string name, IvyData[string] kwArgs = null)
	{
		// Find desired directive by name in current module frame
		ICallableObject callable = this.currentFrame.getValue(name).callable;

		this.log.internalAssert(this._stack.length < 2, "Expected 0 or 1 items in stack!");
		if( this._stack.length == 1 ) {
			this._stack.pop(); // Drop old result from stack
		}

		AsyncResult fResult = new AsyncResult();
		try {
			this.runCallable(callable, kwArgs);
			this.execLoopImpl(fResult, 2);
		} catch( Throwable ex ) {
			fResult.reject(ex);
		}
		return fResult;
	}

	InterpDirAttr[string] getDirAttrs(string name, string[] attrNames = null)
	{
		import std.range: empty;
		import std.algorithm: canFind;

		ICallableObject callable = this.currentFrame.getValue(name).callable;
		DirAttr[] attrs = callable.symbol.attrs;
		IvyData[string] defaults = callable.defaults;
		InterpDirAttr[string] res;

		for( size_t i = 0; i < attrs.length; ++i )
		{
			DirAttr attr = attrs[i];
			if( attrNames.length && !attrNames.canFind(attr.name) ) {
				continue;
			}
			InterpDirAttr ida;
			ida.attr = attr;
			if( auto defValPtr = attr.name in defaults ) {
				ida.defaultValue = *defValPtr;
			}
			res[attr.name] = ida;
		}

		return res;
	}
}

