define('ivy/interpreter/interpreter', [
	'ivy/types/data/consts',
	'ivy/types/symbol/consts',
	'ivy/types/data/data',
	'ivy/utils',
	'ivy/types/data/utils',
	'ivy/bytecode',
	'ivy/interpreter/exec_stack',
	'ivy/interpreter/execution_frame',
	'ivy/types/callable_object',
	'ivy/types/data/range/array',
	'ivy/types/data/range/assoc_array',
	'ivy/types/data/async_result',
	'ivy/log/proxy',
	'ivy/interpreter/directive/global',
	'ivy/types/call_spec'
], function(
	DataConsts,
	SymbolConsts,
	idat,
	iutil,
	dutil,
	Bytecode,
	ExecStack,
	ExecutionFrame,
	CallableObject,
	ArrayRange,
	AssocArrayRange,
	AsyncResult,
	LogProxy,
	globalCallable,
	CallSpec
) {
var
	GLOBAL_SYMBOL_NAME = SymbolConsts.GLOBAL_SYMBOL_NAME,
	SymbolKind = SymbolConsts.SymbolKind,
	IvyDataType = DataConsts.IvyDataType,
	OpCode = Bytecode.OpCode,
	Instruction = Bytecode.Instruction;
return FirClass(
function Interpreter(
	moduleObjCache,
	directiveFactory
) {
	this._log = new LogProxy();

	this._frameStack = [];
	this._moduleFrames = {};
	this._moduleObjCache = moduleObjCache;
	this._directiveFactory = directiveFactory;
	this._stack = new ExecStack();
	this._pk = 0;
	this._codeRange = [];

	this._moduleFrames[GLOBAL_SYMBOL_NAME] = new ExecutionFrame(globalCallable);

	// Add custom native directive interpreters to global scope
	directiveFactory.interps.forEach(function(dirInterp) {
		this.globalFrame.setValue(dirInterp.symbol.name, new CallableObject(dirInterp));
	}.bind(this));
}, {
	execLoop: function() {
		var
			fResult = new AsyncResult(),
			codeObject = this.currentCodeObject;;
		this.log.internalAssert(codeObject != null, "Expected current code object to run");

		this._codeRange = codeObject.instrs;
		this.setJump(0);
		try {
			this.execLoopImpl(fResult);
		} catch (ex) {
			fResult.reject(ex);
		}
		return fResult;
	},

	execLoopImpl: function(fResult, exitFrames) {
		exitFrames = exitFrames || 1;
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

			var result = this._stack.pop(); // Take result
			this.removeFrame(); // Exit out of this frame

			var codeObject = this.currentCodeObject;
			this.log.internalAssert(codeObject != null, "Expected code object");

			this._codeRange = codeObject.instrs; // Set old instruction range back
			this.setJump(this._stack.pop());
			this._stack.push(result); // Put result back
		}

		fResult.resolve(this._stack.back);
	},

	execLoopBody: function() {
		var instr = this._codeRange[this._pk];

		switch( instr.opcode ) {
			case OpCode.InvalidCode: {
				this.log.internalError("Invalid code of operation");
				break;
			}
			case OpCode.Nop: break;

			// Load constant from programme data table into stack
			case OpCode.LoadConst: {
				this._stack.push( this.getModuleConstCopy(instr.arg) );
				break;
			}

			// Stack operations
			case OpCode.PopTop: {
				this._stack.pop();
				break;
			}

			case OpCode.SwapTwo: {
				var
					top = this._stack.pop(),
					beforeTop = this._stack.pop();
				this._stack.push(top);
				this._stack.push(beforeTop);
				break;
			}

			case OpCode.DubTop: {
				this._stack.push(this._stack.back);
				break;
			}

			case OpCode.UnaryPlus: {
				var arg = this._stack.back;
				this.log.internalAssert(
					[IvyDataType.Integer, IvyDataType.Floating].includes(idat.type(arg)),
					"Operand for unary plus operation must have integer or floating type!" );
				// Do nothing
				break;
			}

			// General unary operations opcodes
			case OpCode.UnaryMin: {
				var arg = this._stack.pop();
				this.log.internalAssert(
					[IvyDataType.Integer, IvyDataType.Floating].includes(idat.type(arg)),
					"Operand for unary minus operation must have integer or floating type!" );
				this._stack.push(-arg);
				break;
			}
			case OpCode.UnaryNot: {
				this._stack.push(!idat.toBoolean(this._stack.pop()));
				break;
			}

			// Arithmetic binary operations opcodes
			case OpCode.Add:
			case OpCode.Sub:
			case OpCode.Mul:
			case OpCode.Div:
			case OpCode.Mod: {
				var
					right = this._stack.pop(),
					left = this._stack.pop(),
					lType = idat.type(left),
					res;
				this.log.internalAssert(
					lType == idat.type(right),
					"Left and right values of arithmetic operation must have the same integer or floating type!");

				switch( lType )
				{
					case IvyDataType.Integer:
						res = this._doBinaryOp(instr.opcode, left, right);
						break;
					case IvyDataType.Floating:
						res = this._doBinaryOp(instr.opcode, left, right);
						break;
					default:
						this.log.error("Unexpected types of operands");
						break;
				}

				this._stack.push(res);
				break;
			}

			// Comparision operations opcodes
			case OpCode.Equal:
			case OpCode.NotEqual: {
				this._stack.push(this._doBinaryOp(instr.opcode, this._stack.pop(), this._stack.pop()));
				break;
			}
			case OpCode.LT:
			case OpCode.GT:
			case OpCode.LTEqual:
			case OpCode.GTEqual: {
				var
					right = this._stack.pop(),
					left = this._stack.pop(),
					lType = idat.type(left),
					res;

				this.log.internalAssert(
					lType === idat.type(right),
					"Operands of less or greather comparision must have the same type");
				
				switch( lType )
				{
					case IvyDataType.Undef:
					case IvyDataType.Null:
						// Undef and Null are not less or equal to something
						res = false;
						break;
					case IvyDataType.Integer:
					case IvyDataType.Floating:
					case IvyDataType.String:
						res = this._doBinaryOp(instr.opcode, left.integer, right.integer);
						break;
					default:
						this.log.internalError("Less or greater comparisions doesn't support type ", lType, " yet!");
				}
				this._stack.push(res);
				break;
			}

			// Frame data load/ store
			case OpCode.StoreName:
			case OpCode.StoreGlobalName: {
				var
					varValue = this._stack.pop(),
					varName = idat.str(this.getModuleConstCopy(instr.arg));

				switch( instr.opcode ) {
					case OpCode.StoreName: this.setValue(varName, varValue); break;
					case OpCode.StoreGlobalName: this.setGlobalValue(varName, varValue); break;
					default: this.log.internalError("Unexpected instruction opcode");
				}
				break;
			}
			case OpCode.LoadName: {
				var varName = idat.str(this.getModuleConstCopy(instr.arg));
				this._stack.push(this.getGlobalValue(varName));
				break;
			}

			// Work with attributes
			case OpCode.StoreAttr:
			{
				var
					attrVal = this._stack.pop(),
					attrName = idat.str(this._stack.pop()),
					aggr = this._stack.pop();
				switch( idat.type(aggr) )
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
						this.log.internalError("Unable to set attribute of value with type: ", idat.type(aggrNode));
						break;
					case IvyDataType.AssocArray:
					{
						aggr[attrName.str] = attrVal;
						break;
					}
					case IvyDataType.ClassNode:
					{
						idat.classNode(aggr).__setAttr__(attrVal, attrName);
						break;
					}
				}
				break;
			}

			// 
			case OpCode.LoadAttr:
			{
				var
					attrName = idat.str(this._stack.pop()),
					aggr = this._stack.pop();

				switch( idat.type(aggr) )
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
						this.log.internalError("Unable to get attribute of value with type: ", aggr.type.text);
						break;
					case IvyDataType.AssocArray:
					{
						this._stack.push(aggr[attrName]);
						break;
					}
					case IvyDataType.ClassNode:
					{
						this._stack.push(idat.classNode(aggr).__getAttr__(attrName));
						break;
					}
					case IvyDataType.ExecutionFrame:
					{
						this._stack.push(idat.execFrame(aggr).getValue(attrName));
						break;
					}
				}
				break;
			}

			// Data construction opcodes
			case OpCode.MakeArray: {
				var newArray = [];

				newArray.length = instr.arg; // Preallocating is good ;)
				for( var i = instr.arg; i > 0; --i ) {
					// We take array items from the tail, so we must consider it!
					newArray[i-1] = this._stack.pop();
				}
				this._stack.push(newArray);
				break;
			}
			case OpCode.MakeAssocArray: {
				var newAA = {};

				for( var i = 0; i < instr.arg; ++i ) {
					var
						val = this._stack.pop(),
						key = idat.str(this._stack.pop());

					newAA[key] = val;
				}
				this._stack.push(newAA);
				break;
			}
			case OpCode.MakeClass: {
				var
					baseClass = (instr.arg? idat.classNode(this._stack.pop()): null);
					classDataDict = idat.assocArray(this._stack.pop()),
					className = idat.str(this._stack.pop());

				this._stack.push(new DeclClass(className, classDataDict, baseClass));
				break;
			}

			case OpCode.StoreSubscr: {
				var
					index = this._stack.pop(),
					value = this._stack.pop(),
					aggr = this._stack.pop();

				switch( idat.type(aggr) ) {
					case IvyDataType.Array: {
						this.log.internalAssert(
							idat.integer(index) < aggr.length,
							"Index is out of bounds of array");
						aggr[idat.integer(index)] = value;
						break;
					}
					case IvyDataType.AssocArray: {
						aggr[idat.str(index)] = value;
						break;
					}
					case IvyDataType.ClassNode: {
						switch( idat.type(index) )
						{
							case IvyDataType.Integer:
								aggr[idat.integer(index)] = value;
								break;
							case IvyDataType.String:
								aggr[idat.str(index)] = value;
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

			// Array or assoc array operations
			case OpCode.LoadSubscr: {
				var
					index = this._stack.pop(),
					aggr = this._stack.pop();

				switch( idat.type(aggr) ) {
					case IvyDataType.String:
					case IvyDataType.Array: {
						this.log.internalAssert(
							idat.integer(index) < aggr.length,
							"Array index must be less than array length");
						this._stack.push(aggr[idat.integer(index)]);
						break;
					}
					case IvyDataType.AssocArray: {
						this._stack.push(aggr[idat.str(index)]);
						break;
					}
					case IvyDataType.ClassNode: {
						this._stack.push(aggr.at(index));
						break;
					}
					default:
						this.log.internalError("Unexpected type of aggregate: ", aggr.type);
				}
				break;
			}

			case OpCode.LoadSlice: {
				var
					end = idat.integer(this._stack.pop()),
					begin = idat.integer(this._stack.pop()),
					aggr = this._stack.pop();

				switch( idat.type(aggr) ) {
					case IvyDataType.String:
					case IvyDataType.Array: {
						this._stack.push(aggr.slice(begin, end));
						break;
					}
					case IvyDataType.ClassNode: {
						this._stack.push(aggr.__slice__(begin, end));
						break;
					}
					default:
						this.log.internalError("Unexpected aggregate type");
				}
				break;
			}

			// Arrays or strings concatenation
			case OpCode.Concat: {
				var
					right = this._stack.pop(),
					left = this._stack.pop(),
					lType = idat.type(left);

				this.log.internalAssert(
					lType == idat.type(right),
					"Left and right operands for concatenation operation must have the same type!");

				switch( lType )
				{
					case IvyDataType.String:
						this._stack.push(idat.str(left) + idat.str(right));
						break;
					case IvyDataType.Array:
						this._stack.push(idat.array(left).concat(idat.array(right)));
						break;
					default:
						this.log.internalError("Unexpected type of operand");
				}
				break;
			}

			case OpCode.Append: {
				var value = this._stack.pop();
				idat.array(this._stack.back).push(value);
				break;
			}

			case OpCode.Insert: {
				var
					posNode = this._stack.pop(),
					value = this._stack.pop(),
					aggr = idat.array(this._stack.back);

				var pos;
				switch( idat.type(posNode) )
				{
					case IvyDataType.Integer:
						pos = idat.integer(posNode);
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
				arrNode.splice(pos, 0, value);
				break;
			}

			// Flow control opcodes
			case OpCode.JumpIfTrue:
			case OpCode.JumpIfFalse:
			case OpCode.JumpIfTrueOrPop:
			case OpCode.JumpIfFalseOrPop:
			{
				// This is actual condition to test
				var jumpCond = (
					instr.opcode === OpCode.JumpIfTrue || instr.opcode === OpCode.JumpIfTrueOrPop
				) === idat.toBoolean(this._stack.back);

				if( 
					instr.opcode === OpCode.JumpIfTrue || instr.opcode === OpCode.JumpIfFalse || !jumpCond
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

			case OpCode.Jump: {
				this.setJump(instr.arg);
				return; // Skip _pk increment
			}

			case OpCode.Return: {
				// Set instruction index at the end of code object in order to finish 
				this.setJump(this._codeRange.length);
				var result = this._stack.back;
				// Erase all from the current stack
				this._stack.popN(this._stack.length);
				this._stack.push(result); // Put result on the stack
				return; // Skip _pk increment
			}

			// Loop initialization and execution
			case OpCode.GetDataRange: {
				var
					aggr = this._stack.pop(),
					res;
				switch( idat.type(aggr) ) {
					case IvyDataType.Array:
						res = new ArrayRange(aggr);
						break;
					case IvyDataType.AssocArray:
						res = new AssocArrayRange(aggr);
						break;
					case IvyDataType.ClassNode:
						res = aggr.__range__();
						break;
					case IvyDataType.DataNodeRange:
						res = aggr;
						break;
					default: this.rtError('Expected Array, AssocArray, DataNodeRange or ClassNode as iterable');
				}
				this._stack.push(res); // Push range onto stack
				break;
			}

			case OpCode.RunLoop: {
				var dataRange = idat.dataRange(this._stack.back);
				if( dataRange.empty )
				{
					this._stack.pop(); // Drop data range when iteration finished
					// Jump to instruction after loop
					this.setJump(instr.arg);
					break;
				}

				this._stack.push(dataRange.pop());
				break;
			}

			// Import another module
			case OpCode.ImportModule: {
				if( this.runImportModule(idat.str(this._stack.pop())) )
					return; // Skip _pk increment
				break;
			}

			case OpCode.FromImport: {
				var
					importList = idat.array(this._stack.pop()),
					moduleFrame = idat.execFrame(this._stack.pop());

				for( var i = 0; i < importList.length; ++i ) {
					var name = idat.str(importList[i]);
					this.setValue(name, moduleFrame.getValue(name));
				}
				break;
			}

			case OpCode.LoadFrame: {
				this._stack.push(this.currentFrame);
				break;
			}

			// Preparing and calling directives
			case OpCode.MakeCallable: {
				var callSpec = CallSpec(instr.arg);
				this.log.internalAssert(
					callSpec.posAttrsCount == 0,
					"Positional default attribute values are not expected");

				var codeObject = idat.codeObject(this._stack.pop());

				// Get dict of default attr values from stack if exists
				// We shall not check for odd values here, because we believe compiler can handle it
				var defaults = callSpec.hasKwAttrs? idat.assocArray(this._stack.pop()): {};

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
				var aResult = idat.asyncResult(this._stack.pop());
				++this._pk; // Goto next instruction after resuming execution
				aResult.then(function(data) {
					this._stack.push({
						isError: false,
						data: data
					});
					this.execLoopImpl(fResult, exitFrames);
				}.bind(this), function(data) {
					this._stack.push({
						isError: true,
						data: data
					});
					this.execLoopImpl(fResult, exitFrames);
				}.bind(this));
				return; // Wait for resuming execution
			}

			case OpCode.MarkForEscape: {
				this.log.internalAssert(
					instr.arg < DataConsts.NodeEscapeStateItems.length,
					"Incorrect escape state provided");
				this._stack.back.escapeState = instr.arg;
				break;
			}
			default: this.log.internalError("Unexpected opcode!!!");
		} // switch
		++(this._pk);
	},

	log: firProperty(function() {
		return this._log;
	}),

	globalFrame: firProperty(function() {
		return this._moduleFrames[GLOBAL_SYMBOL_NAME];
	}),


	// Method used to add extra global data into interpreter
	// Consider not to bloat it to much ;)
	addExtraGlobals: function(extraGlobals) {
		for( var name in extraGlobals ) {
			if( extraGlobals.hasOwnProperty(name) ) {
				this.globalFrame.setValue(name, extraGlobals[name]);
			}
		}
	},

	currentFrame: firProperty(function() {
		this.log.internalAssert(this._frameStack.length > 0, "Execution frame stack is empty!");
		return iutil.back(this._frameStack);
	}),

	/** Returns nearest independent execution frame that is not marked `noscope`*/
	independentFrame: firProperty(function() {
		this.log.internalAssert(this._frameStack.length > 0, "Execution frame stack is empty!");

		for( var i = this._frameStack.length; i > 0; --i )
		{
			var frame = this._frameStack[i-1];
			if( frame.hasOwnScope ) {
				return frame;
			}
		}
		this.log.internalError("Cannot get current independent execution frame!");
	}),

	currentCallable: firProperty(function() {
		return this.currentFrame.callable;
	}),

	currentCodeObject: firProperty(function() {
		var callable = this.currentCallable;
		if( !callable.isNative ) {
			return callable.codeObject;
		}
		return null;
	}),

	currentModule: firProperty(function() {
		var codeObject = this.currentCodeObject
		if( codeObject ) {
			return codeObject.moduleObject;
		}
		return null;
	}),

	setJump: function(instrIndex)
	{
		this.log.internalAssert(
			instrIndex <= this._codeRange.length,
			"Cannot jump after the end of code object");
		this._pk = instrIndex;
	},

	getModuleConst: function(index) {
		var moduleObj = this.currentModule;
		this.log.internalAssert(moduleObj != null, "Unable to get module constant");
		return moduleObj.getConst(index);
	},

	getModuleConstCopy: function(index) {
		return dutil.deeperCopy( this.getModuleConst(index) );
	},

	// Execute binary operation
	_doBinaryOp: function(opcode, left, right) {
		switch( opcode ) {
			// Arithmetic
			case OpCode.Add: return left + right;
			case OpCode.Sub: return left - right;
			case OpCode.Mul: return left * right;
			case OpCode.Div: return left / right;
			case OpCode.Mod: return left % right;

			// Equality comparision
			case OpCode.Equal: return idat.opEquals(left, right);
			case OpCode.NotEqual: return !idat.opEquals(left, right);

			// General comparision
			case OpCode.GT: return left > right;
			case OpCode.LT: return left < right;
			case OpCode.GT: return left > right;
			case OpCode.LTEqual: return left <= right;
			case OpCode.GTEqual: return left >= right;
			default: this.log.internalError("Unexpected code of binary operation");;
		}
	},

	newFrame: function(callable, dataDict) {
		var symbolName = callable.symbol.name;

		this._frameStack.push(new ExecutionFrame(callable, dataDict));
		this._stack.addStackBlock();
		this.log.write("Enter new execution frame for callable: ", symbolName);

		if( callable.symbol.kind == SymbolKind.module_ )
		{
			this.log.internalAssert(symbolName != GLOBAL_SYMBOL_NAME, "Cannot create module name with name: ", GLOBAL_SYMBOL_NAME);
			this._moduleFrames[symbolName] = this.currentFrame;
		}
	},

	removeFrame: function() {
		this.log.internalAssert(this._frameStack.length > 0, "Execution frame stack is empty!");
		this._stack.removeStackBlock();
		this._frameStack.pop();
	},

	findValueFrame: function(varName) {
		return this.findValueFrameImpl(varName, false);
	},

	findValueFrameGlobal: function(varName) {
		return this.findValueFrameImpl(varName, true);
	},

	// Returns execution frame for variable
	findValueFrameImpl: function(varName, globalSearch)
	{
		this.log.write("Starting to search for variable: ", varName);

		for( var i = this._frameStack.length; i > 0; --i )
		{
			var frame = this._frameStack[i-1];

			if( frame.hasValue(varName) ) {
				return frame;
			}

			if( globalSearch )
			{
				var modFrame = this._getModuleFrame(frame.callable);
				if( modFrame.hasValue(varName) ) {
					return modFrame;
				}
			}

			if( frame.hasOwnScope ) {
				break;
			}
		}

		if( globalSearch )
		{
			if( this.globalFrame.hasValue(varName) ) {
				return this.globalFrame;
			}
		}
		// By default store vars in local frame
		return iutil.back(this._frameStack);
	},

	getValue: function(varName) {
		return this.findValueFrame(varName).getValue(varName);
	},

	getGlobalValue: function(varName) {
		return this.findValueFrameGlobal(varName).getValue(varName);
	},

	setValue: function(varName, value) {
		this.findValueFrame(varName).setValue(varName, value);
	},

	setGlobalValue: function(varName, value) {
		this.findValueFrameGlobal(varName).setValue(varName, value);
	},

	_getModuleFrame: function(callable) {
		var moduleFrame = this._moduleFrames[callable.moduleSymbol.name];
		this.log.internalAssert(
			moduleFrame != null,
			"Module frame with name: ", moduleFrame, " of callable: ", callable.symbol.name, " does not exist!");
		return moduleFrame;
	},

	_extractCallArgs: function(callable, kwAttrs, callSpec)
	{
		kwAttrs = kwAttrs || {};
		callSpec = callSpec || CallSpec();

		var
			attrSymbols = callable.symbol.attrs,
			defaults = callable.defaults;

		if( callSpec.hasKwAttrs )
			kwAttrs = idat.assocArray(this._stack.pop());

		this.log.internalAssert(
			callSpec.posAttrsCount <= attrSymbols.length,
			"Positional parameters count is more than expected arguments count");

		var callArgs = {};

		// Getting positional arguments from stack (in reverse order)
		for( var idx = callSpec.posAttrsCount; idx > 0; --idx ) {
			callArgs[attrSymbols[idx - 1].name] = this._stack.pop();
		}

		// Getting named parameters from kwArgs
		for( var idx = callSpec.posAttrsCount; idx < attrSymbols.length; ++idx )
		{
			var attr = attrSymbols[idx];
			if( kwAttrs.hasOwnProperty(attr.name) ) {
				callArgs[attr.name] = kwAttrs[attr.name];
			}
			else
			{
				// We should get default value if no value is passed from outside
				this.log.internalAssert(
					defaults.hasOwnProperty(attr.name),
					"Expected value for attr: ",
					attr.name,
					", that has no default value"
				);
				callArgs[attr.name] = dutil.deeperCopy(defaults[attr.name]);
			}
		}

		// Set "context-variable" for callables that has it...
		if( kwAttrs.hasOwnProperty("this") )
			callArgs["this"] =  kwAttrs["this"];
		else if( idat.type(callable.context) != IvyDataType.Undef )
			callArgs["this"] = callable.context;

		return callArgs;
	},

	runCallableNode: function(callableNode, callSpec)
	{
		var callable;
		if( idat.type(callableNode) == IvyDataType.ClassNode )
		{
			// If class node passed there, then we shall get callable from it by calling "__call__"
			callable = idat.classNode(callableNode).__call__();
		}
		else
		{
			// Else we expect that callable passed here
			callable = idat.callable(callableNode);
		}

		return this._runCallableImpl(callable, null, callSpec); // Skip _pk increment
	},

	runCallable: function(callable, kwAttrs) {
		return this._runCallableImpl(callable, kwAttrs); // Skip _pk increment
	},

	_runCallableImpl: function(callable, kwAttrs, callSpec)
	{
		this.log.write("RunCallable name: ", callable.symbol.name);

		var callArgs = this._extractCallArgs(callable, kwAttrs, callSpec);

		this._stack.push(this._pk + 1); // Put next instruction index on the stack to return at

		this.newFrame(callable, callArgs);

		// Set new instruction range to execute
		this._codeRange = callable.isNative? [Instruction(OpCode.Nop)]: callable.codeObject.instrs;
		this.setJump(0);

		if( callable.isNative )
		{
			// Run native directive interpreter
			callable.dirInterp.interpret(this);
			return false;
		}
		return true; // Skip _pk increment
	},

	runImportModule: function(moduleName)
	{
		var
			moduleObject = this._moduleObjCache.get(moduleName),
			moduleFrame = this._moduleFrames[moduleName];

		this.log.internalAssert(moduleObject != null, "No such module object: ", moduleName);
		if( moduleFrame )
		{
			// Module is imported already. Just push it's frame onto stack
			this._stack.push(moduleFrame); 
			return false;
		}
		return this.runCallable(new CallableObject(moduleObject.mainCodeObject));
	},

	importModule: function(moduleName)
	{
		var fResult = new AsyncResult();
		try {
			this.runImportModule(moduleName);
			this.execLoopImpl(fResult, 1);
		} catch(ex) {
			fResult.reject(ex);
		}
		return fResult;
	},

	execModuleDirective(name, kwArgs)
	{
		// Find desired directive by name in current module frame
		var callable = idat.callable(this.currentFrame.getValue(name));

		this.log.internalAssert(this._stack.length < 2, "Expected 0 or 1 items in stack!");
		if( this._stack.length == 1 ) {
			this._stack.pop(); // Drop old result from stack
		}

		var fResult = new AsyncResult();
		try {
			this.runCallable(callable, kwArgs);
			this.execLoopImpl(fResult, 2);
		} catch(ex) {
			fResult.reject(ex);
		}
		return fResult;
	},


	getDirAttrs: function(name, attrNames) {
		var
			callable = idat.callable(this.currentFrame.getValue(name)),
			attrs = callable.symbol.attrs,
			defaults = callable.defaults;
			res = {};

		for( var i = 0; i < attrs.length; ++i )
		{
			var attr = attrs[i];
			if( attrNames.length && !attrNames.includes(attr.name) ) {
				continue;
			}
			var ida = {};
			ida.attr = attr;
			if( defaults.hasOwnProperty(attr.name) ) {
				ida.defaultValue = defaults[attr.name];
			}
			res[attr.name] = ida;
		}

		return res;
	}
});
}); // define