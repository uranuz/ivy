module ivy.interpreter.directive.bool_ctor;

import ivy.interpreter.directive.utils;

class BoolCtorDirInterpreter: INativeDirectiveInterpreter
{
	override void interpret(Interpreter interp)
	{
		auto value = interp.getValue("value");
		interp._stack ~= IvyData(interp.evalAsBoolean(value));
	}

	private __gshared DirAttrsBlock[] _attrBlocks = [
		DirAttrsBlock(DirAttrKind.ExprAttr, [
			DirValueAttr("value", "any")
		]),
		DirAttrsBlock(DirAttrKind.BodyAttr)
	];

	mixin BaseNativeDirInterpreterImpl!("bool");
}