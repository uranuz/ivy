module ivy.interpreter.interpreter;

// If IvyTotalDebug is defined then enable parser debug
version(IvyTotalDebug) version = IvyInterpreterDebug;

private enum LoopAction: byte {
	skipPKIncr, // Do not increment pk after loop body execution
	normal, // Increment pk after loop body execution
	await // Increment pk after loop body execution and await
}


class Interpreter {
	import trifle.location: Location;
	import trifle.utils: ensure;

	import ivy.bytecode: Instruction, OpCode;

	import ivy.engine.module_object_cache: ModuleObjectCache;
	import ivy.exception: IvyException;

	import ivy.types.code_object: CodeObject;
	import ivy.types.call_spec: CallSpec;
	import ivy.types.callable_object: CallableObject;
	import ivy.types.data: IvyDataType, IvyData;
	import ivy.types.data.iface.class_node: IClassNode;
	import ivy.types.data.decl_class: DeclClass;
	import ivy.types.data.utils: deeperCopy;
	import ivy.types.data.async_result: AsyncResult, AsyncResultState;
	import ivy.types.module_object: ModuleObject;
	import ivy.types.symbol.dir_attr: DirAttr;
	import ivy.types.symbol.global: GLOBAL_SYMBOL_NAME;
	import ivy.types.symbol.iface.callable: ICallableSymbol;

	import ivy.interpreter.directive.iface: IDirectiveInterpreter;
	import ivy.interpreter.directive.factory: InterpreterDirectiveFactory;
	import ivy.interpreter.exec_frame_info: ExecFrameInfo;
	import ivy.interpreter.execution_frame: ExecutionFrame;
	import ivy.interpreter.exec_stack: ExecStack;
	import ivy.interpreter.exception: IvyInterpretException;

	import ivy.log: LogInfo, IvyLogProxy, LogerMethod;

public:
	alias assure = ensure!IvyInterpretException;

	package __gshared CallableObject _globalCallable;

	// LogWriter method used to send error and debug messages
	IvyLogProxy _log;

	// Storage for bytecode code and initial constant data for modules
	ModuleObjectCache _moduleObjCache;

	InterpreterDirectiveFactory _directiveFactory;

	// Storage for execution frames of imported modules
	ExecutionFrame[string] _moduleFrames;

	// Stack of execution frames with directives or modules local data
	ExecutionFrame[] _frameStack;

	// Stack of data of frame that is used by interpreter
	ExecStack _stack;

	this(
		ModuleObjectCache moduleObjCache,
		InterpreterDirectiveFactory directiveFactory,
		LogerMethod logerMethod = null
	) {
		this._moduleObjCache = moduleObjCache;
		this._directiveFactory = directiveFactory;

		this._log = IvyLogProxy(logerMethod? (ref LogInfo logInfo) {
			// Add current location info to log message
			logInfo.location = this.currentLocation;
			logerMethod(logInfo);
		}: null);

		assure(this._moduleObjCache !is null, "Expected module objects cache");
		assure(this._directiveFactory !is null, "Expected directive factory");

		// Add global execution frame. Do not add it to _frameStack!
		this._moduleFrames[GLOBAL_SYMBOL_NAME] = new ExecutionFrame(_globalCallable);

		// Add custom native directive interpreters to global scope
		foreach( dirInterp; directiveFactory.interps ) {
			this.globalFrame.setValue(dirInterp.symbol.name, IvyData(new CallableObject(dirInterp)));
		}
	}

	void execLoop(AsyncResult fResult) {
		// Save initial execution frame count.
		size_t initFrameCount = this._frameStack.length;

		IvyData res = this.execLoopImpl(initFrameCount);
		if( this._frameStack.length < initFrameCount ) {
			// If exec frame stack is less than initial then job is done
			fResult.resolve(res);
		}
		// Looks like interpreter was suspended by async operation
	}

	IvyData execLoopSync() {
		// Save initial execution frame count.
		size_t initFrameCount = this._frameStack.length;

		IvyData res = this.execLoopImpl(initFrameCount);
		assure(
			this._frameStack.length < initFrameCount,
			"Requested synchronous code execution, but detected that interpreter was suspended!");
		return res;
	}

	IvyData execLoopImpl(size_t initFrameCount) {
		assure(this._frameStack.length, "Unable to run interpreter if exec frame is empty");

		IvyData res;
		while( this._frameStack.length >= initFrameCount ) {
			while( this.currentFrame.hasInstrs ) {
				LoopAction la = this.execLoopBody();
				if( la == LoopAction.skipPKIncr )
					continue;
				this.currentFrame.nextInstr();
				if( la == LoopAction.await )
					return IvyData();
			}

			// We expect to have only the result of directive on the stack
			assure(this._stack.length == 1, "Exec stack should contain 1 item now");

			res = this._stack.pop(); // Take result
			this.removeFrame(); // Exit out of this frame

			if( this._frameStack.length )
				this._stack.push(res); // Put result back if there is a place for it
		}
		return res;
	}

	LoopAction execLoopBody() {
		Instruction instr = this.currentInstr;
		final switch( instr.opcode ) {
			case OpCode.InvalidCode: {
				assure(false, "Invalid code of operation");
				break;
			}
			case OpCode.Nop: break;

			// Load constant from programme data table into stack
			case OpCode.LoadConst: {
				this._stack.push(this.getModuleConstCopy(instr.arg));
				break;
			}

			// Stack operations
			case OpCode.PopTop: {
				this._stack.pop();
				break;
			}

			// Swaps two top items on the stack
			case OpCode.SwapTwo: {
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

			// General unary operations opcodes
			case OpCode.UnaryPlus: {
				IvyDataType aType = this._stack.back.type;
				assure(
					aType == IvyDataType.Integer || aType == IvyDataType.Floating,
					"Operand for unary plus operation must have integer or floating type!" );

				// Do nothing for now:)
				break;
			}

			case OpCode.UnaryMin: {
				IvyData arg = this._stack.pop();
				switch( arg.type ) {
					case IvyDataType.Integer:
						arg = -arg.integer;
						break;
					case IvyDataType.Floating:
						arg = -arg.floating;
						break;
					default:
						assure(false, "Unexpected type of operand");
						break;
				}
				this._stack.push(arg);
				break;
			}

			case OpCode.UnaryNot: {
				this._stack.push(!this._stack.pop().toBoolean());
				break;
			}

			// Base arithmetic operations execution
			case OpCode.Add:
			case OpCode.Sub:
			case OpCode.Mul:
			case OpCode.Div:
			case OpCode.Mod: {
				// Right value was evaluated last so it goes first in the stack
				IvyData right = this._stack.pop();
				IvyData left = this._stack.pop();

				IvyData res;
				assure(
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
						assure(false, "Unexpected types of operands");
						break;
				}

				this._stack.push(res);
				break;
			}

			// Shallow equality comparision
			case OpCode.Equal:
			case OpCode.NotEqual: {
				this._stack.push(this._doBinaryOp(instr.opcode, this._stack.pop(), this._stack.pop()));
				break;
			}

			// Comparision operations
			case OpCode.LT:
			case OpCode.GT:
			case OpCode.LTEqual:
			case OpCode.GTEqual: {
				// Right value was evaluated last so it goes first in the stack
				IvyData right = this._stack.pop();
				IvyData left = this._stack.pop();

				IvyData res;
				assure(
					left.type == right.type,
					"Operands of less or greather comparision must have the same type");

				switch( left.type ) {
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
						assure(false, "Less or greater comparisions doesn't support type ", left.type, " yet!");
				}
				this._stack.push(res);
				break;
			}

			// Stores data from stack into local context frame variable
			case OpCode.StoreName:
			case OpCode.StoreGlobalName: {
				IvyData varValue = this._stack.pop();
				string varName = getModuleConstCopy(instr.arg).str;

				switch(instr.opcode) {
					case OpCode.StoreName: this.setValue(varName, varValue); break;
					case OpCode.StoreGlobalName: this.setGlobalValue(varName, varValue); break;
					default: assure(false, "Unexpected instruction opcode");
				}
				break;
			}

			// Loads data from local context frame variable by index of var name in module constants
			case OpCode.LoadName: {
				string varName = this.getModuleConstCopy(instr.arg).str;
				this._stack.push(this.getGlobalValue(varName));
				break;
			}

			case OpCode.StoreAttr: {
				IvyData attrVal = this._stack.pop();
				string attrName = this._stack.pop().str;
				IvyData aggr = this._stack.pop();
				final switch( aggr.type ) {
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
						assure(false, "Unable to set attribute of value with type: ", aggr.type);
						break;
					case IvyDataType.AssocArray:
						aggr[attrName] = attrVal;
						break;
					case IvyDataType.ClassNode:
						aggr.classNode.__setAttr__(attrVal, attrName);
						break;
				}
				break;
			}

			// 
			case OpCode.LoadAttr: {
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
						assure(false, "Unable to get attribute of value with type: ", aggr.type);
						break;
					case IvyDataType.AssocArray: {
						IvyData* valPtr = attrName in aggr;
						this._stack.push(valPtr is null? IvyData(): *valPtr);
						break;
					}
					case IvyDataType.ClassNode:
						this._stack.push(aggr.classNode.__getAttr__(attrName));
						break;
					case IvyDataType.ExecutionFrame:
						this._stack.push(aggr.execFrame.getValue(attrName));
						break;
				}
				break;
			}

			case OpCode.MakeArray: {
				IvyData[] newArray = [IvyData()];

				newArray.length = instr.arg; // Preallocating is good ;)
				for( size_t i = instr.arg; i > 0; --i ) {
					// We take array items from the tail, so we must consider it!
					newArray[i-1] = this._stack.pop();
				}
				this._stack.push(newArray);
				break;
			}

			case OpCode.MakeAssocArray: {
				IvyData[string] res;

				for( size_t i = 0; i < instr.arg; ++i ) {
					IvyData val = this._stack.pop();
					string key = this._stack.pop().str;

					res[key] = val;
				}
				this._stack.push(res);
				break;
			}

			case OpCode.MakeClass: {
				DeclClass baseClass = (instr.arg? cast(DeclClass) this._stack.pop().classNode: null);
				IvyData[string] classDataDict = this._stack.pop().assocArray;
				string className = this._stack.pop().str;

				this._stack.push(new DeclClass(className, classDataDict, baseClass));
				break;
			}

			// Set property of object, array item or class object with writeable attribute
			// by passed property name or index
			case OpCode.StoreSubscr: {
				IvyData index = this._stack.pop();
				IvyData value = this._stack.pop();
				IvyData aggr = this._stack.pop();

				switch( aggr.type ) {
					case IvyDataType.Array: {
						assure(
							index.integer < aggr.length,
							"Index is out of bounds of array");
						aggr[index.integer] = value;
						break;
					}
					case IvyDataType.AssocArray:
						aggr[index.str] = value;
						break;
					case IvyDataType.ClassNode: {
						switch( index.type ) {
							case IvyDataType.Integer:
								aggr[index.integer] = value;
								break;
							case IvyDataType.String:
								aggr[index.str] = value;
								break;
							default:
								assure(false, "Index for class node must be string or integer!");
								break;
						}
						break;
					}
					default:
						assure(false, "Unexpected aggregate type");
				}
				break;
			}

			// Load constant from programme data table into stack
			case OpCode.LoadSubscr: {
				import std.utf: toUTFindex, decode;

				IvyData index = this._stack.pop();
				IvyData aggr = this._stack.pop();

				switch( aggr.type ) {
					case IvyDataType.String: {
						// Index operation for string in D is little more complicated
						string aggrStr = aggr.str;
						size_t startIndex = aggrStr.toUTFindex(index.integer); // Get code unit index by index of symbol
						size_t endIndex = startIndex;

						aggrStr.decode(endIndex); // decode increases passed index
						assure(startIndex < aggr.length, "String slice start index must be less than str length");
						assure(endIndex <= aggr.length, "String slice end index must be less or equal to str length");
						this._stack.push(aggrStr[startIndex..endIndex]);
						break;
					}
					case IvyDataType.Array: {
						assure(index.integer < aggr.array.length, "Array index must be less than array length");
						this._stack.push(aggr.array[index.integer]);
						break;
					}
					case IvyDataType.AssocArray: {
						auto valPtr = index.str in aggr.assocArray;
						assure(valPtr, "Key in associative array is not found: ", index);
						this._stack.push(*valPtr);
						break;
					}
					case IvyDataType.ClassNode:
						this._stack.push(aggr.classNode[index]);
						break;
					default:
						assure(false, "Unexpected type of aggregate: ", aggr.type);
				}
				break;
			}

			// Load data node slice for array-like nodes onto stack
			case OpCode.LoadSlice: {
				size_t end = this._stack.pop().integer;
				size_t begin = this._stack.pop().integer;
				IvyData aggr = this._stack.pop();

				switch( aggr.type ) {
					case IvyDataType.String: {
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
						assure(false, "Unexpected aggregate type");
				}
				break;
			}

			// Concatenates two arrays or strings and puts result onto stack
			case OpCode.Concat: {
				IvyData right = this._stack.pop();
				IvyData left = this._stack.pop();

				assure(
					left.type == right.type,
					"Left and right operands for concatenation operation must have the same type!");

				switch( left.type ) {
					case IvyDataType.String:
						this._stack.push(left.str ~ right.str);
						break;
					case IvyDataType.Array:
						this._stack.push(left.array ~ right.array);
						break;
					default:
						assure(false, "Unexpected type of operand");
				}
				break;
			}

			case OpCode.Append: {
				IvyData value = this._stack.pop();
				this._stack.back.array ~= value;
				break;
			}

			case OpCode.Insert: {
				import std.array: insertInPlace;

				IvyData posNode = this._stack.pop();
				IvyData value = this._stack.pop();
				IvyData[] aggr = this._stack.back.array;

				size_t pos;
				switch( posNode.type ) {
					case IvyDataType.Integer:
						pos = posNode.integer;
						break;
					case IvyDataType.Undef:
					case IvyDataType.Null:
						pos = aggr.length; // Act like append
						break;
					default:
						assure(false, "Position argument expected to be an integer or empty (for append), but got: ", posNode);
				}
				assure(pos <= aggr.length, "Insert position is wrong: ", pos);
				aggr.insertInPlace(pos, value);
				break;
			}

			// Flow control opcodes
			case OpCode.JumpIfTrue:
			case OpCode.JumpIfFalse:
			case OpCode.JumpIfTrueOrPop:
			case OpCode.JumpIfFalseOrPop: {
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

				if( jumpCond ) {
					this.setJump(instr.arg);
					return LoopAction.skipPKIncr;
				}
				break;
			}

			case OpCode.Jump: {
				this.setJump(instr.arg);
				return LoopAction.skipPKIncr;
			}

			case OpCode.Return: {
				// Set instruction index at the end of code object in order to finish 
				this.setJump(this.currentFrame.callable.codeObject.instrCount);
				IvyData result = this._stack.back;
				// Erase all from the current stack
				this._stack.popN(this._stack.length);
				this._stack.push(result); // Put result on the stack
				return LoopAction.skipPKIncr;
			}

			case OpCode.GetDataRange: {
				import ivy.types.data.range.array: ArrayRange;
				import ivy.types.data.range.assoc_array: AssocArrayRange;

				IvyData aggr = this._stack.pop();
				IvyData res;
				switch( aggr.type ) {
					case IvyDataType.Array:
						res = new ArrayRange(aggr.array);
						break;
					case IvyDataType.AssocArray:
						res = new AssocArrayRange(aggr.assocArray);
						break;
					case IvyDataType.ClassNode:
						res = aggr.classNode[];
						break;
					case IvyDataType.DataNodeRange:
						res = aggr;
						break;
					default:
						assure(false, "Expected iterable aggregate, but got: ", aggr);
				}
				this._stack.push(res); // Push range onto stack
				break;
			}

			case OpCode.RunLoop: {
				auto dataRange = this._stack.back.dataRange;
				if( dataRange.empty ) {
					// Drop data range when iteration finished
					this._stack.pop();
					// Jump to instruction after loop
					this.setJump(instr.arg);
					break;
				}

				this._stack.push(dataRange.front);
				dataRange.popFront();
				break;
			}

			case OpCode.ImportModule: {
				if( this.runImportModule(this._stack.pop().str) )
					return LoopAction.skipPKIncr;
				break;
			}

			case OpCode.FromImport: {
				IvyData[] importList = this._stack.pop().array;
				ExecutionFrame moduleFrame = this._stack.pop().execFrame;

				foreach( nameNode; importList ) {
					string name = nameNode.str;
					this.setValue(name, moduleFrame.getValue(name));
				}
				break;
			}

			case OpCode.LoadFrame: {
				this._stack.push(this.currentFrame);
				break;
			}

			case OpCode.MakeCallable: {
				CallSpec callSpec = CallSpec(instr.arg);
				assure(
					callSpec.posAttrsCount == 0,
					"Positional default attribute values are not expected");

				CodeObject codeObject = this._stack.pop().codeObject;

				// Get dict of default attr values from stack if exists
				// We shall not check for odd values here, because we believe compiler can handle it
				IvyData[string] defaults = callSpec.hasKwAttrs? this._stack.pop().assocArray: null;

				this._stack.push(new CallableObject(codeObject, defaults));
				break;
			}

			case OpCode.RunCallable: {
				if( this.runCallableNode(this._stack.pop(), CallSpec(instr.arg)) )
					return LoopAction.skipPKIncr;
				break;
			}

			case OpCode.Await: {
				import ivy.types.data.utils: errorToIvyData;

				AsyncResult aResult = this._stack.pop().asyncResult;
				assure(
					aResult.state != AsyncResultState.pending,
					"Async operations in server-side interpreter are fake and actually not supported");
				aResult.then(
					(IvyData data) {
						this._stack.push([
							"isError": IvyData(false),
							"data": data
						]);
					},
					(Throwable error) {
						IvyData ivyError = errorToIvyData(error);
						ivyError["isError"] = true;
						this._stack.push(ivyError);
					}
				);
				break;
				//return LoopAction.await;
			}
		} // switch

		return LoopAction.normal;
	} // execLoopBody

	ExecutionFrame globalFrame() @property {
		return this._moduleFrames[GLOBAL_SYMBOL_NAME];
	}

	// Method used to add extra global data into interpreter
	// Consider not to bloat it to much ;)
	void addExtraGlobals(IvyData[string] extraGlobals) {
		foreach( string name, IvyData dataNode; extraGlobals )
			this.globalFrame.setValue(name, dataNode);
	}

	/++ Returns nearest execution frame from _frameStack +/
	ExecutionFrame currentFrame() @property {
		assure(this._frameStack.length, "Execution frame stack is empty!");
		return this._frameStack[this._frameStack.length - 1];
	}

	/++ Returns previous execution frame +/
	ExecutionFrame previousFrame() @property {
		assure(this._frameStack.length > 1, "No previous execution frame exists!");
		return this._frameStack[this._frameStack.length - 2];
	}

	CallableObject currentCallable() @property {
		return this.currentFrame.callable;
	}

	CodeObject currentCodeObject() {
		CallableObject callable = this.currentCallable;
		if( !callable.isNative ) {
			return callable.codeObject;
		}
		return null;
	}

	ModuleObject currentModule() @property {
		CodeObject codeObject = this.currentCodeObject;
		if( codeObject ) {
			return codeObject.moduleObject;
		}
		return null;
	}

	void setJump(size_t instrIndex) {
		this.currentFrame.setJump(instrIndex);
	}

	Instruction currentInstr() @property {
		if( !this._frameStack.length )
			return typeof(return)();
		return this.currentFrame.currentInstr;
	}

	size_t currentInstrLine() @property {
		import std.range: empty;
		if( !this._frameStack.length  )
			return 0;
		return this.currentFrame.currentInstrLine;
	}

	Location currentLocation() @property {
		import std.range: empty;
		if( !this._frameStack.length  )
			return typeof(return)();
		return this.currentFrame.currentLocation;
	}

	ExecFrameInfo[] frameStackInfo() {
		import std.algorithm: map;
		import std.array: array;

		return this._frameStack.map!((it) => it.info).array;
	}

	IvyData getModuleConst(size_t index) {
		ModuleObject moduleObject = this.currentModule;
		assure(moduleObject, "Unable to get current module object");

		return moduleObject.getConst(index);
	}

	IvyData getModuleConstCopy(size_t index) {
		import ivy.types.data.utils: deeperCopy;

		return deeperCopy(getModuleConst(index));
	}

	auto _doBinaryOp(T)(OpCode opcode, T left, T right)
	{
		import std.traits: isNumeric;

		switch( opcode ) {
			static if( isNumeric!T ) {
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

			static if( isNumeric!T ) {
				// General comparision
				case OpCode.LT: return left < right;
				case OpCode.GT: return left > right;
				case OpCode.LTEqual: return left <= right;
				case OpCode.GTEqual: return left >= right;
			}
			default: assure(false, "Unexpected code of binary operation");
		}
		assert(false);
	}

	void newFrame(CallableObject callable, IvyData[string] dataDict = null) {
		import ivy.types.symbol.consts: SymbolKind;
		string symbolName = callable.symbol.name;

		this._frameStack ~= new ExecutionFrame(callable, dataDict);
		this._stack.addBlock();

		if( callable.symbol.kind == SymbolKind.module_ ) {
			assure(symbolName != GLOBAL_SYMBOL_NAME, "Cannot create module name with name: ", GLOBAL_SYMBOL_NAME);
			this._moduleFrames[symbolName] = this.currentFrame;
		}
	}

	void removeFrame() {
		import std.range: popBack;
		assure(this._frameStack.length, "Execution frame stack is empty!");
		this._stack.removeBlock();
		this._frameStack.popBack();
	}

	ExecutionFrame findValueFrame(string varName) {
		return this.findValueFrameImpl!false(varName);
	}

	ExecutionFrame findValueFrameGlobal(string varName) {
		return this.findValueFrameImpl!true(varName);
	}

	// Returns execution frame for variable
	ExecutionFrame findValueFrameImpl(bool globalSearch = false)(string varName) {
		ExecutionFrame currFrame = this.currentFrame;

		if( currFrame.hasValue(varName) )
			return currFrame;

		static if( globalSearch ) {
			ExecutionFrame modFrame = this._getModuleFrame(currFrame.callable);
			if( modFrame.hasValue(varName) )
				return modFrame;

			if( this.globalFrame.hasValue(varName) )
				return this.globalFrame;
		}
		// By default store vars in local frame
		return currFrame;
	}

	bool hasValue(string varName) {
		return this.findValueFrame(varName).hasValue(varName);
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

	ExecutionFrame _getModuleFrame(CallableObject callable) {
		string moduleName = callable.moduleSymbol.name;
		ExecutionFrame moduleFrame = this._moduleFrames.get(moduleName, null);
		assure(
			moduleFrame,
			"Module frame with name: ", moduleName, " of callable: ", callable.symbol.name, " does not exist!");
		return moduleFrame;
	}

	IvyData[string] _extractCallArgs(
		CallableObject callable,
		IvyData[string] kwAttrs = null,
		CallSpec callSpec = CallSpec()
	) {
		DirAttr[] attrSymbols = callable.symbol.attrs;
		IvyData[string] defaults = callable.defaults;

		if( callSpec.hasKwAttrs )
			kwAttrs = this._stack.pop().assocArray;

		assure(
			callSpec.posAttrsCount <= attrSymbols.length,
			"Positional parameters count is more than expected arguments count");

		IvyData[string] callArgs;

		// Getting positional arguments from stack (in reverse order)
		for( size_t idx = callSpec.posAttrsCount; idx > 0; --idx ) {
			callArgs[attrSymbols[idx - 1].name] = this._stack.pop();
		}

		// Getting named parameters from kwArgs
		for( size_t idx = callSpec.posAttrsCount; idx < attrSymbols.length; ++idx ) {
			DirAttr attr = attrSymbols[idx];
			if( IvyData* valPtr = attr.name in kwAttrs ) {
				callArgs[attr.name] = *valPtr;
			} else {
				// We should get default value if no value is passed from outside
				IvyData* defValPtr = attr.name in defaults;
				assure(defValPtr, "Expected value for attr: ", attr.name, ", that has no default value for callable: ", callable.symbol.name);
				callArgs[attr.name] = deeperCopy(*defValPtr);
			}
		}

		// Set "context-variable" for callables that has it...
		if( auto thisArgPtr = "this" in kwAttrs ) {
			callArgs["this"] =  *thisArgPtr;
		} else if( callable.context.type != IvyDataType.Undef ) {
			callArgs["this"] = callable.context;
		}

		return callArgs;
	}

	bool runCallableNode(IvyData callableNode, CallSpec callSpec) {
		// Skip instruction index increment
		return this._runCallableImpl(this.asCallable(callableNode), null, callSpec);
	}

	bool runCallable(CallableObject callable, IvyData[string] kwAttrs = null) {
		// Skip instruction index increment
		return this._runCallableImpl(callable, kwAttrs);
	}

	bool _runCallableImpl(CallableObject callable, IvyData[string] kwAttrs = null, CallSpec callSpec = CallSpec()) {
		IvyData[string] callArgs = this._extractCallArgs(callable, kwAttrs, callSpec);

		if( this._frameStack.length )
			this.currentFrame.nextInstr(); // Set next instruction to execute after callable

		this.newFrame(callable, callArgs);

		if( callable.isNative ) {
			// Run native directive interpreter
			callable.dirInterp.interpret(this);
			return false;
		}
		return true; // Skip instruction index increment
	}

	bool runImportModule(string moduleName) {
		ModuleObject moduleObject = this._moduleObjCache.get(moduleName);
		ExecutionFrame moduleFrame = this._moduleFrames.get(moduleName, null);

		assure(moduleObject, "No such module object: ", moduleName);
		if( moduleFrame ) {
			// Module is imported already. Just push it's frame onto stack
			this._stack.push(moduleFrame); 
			return false;
		}
		return this.runCallable(new CallableObject(moduleObject.mainCodeObject));
	}

	AsyncResult importModule(string moduleName) {
		AsyncResult fResult = new AsyncResult();
		try {
			if( this.runImportModule(moduleName) )
				// Need to run interpreter to import module
				this.execLoop(fResult);
			else
				// Module is imported already. Just return it
				fResult.resolve(this._stack.back);
		} catch(Throwable ex) {
			fResult.reject(this.updateNLogError(ex));
		}
		return fResult;
	}

	AsyncResult execCallable(CallableObject callable, IvyData[string] kwArgs = null) {
		AsyncResult fResult = new AsyncResult();
		try {
			this.runCallable(callable, kwArgs);
			this.execLoop(fResult);
		} catch( Throwable ex ) {
			fResult.reject(this.updateNLogError(ex));
		}
		return fResult;
	}

	IvyData execCallableSync(CallableObject callable, IvyData[string] kwArgs = null) {
		this.runCallable(callable, kwArgs);
		return this.execLoopSync();
	}

	IvyData execClassMethodSync(IClassNode classNode, string method, IvyData[string] kwArgs = null) {
		return this.execCallableSync(classNode.__getAttr__(method).callable, kwArgs);
	}

	AsyncResult execClassMethod(IClassNode classNode, string method, IvyData[string] kwArgs = null) {
		return this.execCallable(classNode.__getAttr__(method).callable, kwArgs);
	}

	/// Updates exception with frame stack info of interpreter
	IvyException updateError(Throwable ex) {
		import std.algorithm: castSwitch;
		return ex.castSwitch!(
			(IvyInterpretException interpEx) {
				interpEx.frameStackInfo = this.frameStackInfo;
				return interpEx;
			},
			(IvyException ivyEx) {
				return ivyEx; // It's good exception. Do nothing more...
			},
			(Throwable anyEx) {
				auto updEx = new IvyInterpretException(ex.msg, ex.file, ex.line, anyEx);
				updEx.frameStackInfo = this.frameStackInfo;
				return updEx;
			},
			() {
				auto updEx = new IvyInterpretException("Unhandled error");
				updEx.frameStackInfo = this.frameStackInfo;
				return updEx;
			}
		)();
	}

	/// Updates exception with frame stack info of interpreter and writes it to log
	IvyException updateNLogError(Throwable ex) {
		IvyException updEx = this.updateError(ex);
		this._log.error(cast(string) updEx.message);
		return updEx;
	}

	static CallableObject asCallable(IvyData callableNode) {
		// If class node passed there, then we shall get callable from it by calling "__call__"
		if( callableNode.type == IvyDataType.ClassNode )
			return callableNode.classNode.__call__();

		// Else we expect that callable passed here
		return callableNode.callable;
	}
}

