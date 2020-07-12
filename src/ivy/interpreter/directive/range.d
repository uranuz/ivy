module ivy.interpreter.directive.range;

import ivy.interpreter.directive.utils;

import ivy.interpreter.data_node_types: IntegerRange;

class RangeDirInterpreter: INativeDirectiveInterpreter
{
	import std.typecons: Tuple;

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

	private __gshared DirAttrsBlock[] _attrBlocks = [
		DirAttrsBlock(DirAttrKind.ExprAttr, [
			DirValueAttr("begin", "any"),
			DirValueAttr("end", "any")
		]),
		DirAttrsBlock(DirAttrKind.BodyAttr)
	];

	mixin BaseNativeDirInterpreterImpl!("range");
}