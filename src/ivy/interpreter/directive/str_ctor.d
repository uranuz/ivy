module ivy.interpreter.directive.str_ctor;

import ivy.interpreter.directive.utils;

class StrCtorDirInterpreter: BaseDirectiveInterpreter
{
	this() {
		this._symbol = new DirectiveSymbol("str", [DirAttr("value", IvyAttrType.Any)]);
	}

	override void interpret(Interpreter interp) {
		interp._stack.push(interp.getValue("value").toString());
	}
}