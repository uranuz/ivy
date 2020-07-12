module ivy.interpreter.directive.len;

import ivy.interpreter.directive.utils;

class LenDirInterpreter: INativeDirectiveInterpreter
{
	override void interpret(Interpreter interp) {
		interp._stack.push(interp.getValue("value").length);
	}

	private __gshared DirAttrsBlock[] _attrBlocks = [
		DirAttrsBlock(DirAttrKind.ExprAttr, [
			DirValueAttr("value", "any")
		]),
		DirAttrsBlock(DirAttrKind.BodyAttr)
	];

	mixin BaseNativeDirInterpreterImpl!("len");
}