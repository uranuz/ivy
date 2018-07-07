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
			//var opCode = codeRange{}
			with(OpCode) switch() {
				case Nop: break;

				// Load constant data from code
				case LoadConst: {
					break;
				}

				// Arithmetic binary operations opcodes
				case Add: {
					break;
				}
				case Sub: {
					break;
				}
				case Mul: {
					break;
				}
				case Div: {
					break;
				}
				case Mod: {
					break;
				}

				// Arrays or strings concatenation
				case Concat: {
					break;
				}
				case Append: {
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
					break;
				}
				case UnaryPlus: {
					break;
				}
				case UnaryNot: {
					break;
				}

				// Comparision operations opcodes
				case LT: {
					break;
				}
				case GT: {
					break;
				}
				case Equal: {
					break;
				}
				case NotEqual: {
					break;
				}
				case LTEqual: {
					break;
				}
				case GTEqual: {
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
					break;
				}
				case SwapTwo: {
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
					break;
				}
				case MakeAssocArray: {
					break;
				}

				case MarkForEscape: {
					break;
				}
				default: throw Error(`Unexpected opcode!!!`);
			}
		}
		
	},
	load = function(moduleName) {
		var self = this;
		$.ajax("/dyn/server/template?moduleName=" + moduleName, {
			success: function(jsonText) {
				var json = JSON.parse(jsonText);
				self.parseModules(json);
			},
			error: function(error) {
				console.error(error);
			}
		});
	},
	parseModules = function(json) {
		var moduleObjects = json.moduleObjects;
		this._mainModuleObject = json.mainModuleObject;

		for(var modName in moduleObjects) {
			if( !moduleObjects.hasOwnProperty(modName) ) continue;
			var
				jMod = moduleObjects[modName],
				consts = jMod.consts;

			this._moduleObjects[modName] = new ModuleObject(modName, consts);
			for( var i = 0; i < consts.length; ++i ) {
				var con = consts[i];
				if( con === 'undef' ) {
					consts[i] = undefined;
				} else if(
					con === null
					|| con === true
					|| con === false
					|| typeof(con) === 'number'
					|| typeof(con) === 'string'
					|| con instanceof Array
				) {
					continue;
				} else if( con instanceof Object ) {
					switch( con._t ) {
						case DataNodeType.CodeObject: {
							consts[i] = new CodeObject(con.instrs, this._moduleObjects[modName]);
							break;
						}
						case DataNodeType.DateTime: {
							consts[i] = new Date(con._v);
							break;
						}
						default:
							continue;
					}
				}
			}
		}
		return this._moduleObjects;
	}
});
}); // define