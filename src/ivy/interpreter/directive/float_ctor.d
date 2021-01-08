module ivy.interpreter.directive.float_ctor;

import ivy.interpreter.directive.utils;

class FloatCtorDirInterpreter: BaseDirectiveInterpreter
{
	this() {
		this._symbol = new DirectiveSymbol("float", [DirAttr("value", IvyAttrType.Any)]);
	}

	override void interpret(Interpreter interp) {
		interp._stack.push(interp.getValue("value").toFloating());
	}
}