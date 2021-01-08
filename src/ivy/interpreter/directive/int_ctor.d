module ivy.interpreter.directive.int_ctor;

import ivy.interpreter.directive.utils;

class IntCtorDirInterpreter: BaseDirectiveInterpreter
{
	this() {
		this._symbol = new DirectiveSymbol("int", [DirAttr("value", "any")]);
	}
	
	override void interpret(Interpreter interp) {
		interp._stack.push(interp.getValue("value").toInteger());
	}
}