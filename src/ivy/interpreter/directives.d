module ivy.interpreter.directives;

import ivy.directive_stuff;
import ivy.parser.node: ICompoundStatement;
import ivy.interpreter.interpreter;
import ivy.interpreter.data_node;
import ivy.interpreter.data_node_render: renderDataNode, DataRenderType;
import ivy.interpreter.data_node_types: IntegerRange;

mixin template BaseNativeDirInterpreterImpl(string symbolName)
{
	import ivy.compiler.symbol_table: DirectiveDefinitionSymbol, Symbol;

	private __gshared DirAttrsBlock!(false)[] _interpAttrBlocks;
	private __gshared DirectiveDefinitionSymbol _symbol;

	shared static this()
	{
		import std.algorithm: map;
		import std.array: array;

		// Get directive description for interpreter
		_interpAttrBlocks = _compilerAttrBlocks.map!( a => a.toInterpreterBlock() ).array;
		// Create symbol for compiler
		_symbol = new DirectiveDefinitionSymbol(symbolName, _compilerAttrBlocks);
	}

	override DirAttrsBlock!(false)[] attrBlocks() @property {
		return _interpAttrBlocks;
	}

	override Symbol compilerSymbol() @property {
		return _symbol;
	}
}

class IntCtorDirInterpreter: INativeDirectiveInterpreter
{
	override void interpret(Interpreter interp)
	{
		import std.conv: to;
		IvyData value = interp.getValue("value");
		switch(value.type)
		{
			case IvyDataType.Boolean:
				interp._stack ~= IvyData(value.boolean? 1: 0);
				break;
			case IvyDataType.Integer:
				interp._stack ~= value;
				break;
			case IvyDataType.String:
				interp._stack ~= IvyData(value.str.to!long);
				break;
			default:
				interp.loger.error(`Cannot convert value of type: `, value.type, ` to integer`);
				break;
		}
	}

	private __gshared DirAttrsBlock!(true)[] _compilerAttrBlocks = [
		DirAttrsBlock!true( DirAttrKind.ExprAttr, [
			DirValueAttr!(true)("value", "any")
		]),
		DirAttrsBlock!true(DirAttrKind.BodyAttr)
	];

	mixin BaseNativeDirInterpreterImpl!("int");
}

class FloatCtorDirInterpreter: INativeDirectiveInterpreter
{
	override void interpret(Interpreter interp)
	{
		import std.conv: to;
		IvyData value = interp.getValue("value");
		switch(value.type)
		{
			case IvyDataType.Boolean:
				interp._stack ~= IvyData(value.boolean? 1.0: 0.0);
				break;
			case IvyDataType.Integer:
				interp._stack ~= IvyData(value.integer.to!double);
				break;
			case IvyDataType.Floating:
				interp._stack ~= value;
				break;
			case IvyDataType.String:
				interp._stack ~= IvyData(value.str.to!double);
				break;
			default:
				interp.loger.error(`Cannot convert value of type: `, value.type, ` to integer`);
				break;
		}
	}

	private __gshared DirAttrsBlock!(true)[] _compilerAttrBlocks = [
		DirAttrsBlock!true(DirAttrKind.ExprAttr, [
			DirValueAttr!(true)("value", "any")
		]),
		DirAttrsBlock!true(DirAttrKind.BodyAttr)
	];

	mixin BaseNativeDirInterpreterImpl!("float");
}

class StrCtorDirInterpreter: INativeDirectiveInterpreter
{
	override void interpret(Interpreter interp) {
		interp._stack ~= IvyData(interp.getValue("value").toString());
	}

	private __gshared DirAttrsBlock!(true)[] _compilerAttrBlocks = [
		DirAttrsBlock!true(DirAttrKind.ExprAttr, [
			DirValueAttr!(true)("value", "any")
		]),
		DirAttrsBlock!true(DirAttrKind.BodyAttr)
	];

	mixin BaseNativeDirInterpreterImpl!("str");
}

class HasDirInterpreter: INativeDirectiveInterpreter
{
	override void interpret(Interpreter interp)
	{
		import std.conv: to;
		import std.algorithm: canFind;
		IvyData collection = interp.getValue("collection");
		IvyData key = interp.getValue("key");
		switch(collection.type)
		{
			case IvyDataType.AssocArray:
				if( key.type != IvyDataType.String ) {
					interp.loger.error(`Expected string as second "has" directive attribute, but got: `, key.type);
				}
				interp._stack ~= IvyData(cast(bool)(key.str in collection));
				break;
			case IvyDataType.Array:
				interp._stack ~= IvyData(collection.array.canFind(key));
				break;
			default:
				interp.loger.error(`Expected array or assoc array as first "has" directive attribute, but got: `, collection.type);
				break;
		}
	}

	private __gshared DirAttrsBlock!(true)[] _compilerAttrBlocks = [
		DirAttrsBlock!true(DirAttrKind.ExprAttr, [
			DirValueAttr!(true)("collection", "any"),
			DirValueAttr!(true)("key", "any")
		]),
		DirAttrsBlock!true(DirAttrKind.BodyAttr)
	];

	mixin BaseNativeDirInterpreterImpl!("has");
}

class TypeStrDirInterpreter: INativeDirectiveInterpreter
{
	override void interpret(Interpreter interp)
	{
		import std.conv: text;
		IvyData value = interp.getValue("value");
		interp._stack ~= IvyData(value.type.text);
	}

	private __gshared DirAttrsBlock!(true)[] _compilerAttrBlocks = [
		DirAttrsBlock!true(DirAttrKind.ExprAttr, [
			DirValueAttr!(true)("value", "any")
		]),
		DirAttrsBlock!true(DirAttrKind.BodyAttr)
	];

	mixin BaseNativeDirInterpreterImpl!("typestr");
}

class LenDirInterpreter: INativeDirectiveInterpreter
{
	override void interpret(Interpreter interp)
	{
		import std.conv: text;
		IvyData value = interp.getValue("value");
		switch(value.type)
		{
			case IvyDataType.String:
				interp._stack ~= IvyData(value.str.length);
				break;
			case IvyDataType.Array:
				interp._stack ~= IvyData(value.array.length);
				break;
			case IvyDataType.AssocArray:
				interp._stack ~= IvyData(value.assocArray.length);
				break;
			case IvyDataType.ClassNode:
				interp._stack ~= IvyData(value.classNode.length);
				break;
			default:
				interp.loger.error(`Cannot get length for value of type: `, value.type);
				break;
		}
	}

	private __gshared DirAttrsBlock!(true)[] _compilerAttrBlocks = [
		DirAttrsBlock!true(DirAttrKind.ExprAttr, [
			DirValueAttr!(true)("value", "any")
		]),
		DirAttrsBlock!true(DirAttrKind.BodyAttr)
	];

	mixin BaseNativeDirInterpreterImpl!("len");
}

class EmptyDirInterpreter: INativeDirectiveInterpreter
{
	override void interpret(Interpreter interp)
	{
		IvyData value = interp.getValue("value");
		switch(value.type)
		{
			case IvyDataType.Undef, IvyDataType.Null:
				interp._stack ~= IvyData(true);
				break;
			case IvyDataType.Integer, IvyDataType.Floating, IvyDataType.DateTime, IvyDataType.Boolean:
				// Considering numbers just non-empty there. Not try to interpret 0 or 0.0 as logical false,
				// because in many cases they could be treated as significant values
				// DateTime and Boolean are not empty too, because we cannot say what value should be treated as empty
				interp._stack ~= IvyData(false);
				break;
			case IvyDataType.String:
				interp._stack ~= IvyData(!value.str.length);
				break;
			case IvyDataType.Array:
				interp._stack ~= IvyData(!value.array.length);
				break;
			case IvyDataType.AssocArray:
				interp._stack ~= IvyData(!value.assocArray.length);
				break;
			case IvyDataType.DataNodeRange:
				interp._stack ~= IvyData(!value.dataRange || value.dataRange.empty);
				break;
			case IvyDataType.ClassNode:
				// Basic check for ClassNode for emptyness is that it should not be null reference
				// If some interface method will be introduced to check for empty then we shall consider to check it too
				interp._stack ~= IvyData(value.classNode is null);
				break;
			default:
				interp.loger.error(`Cannot test type: `, value.type, ` for emptyness`);
				break;
		}
	}

	private __gshared DirAttrsBlock!(true)[] _compilerAttrBlocks = [
		DirAttrsBlock!true(DirAttrKind.ExprAttr, [
			DirValueAttr!(true)("value", "any")
		]),
		DirAttrsBlock!true(DirAttrKind.BodyAttr)
	];

	mixin BaseNativeDirInterpreterImpl!("empty");
}

class ToJSONBase64DirInterpreter: INativeDirectiveInterpreter
{
	import std.typecons: Tuple;

	override void interpret(Interpreter interp)
	{
		import std.base64: Base64;
		ubyte[] jsonStr = cast(ubyte[]) interp.getValue("value").toJSONString();
		interp._stack ~= IvyData(cast(string) Base64.encode(jsonStr));
	}

	private __gshared DirAttrsBlock!(true)[] _compilerAttrBlocks = [
		DirAttrsBlock!true(DirAttrKind.ExprAttr, [
			DirValueAttr!(true)("value", "any")
		]),
		DirAttrsBlock!true(DirAttrKind.BodyAttr)
	];

	mixin BaseNativeDirInterpreterImpl!("toJSONBase64");
}

class ScopeDirInterpreter: INativeDirectiveInterpreter
{
	import std.typecons: Tuple;

	override void interpret(Interpreter interp)
	{
		interp.loger.internalAssert(interp.independentFrame, `Current frame is null!`);
		interp._stack ~= interp.independentFrame._dataDict;
	}

	private __gshared DirAttrsBlock!(true)[] _compilerAttrBlocks = [
		DirAttrsBlock!true(DirAttrKind.BodyAttr,
			Tuple!(ICompoundStatement, "ast", bool, "isNoscope", bool, "isNoescape")(null, true, false)
		)
	];

	mixin BaseNativeDirInterpreterImpl!("scope");
}

class DateTimeGetDirInterpreter: INativeDirectiveInterpreter
{
	import std.typecons: Tuple;
	import std.datetime: SysTime;
	import std.algorithm: canFind;

	override void interpret(Interpreter interp)
	{
		IvyData value = interp.getValue("value");
		IvyData field = interp.getValue("field");

		if( ![IvyDataType.DateTime, IvyDataType.Undef, IvyDataType.Null].canFind(value.type) ) {
			interp.loger.error(`Expected DateTime as first argument in dtGet!`);
		}
		if( field.type !=  IvyDataType.String ) {
			interp.loger.error(`Expected string as second argument in dtGet!`);
		}
		if( value.type != IvyDataType.DateTime ) {
			interp._stack ~= value; // Will not fail if it is null or undef, but just return it!
			return;
		}

		SysTime dt = value.dateTime;
		switch( field.str )
		{
			case "year": interp._stack ~= IvyData(dt.year); break;
			case "month": interp._stack ~= IvyData(dt.month); break;
			case "day": interp._stack ~= IvyData(dt.day); break;
			case "hour": interp._stack ~= IvyData(dt.hour); break;
			case "minute": interp._stack ~= IvyData(dt.minute); break;
			case "second": interp._stack ~= IvyData(dt.second); break;
			case "millisecond": interp._stack ~= IvyData(dt.fracSecs.split().msecs); break;
			case "dayOfWeek": interp._stack ~= IvyData(cast(int) dt.dayOfWeek); break;
			case "dayOfYear": interp._stack ~= IvyData(dt.dayOfYear); break;
			case "utcMinuteOffset" : interp._stack ~= IvyData(dt.utcOffset.total!("minutes")); break;
			default:
				interp.loger.error("Unexpected date field specifier: ", field.str);
		}
	}

	private __gshared DirAttrsBlock!(true)[] _compilerAttrBlocks = [
		DirAttrsBlock!true(DirAttrKind.ExprAttr, [
			DirValueAttr!(true)("value", "any"),
			DirValueAttr!(true)("field", "any")
		]),
		DirAttrsBlock!true(DirAttrKind.BodyAttr)
	];

	mixin BaseNativeDirInterpreterImpl!("dtGet");
}

class RangeDirInterpreter: INativeDirectiveInterpreter
{
	import std.typecons: Tuple;

	override void interpret(Interpreter interp)
	{
		IvyData begin = interp.getValue("begin");
		IvyData end = interp.getValue("end");

		if( begin.type !=  IvyDataType.Integer ) {
			interp.loger.error(`Expected integer as 'begin' argument!`);
		}
		if( end.type !=  IvyDataType.Integer ) {
			interp.loger.error(`Expected integer as 'end' argument!`);
		}

		interp._stack ~= IvyData(new IntegerRange(begin.integer, end.integer));
	}

	private __gshared DirAttrsBlock!(true)[] _compilerAttrBlocks = [
		DirAttrsBlock!true(DirAttrKind.ExprAttr, [
			DirValueAttr!(true)("begin", "any"),
			DirValueAttr!(true)("end", "any")
		]),
		DirAttrsBlock!true(DirAttrKind.BodyAttr)
	];

	mixin BaseNativeDirInterpreterImpl!("range");
}


/++
class EscapeDirInterpreter: INativeDirectiveInterpreter
{
	import std.typecons: Tuple;

	override void interpret(Interpreter interp)
	{
		IvyData begin = interp.getValue("begin");
		IvyData end = interp.getValue("end");

		if( begin.type !=  IvyDataType.Integer ) {
			interp.loger.error(`Expected integer as 'begin' argument!`);
		}

		interp._stack ~= IvyData(new IntegerRange(begin.integer, end.integer));
	}

	private __gshared DirAttrsBlock!(true)[] _compilerAttrBlocks = [
		DirAttrsBlock!true(DirAttrKind.ExprAttr, [
			DirValueAttr!(true)("value", "any")
		]),
		DirAttrsBlock!true(DirAttrKind.BodyAttr)
	];

	mixin BaseNativeDirInterpreterImpl!("escape");
}
+/