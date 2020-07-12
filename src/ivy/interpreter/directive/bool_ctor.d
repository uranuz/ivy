module ivy.interpreter.directive.bool_ctor;

import ivy.interpreter.directive.utils;

class BoolCtorDirInterpreter: INativeDirectiveInterpreter
{
	override void interpret(Interpreter interp) {
		interp._stack.push(interp.getValue("value").toBoolean());
	}

	private __gshared DirAttrsBlock[] _attrBlocks = [
		DirAttrsBlock(DirAttrKind.ExprAttr, [
			DirValueAttr("value", "any")
		]),
		DirAttrsBlock(DirAttrKind.BodyAttr)
	];

	mixin BaseNativeDirInterpreterImpl!("bool");
}