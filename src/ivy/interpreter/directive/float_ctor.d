module ivy.interpreter.directive.float_ctor;

import ivy.interpreter.directive.utils;

class FloatCtorDirInterpreter: BaseDirectiveInterpreter
{
	shared static this() {
		_symbol = new DirectiveSymbol(`float`, [DirAttr("value", IvyAttrType.Any)]);
	}

	override void interpret(Interpreter interp)
	{
		import std.conv: to;
		IvyData value = interp.getValue("value");
		switch(value.type)
		{
			case IvyDataType.Boolean:
				interp._stack.push(value.boolean? 1.0: 0.0);
				break;
			case IvyDataType.Integer:
				interp._stack.push(value.integer.to!double);
				break;
			case IvyDataType.Floating:
				interp._stack.push(value);
				break;
			case IvyDataType.String:
				interp._stack.push(value.str.to!double);
				break;
			default:
				interp.log.error(`Cannot convert value of type: `, value.type, ` to integer`);
				break;
		}
	}
}