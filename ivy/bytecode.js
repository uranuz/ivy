define('ivy/bytecode', [], function() {
var
	Bytecode = {},
	OpCodeItems = [
		'InvalidCode', // Used to check if code of operation was not properly set

		'Nop',

		// Load constant data from code
		'LoadConst',

		// Stack operations
		'PopTop',
		'SwapTwo',
		'DubTop',

		// General unary operations opcodes
		'UnaryPlus',
		'UnaryMin',
		'UnaryNot',

		// Arithmetic binary operations opcodes
		'Add',
		'Sub',
		'Mul',
		'Div',
		'Mod',

		// Comparision operations opcodes
		'Equal',
		'NotEqual',
		'LT',
		'GT',
		'LTEqual',
		'GTEqual',

		// Frame data load/ store
		'StoreName',
		'StoreGlobalName',
		'LoadName',

		// Work with attributes
		'StoreAttr',
		'LoadAttr',

		// Data construction opcodes
		'MakeArray',
		'MakeAssocArray',
		'MakeClass',

		// Array or assoc array operations
		'StoreSubscr',
		'LoadSubscr',
		'LoadSlice',

		// Arrays or strings concatenation
		'Concat',
		'Append',
		'Insert',

		// Flow control opcodes
		'JumpIfTrue',
		'JumpIfFalse',
		'JumpIfTrueOrPop',
		'JumpIfFalseOrPop',
		'Jump',
		'Return',

		// Loop initialization and execution
		'GetDataRange',
		'RunLoop',

		// Import another module
		'ImportModule',
		'FromImport',

		// Preparing and calling directives
		'MakeCallable',
		'RunCallable',
		'Await',

		// Other stuff
		'MarkForEscape'
	],
	EnumConsts = [
		'OpCode'
	];
Bytecode.OpCodeItems = OpCodeItems;
for( var i = 0; i < EnumConsts.length; ++i ) {
	var
		constName = EnumConsts[i],
		constItems = Bytecode[constName + 'Items'],
		enumObj = {};
	for( var j = 0; j < constItems.length; ++j ) {
		enumObj[constItems[j]] = j;
	}
	Bytecode[constName] = enumObj;
}

Bytecode.Instruction = FirClass(
	function Instruction(opcode, arg) {
		var inst = firPODCtor(this, arguments);
		if( inst ) return inst;

		this.opcode = opcode; // So... it's instruction opcode
		this.arg = arg; // One arg for now
	}, {
		name: firProperty(function() {
			return OpCodeItems[this.opcode];
		}),

		toString: function() {
			return this.name + ': ' + this.arg;
		}
	});

return Bytecode;
});