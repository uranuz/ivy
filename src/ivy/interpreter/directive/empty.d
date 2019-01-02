module ivy.interpreter.directive.empty;

import ivy.interpreter.directive.utils;

class EmptyDirInterpreter: INativeDirectiveInterpreter
{
	override void interpret(Interpreter interp)
	{
		IvyData value = interp.getValue("value");
		switch(value.type)
		{
			case IvyDataType.Undef: case IvyDataType.Null:
				interp._stack ~= IvyData(true);
				break;
			case IvyDataType.Integer, IvyDataType.Floating, IvyDataType.DateTime, IvyDataType.Boolean:
				// Considering numbers just non-empty there. Not try to interpret 0 or 0.0 as logical false,
				// because in many cases they could be treated as significant values
				// DateTime and Boolean are not empty too, because we cannot say what value should be treated as empty
				interp._stack ~= IvyData(false);
				break;
			case IvyDataType.String:
				interp._stack ~= IvyData(!value.str.length);
				break;
			case IvyDataType.Array:
				interp._stack ~= IvyData(!value.array.length);
				break;
			case IvyDataType.AssocArray:
				interp._stack ~= IvyData(!value.assocArray.length);
				break;
			case IvyDataType.DataNodeRange:
				interp._stack ~= IvyData(!value.dataRange || value.dataRange.empty);
				break;
			case IvyDataType.ClassNode:
				// Basic check for ClassNode for emptyness is that it should not be null reference
				// If some interface method will be introduced to check for empty then we shall consider to check it too
				interp._stack ~= IvyData(value.classNode is null);
				break;
			default:
				interp.loger.error(`Cannot test type: `, value.type, ` for emptyness`);
				break;
		}
	}

	private __gshared DirAttrsBlock[] _attrBlocks = [
		DirAttrsBlock(DirAttrKind.ExprAttr, [
			DirValueAttr("value", "any")
		]),
		DirAttrsBlock(DirAttrKind.BodyAttr)
	];

	mixin BaseNativeDirInterpreterImpl!("empty");
}