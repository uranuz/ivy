define('ivy/interpreter/directive/standard_factory', [
	'ivy/interpreter/directive/factory',
	'ivy/types/data/consts',
	'ivy/types/data/data',
	'ivy/types/data/render',
	'ivy/types/symbol/consts',
	'ivy/types/symbol/dir_attr',
	'ivy/interpreter/directive/utils',
	'ivy/types/data/decl_class_node'
], function(
	DirectiveFactory,
	DataConsts,
	idat,
	DataRender,
	SymbolConsts,
	DirAttr,
	DirUtils,
	DeclClassNode
) {
	var
		IvyDataType = DataConsts.IvyDataType,
		IvyDataTypeItems = DataConsts.IvyDataTypeItems,
		makeDir = DirUtils.makeDir,
		renderDataNode2 = DataRender.renderDataNode2,
		IvyAttrType = SymbolConsts.IvyAttrType,
		_factory = new DirectiveFactory();

	function boolCtorFn(value) {
		return idat.toBoolean(value);
	}

	function intCtorFn(value) {
		return idat.toInteger(value);
	}

	function floatCtorFn(value) {
		return value.toFloating();
	}

	function strCtorFn(value) {
		return idat.toString(value);
	}

	function hasFn(collection, key)
	{
		switch( idat.type(collection) )
		{
			case IvyDataType.AssocArray:
				return collection.hasOwnProperty(idat.str(key));
			case IvyDataType.Array:
				return collection.includes(key);
			default:
				Interpreter.assure(false, "Expected array or assoc array as first \"has\" directive attribute, but got: ", collection.type);
				break;
		}
		assert(false);
	}

	function typeStrFn(value) {
		interp._stack.push(IvyDataTypeItems[idat.type(value)]);
	}

	function lenFn(value) {
		return idat.length(value);
	}

	function emptyFn(value) {
		return idat.empty(value);
	}

	function scopeFn(interp) {
		return interp.previousFrame.dict;
	}

	function rangeFn(begin, end) {
		return new IntegerRange(begin, end);
	}

	function toJSONStrFn(value, interp)
	{
		var res = renderDataNode2(value, interp, DataRenderType.JSON);
		res.escapeState = NodeEscapeState.Safe;
		return res;
	}

	function newAllocFn(class_) {
		return new DeclClassNode(class_);
	}

	_factory.add(makeDir(boolCtorFn, "bool", [
		DirAttr("value", IvyAttrType.Any)
	]));
	_factory.add(makeDir(intCtorFn, "int", [
		DirAttr("value", IvyAttrType.Any)
	]));
	_factory.add(makeDir(floatCtorFn, "float", [
		DirAttr("value", IvyAttrType.Any)
	]));
	_factory.add(makeDir(strCtorFn, "str", [
		DirAttr("value", IvyAttrType.Any)
	]));
	_factory.add(makeDir(hasFn, "has", [
		DirAttr("collection", IvyAttrType.Any),
		DirAttr("key", IvyAttrType.Any)
	]));
	_factory.add(makeDir(typeStrFn, "typestr", [
		DirAttr("value", IvyAttrType.Any)
	]));
	_factory.add(makeDir(lenFn, "len", [
		DirAttr("value", IvyAttrType.Any)
	]));
	_factory.add(makeDir(emptyFn, "empty", [
		DirAttr("value", IvyAttrType.Any)
	]));
	_factory.add(makeDir(scopeFn, "scope"));
	_factory.add(makeDir(rangeFn, "range", [
		DirAttr("begin", IvyAttrType.Any),
		DirAttr("end", IvyAttrType.Any)
	]));
	_factory.add(makeDir(toJSONStrFn, "to_json_str", [
		DirAttr("value", IvyAttrType.Any)
	]));
	_factory.add(makeDir(newAllocFn, "__new_alloc__", [
		DirAttr("class_", IvyAttrType.Any)
	]));

	return _factory;
});