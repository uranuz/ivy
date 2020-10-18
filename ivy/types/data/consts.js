define('ivy/types/data/consts', [], function() {
var
	IvyDataTypeItems = [
		'Undef',
		'Null',
		'Boolean',
		'Integer',
		'Floating',
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
	NodeEscapeStateItems = [
		'Init',
		'Safe',
		'Unsafe'
	],
	AsyncResultStateItems = [
		'Init',
		'Pending',
		'Success',
		'Error'
	],
	DateTimeAttrItems = [
		'year',
		'month',
		'day',
		'hour',
		'minute',
		'second',
		'millisecond',
		'dayOfWeek',
		'dayOfYear',
		'utcMinuteOffset'
	],
	Consts = {
		IvyDataTypeItems: IvyDataTypeItems,
		NodeEscapeStateItems: NodeEscapeStateItems,
		AsyncResultStateItems: AsyncResultStateItems,

		DateTimeAttrItems: DateTimeAttrItems
	};
[
	['IvyDataType', true],
	['NodeEscapeState', true],
	['AsyncResultState', true],

	['DateTimeAttr', false]
].forEach(function(constNameType) {
	var
		constName = constNameType[0],
		intConst = constNameType[1],
		constItems = Consts[constName + 'Items'],
		enumObj = {};

	constItems.forEach(function(key, index) {
		enumObj[key] = intConst? index: key;
	});

	Consts[constName] = enumObj;
});
return Consts;
});