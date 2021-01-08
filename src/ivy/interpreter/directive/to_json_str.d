module ivy.interpreter.directive.to_json_str;

import ivy.interpreter.directive.utils;

class ToJSONStrDirInterpreter: BaseDirectiveInterpreter
{
	this() {
		this._symbol = new DirectiveSymbol("to_json_str", [DirAttr("value", IvyAttrType.Any)]);
	}

	override void interpret(Interpreter interp)
	{
		IvyData val = IvyData(interp.getValue("value").toJSONString());
		val.escapeState = NodeEscapeState.Safe;
		interp._stack.push(val);
	}
}