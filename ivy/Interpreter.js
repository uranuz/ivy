define('ivy/Interpreter', [
	'ivy/Consts',
	'ivy/ExecStack',
	'ivy/ModuleObject',
	'ivy/CodeObject',
	'ivy/ExecutionFrame',
	'ivy/errors',
	'ivy/CallableObject',
	'ivy/ArrayRange',
	'ivy/AssocArrayRange',
	'ivy/utils'
], function(
	Consts,
	ExecStack,
	ModuleObject,
	CodeObject,
	ExecutionFrame,
	errors,
	CallableObject,
	ArrayRange,
	AssocArrayRange,
	iu
) {
	var
		IvyDataType = Consts.IvyDataType,
		CallableKind = Consts.CallableKind,
		FrameSearchMode = Consts.FrameSearchMode,
		OpCode = Consts.OpCode,
		DirAttrKind = Consts.DirAttrKind;
function Interpreter(moduleObjs, mainModuleName, dataDict) {
	this._frameStack = [];
	this._stack = new ExecStack();
	this._moduleObjects = moduleObjs;
	this._pk = 0;
	this._codeRange = [];
	
	if( !this._moduleObjects.hasOwnProperty(mainModuleName) ) {
		this.rtError('Unable to get main module object');
	}
	
	var
		rootCallableObj = new CallableObject(
			'__main__',
			this._moduleObjects[mainModuleName].mainCodeObject()
		),
		globalDataDict = {
			'__scopeName__': '__global__'
		};
	this._globalFrame = new ExecutionFrame(null, null, globalDataDict, false);
	this._moduleFrames = {'__global__': this._globalFrame};
	dataDict = dataDict || {};
	dataDict.__scopeName__ = '__main__'; // Allocating a dict if it's not
	this._moduleFrames[mainModuleName] = this.newFrame(rootCallableObj, null, dataDict, false);
	this._stack.addStackBlock();
}

return __mixinProto(Interpreter, {
	execLoop: function() {
		var loger = this;
		loger.internalAssert(this._frameStack.length, `this._frameStack is empty`);
		loger.internalAssert(iu.back(this._frameStack), `this._frameStack.back is null`);
		loger.internalAssert(iu.back(this._frameStack)._callableObj, `this._frameStack.back._callableObj is null`);
		loger.internalAssert(iu.back(this._frameStack)._callableObj._codeObj, `this._frameStack.back._callableObj._codeObj is null`);
		this._pk = 0;
		this._codeRange = iu.back(this._frameStack)._callableObj._codeObj._instrs;

		return this.execLoopImpl();
	},
	execLoopImpl: function(exitFrames) {
		var
			codeObj = this.getCodeObject(),
			loger = this;
		exitFrames = exitFrames || 1;
		loger.internalAssert(codeObj, 'Unable to get CodeObject to execute');
		this._codeRange = codeObj._instrs;
		for( this._pk = 0; this._pk <= this._codeRange.length; ) {
			if( this._pk >= this._codeRange.length ) {
				// Ended with this code object
				var result = this._stack.pop();

				this.removeFrame(); // Exit out of this frame
				if( this._frameStack.length === 0 ) {
					return result; // If there is no frames left - then we finished
				}
				var returnPk = this._stack.pop();
				loger.internalAssert(
					iu.getDataNodeType(returnPk) === IvyDataType.Integer,
					'Expected integer as instruction pointer'
				);
				this._pk = returnPk;
				// Set old instruction range back
				var oldCodeObj = this.getCodeObject();
				loger.internalAssert(oldCodeObj, 'Expected code object to return control to');
				this._codeRange = oldCodeObj._instrs; 
				this._stack.push(result); // Get result back
				continue;
			} // if
			var instr = this._codeRange[this._pk];

			with(Consts.OpCode) switch(instr[0]) {
				case Nop: break;

				// Load constant data from code
				case LoadConst: {
					this._stack.push( this.getModuleConstCopy(instr[1]) );
					break;
				}

				// Arithmetic binary operations opcodes
				case Add: {
					var args =  this._getNumberArgs();
					this._stack.push(args[0] + args[1]);
					break;
				}
				case Sub: {
					var args =  this._getNumberArgs();
					this._stack.push(args[0] - args[1]);
					break;
				}
				case Mul: {
					var args =  this._getNumberArgs();
					this._stack.push(args[0] * args[1]);
					break;
				}
				case Div: {
					var args =  this._getNumberArgs();
					this._stack.push(args[0] / args[1]);
					break;
				}
				case Mod: {
					var args =  this._getNumberArgs();
					this._stack.push(args[0] % args[1]);
					break;
				}

				// Arrays or strings concatenation
				case Concat: {
					var
						right = this._stack.pop(), left = this._stack.pop(),
						rType = iu.getDataNodeType(right), lType = iu.getDataNodeType(left);
					if( rType !== IvyDataType.Array && rType !== IvyDataType.String || lType !== rType ) {
						this.rtError('Expected String or Array operands')
					}
					if( rType === IvyDataType.String ) {
						this._stack.push(left + right);
					} else {
						this._stack.push(left.concat(right));
					}
					break;
				}
				case Append: {
					var right = this._stack.pop(), left = this._stack.back(), lType = iu.getDataNodeType(left);
					loger.internalAssert(lType === IvyDataType.Array, 'Expected Array target operand');
					left.push(right);
					break;
				}
				case Insert: {
					var
						posNode = this._stack.pop(), posType = iu.getDataNodeType(posNode),
						valNode = this._stack.pop(),
						// Don't pop result form stack here
						arrNode = this._stack.back(), arrType = iu.getDataNodeType(arrNode);
					
					if( [IvyDataType.Integer, IvyDataType.Null, IvyDataType.Undef].indexOf(posType) < 0 ) {
						this.rtError('Expected Null, Undef (for append) or Integer as position operand');
					}
					if( arrType !== IvyDataType.Array ) {
						this.rtError('Expected Array target operand')
					}
					if( posNode == null ) {
						posNode = arrNode.length;
					}
					arrNode.splice(posNode, 0, valNode);
					break;
				}
				case InsertMass: {
					loger.internalAssert(false, 'Not implemented operation');
					break;
				}

				// General unary operations opcodes
				case UnaryMin: {
					var arg = this._stack.pop();
					if( typeof(arg) !== 'number' ) {
						throw this.rtError('Expected number operand');
					}
					this._stack.push(-arg);
					break;
				}
				case UnaryPlus: {
					if( typeof(arg) !== 'number' ) {
						this.rtError('Expected number operand');
					}
					// Do nothing
					break;
				}
				case UnaryNot: {
					this._stack.push( !this.evalAsBoolean(this._stack.pop()) );
					break;
				}

				// Comparision operations opcodes
				case Equal: case NotEqual: {
					var
						right = this._stack.pop(),
						left = this._stack.pop(),
						rType = iu.getDataNodeType(right),
						lType = iu.getDataNodeType(left);
					if( rType !== lType ) {
						this._stack.push(instr[0] === NotEqual);
						break;
					}
					if( [
						IvyDataType.Boolean,
						IvyDataType.Integer,
						IvyDataType.Floating,
						IvyDataType.String,
						IvyDataType.DateTime
						].indexOf(rType) < 0
					) {
						this.rtError('Cannot compare values!')
					}
					if( instr[0] === Equal ) {
						this._stack.push(left === right);
					} else {
						this._stack.push(left !== right);
					}
					break;
				}
				case LT: case GT: case LTEqual: case GTEqual: {
					var
						right = this._stack.pop(),
						left = this._stack.pop(),
						rType = iu.getDataNodeType(right),
						lType = iu.getDataNodeType(left);
					if( rType !== lType ) {
						this.rtError(`Left and right operands of comparision must have the same type`);
					}
					if( [
						IvyDataType.Integer,
						IvyDataType.Floating,
						IvyDataType.String
						].indexOf(rType) < 0
					) {
						this.rtError(`Unsupported type of operand in comparision operation`)
					}
					// Comparision itself
					switch( instr[0] ) {
						case LT: this._stack.push(left < right); break;
						case GT: this._stack.push(left > right); break;
						case LTEqual: this._stack.push(left <= right); break;
						case GTEqual: this._stack.push(left >= right); break;
						default: this.rtError('Unexpected bug!');
					}
					break;
				}

				// Array or assoc array operations
				case LoadSubscr: {
					var
						indexValue = this._stack.pop(), indexType = iu.getDataNodeType(indexValue),
						aggr = this._stack.pop();

					switch( iu.getDataNodeType(aggr) ) {
						case IvyDataType.String:
						case IvyDataType.Array: {
							if( indexType !== IvyDataType.Integer ) {
								this.rtError('Index value for String or Array must be Integer');
							}
							if( indexValue >= aggr.length ) {
								this.rtError('Index value is out of bounds of String or Array');
							}
							this._stack.push(aggr[indexValue]);
							break;
						}
						case IvyDataType.AssocArray: {
							if( indexType !== IvyDataType.String ) {
								this.rtError('Index value for AssocArray must be String');
							}
							this._stack.push(aggr[indexValue]);
							break;
						}
						case IvyDataType.ClassNode: {
							if( [IvyDataType.String, IvyDataType.Integer].indexOf(indexType) < 0 ) {
								this.rtError('Expected String or Integer as index value');
							}
							this._stack.push(aggr.at( indexValue ));
							break;
						}
						default:
							this.rtError('Unexpected aggregate type');
					}
					break;
				}
				case StoreSubscr: {
					var
						indexValue = this._stack.pop(), indexType = iu.getDataNodeType(indexValue),
						value = this._stack.pop(),
						aggr = this._stack.pop();

					switch( iu.getDataNodeType(aggr) ) {
						case IvyDataType.Array: {
							if( indexType !== IvyDataType.Integer ) {
								this.rtError('Index value for Array must be Integer');
							}
							if( indexValue >= aggr.length ) {
								this.rtError('Index value is out of bounds of Array');
							}
							aggr[indexValue] = value;
							break;
						}
						case IvyDataType.AssocArray: {
							if( indexType !== IvyDataType.String ) {
								this.rtError('Index value for AssocArray must be String');
							}
							aggr[indexValue] = value;
							break;
						}
						case IvyDataType.ClassNode: {
							if( [IvyDataType.String, IvyDataType.Integer].indexOf(indexType) < 0 ) {
								this.rtError('Expected String or Integer as index value');
							}
							aggr.setAt(value, indexType);
							break;
						}
						default:
							this.rtError('Unexpected aggregate type');
					}
					break;
				}
				case LoadSlice: {
					var
						endValue = this._stack.pop(), endType = iu.getDataNodeType(endValue),
						beginValue = this._stack.pop(), beginType = iu.getDataNodeType(beginValue),
						aggr = this._stack.pop(), aggrType = iu.getDataNodeType(aggr);

					if( beginType !== IvyDataType.Integer ) {
						this.rtError('Begin value of slice must be integer');
					}
					if( endValue !== IvyDataType.Integer ) {
						this.rtError('End value of slice must be integer');
					}

					switch( aggrType ) {
						case IvyDataType.String: case IvyDataType.Array: {
							this._stack.push( aggr.slice(beginValue, endValue) );
							break;
						}
						default:
							this.rtError('Unexpected type of aggregate!');
					}
					break;
				}

				// Frame data load/ store
				case StoreName: case StoreLocalName: case StoreNameWithParents: {
					var
						varValue = this._stack.pop(),
						varName = this.getModuleConstCopy(instr[1]);

					if( iu.getDataNodeType(varName) !== IvyDataType.String ) {
						this.rtError('Expected String as variable name');
					}

					switch( instr[0] ) {
						case StoreName: this.setValue(varName, varValue); break;
						case StoreLocalName: this.setLocalValue(varName, varValue); break;
						case StoreNameWithParents: this.setValueWithParents(varName, varValue); break;
						default: this.rtError('Unexpected StoreName instruction kind');
					}
					break;
				}
				case LoadName: {
					var varName = this.getModuleConstCopy(instr[1]);
					if( iu.getDataNodeType(varName) !== IvyDataType.String ) {
						this.rtError('Expected String as variable name');
					}
					this._stack.push(this.getValue(varName));
					break;
				}

				// Preparing and calling directives
				case LoadDirective: {
					var stackArgCount = instr[1];
					loger.internalAssert(
						stackArgCount > 1,
						'Directive load must have at least 2 items in stack!'
					);
					loger.internalAssert(
						stackArgCount <= this._stack.getLength(),
						'Not enough arguments in execution stack'
					);

					var
						codeObj = this._stack.at(this._stack.getLength() - stackArgCount),
						varName = this._stack.at(this._stack.getLength() - stackArgCount + 1);

					loger.internalAssert(
						iu.getDataNodeType(codeObj) === IvyDataType.CodeObject,
						`Expected CodeObject`
					);
					loger.internalAssert(
						iu.getDataNodeType(varName) === IvyDataType.String,
						`Expected String as directive name`
					)

					if( stackArgCount > 2 )
					{
						var stackArgsProcessed = 2;
						for( var i = 0; i < codeObj._attrBlocks.length; ++i )
						{
							var
								attrBlock = codeObj._attrBlocks[i],
								blockArgCount,
								blockType;
							switch( attrBlock.kind ) {
								case DirAttrKind.NamedAttr: case DirAttrKind.ExprAttr: {
									var blockHeader = this._stack.pop(); // Get block header
									++stackArgsProcessed;
									loger.internalAssert(
										iu.getDataNodeType(blockHeader) === IvyDataType.Integer,
										`Expected integer as arguments block header!`
									);
									blockArgCount = blockHeader >> Consts.stackBlockHeaderSizeOffset;
									blockType = blockHeader & Consts.stackBlockHeaderTypeMask;
									loger.internalAssert(
										(blockHeader & Consts.stackBlockHeaderCheckMask) === 0,
										// Bit between block size part and block type must always be zero
										`Seeems that stack is corrupted`
									);
									break;
								}
								default: break;
							}

							switch( attrBlock.kind )
							{
								case DirAttrKind.NamedAttr: {
									var passedArgs = {};
									
									for( var k = 0; k < blockArgCount; ++k )
									{
										var attrValue = this._stack.pop(); ++stackArgsProcessed;

										var attrName = this._stack.pop(); ++stackArgsProcessed;
										loger.internalAssert(
											iu.getDataNodeType(attrName) === IvyDataType.String,
											'Named attribute name must be string!'
										);
										loger.internalAssert(
											passedArgs[attrName] == null,
											'Duplicate named argument detected!'
										);
										loger.internalAssert(
											attrBlock.namedAttrs[attrName] != null,
											'Unexpected argument detected!'
										);

										attrBlock.namedAttrs[attrName].defaultValue = attrValue;
										passedArgs[attrName] = true;
									}
									loger.internalAssert(
										Object.keys(passedArgs).length === blockArgCount,
										"Processed and required default arguments doesn't match!"
									);
									break;
								}
								case DirAttrKind.ExprAttr:
								{
									for( var j = 0; j < blockArgCount; ++j )
									{
										// Set last items with default values from stack
										attrBlock.exprAttrs[attrBlock.exprAttrs.length - 1 - j].defaultValue = this._stack.pop();
										++stackArgsProcessed;
									}
									break;
								}
								default: break;
							}
						}
						loger.internalAssert(
							stackArgsProcessed === stackArgCount,
							"Processed and required stack arguments doesn't match!"
						);
					}

					loger.internalAssert(
						iu.getDataNodeType(this._stack.pop()) === IvyDataType.String,
						`Expected String as directive name`);
					loger.internalAssert(
						iu.getDataNodeType(this._stack.pop()) === IvyDataType.CodeObject,
						`Expected CodeObject`
					);

					this.setLocalValue(varName, new CallableObject(varName, codeObj)); // Put this directive in context
					this._stack.push(undefined); // We should return something
					break;
				}
				case RunCallable: {
					var stackArgCount = instr[1];
					loger.internalAssert(stackArgCount > 0, "Call must at least have 1 arguments in stack!");
					loger.internalAssert(stackArgCount <= this._stack.getLength(), "Not enough arguments in execution stack");

					var callableObj = this._stack.at(this._stack.getLength() - stackArgCount);
					loger.internalAssert(
						iu.getDataNodeType(callableObj) === IvyDataType.Callable,
						`Expected Callable operand`
					);

					var
						attrBlocks = callableObj.attrBlocks(),
						dataDict = {
							"__scopeName__": callableObj._name
						}; // Allocating scope

					this.newFrame(callableObj, this._getModuleFrame(callableObj), dataDict, callableObj.isNoscope);

					if( stackArgCount > 1 ) // If args count is 1 - it mean that there is no arguments
					{
						var stackArgsProcessed = 0;
						for( var i = 0; i < attrBlocks.length; ++i )
						{
							var
								attrBlock = attrBlocks[i],
								// Getting args block metainfo
								blockArgCount,
								blockType;
							switch( attrBlock.kind ) {
								case DirAttrKind.NamedAttr: case DirAttrKind.ExprAttr: {
									var blockHeader = this._stack.pop(); // Get block header
									++stackArgsProcessed;
									loger.internalAssert(
										iu.getDataNodeType(blockHeader) === IvyDataType.Integer,
										`Expected integer as arguments block header!`
									);
									blockArgCount = blockHeader >> Consts.stackBlockHeaderSizeOffset;
									blockType = blockHeader & Consts.stackBlockHeaderTypeMask;
									// Bit between block size part and block type must always be zero
									loger.internalAssert(
										(blockHeader & Consts.stackBlockHeaderCheckMask) == 0,
										`Seeems that stack is corrupted`
									);
									break;
								}
								default: break;
							}

							switch( attrBlock.kind )
							{
								case DirAttrKind.NamedAttr:
								{
									var passedArgs = {};
									
									for( var k = 0; k < blockArgCount; ++k )
									{
										var attrValue = this._stack.pop(); ++stackArgsProcessed;

										var attrName = this._stack.pop(); ++stackArgsProcessed;
										loger.internalAssert(
											iu.getDataNodeType(attrName) === IvyDataType.String,
											"Named attribute name must be string!"
										);
										loger.internalAssert(
											!passedArgs.hasOwnProperty(attrName),
											"Duplicate named argument detected!"
										);
										loger.internalAssert(
											attrBlock.namedAttrs.hasOwnProperty(attrName),
											"Unexpected argument detected!"
										);

										this.setLocalValue(attrName, attrValue);
										passedArgs[attrName] = true;
									}

									for( var attrName in attrBlock.namedAttrs )
									{
										if( !attrBlock.namedAttrs.hasOwnProperty(attrName) ) {
											continue;
										}
										var namedAttr = attrBlock.namedAttrs[attrName];
										if( passedArgs.hasOwnProperty(attrName) ) {
											continue; // Attribute already passes to directive
										}
										// Do deep copy of default value
										this.setLocalValue(attrName, iu.deeperCopy(namedAttr.defaultValue));
									}
									break;
								}
								case DirAttrKind.ExprAttr:
								{
									for( var j = 0; j < attrBlock.exprAttrs.length; ++j )
									{
										var
											backIndex = attrBlock.exprAttrs.length - 1 - j,
											exprAttr = attrBlock.exprAttrs[backIndex];
										if( backIndex < blockArgCount )
										{
											var attrValue = this._stack.pop(); ++stackArgsProcessed;
											this.setLocalValue(exprAttr.name, attrValue);
										} else {
											this.setLocalValue(exprAttr.name, exprAttr.defaultValue);
										}
									}
									break;
								}
								default: break;
							}
						}
					}

					loger.internalAssert(
						iu.getDataNodeType(this._stack.pop()) === IvyDataType.Callable,
						`Expected callable object operand in call operation`
					); // Drop callable object from stack

					if( callableObj._codeObj )
					{
						this._stack.push(this._pk+1); // Put next instruction index on the stack to return at
						this._stack.addStackBlock();
						this._codeRange = callableObj._codeObj._instrs; // Set new instruction range to execute
						this._pk = 0;
						continue; // Skip _pk increment
					}
					else
					{
						loger.internalAssert(
							callableObj._dirInterp,
							`Callable object expected to have non null code object or native directive interpreter object!`
						);
						this._stack.addStackBlock();
						callableObj._dirInterp.interpret(this); // Run native directive interpreter

						// Else we expect to have result of directive on the stack
						loger.internalAssert(
							this._stack.getLength(),
							"Stack should contain 1 item empty now!"
						);

						// If frame stack contains last frame - it means that we nave done with programme
						if( this._frameStack.length == exitFrames ) {
							return this._stack.back();
						}
						var result = this._stack.pop();
						this.removeFrame(); // Drop frame from stack after end of execution
						this._stack.push(result); // Get result back
					}

					break;
				}

				// Import another module
				case ImportModule: {
					var moduleName = this._stack.pop();
					if( iu.getDataNodeType(moduleName) !== IvyDataType.String ) {
						this.rtError('Expected String as module name');
					}
					
					if( !this._moduleObjects.hasOwnProperty(moduleName) ) {
						this.rtError('Failed to get module with name: ' + moduleName);
					}

					if( !this._moduleFrames.hasOwnProperty(moduleName) ) {
						// Run module here
						var
							modObject = this._moduleObjects[moduleName],
							codeObject = modObject.mainCodeObject(),
							callableObj = new CallableObject(moduleName, codeObject),
							dataDict = {
								"__scopeName__": moduleName
							},
							// Create entry point module frame
							frame = this.newFrame(callableObj, null, dataDict, false);

						// We need to store module frame into storage
						this._moduleFrames[moduleName] = frame; 

						// Put module root frame into previous execution frame`s stack block (it will be stored with StoreName)
						this._stack.push(frame);
						// Decided to put return address into parent frame`s stack block instead of current
						this._stack.push(this._pk + 1);
						// Add new stack block for execution frame
						this._stack.addStackBlock(); 

						// Preparing to run code object in newly created frame
						this._codeRange = codeObject._instrs;
						this._pk = 0;

						continue; // Skip this._pk increment
					} else {
						// Put module root frame into previous execution frame (it will be stored with StoreName)
						this._stack.push(this._moduleFrames[moduleName]); 
						// As long as module returns some value at the end of execution, so put fake value there for consistency
						this._stack.push(undefined);
					}
					break;
				}
				case FromImport: {
					var symbolsNode = this._stack.pop(), symbolsType = iu.getDataNodeType(symbolsNode);
					if( symbolsType !== IvyDataType.Array ) {
						this.rtError('Expected list of symbol names');
					}
					var frameNode = this._stack.pop(), frameType = iu.getDataNodeType(frameNode);
					if( frameType !== IvyDataType.ExecutionFrame ) {
						this.rtError('Expected ExecutionFrame');
					}

					for( var i = 0; i < symbolsNode.length; ++i ) {
						if( typeof(symbolsNode[i]) !== 'string' ) {
							this.rtError('Symbol name must be String');
						}
						this.setValue(symbolsNode[i], frameNode.getValue(symbolsNode[i]));
					}
					break;
				}

				// Flow control opcodes
				case JumpIfTrue:
				case JumpIfFalse:
				case JumpIfFalseOrPop: // Used in "and"
				case JumpIfTrueOrPop: // Used in "or"
				{
					if( instr[1] >= this._codeRange.length ) {
						this.rtError('Cannot jump after the end of code object');
					}
					var jumpCond = this.evalAsBoolean(this._stack.back()); // This is actual condition to test
					if( [OpCode.JumpIfFalse, OpCode.JumpIfFalseOrPop].indexOf(instr[0]) >= 0 ) {
						jumpCond = !jumpCond; // Invert condition if False family is used
					}

					if( [OpCode.JumpIfTrue, OpCode.JumpIfFalse].indexOf(instr[0]) >= 0 || !jumpCond ) {
						// Drop condition from _stack on JumpIfTrue, JumpIfFalse anyway
						// But for JumpIfTrueOrPop, JumpIfFalseOrPop drop it only if jumpCond is false
						this._stack.pop();
					}

					if( jumpCond )
					{
						this._pk = instr[1];
						continue; // Skip _pk increment
					}
					break;
				}
				case Jump: {
					if( instr[1] >= this._codeRange.length ) {
						this.rtError('Cannot jump after the end of code object');
					}
					this._pk = instr[1];
					continue; // Skip _pk increment
				}
				case Return: {
					// Set instruction index at the end of code object in order to finish 
					this._pk = this._codeRange.length;
					var result = this._stack.back();
					// Erase all from the current stack
					this._stack.popN(this._stack.getLength());
					this._stack.push(result); // Put result on the stack
					continue; // Skip _pk increment
				}

				// Stack operations
				case PopTop: {
					this._stack.pop();
					break;
				}
				case SwapTwo: {
					var
						tmp = this._stack.back(), len = this._stack.getLength(),
						lastIndex = len - 1, prevIndex = len - 2;
					this._stack.setAt(this._stack.at(prevIndex), lastIndex);
					this._stack.setAt(tmp, prevIndex)
					break;
				}

				// Loop initialization and execution
				case GetDataRange: {
					var aggr = this._stack.pop();
					switch( iu.getDataNodeType(aggr) ) {
						case IvyDataType.Array:
							this._stack.push(new ArrayRange(aggr));
							break;
						case IvyDataType.ClassNode:
							this._stack.push(aggr.range());
							break;
						case IvyDataType.AssocArray:
							this._stack.push(new AssocArrayRange(aggr));
							break;
						case IvyDataType.DataNodeRange:
							this._stack.push(aggr);
							break;
						default: this.rtError('Expected Array, AssocArray, DataNodeRange or ClassNode as iterable');
					}
					break;
				}
				case RunLoop: {
					var dataRange = this._stack.back();
					if( iu.getDataNodeType(dataRange) !== IvyDataType.DataNodeRange ) {
						this.rtError('Expected DataNodeRange to iterate over');
					}
					if( dataRange.empty() )
					{
						if( instr[1] >= this._codeRange.length ) {
							this.rtError('Cannot jump after the end of code object');
						}
						this._pk = instr[1];
						this._stack.pop(); // Drop data range from stack as we no longer need it
						break;
					}

					// TODO: For now we just move range forward as take current value from it
					// Maybe should fix it and make it move after loop block finish
					this._stack.push(dataRange.pop());
					break;
				}

				// Data construction opcodes
				case MakeArray: {
					var
						arrayLen = instr[1],
						newArray = [];
					if( iu.getDataNodeType(arrayLen) !== IvyDataType.Integer ) {
						this.rtError('Expected Integer as new Array length');
					}
					newArray.length = arrayLen; // Preallocating is good ;)

					for( var i = arrayLen; i > 0; --i ) {
						// We take array items from the tail, so we must consider it!
						newArray[i-1] = this._stack.pop();
					}
					this._stack.push(newArray);
					break;
				}
				case MakeAssocArray: {
					var
						aaLen = instr[1],
						newAA = {};
					if( iu.getDataNodeType(aaLen) !== IvyDataType.Integer ) {
						this.rtError('Expected Integer as new AssocArray length');
					}

					for( var i = 0; i < aaLen; ++i ) {
						var val = this._stack.pop(), key = this._stack.pop(), keyType = iu.getDataNodeType(key);
						if( keyType !== IvyDataType.String ) {
							this.rtError('Expected String as AssocArray key');
						}

						newAA[key] = val;
					}
					this._stack.push(newAA);
					break;
				}

				case MarkForEscape: {
					if( instr[1] >= Consts.NodeEscapeStateItems.length ) {
						this.rtError('Incorrect escape state provided');
					}
					this._stack.back().escapeState = instr[1];
					break;
				}
				default: this.rtError(`Unexpected opcode!!!`);
			} // switch
			++(this._pk);
		}
	},
	rtError: function(msg) {
		var instr = this._codeRange[this._pk];
		throw new errors.InterpreterError({
			msg: msg,
			instrIndex: this._pk,
			instrName: Consts.OpCodeItems[instr[0]]
		});
	},
	_getNumberArgs: function() {
		var
			right = this._stack.pop(),
			left = this._stack.pop();
		if( typeof(right) !== 'number' || typeof(left) !== 'number' ) {
			this.rtError('Expected number operands');
		}
		return [left, right];
	},
	getCurrentFrame: function() {
		if( this._frameStack.length === 0 ) {
			return null;
		}
		return iu.back(this._frameStack);
	},
	/** Returns nearest independent execution frame that is not marked `noscope`*/
	independentFrame: function() {
		for( var i = this._frameStack.length; i > 0; --i ) {
			var frame = this._frameStack[i-1];
			if( frame.hasOwnScope() ) {
				return frame;
			}
		}
		this.rtError('Cannot get current independent execution frame!');
	},
	getCodeObject: function() {
		var frame = this.getCurrentFrame();
		if( !frame ) {
			return null;
		}
		var callable = frame._callableObj;
		if( !callable ) {
			return null;
		}
		return callable._codeObj;
	},
	getModuleObject: function() {
		var codeObj = this.getCodeObject();
		if( codeObj ) {
			return codeObj._moduleObj;
		}
		return null;
	},
	getModuleConst: function(index) {
		var moduleObj = this.getModuleObject();
		if( !moduleObj ) {
			this.rtError('Unable to get module constant');
		}
		return moduleObj.getConst(index);
	},
	getModuleConstCopy: function(index) {
		return iu.deeperCopy( this.getModuleConst(index) );
	},
	evalAsBoolean: function(val) {
		switch( iu.getDataNodeType(val) ) {
			case IvyDataType.Undef:
			case IvyDataType.Null:
				return false;
			case IvyDataType.Boolean:
				return val;
			case IvyDataType.Integer:
			case IvyDataType.Floating:
			case IvyDataType.DateTime:
			case IvyDataType.ClassNode:
				// Considering numbers just non-empty there. Not try to interpret 0 or 0.0 as logical false,
				// because in many cases they could be treated as significant values
				// DateTime and Boolean are not empty too, because we cannot say what value should be treated as empty
				return true;
			case IvyDataType.String:
			case IvyDataType.Array:
			case IvyDataType.AssocArray:
				return !!val.length;
			case IvyDataType.DataNodeRange:
				return !val.empty();
			default:
				throw new Error('Cannot evaluate value in logical context!');
		}
	},
	newFrame: function(callableObj, modFrame, dataDict, isNoscope) {
		var frame = new ExecutionFrame(callableObj, modFrame, dataDict, isNoscope);
		this._frameStack.push(frame);
		return frame;
	},
	removeFrame: function() {
		this._stack.removeStackBlock();
		this._frameStack.pop();
	},
	canFindValue: function(varName) {
		return this.findValue(varName, FrameSearchMode.tryGet).node !== undefined;
	},

	findValue: function(varName, mode) {
		var result;
		for( var i = this._frameStack.length; i > 0; --i ) {
			var frame = this._frameStack[i-1];

			result = frame.findValue(varName, mode);

			if( !frame.hasOwnScope() && result.node === undefined ) {
				continue; // Let's try to find in parent
			}

			if( result.node !== undefined || (result.node === undefined && result.allowUndef) ) {
				return result;
			}
		}

		if( mode == FrameSearchMode.get || mode == FrameSearchMode.tryGet ) {
			result = this._globalFrame.findValue(varName, mode);
			if( result.node !== undefined ) {
				return result;
			}
		}

		return result;
	},

	findValueLocal: function(varName, mode) {
		var result;
		for( var i = this._frameStack.length; i > 0; --i ) {
			var frame = this._frameStack[i-1];
			result = frame.findLocalValue(varName, mode);
			if( result.node !== undefined ) {
				return result;
			}
		}
		return iu.back(this._frameStack).findLocalValue(varName, mode);
	},
	getValue: function(varName) {
		return this.findValue(varName, FrameSearchMode.get).node;
	},

	_assignNodeAttribute: function(parent, value, varName) {
		var attrName = iu.back(varName.split('.'));
		switch( iu.getDataNodeType(parent) )
		{
			case IvyDataType.AssocArray:
				parent[attrName] = value;
				break;
			case IvyDataType.ClassNode:
				parent.setAttr(value, attrName);
				break;
			default:
				this.rtError('Unexpected node type');
		}
	},

	setValue: function(varName, value) {
		var result = this.findValue(varName, FrameSearchMode.set);
		this._assignNodeAttribute(result.parent, value, varName);
	},

	setValueWithParents: function(varName, value) {
		var result = this.findValue(varName, FrameSearchMode.setWithParents);
		this._assignNodeAttribute(result.parent, value, varName);
	},

	setLocalValue: function(varName, value) {
		var result = this.findValueLocal(varName, FrameSearchMode.set);
		this._assignNodeAttribute(result.parent, value, varName);
	},

	setLocalValueWithParents: function(varName, value) {
		var result = findValueLocal(varName, FrameSearchMode.setWithParents);
		this._assignNodeAttribute(result.parent, value, varName);
	},

	_addNativeDirInterp: function(name, dirInterp) {
		// Add custom native directive interpreters to global scope
		var dirCallable = new CallableObject(name, dirInterp);
		this._globalFrame.setValue(name, dirCallable);
	},

	// Method used to set custom global directive interpreters
	addDirInterpreters: function(dirInterps) {
		for( var name in dirInterps ) {
			this._addNativeDirInterp(name, dirInterps[name]);
		}
	},

	internalAssert: function(cond, msg) {
		if( !cond ) {
			this.rtError(msg)
		}
	},

	_getModuleFrame: function(callableObj) {
		var
			moduleName = callableObj._codeObj? callableObj._codeObj._moduleObj._name: "__global__",
			moduleFrame = this._moduleFrames[moduleName];
		this.internalAssert(moduleFrame, "Module frame doesn't exist");
		return moduleFrame;
	},

	runModuleDirective: function(name, args)
	{
		var loger = this;
		enforce(
			[IvyDataType.Undef, IvyDataType.Null, IvyDataType.AssocArray].canFind(iu.getDataNodeType(args)),
			`Expected Undef, Null or AssocArray as list of directive arguments`
		);

		loger.internalAssert(this.currentFrame, `Could not get module frame!`);

		// Find desired directive by name in current module frame
		var callableNode = this.currentFrame.getValue(name);
		loger.internalAssert(iu.getDataNodeType(callableNode) === IvyDataType.Callable, `Expected Callable!`);

		loger.internalAssert(this._stack.getLength() < 2, `Expected 0 or 1 items in stack!`);
		if( this._stack.getLength() === 1 ) {
			this._stack.pop(); // Drop old result from stack
		}

		this._stack.push(callableNode);
		var
			stackItemsCount = 1, // Pass callable at least
			attrBlocks = callableNode.callable.attrBlocks();

		// Put params into stack
		for( var i = 0; i < attrBlocks.length; ++i )
		{
			var attrBlock = attrBlocks[i];
			switch( attrBlock.kind )
			{
				case DirAttrKind.ExprAttr:
				{
					var argCount = 0;
					if( iu.getDataNodeType(args) === IvyDataType.AssocArray )
					{
						for( var j = 0; j < attrBlock.exprAttrs; ++j )
						{
							var exprAttr = attrBlock.exprAttrs[j];
							if( args.hasOwnProperty(exprAttr.name) ) {
								this._stack.push(args[exprAttr.name]); ++stackItemsCount; ++argCount;
							}
						}
					}

					// Add instruction to load value that consists of number of positional arguments in block and type of block
					var blockHeader = ( argCount << Consts.stackBlockHeaderSizeOffset ) + DirAttrKind.ExprAttr;
					this._stack.push(blockHeader);
					++stackItemsCount; // We should count args block header
					break;
				}
				case DirAttrKind.NamedAttr:
				{
					var argCount = 0;
					if( iu.getDataNodeType(args) == IvyDataType.AssocArray )
					{
						for( var attrName in attrBlock.namedAttrs )
						{
							if( !attrBlock.namedAttrs.hasOwnProperty(attrName) ) {
								continue;
							}
							var namedAttr = attrBlock.namedAttrs[attrName];
							if( args.hasOwnProperty(attrName) )
							{
								this._stack.push(attrName); ++stackItemsCount;
								this._stack.push(args[attrName]); ++stackItemsCount;
								++argCount;
							}
						}
					}

					// Add instruction to load value that consists of number of positional arguments in block and type of block
					var blockHeader = ( argCount << Consts.stackBlockHeaderSizeOffset ) + DirAttrKind.NamedAttr;
					this._stack.push(blockHeader);
					++stackItemsCount; // We should count args block header
					break;
				}
				default: break;
			}
		}
		this._pk = 0;
		this._codeRange = [Instruction(OpCode.RunCallable, stackItemsCount)];
		return this.execLoopImpl(2);
	}
});
}); // define