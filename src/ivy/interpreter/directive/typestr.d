module ivy.interpreter.directive.typestr;

import ivy.interpreter.directive.utils;

class TypeStrDirInterpreter: BaseDirectiveInterpreter
{
	this() {
		this._symbol = new DirectiveSymbol("typestr", [DirAttr("value", IvyAttrType.Any)]);
	}

	override void interpret(Interpreter interp)
	{
		import std.conv: text;
		interp._stack.push(interp.getValue("value").type.text);
	}
}