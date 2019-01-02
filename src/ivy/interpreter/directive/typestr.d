module ivy.interpreter.directive.typestr;

import ivy.interpreter.directive.utils;

class TypeStrDirInterpreter: INativeDirectiveInterpreter
{
	override void interpret(Interpreter interp)
	{
		import std.conv: text;
		IvyData value = interp.getValue("value");
		interp._stack ~= IvyData(value.type.text);
	}

	private __gshared DirAttrsBlock[] _attrBlocks = [
		DirAttrsBlock(DirAttrKind.ExprAttr, [
			DirValueAttr("value", "any")
		]),
		DirAttrsBlock(DirAttrKind.BodyAttr)
	];

	mixin BaseNativeDirInterpreterImpl!("typestr");
}