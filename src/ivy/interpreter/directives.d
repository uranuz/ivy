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

class RenderDirInterpreter: INativeDirectiveInterpreter
{
	override void interpret(Interpreter interp)
	{
		import std.array: appender;
		debug import std.stdio;
		TDataNode result = interp.getValue("__result__");

		auto renderedResult = appender!string();
		renderDataNode!(DataRenderType.HTML)(result, renderedResult);
		auto safetyResult = appender!string();
		renderDataNode!(DataRenderType.TextDebug)(result, safetyResult);
		writeln(`safetyResult: `, safetyResult.data);
		interp._stack ~= TDataNode(renderedResult.data);
	}

	private __gshared DirAttrsBlock!(true)[] _compilerAttrBlocks;
	shared static this()
	{
		_compilerAttrBlocks = [
			DirAttrsBlock!true(DirAttrKind.NamedAttr, [
				"__result__": DirValueAttr!(true)("__result__", "any")
			]),
			DirAttrsBlock!true(DirAttrKind.BodyAttr)
		];
	}

	mixin BaseNativeDirInterpreterImpl!("__render__");
}

class IntCtorDirInterpreter: INativeDirectiveInterpreter
{
	override void interpret(Interpreter interp)
	{
		import std.conv: to;
		TDataNode value = interp.getValue("value");
		switch(value.type)
		{
			case DataNodeType.Boolean:
				interp._stack ~= TDataNode(value.boolean? 1: 0);
				break;
			case DataNodeType.Integer:
				interp._stack ~= value;
				break;
			case DataNodeType.String:
				interp._stack ~= TDataNode(value.str.to!long);
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
		TDataNode value = interp.getValue("value");
		switch(value.type)
		{
			case DataNodeType.Boolean:
				interp._stack ~= TDataNode(value.boolean? 1.0: 0.0);
				break;
			case DataNodeType.Integer:
				interp._stack ~= TDataNode(value.integer.to!double);
				break;
			case DataNodeType.Floating:
				interp._stack ~= value;
				break;
			case DataNodeType.String:
				interp._stack ~= TDataNode(value.str.to!double);
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

class HasDirInterpreter: INativeDirectiveInterpreter
{
	override void interpret(Interpreter interp)
	{
		import std.conv: to;
		import std.algorithm: canFind;
		TDataNode collection = interp.getValue("collection");
		TDataNode key = interp.getValue("key");
		switch(collection.type)
		{
			case DataNodeType.AssocArray:
				if( key.type != DataNodeType.String ) {
					interp.loger.error(`Expected string as second "has" directive attribute, but got: `, key.type);
				}
				interp._stack ~= TDataNode(cast(bool)(key.str in collection));
				break;
			case DataNodeType.Array:
				interp._stack ~= TDataNode(collection.array.canFind(key));
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
		TDataNode value = interp.getValue("value");
		interp._stack ~= TDataNode(value.type.text);
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
		TDataNode value = interp.getValue("value");
		switch(value.type)
		{
			case DataNodeType.String:
				interp._stack ~= TDataNode(value.str.length);
				break;
			case DataNodeType.Array:
				interp._stack ~= TDataNode(value.array.length);
				break;
			case DataNodeType.AssocArray:
				interp._stack ~= TDataNode(value.assocArray.length);
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
		TDataNode value = interp.getValue("value");
		switch(value.type)
		{
			case DataNodeType.Undef, DataNodeType.Null:
				interp._stack ~= TDataNode(true);
				break;
			case DataNodeType.Integer, DataNodeType.Floating, DataNodeType.DateTime, DataNodeType.Boolean:
				// Considering numbers just non-empty there. Not try to interpret 0 or 0.0 as logical false,
				// because in many cases they could be treated as significant values
				// DateTime and Boolean are not empty too, because we cannot say what value should be treated as empty
				interp._stack ~= TDataNode(false);
				break;
			case DataNodeType.String:
				interp._stack ~= TDataNode(!value.str.length);
				break;
			case DataNodeType.Array:
				interp._stack ~= TDataNode(!value.array.length);
				break;
			case DataNodeType.AssocArray:
				interp._stack ~= TDataNode(!value.assocArray.length);
				break;
			case DataNodeType.DataNodeRange:
				interp._stack ~= TDataNode(!value.dataRange || value.dataRange.empty);
				break;
			case DataNodeType.ClassNode:
				// Basic check for ClassNode for emptyness is that it should not be null reference
				// If some interface method will be introduced to check for empty then we shall consider to check it too
				interp._stack ~= TDataNode(value.classNode is null);
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
		interp._stack ~= TDataNode(cast(string) Base64.encode(jsonStr));
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
		interp.loger.internalAssert(interp.currentFrame, `Current frame is null!`);
		interp._stack ~= interp.currentFrame._dataDict;
	}

	private __gshared DirAttrsBlock!(true)[] _compilerAttrBlocks = [
		DirAttrsBlock!true(DirAttrKind.BodyAttr,
			Tuple!(ICompoundStatement, "ast", bool, "isNoscope", bool, "isEscape")(null, true, false)
		)
	];

	mixin BaseNativeDirInterpreterImpl!("scope");
}

class DateTimeGetDirInterpreter: INativeDirectiveInterpreter
{
	import std.typecons: Tuple;
	import std.datetime: SysTime;

	override void interpret(Interpreter interp)
	{
		TDataNode value = interp.getValue("value");
		TDataNode field = interp.getValue("field");

		if( value.type !=  DataNodeType.DateTime ) {
			interp.loger.error(`Expected DateTime as first argument in dtGet!`);
		}
		if( field.type !=  DataNodeType.String ) {
			interp.loger.error(`Expected string as second argument in dtGet!`);
		}

		SysTime dt = value.dateTime;
		switch( field.str )
		{
			case "year": interp._stack ~= TDataNode(dt.year); break;
			case "month": interp._stack ~= TDataNode(dt.month); break;
			case "day": interp._stack ~= TDataNode(dt.day); break;
			case "hour": interp._stack ~= TDataNode(dt.hour); break;
			case "minute": interp._stack ~= TDataNode(dt.minute); break;
			case "second": interp._stack ~= TDataNode(dt.second); break;
			case "millisecond": interp._stack ~= TDataNode(dt.fracSecs.split().msecs); break;
			case "dayOfWeek": interp._stack ~= TDataNode(cast(int) dt.dayOfWeek); break;
			case "dayOfYear": interp._stack ~= TDataNode(dt.dayOfYear); break;
			case "utcMinuteOffset" : interp._stack ~= TDataNode(dt.utcOffset.total!("minutes")); break;
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
		TDataNode begin = interp.getValue("begin");
		TDataNode end = interp.getValue("end");

		if( begin.type !=  DataNodeType.Integer ) {
			interp.loger.error(`Expected integer as 'begin' argument!`);
		}
		if( end.type !=  DataNodeType.Integer ) {
			interp.loger.error(`Expected integer as 'end' argument!`);
		}

		interp._stack ~= TDataNode(new IntegerRange(begin.integer, end.integer));
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
		TDataNode begin = interp.getValue("begin");
		TDataNode end = interp.getValue("end");

		if( begin.type !=  DataNodeType.Integer ) {
			interp.loger.error(`Expected integer as 'begin' argument!`);
		}

		interp._stack ~= TDataNode(new IntegerRange(begin.integer, end.integer));
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