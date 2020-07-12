module ivy.interpreter.directive.empty;

import ivy.interpreter.directive.utils;

class EmptyDirInterpreter: INativeDirectiveInterpreter
{
	override void interpret(Interpreter interp)
	{
		interp._stack.push(interp.getValue("value").empty);
	}

	private __gshared DirAttrsBlock[] _attrBlocks = [
		DirAttrsBlock(DirAttrKind.ExprAttr, [
			DirValueAttr("value", "any")
		]),
		DirAttrsBlock(DirAttrKind.BodyAttr)
	];

	mixin BaseNativeDirInterpreterImpl!("empty");
}