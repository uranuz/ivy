define('ivy/interpreter/interpreter', [
	'ivy/bytecode',

	'ivy/types/call_spec',
	'ivy/types/callable_object',
	'ivy/types/data/async_result',
	'ivy/types/data/consts',
	'ivy/types/data/data',
	'ivy/types/data/range/array',
	'ivy/types/data/range/assoc_array',
	'ivy/types/data/decl_class',
	'ivy/types/data/utils',
	'ivy/types/symbol/consts',
	
	'ivy/utils',

	'ivy/interpreter/directive/global',
	'ivy/interpreter/exec_stack',
	'ivy/interpreter/exception',
	'ivy/interpreter/execution_frame',

	'ivy/log/proxy'
], function(
	Bytecode,

	CallSpec,
	CallableObject,
	AsyncResult,
	DataConsts,
	idat,
	ArrayRange,
	AssocArrayRange,
	DeclClass,
	dutil,
	SymbolConsts,

	iutil,
	
	globalCallable,
	ExecStack,
	InterpreterException,
	ExecutionFrame,

	LogProxy
) {
var
	GLOBAL_SYMBOL_NAME = SymbolConsts.GLOBAL_SYMBOL_NAME,
	SymbolKind = SymbolConsts.SymbolKind,
	IvyDataType = DataConsts.IvyDataType,
	OpCode = Bytecode.OpCode,
	Instruction = Bytecode.Instruction,
	LoopAction = {
		skipPKIncr: 0, // Do not increment pk after loop body execution
		normal: 1, // Increment pk after loop body execution
		await: 2 // Increment pk after loop body execution and await
	},
	assure = iutil.ensure.bind(iutil, InterpreterException);

return FirClass(
function Interpreter(
	moduleObjCache,
	directiveFactory
) {
	this._log = new LogProxy();

	this._moduleObjCache = moduleObjCache;
	this._directiveFactory = directiveFactory;
	this._moduleFrames = {};

	this._frameStack = [];
	this._stack = new ExecStack();

	this._moduleFrames[GLOBAL_SYMBOL_NAME] = new ExecutionFrame(globalCallable);

	// Add custom native directive interpreters to global scope
	directiveFactory.interps.forEach(function(dirInterp) {
		this.globalFrame.setValue(dirInterp.symbol.name, new CallableObject(dirInterp));
	}.bind(this));
}, {
	assure: assure,

	_globalCallable: null,

	execLoop: function(fResult) {
		// Save initial execution frame count.
		var initFrameCount = this._frameStack.length;

		var res = this.execLoopImpl(initFrameCount);
		if( this._frameStack.length < initFrameCount ) {
			// If exec frame stack is less than initial then job is done
			fResult.resolve(res);
		}
		// Looks like interpreter was suspended by async operation
	},

	execLoopSync: function() {
		// Save initial execution frame count.
		var initFrameCount = this._frameStack.length;

		var res = this.execLoopImpl(initFrameCount);
		assure(
			this._frameStack.length < initFrameCount,
			"Requested synchronous code execution, but detected that interpreter was suspended!");
		return res;
	},

	execLoopImpl(initFrameCount) {
		assure(this._frameStack.length, "Unable to run interpreter if exec frame is empty");

		var res;
		while( this._frameStack.length >= initFrameCount ) {
			while( this.currentFrame.hasInstrs ) {
				var la = this.execLoopBody();
				if( la === LoopAction.skipPKIncr )
					continue;
				this.currentFrame.nextInstr();
				if( la === LoopAction.await )
					return;
			}

			// We expect to have only the result of directive on the stack
			assure(this._stack.length === 1, "Exec stack should contain 1 item now");

			res = this._stack.pop(); // Take result
			this.removeFrame(); // Exit out of this frame

			if( this._frameStack.length )
				this._stack.push(res); // Put result back if there is a place for it
		}
		return res;
	},

	execLoopBody: function() {
		var instr = this.currentInstr;
		//console.log(this.currentFrame.callable.symbol.name + ": " + instr.toString());
		switch( instr.opcode ) {
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
				var	top = this._stack.pop();
				var beforeTop = this._stack.pop();
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
				var aType = idat.type(this._stack.back);
				assure(
					aType === IvyDataType.Integer || aType == IvyDataType.Floating,
					"Operand for unary plus operation must have integer or floating type!" );
				// Do nothing
				break;
			}

			case OpCode.UnaryMin: {
				var arg = this._stack.pop();
				switch( idat.type(arg) ) {
					case IvyDataType.Integer:
						arg = -idat.integer(arg);
						break;
					case IvyDataType.Floating:
						arg = -idat.floating(arg);
						break;
					default:
						assure(false, "Unexpected type of operand");
						break;
				}
				this._stack.push(arg);
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
				var	right = this._stack.pop();
				var left = this._stack.pop();
				var lType = idat.type(left);
				var res;
				assure(
					lType === idat.type(right),
					"Left and right values of arithmetic operation must have the same integer or floating type!");

				switch( lType ) {
					case IvyDataType.Integer:
						res = this._doBinaryOp(instr.opcode, left, right);
						break;
					case IvyDataType.Floating:
						res = this._doBinaryOp(instr.opcode, left, right);
						break;
					default:
						assure(false, "Unexpected types of operands");
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
				var	right = this._stack.pop();
				var left = this._stack.pop();
				var lType = idat.type(left);
				var res;
				assure(
					lType === idat.type(right),
					"Operands of less or greather comparision must have the same type");
				
				switch( lType ) {
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
						assure(false, "Less or greater comparisions doesn't support type ", lType, " yet!");
				}
				this._stack.push(res);
				break;
			}

			// Frame data load/ store
			case OpCode.StoreName:
			case OpCode.StoreGlobalName: {
				var varValue = this._stack.pop();
				var varName = idat.str(this.getModuleConstCopy(instr.arg));

				switch( instr.opcode ) {
					case OpCode.StoreName: this.setValue(varName, varValue); break;
					case OpCode.StoreGlobalName: this.setGlobalValue(varName, varValue); break;
					default: assure(false, "Unexpected instruction opcode");
				}
				break;
			}
			case OpCode.LoadName: {
				var varName = idat.str(this.getModuleConstCopy(instr.arg));
				this._stack.push(this.getGlobalValue(varName));
				break;
			}

			// Work with attributes
			case OpCode.StoreAttr: {
				var	attrVal = this._stack.pop();
				var attrName = idat.str(this._stack.pop());
				var aggr = this._stack.pop();
				switch( idat.type(aggr) ) {
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
						assure(false, "Unable to set attribute of value with type: ", idat.type(aggrNode));
						break;
					case IvyDataType.AssocArray:
						aggr[attrName] = attrVal;
						break;
					case IvyDataType.ClassNode:
						aggr.__setAttr__(attrVal, attrName);
						break;
				}
				break;
			}

			// 
			case OpCode.LoadAttr: {
				var attrName = idat.str(this._stack.pop());
				var aggr = this._stack.pop();

				switch( idat.type(aggr) ) {
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
						assure(false, "Unable to get attribute of value with type: ", idat.type(aggr));
						break;
					case IvyDataType.AssocArray:
						this._stack.push(aggr[attrName]);
						break;
					case IvyDataType.ClassNode:
						this._stack.push(aggr.__getAttr__(attrName));
						break;
					case IvyDataType.ExecutionFrame:
						this._stack.push(aggr.getValue(attrName));
						break;
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
					var val = this._stack.pop();
					var key = idat.str(this._stack.pop());

					newAA[key] = val;
				}
				this._stack.push(newAA);
				break;
			}
			case OpCode.MakeClass: {
				var baseClass = (instr.arg? idat.classNode(this._stack.pop()): null);
				var classDataDict = idat.assocArray(this._stack.pop());
				var className = idat.str(this._stack.pop());

				this._stack.push(new DeclClass(className, classDataDict, baseClass));
				break;
			}

			case OpCode.StoreSubscr: {
				var index = this._stack.pop();
				var value = this._stack.pop();
				var aggr = this._stack.pop();

				switch( idat.type(aggr) ) {
					case IvyDataType.Array: {
						assure(
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
						switch( idat.type(index) ) {
							case IvyDataType.Integer:
								aggr[idat.integer(index)] = value;
								break;
							case IvyDataType.String:
								aggr[idat.str(index)] = value;
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

			// Array or assoc array operations
			case OpCode.LoadSubscr: {
				var index = this._stack.pop();
				var aggr = this._stack.pop();

				switch( idat.type(aggr) ) {
					case IvyDataType.String:
					case IvyDataType.Array: {
						assert(
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
						assure(false, "Unexpected type of aggregate: ", aggr.type);
				}
				break;
			}

			case OpCode.LoadSlice: {
				var end = idat.integer(this._stack.pop());
				var begin = idat.integer(this._stack.pop());
				var aggr = this._stack.pop();

				switch( idat.type(aggr) ) {
					case IvyDataType.String:
					case IvyDataType.Array:
						this._stack.push(aggr.slice(begin, end));
						break;
					case IvyDataType.ClassNode:
						this._stack.push(aggr.__slice__(begin, end));
						break;
					default:
						assure(false, "Unexpected aggregate type");
				}
				break;
			}

			// Arrays or strings concatenation
			case OpCode.Concat: {
				var right = this._stack.pop();
				var left = this._stack.pop();
				var lType = idat.type(left);
				assure(
					lType == idat.type(right),
					"Left and right operands for concatenation operation must have the same type!");

				switch( lType ) {
					case IvyDataType.String:
						this._stack.push(left + right);
						break;
					case IvyDataType.Array:
						this._stack.push(left.concat(right));
						break;
					default:
						assure(false, "Unexpected type of operand");
				}
				break;
			}

			case OpCode.Append: {
				var value = this._stack.pop();
				idat.array(this._stack.back).push(value);
				break;
			}

			case OpCode.Insert: {
				var posNode = this._stack.pop();
				var value = this._stack.pop();
				var aggr = idat.array(this._stack.back);

				var pos;
				switch( idat.type(posNode) ) {
					case IvyDataType.Integer:
						pos = posNode;
						break;
					case IvyDataType.Undef:
					case IvyDataType.Null:
						pos = aggr.length; // Act like append
						break;
					default:
						assure(false, "Position argument expected to be an integer or empty (for append), but got: ", posNode);
				}
				assure(
					pos <= aggr.length,
					"Insert position is wrong: ", pos);
				arrNode.splice(pos, 0, value);
				break;
			}

			// Flow control opcodes
			case OpCode.JumpIfTrue:
			case OpCode.JumpIfFalse:
			case OpCode.JumpIfTrueOrPop:
			case OpCode.JumpIfFalseOrPop: {
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
				this.setJump(this._codeRange.length);
				var result = this._stack.back;
				// Erase all from the current stack
				this._stack.popN(this._stack.length);
				this._stack.push(result); // Put result on the stack
				return LoopAction.skipPKIncr;
			}

			// Loop initialization and execution
			case OpCode.GetDataRange: {
				var aggr = this._stack.pop();
				var res;
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
					default: assure(false, 'Expected Array, AssocArray, DataNodeRange or ClassNode as iterable');
				}
				this._stack.push(res); // Push range onto stack
				break;
			}

			case OpCode.RunLoop: {
				var dataRange = idat.dataRange(this._stack.back);
				if( dataRange.empty ) {
					// Drop data range when iteration finished
					this._stack.pop();
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
					return LoopAction.skipPKIncr;
				break;
			}

			case OpCode.FromImport: {
				var importList = idat.array(this._stack.pop());
				var moduleFrame = idat.execFrame(this._stack.pop());

				importList.forEach(function(nameNode) {
					var name = idat.str(nameNode);
					this.setValue(name, moduleFrame.getValue(name));
				}.bind(this));
				break;
			}

			case OpCode.LoadFrame: {
				this._stack.push(this.currentFrame);
				break;
			}

			// Preparing and calling directives
			case OpCode.MakeCallable: {
				var callSpec = CallSpec(instr.arg);
				assure(
					callSpec.posAttrsCount === 0,
					"Positional default attribute values are not expected");

				var codeObject = idat.codeObject(this._stack.pop());

				// Get dict of default attr values from stack if exists
				// We shall not check for odd values here, because we believe compiler can handle it
				var defaults = callSpec.hasKwAttrs? idat.assocArray(this._stack.pop()): {};

				this._stack.push(new CallableObject(codeObject, defaults));
				break;
			}

			case OpCode.RunCallable: {
				if( this.runCallableNode(this._stack.pop(), CallSpec(instr.arg)) )
					return LoopAction.skipPKIncr;
				break;
			}

			case OpCode.Await: {
				var aResult = idat.asyncResult(this._stack.pop());
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
				return LoopAction.await;
			}

			default: assure(false, "Unexpected opcode!!!");
		} // switch

		return LoopAction.normal;
	}, // execLoopBody

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
		assure(this._frameStack.length > 0, "Execution frame stack is empty!");
		return this._frameStack[this._frameStack.length - 1];
	}),

	/** Returns nearest independent execution frame that is not marked `noscope`*/
	previousFrame: firProperty(function() {
		assure(this._frameStack.length > 1, "No previous execution frame exists!");

		return this._frameStack[this._frameStack.length - 2];
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

	setJump: function(instrIndex) {
		this.currentFrame.setJump(instrIndex);
	},

	currentInstr: firProperty(function() {
		if( this._frameStack.empty )
			return null;
		return this.currentFrame.currentInstr;
	}),

	currentInstrLine: firProperty(function () {
		if( this._frameStack.empty )
			return 0;
		return this.currentFrame.currentInstrLine;
	}),

	currentLocation: firProperty(function() {
		if( this._frameStack.empty )
			return null;
		return this.currentFrame.currentLocation;
	}),

	frameStackInfo: firProperty(function() {
		return this._frameStack.map(function(it) {
			return it.info;
		});
	}),

	getModuleConst: function(index) {
		var moduleObj = this.currentModule;
		assure(moduleObj != null, "Unable to get module constant");
		return moduleObj.getConst(index);
	},

	getModuleConstCopy: function(index) {
		return dutil.deeperCopy(this.getModuleConst(index));
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
			default: assure(false, "Unexpected code of binary operation");;
		}
	},

	newFrame: function(callable, dataDict) {
		var symbolName = callable.symbol.name;

		this._frameStack.push(new ExecutionFrame(callable, dataDict));
		this._stack.addBlock();

		if( callable.symbol.kind === SymbolKind.module_ ) {
			assure(symbolName != GLOBAL_SYMBOL_NAME, "Cannot create module name with name: ", GLOBAL_SYMBOL_NAME);
			this._moduleFrames[symbolName] = this.currentFrame;
		}
	},

	removeFrame: function() {
		assure(this._frameStack.length, "Execution frame stack is empty!");
		this._stack.removeBlock();
		this._frameStack.pop();
	},

	findValueFrame: function(varName) {
		return this.findValueFrameImpl(varName, false);
	},

	findValueFrameGlobal: function(varName) {
		return this.findValueFrameImpl(varName, true);
	},

	// Returns execution frame for variable
	findValueFrameImpl: function(varName, globalSearch) {
		var currFrame = this.currentFrame;

		if( currFrame.hasValue(varName) )
			return currFrame;

		if( globalSearch ) {
			var modFrame = this._getModuleFrame(currFrame.callable);
			if( modFrame.hasValue(varName) )
				return modFrame;

			if( this.globalFrame.hasValue(varName) )
				return this.globalFrame;
		}
		// By default store vars in local frame
		return currFrame;
	},

	hasValue: function(varName) {
		return this.findValueFrame(varName).hasValue(varName);
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
		var moduleName = callable.moduleSymbol.name;
		var moduleFrame = this._moduleFrames[moduleName];
		assure(
			moduleFrame != null,
			"Module frame with name: ", moduleFrame, " of callable: ", moduleName, " does not exist!");
		return moduleFrame;
	},

	_extractCallArgs: function(callable, kwAttrs, callSpec) {
		kwAttrs = kwAttrs || {};
		callSpec = callSpec || CallSpec();

		var attrSymbols = callable.symbol.attrs;
		var defaults = callable.defaults;

		if( callSpec.hasKwAttrs )
			kwAttrs = idat.assocArray(this._stack.pop());

		assure(
			callSpec.posAttrsCount <= attrSymbols.length,
			"Positional parameters count is more than expected arguments count");

		var callArgs = {};

		// Getting positional arguments from stack (in reverse order)
		for( var idx = callSpec.posAttrsCount; idx > 0; --idx ) {
			callArgs[attrSymbols[idx - 1].name] = this._stack.pop();
		}

		// Getting named parameters from kwArgs
		for( var idx = callSpec.posAttrsCount; idx < attrSymbols.length; ++idx ) {
			var attr = attrSymbols[idx];
			if( kwAttrs.hasOwnProperty(attr.name) ) {
				callArgs[attr.name] = kwAttrs[attr.name];
			} else{
				// We should get default value if no value is passed from outside
				assure(
					defaults.hasOwnProperty(attr.name),
					"Expected value for attr: ",
					attr.name,
					", that has no default value"
				);
				callArgs[attr.name] = dutil.deeperCopy(defaults[attr.name]);
			}
		}

		// Set "context-variable" for callables that has it...
		if( kwAttrs.hasOwnProperty("this") ) {
			callArgs["this"] =  kwAttrs["this"];
		} else if( idat.type(callable.context) != IvyDataType.Undef ) {
			callArgs["this"] = callable.context;
		}

		return callArgs;
	},

	runCallableNode: function(callableNode, callSpec) {
		// Skip instruction index increment
		return this._runCallableImpl(this.asCallable(callableNode), null, callSpec);
	},

	runCallable: function(callable, kwAttrs) {
		return this._runCallableImpl(callable, kwAttrs); // Skip _pk increment
	},

	_runCallableImpl: function(callable, kwAttrs, callSpec) {
		var callArgs = this._extractCallArgs(callable, kwAttrs, callSpec);

		if( this._frameStack.length )
			this.currentFrame.nextInstr(); // Set next instruction to execute after callable

		this.newFrame(callable, callArgs);

		if( callable.isNative ) {
			// Run native directive interpreter
			callable.dirInterp.interpret(this);
			return false;
		}
		return true; // Skip instruction index increment
	},

	runImportModule: function(moduleName) {
		var moduleObject = this._moduleObjCache.get(moduleName);
		var moduleFrame = this._moduleFrames[moduleName];

		assure(moduleObject, "No such module object: ", moduleName);
		if( moduleFrame ) {
			// Module is imported already. Just push it's frame onto stack
			this._stack.push(moduleFrame); 
			return false;
		}
		return this.runCallable(new CallableObject(moduleObject.mainCodeObject));
	},

	importModule: function(moduleName) {
		var fResult = new AsyncResult();
		try {
			if( this.runImportModule(moduleName) )
				// Need to run interpreter to import module
				this.execLoop(fResult);
			else
				// Module is imported already. Just return it
				fResult.resolve(this._stack.back);
		} catch(ex) {
			fResult.reject(ex);
		}
		return fResult;
	},

	execCallable: function(callable, kwArgs) {
		var fResult = new AsyncResult();
		try {
			this.runCallable(callable, kwArgs);
			this.execLoop(fResult);
		} catch(ex) {
			fResult.reject(this.updateNLogError(ex));
		}
		return fResult;
	},

	execClassMethodSync: function(classNode, method, kwArgs) {
		return this.execCallableSync(idat.callable(classNode.__getAttr__(method)), kwArgs);
	},

	execClassMethod: function(classNode, method, kwArgs) {
		return this.execCallable(idat.callable(classNode.__getAttr__(method)), kwArgs);
	},

	/// Updates exception with frame stack info of interpreter
	updateError: function(ex) {
		return ex;
		/*
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
		*/
	},

	/// Updates exception with frame stack info of interpreter and writes it to log
	updateNLogError: function(ex) {
		var updEx = updateError(ex);
		this._log.error(updEx.message);
		return updEx;
	},

	asCallable: function(callableNode) {
		// If class node passed there, then we shall get callable from it by calling "__call__"
		if( idat.type(callableNode) === IvyDataType.ClassNode )
			return callableNode.__call__();

		// Else we expect that callable passed here
		return idat.callable(callableNode);
	}
});
}); // define