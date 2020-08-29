module ivy.interpreter.directive.int_ctor;

import ivy.interpreter.directive.utils;

class IntCtorDirInterpreter: BaseDirectiveInterpreter
{
	shared static this() {
		_symbol = new DirectiveSymbol(`int`, [DirAttr("value", "any")]);
	}
	
	override void interpret(Interpreter interp)
	{
		import std.conv: to;
		IvyData value = interp.getValue("value");
		switch(value.type)
		{
			case IvyDataType.Boolean:
				interp._stack.push(value.boolean? 1: 0);
				break;
			case IvyDataType.Integer:
				interp._stack.push(value);
				break;
			case IvyDataType.String:
				interp._stack.push(value.str.to!ptrdiff_t);
				break;
			default:
				interp.log.error(`Cannot convert value of type: `, value.type, ` to integer`);
				break;
		}
	}


}