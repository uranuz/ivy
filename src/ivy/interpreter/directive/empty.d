module ivy.interpreter.directive.empty;

import ivy.interpreter.directive.utils;

class EmptyDirInterpreter: BaseDirectiveInterpreter
{
	this() {
		_symbol = new DirectiveSymbol("empty", [DirAttr("value", IvyAttrType.Any)]);
	}
	
	override void interpret(Interpreter interp)
	{
		interp._stack.push(interp.getValue("value").empty);
	}
}