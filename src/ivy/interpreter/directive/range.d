module ivy.interpreter.directive.range;

import ivy.interpreter.directive.utils;

import ivy.types.data.range.integer: IntegerRange;

class RangeDirInterpreter: BaseDirectiveInterpreter
{
	this()
	{
		_symbol = new DirectiveSymbol(`range`, [
			DirAttr("begin", IvyAttrType.Any),
			DirAttr("end", IvyAttrType.Any)
		]);
	}

	override void interpret(Interpreter interp)
	{
		IvyData begin = interp.getValue("begin");
		IvyData end = interp.getValue("end");

		if( begin.type !=  IvyDataType.Integer ) {
			interp.log.error(`Expected integer as 'begin' argument!`);
		}
		if( end.type !=  IvyDataType.Integer ) {
			interp.log.error(`Expected integer as 'end' argument!`);
		}

		interp._stack.push(new IntegerRange(begin.integer, end.integer));
	}
}