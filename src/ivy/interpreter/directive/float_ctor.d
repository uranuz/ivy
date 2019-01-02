module ivy.interpreter.directive.float_ctor;

import ivy.interpreter.directive.utils;

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

	private __gshared DirAttrsBlock[] _attrBlocks = [
		DirAttrsBlock(DirAttrKind.ExprAttr, [
			DirValueAttr("value", "any")
		]),
		DirAttrsBlock(DirAttrKind.BodyAttr)
	];

	mixin BaseNativeDirInterpreterImpl!("float");
}