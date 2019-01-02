module ivy.interpreter.directive.str_ctor;

import ivy.interpreter.directive.utils;

class StrCtorDirInterpreter: INativeDirectiveInterpreter
{
	override void interpret(Interpreter interp) {
		interp._stack ~= IvyData(interp.getValue("value").toString());
	}

	private __gshared DirAttrsBlock[] _attrBlocks = [
		DirAttrsBlock(DirAttrKind.ExprAttr, [
			DirValueAttr("value", "any")
		]),
		DirAttrsBlock(DirAttrKind.BodyAttr)
	];

	mixin BaseNativeDirInterpreterImpl!("str");
}