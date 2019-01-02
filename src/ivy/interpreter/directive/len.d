module ivy.interpreter.directive.len;

import ivy.interpreter.directive.utils;

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

	private __gshared DirAttrsBlock[] _attrBlocks = [
		DirAttrsBlock(DirAttrKind.ExprAttr, [
			DirValueAttr("value", "any")
		]),
		DirAttrsBlock(DirAttrKind.BodyAttr)
	];

	mixin BaseNativeDirInterpreterImpl!("len");
}