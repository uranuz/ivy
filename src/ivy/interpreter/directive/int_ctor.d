module ivy.interpreter.directive.int_ctor;

import ivy.interpreter.directive.utils;

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
				interp._stack ~= IvyData(value.str.to!ptrdiff_t);
				break;
			default:
				interp.loger.error(`Cannot convert value of type: `, value.type, ` to integer`);
				break;
		}
	}

	private __gshared DirAttrsBlock[] _attrBlocks = [
		DirAttrsBlock( DirAttrKind.ExprAttr, [
			DirValueAttr("value", "any")
		]),
		DirAttrsBlock(DirAttrKind.BodyAttr)
	];

	mixin BaseNativeDirInterpreterImpl!("int");
}