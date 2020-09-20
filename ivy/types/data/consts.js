define('ivy/types/data/consts', [], function() {
function NullPtrType() {}
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
		'AsyncResult',
		'ModuleObject'
	],
	NodeEscapeStateItems: [
		'Init', 'Safe', 'Unsafe'
	],
	AsyncResultStateItems: [
		'Init', 'Pending', 'Success', 'Error'
	],
	NullPtrType: NullPtrType,
	NullPtr: new NullPtrType
},
EnumConsts = [
	'IvyDataType',
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