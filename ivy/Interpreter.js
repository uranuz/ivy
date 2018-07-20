define('ivy/Interpreter', [
	'ivy/ExecStack',
	'ivy/Consts',
	'ivy/ModuleObject',
	'ivy/CodeObject',
	'ivy/ExecutionFrame',
	'ivy/utils',
	'ivy/errors'
], function(
	ExecStack,
	Consts,
	ModuleObject,
	CodeObject,
	ExecutionFrame,
	iu,
	errors
) {
	var DataNodeType = Consts.DataNodeType;
function Interpreter() {
	this._frameStack = [];
	this._stack = new ExecStack();
	this._moduleObjects = {};
	this._mainModuleObject = null;
	this._pk = 0;
	this._codeRange = [];
}

return __mixinProto(Interpreter, {
	runLoop: function() {
		this._codeRange = iu.back(_frameStack)._callableObj._codeObj._instrs;
		for( this._pk = 0; this._pk < this._codeRange.length; ) {
			var instr = this._codeRange[this._pk];

			with(OpCode) switch(instr[0]) {
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
					if( rType !== DataNodeType.Array && rType !== DataNodeType.String || lType !== rType ) {
						this.rtError('Expected String or Array operands')
					}
					if( rType === DataNodeType.String ) {
						this._stack.push(left + right);
					} else {
						this._stack.push(left.concat(right));
					}
					break;
				}
				case Append: {
					var right = this._stack.pop(), left = this._stack.back(), lType = iu.getDataNodeType(left);
					if( lType !== DataNodeType.Array ) {
						this.rtError('Expected Array target operand');
					}
					left.push(right);
					break;
				}
				case Insert: {
					var
						posNode = this._stack.pop(), posType = iu.getDataNodeType(posNode),
						valNode = this._stack.pop(),
						arrNode = this._stack.pop(), arrType = iu.getDataNodeType(arrNode);
					
					if( [DataNodeType.Integer, DataNodeType.Null, DataNodeType.Undef].indexOf(posType) < 0 ) {
						this.rtError('Expected Null, Undef (for append) or Integer as position operand');
					}
					if( arrType !== DataNodeType.Array ) {
						this.rtError('Expected Array target operand')
					}
					if( posNode == null ) {
						posNode = arrNode.length;
					}
					arrNode.splice(posNode, 0, valNode);
					break;
				}
				case InsertMass: {
					this.rtError('Not implemented operation');
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
					if( rType === lType ) {
						return instr[0] === Equal;
					}
					if( [
						DataNodeType.Boolean,
						DataNodeType.Integer,
						DataNodeType.Floating,
						DataNodeType.String,
						DataNodeType.DateTime
						].indexOf(rType) < 0
					) {
						this.rtError('Cannot compare values!')
					}
					if( instr[0] === Equal ) {
						return left === right;
					}
					return left !== right;
				}
				case LT: case GT: case LTEqual: case GTEqual: {
					var
						right = this._stack.pop(),
						left = this._stack.pop(),
						rType = iu.getDataNodeType(right),
						lType = iu.getDataNodeType(left);
					if( rType !== lType ) {
						throw this.rtError(`Left and right operands of comparision must have the same type`);
					}
					if( [
						DataNodeType.Integer,
						DataNodeType.Floating,
						DataNodeType.String
						].indexOf(rType) < 0
					) {
						throw this.rtError(`Unsupported type of operand in comparision operation`)
					}
					// Comparision itself
					switch( instr[0] ) {
						case LT: this._stack.push(left < right);
						case GT: this._stack.push(left > right);
						case LTEqual: this._stack.push(left <= right);
						case GTEqual: this._stack.push(left >= right);
						default: this.rtError('Unexpected bug!');
					}
					break;
				}

				// Array or assoc array operations
				case LoadSubscr: {
					break;
				}
				case StoreSubscr: {
					break;
				}
				case LoadSlice: {
					break;
				}

				// Frame data load/ store
				case StoreName: {
					break;
				}
				case StoreLocalName: {
					break;
				}
				case StoreNameWithParents: {
					break;
				}
				case LoadName: {
					break;
				}

				// Preparing and calling directives
				case LoadDirective: {
					break;
				}
				case RunCallable: {
					break;
				}

				// Import another module
				case ImportModule: {
					break;
				}
				case FromImport: {
					var symbolsNode = this._stack.pop(), symbolsType = iu.getDataNodeType(symbolsType);
					if( symbolsType !== DataNodeType.Array ) {
						this.rtError('Expected list of symbol names');
					}
					var frameNode = this._stack.pop(), frameType = iu.getDataNodeType(frameNode);
					if( frameType !== DataNodeType.ExecutionFrame ) {
						this.rtError('Expected ExecutionFrame');
					}

					for( var i = 0; i < symbolsNode; ++i ) {
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
					var jumpCond = evalAsBoolean(this._stack.back()); // This is actual condition to test
					if( [OpCode.JumpIfFalse, OpCode.JumpIfFalseOrPop].canFind(instr[0]) ) {
						jumpCond = !jumpCond; // Invert condition if False family is used
					}

					if( [OpCode.JumpIfTrue, OpCode.JumpIfFalse].canFind(instr[0]) || !jumpCond ) {
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
					break;
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
					this._stack.setAt(this.at(prevIndex), lastIndex);
					this._stack.setAt(tmp, prevIndex)
					break;
				}

				// Loop initialization and execution
				case GetDataRange: {
					break;
				}
				case RunLoop: {
					break;
				}

				// Data construction opcodes
				case MakeArray: {
					var
						arrayLen = instr[1],
						newArray = [];
					if( iu.getDataNodeType(arrayLen) !== DataNodeType.Integer ) {
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
					if( iu.getDataNodeType(aaLen) !== DataNodeType.Integer ) {
						this.rtError('Expected Integer as new AssocArray length');
					}

					for( var i = 0; i < aaLen; ++i ) {
						var val = this._stack.pop(), key = this._stack.pop(), keyType = iu.getDataNodeType(key);
						if( keyType !== DataNodeType.String ) {
							this.rtError('Expected String as AssocArray key');
						}

						newAA[key] = val;
					}
					this._stack.push(newAA);
					break;
				}

				case MarkForEscape: {
					break;
				}
				default: this.rtError(`Unexpected opcode!!!`);
			}
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
		if( this._stack.empty() ) {
			return null;
		}
		return this._frameStack.back();
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
	evalAsBoolean: function(val)
	{
		switch(val)
		{
			case DataNodeType.Undef:
			case DataNodeType.Null:
				return false;
			case DataNodeType.Boolean:
				return val;
			case DataNodeType.Integer:
			case DataNodeType.Floating:
			case DataNodeType.DateTime:
			case DataNodeType.ClassNode:
				// Considering numbers just non-empty there. Not try to interpret 0 or 0.0 as logical false,
				// because in many cases they could be treated as significant values
				// DateTime and Boolean are not empty too, because we cannot say what value should be treated as empty
				return true;
			case DataNodeType.String:
			case DataNodeType.Array:
			case DataNodeType.AssocArray:
				return !!val.length;
			case DataNodeType.DataNodeRange:
				return !val.empty();
			default:
				throw new Error('Cannot evaluate value in logical context!');
		}
	},
	setValue: function() {

	}
});
}); // define