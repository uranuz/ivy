define('ivy/Consts', [], function() {
var Consts = {
	IvyDataTypeItems: [
		'Undef',
		'Null',
		'Boolean',
		'Integer',
		'Floating',
		'DateTime',
		'String',
		'Array',
		'AssocArray',
		'ClassNode',
		'CodeObject',
		'Callable',
		'ExecutionFrame',
		'DataNodeRange',
		'AsyncResult'
	],
	OpCodeItems: [
		'InvalidCode', // Used to check if code of operation was not properly set

		'Nop',

		// Load constant data from code
		'LoadConst',

		// Arithmetic binary operations opcodes
		'Add',
		'Sub',
		'Mul',
		'Div',
		'Mod',

		// Arrays or strings concatenation
		'Concat',
		'Append',
		'Insert',
		'InsertMass',

		// General unary operations opcodes
		'UnaryMin',
		'UnaryPlus',
		'UnaryNot',

		// Comparision operations opcodes
		'LT',
		'GT',
		'Equal',
		'NotEqual',
		'LTEqual',
		'GTEqual',

		// Array or assoc array operations
		'LoadSubscr',
		'StoreSubscr',
		'LoadSlice',

		// Frame data load/ store
		'StoreName',
		'StoreLocalName',
		'StoreNameWithParents',
		'LoadName',

		// Preparing and calling directives
		'LoadDirective',
		'RunCallable',
		'Call',
		'Await',

		// Import another module
		'ImportModule',
		'FromImport',

		// Flow control opcodes
		'JumpIfTrue',
		'JumpIfFalse',
		'JumpIfFalseOrPop', // Used in "and"
		'JumpIfTrueOrPop', // Used in "or"
		'Jump',
		'Return',

		// Stack operations
		'PopTop',
		'SwapTwo',

		// Loop initialization and execution
		'GetDataRange',
		'RunLoop',

		// Data construction opcodes
		'MakeArray',
		'MakeAssocArray',

		'MarkForEscape'
	],
	FrameSearchModeItems: [
		'get', 'tryGet', 'set', 'setWithParents'
	],
	CallableKindItems: [
		'ScopedDirective',
		'NoscopeDirective',
		'Module',
		'Package'
	],
	DirAttrKindItems: [
		'NamedAttr',
		'ExprAttr',
		'IdentAttr',
		'KwdAttr',
		'BodyAttr'
	],
	stackBlockHeaderSizeOffset: 4,
	stackBlockHeaderCheckMask: parseInt('1000', 2),
	stackBlockHeaderTypeMask: parseInt('111', 2),
	NodeEscapeStateItems: [
		'Init', 'Safe', 'Unsafe'
	],
	AsyncResultStateItems: [
		'Init', 'Pending', 'Success', 'Error'
	]
},
EnumConsts = [
	'IvyDataType',
	'OpCode',
	'FrameSearchMode',
	'CallableKind',
	'DirAttrKind',
	'NodeEscapeState',
	'AsyncResultState'
];
for( var i = 0; i < EnumConsts.length; ++i ) {
	var
		constName = EnumConsts[i],
		constItems = Consts[constName + 'Items'],
		enumObj = {};
	for( var j = 0; j < constItems.length; ++j ) {
		enumObj[constItems[j]] = j;
	}
	Consts[constName] = enumObj;
}
return Consts;
});