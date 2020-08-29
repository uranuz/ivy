module ivy.interpreter.directive.scope_dir;

import ivy.interpreter.directive.utils;

class ScopeDirInterpreter: BaseDirectiveInterpreter
{
	shared static this()
	{
		DirBodyAttrs bodyAttrs;
		bodyAttrs.isNoscope = true;
		bodyAttrs.isNoescape = false;
		_symbol = new DirectiveSymbol(`scope`, null, bodyAttrs);
	}

	override void interpret(Interpreter interp)
	{
		interp.log.internalAssert(interp.independentFrame, `Current frame is null!`);
		interp._stack.push(interp.independentFrame._dataDict);
	}
}