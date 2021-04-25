module ivy.interpreter.directive.standard_factory;

import ivy.types.data: IvyData, IvyDataType, NodeEscapeState;
import ivy.types.data.range.integer: IntegerRange;
import ivy.types.data.decl_class: DeclClass;
import ivy.types.data.decl_class_node: DeclClassNode;
import ivy.interpreter.interpreter: Interpreter;
import ivy.interpreter.directive.factory: InterpreterDirectiveFactory;
import ivy.interpreter.directive.base: makeDir;
import ivy.types.symbol.dir_attr: DirAttr;
import ivy.types.symbol.consts: IvyAttrType;
import ivy.types.symbol.consts: GLOBAL_SYMBOL_NAME;


InterpreterDirectiveFactory ivyDirFactory() @property {
	return _factory;
}

private __gshared InterpreterDirectiveFactory _factory;

shared static this()
{
	_factory = new InterpreterDirectiveFactory;

	_factory.add(makeDir!boolCtorFn("bool", [
		DirAttr("value", IvyAttrType.Any)
	]));
	_factory.add(makeDir!intCtorFn("int", [
		DirAttr("value", IvyAttrType.Any)
	]));
	_factory.add(makeDir!floatCtorFn("float", [
		DirAttr("value", IvyAttrType.Any)
	]));
	_factory.add(makeDir!strCtorFn("str", [
		DirAttr("value", IvyAttrType.Any)
	]));
	_factory.add(makeDir!hasFn("has", [
		DirAttr("collection", IvyAttrType.Any),
		DirAttr("key", IvyAttrType.Any)
	]));
	_factory.add(makeDir!typeStrFn("typestr", [
		DirAttr("value", IvyAttrType.Any)
	]));
	_factory.add(makeDir!lenFn("len", [
		DirAttr("value", IvyAttrType.Any)
	]));
	_factory.add(makeDir!emptyFn("empty", [
		DirAttr("value", IvyAttrType.Any)
	]));
	_factory.add(makeDir!scopeFn("scope"));
	_factory.add(makeDir!rangeFn("range", [
		DirAttr("begin", IvyAttrType.Any),
		DirAttr("end", IvyAttrType.Any)
	]));
	_factory.add(makeDir!toJSONStrFn("to_json_str", [
		DirAttr("value", IvyAttrType.Any)
	]));
	_factory.add(makeDir!newAllocFn("__new_alloc__", [
		DirAttr("class_", IvyAttrType.Any)
	]));
}


bool boolCtorFn(IvyData value) {
	return value.toBoolean();
}

long intCtorFn(IvyData value) {
	return value.toInteger();
}

double floatCtorFn(IvyData value) {
	return value.toFloating();
}

string strCtorFn(IvyData value) {
	return value.toString();
}

bool hasFn(IvyData collection, IvyData key)
{
	import std.algorithm: canFind;
	import std.exception: enforce;

	switch( collection.type )
	{
		case IvyDataType.AssocArray:
			Interpreter.assure(
				key.type == IvyDataType.String,
				"Expected string as second \"has\" directive attribsute, but got: ", key.type);
			return cast(bool)(key.str in collection);
		case IvyDataType.Array:
			return collection.array.canFind(key);
		default:
			Interpreter.assure(false, "Expected array or assoc array as first \"has\" directive attribute, but got: ", collection.type);
			break;
	}
	assert(false);
}

string typeStrFn(IvyData value)
{
	import std.conv: text;
	return value.type.text;
}

size_t lenFn(IvyData value) {
	return value.length;
}

bool emptyFn(IvyData value) {
	return value.empty;
}

IvyData scopeFn(Interpreter interp) {
	return IvyData(interp.previousFrame._dataDict);
}

IntegerRange rangeFn(size_t begin, size_t end) {
	return new IntegerRange(begin, end);
}

IvyData toJSONStrFn(IvyData value, Interpreter interp)
{
	import ivy.types.data.render: DataRenderType;
	import ivy.types.data.render: renderDataNode2;

	IvyData res = renderDataNode2!(DataRenderType.JSON)(value, interp);
	res.escapeState = NodeEscapeState.Safe;
	return res;
}

DeclClassNode newAllocFn(DeclClass class_) {
	return new DeclClassNode(class_);
}