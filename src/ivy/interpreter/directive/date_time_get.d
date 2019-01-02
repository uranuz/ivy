module ivy.interpreter.directive.date_time_get;

import ivy.interpreter.directive.utils;

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
			case "millisecond": interp._stack ~= IvyData(cast(ptrdiff_t) dt.fracSecs.split().msecs); break;
			case "dayOfWeek": interp._stack ~= IvyData(cast(ptrdiff_t) dt.dayOfWeek); break;
			case "dayOfYear": interp._stack ~= IvyData(cast(ptrdiff_t) dt.dayOfYear); break;
			case "utcMinuteOffset" : interp._stack ~= IvyData(cast(ptrdiff_t) dt.utcOffset.total!("minutes")); break;
			default:
				interp.loger.error("Unexpected date field specifier: ", field.str);
		}
	}

	private __gshared DirAttrsBlock[] _attrBlocks = [
		DirAttrsBlock(DirAttrKind.ExprAttr, [
			DirValueAttr("value", "any"),
			DirValueAttr("field", "any")
		]),
		DirAttrsBlock(DirAttrKind.BodyAttr)
	];

	mixin BaseNativeDirInterpreterImpl!("dtGet");
}