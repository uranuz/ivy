module ivy.interpreter.directive.scope_dir;

import ivy.interpreter.directive.utils;

class ScopeDirInterpreter: INativeDirectiveInterpreter
{
	import std.typecons: Tuple;

	override void interpret(Interpreter interp)
	{
		interp.log.internalAssert(interp.independentFrame, `Current frame is null!`);
		interp._stack.push(interp.independentFrame._dataDict);
	}

	private __gshared DirAttrsBlock[] _attrBlocks = [
		DirAttrsBlock(DirAttrKind.BodyAttr,
			Tuple!(bool, "isNoscope", bool, "isNoescape")(true, false)
		)
	];

	mixin BaseNativeDirInterpreterImpl!("scope");
}