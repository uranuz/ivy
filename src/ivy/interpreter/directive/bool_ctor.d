module ivy.interpreter.directive.bool_ctor;

import ivy.interpreter.directive.utils;

class BoolCtorDirInterpreter: BaseDirectiveInterpreter
{
	shared static this() {
		_symbol = new DirectiveSymbol(`bool`, [DirAttr("value", IvyAttrType.Any)]);
	}
	
	override void interpret(Interpreter interp) {
		interp._stack.push(interp.getValue("value").toBoolean());
	}
}