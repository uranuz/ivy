module ivy.interpreter.directive.len;

import ivy.interpreter.directive.utils;

class LenDirInterpreter: BaseDirectiveInterpreter
{
	this() {
		this._symbol = new DirectiveSymbol("len", [DirAttr("value", IvyAttrType.Any)]);
	}

	override void interpret(Interpreter interp) {
		interp._stack.push(interp.getValue("value").length);
	}
}