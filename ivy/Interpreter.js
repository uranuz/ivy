define('ivy/Interpreter', [
	'ivy/ExecStack',
	'ivy/Consts',
	'ivy/ModuleObject',
	'ivy/CodeObject',
	'ivy/ExecutionFrame',
	'ivy/utils'
], function(
	ExecStack,
	Consts,
	ModuleObject,
	CodeObject,
	ExecutionFrame,
	iu
) {
	var DataNodeType = Consts.DataNodeType;
function Interpreter() {
	this._frameStack = [];
	this._stack = new ExecStack();
	this._moduleObjects = {};
	this._mainModuleObject = null;
	this._pk = 0;
}

return __mixinProto(Interpreter, {
	runLoop: function() {
		var codeRange = iu.back(_frameStack)._callableObj._codeObj._instrs;
		for( this._pk = 0; this._pk < codeRange.length; ) {
			var instr = codeRange[this._pk];
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
						throw new Error('Expected string or array arguments in Concat instruction!');
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
						throw new Error('Argument for appending to must be array');
					}
					left.push(right);
					break;
				}
				case Insert: {
					break;
				}
				case InsertMass: {
					break;
				}

				// General unary operations opcodes
				case UnaryMin: {
					var arg = this._stack.pop();
					if( typeof(arg) !== 'number' ) {
						throw new Error('Cannot negate not a number!');
					}
					this._stack.push(-arg);
					break;
				}
				case UnaryPlus: {
					if( typeof(arg) !== 'number' ) {
						throw new Error('Expected number in unary plus instruction!');
					}
					// Do nothing
					break;
				}
				case UnaryNot: {
					if( this._stack.empty() ) {
						throw new Error('Cannot execute UnaryNot instruction. Operand expected, but exec stack is empty!');
					}
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
						throw new Error('Cannot compare values!')
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
						throw new Error(`Left and right operands of comparision must have the same type`);
					}
					if( [
						DataNodeType.Integer,
						DataNodeType.Floating,
						DataNodeType.String
						].indexOf(rType) < 0
					) {
						throw new Error(`Unsupported type of operand in comparision operation`)
					}
					// Comparision itself
					switch( instr[0] ) {
						case LT: this._stack.push(left < right);
						case GT: this._stack.push(left > right);
						case LTEqual: this._stack.push(left <= right);
						case GTEqual: this._stack.push(left >= right);
						default: throw new Error('Unexpected bug!');
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
					break;
				}

				// Flow control opcodes
				case JumpIfTrue: {
					break;
				}
				case JumpIfFalse: {
					break;
				}
				case JumpIfFalseOrPop: {
					break;
				} // Used in "and"
				case JumpIfTrueOrPop: {
					break;
				} // Used in "or"
				case Jump: {
					break;
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
						throw new Error('New array length must be integer!');
					}
					newArray.length = arrayLen; // Preallocating is good ;)

					for( var i = arrayLen; i > 0; --i ) {
						if( this._stack.empty() ) {
							throw new Error('Expected new array element, but got empty stack');
						}
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
						throw new Error('New array length must be integer!');
					}

					for( var i = 0; i < aaLen; ++i )
					{
						if( this._stack.empty() ) {
							throw new Error('Expected assoc array value, but got empty stack');
						}
						var val = this._stack.pop();

						if( this._stack.empty() ) {
							throw new Error('Expected assoc array key, but got empty stack');
						}
						if( iu.getDataNodeType(this._stack.back()) !== DataNodeType.String ) {
							throw new Error('Expected string as assoc array key');
						}

						newAA[_stack.pop()] = val;
					}
					this._stack.push(newAA);
					break;
				}

				case MarkForEscape: {
					break;
				}
				default: throw Error(`Unexpected opcode!!!`);
			}
		}
		
	},
	_getNumberArgs: function() {
		var
			right = this._stack.pop(),
			left = this._stack.pop();
		if( typeof(right) !== 'number' || typeof(left) !== 'number' ) {
			throw new Error('Expected number arguments in arithmetic operation!');
		}
		return [left, right];
	},
	getModuleConst: function(index) {
		if( this._frameStack.length === 0 ) {
			throw new Error('_frameStack is empty');
		}
		if( this._frameStack.back() === null ) {
			throw new Error('_frameStack.back is null');
		}
		if( this._frameStack.back()._callableObj === null ) {
			throw new Error('_frameStack.back._callableObj is null');
		}
		if( this._frameStack.back()._callableObj._codeObj === null ) {
			throw new Error('_frameStack.back._callableObj._codeObj is null');
		}
		if( this._frameStack.back()._callableObj._codeObj._moduleObj === null ) {
			throw new Error('_frameStack.back._callableObj._codeObj._moduleObj is null');
		}

		return _frameStack.back()._callableObj._codeObj._moduleObj.getConst(index);
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
	}
});
}); // define