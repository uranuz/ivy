module ivy.interpreter.directive.range;

import ivy.interpreter.directive.utils;

class RangeDirInterpreter: BaseDirectiveInterpreter
{
	import ivy.types.data.range.integer: IntegerRange;

	this()
	{
		this._symbol = new DirectiveSymbol("range", [
			DirAttr("begin", IvyAttrType.Any),
			DirAttr("end", IvyAttrType.Any)
		]);
	}

	override void interpret(Interpreter interp)
	{
		interp._stack.push(
			new IntegerRange(
				interp.getValue("begin").integer,
				interp.getValue("end").integer));
	}
}