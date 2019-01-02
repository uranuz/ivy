module ivy.interpreter.directive.has;

import ivy.interpreter.directive.utils;

class HasDirInterpreter: INativeDirectiveInterpreter
{
	override void interpret(Interpreter interp)
	{
		import std.conv: to;
		import std.algorithm: canFind;
		IvyData collection = interp.getValue("collection");
		IvyData key = interp.getValue("key");
		switch(collection.type)
		{
			case IvyDataType.AssocArray:
				if( key.type != IvyDataType.String ) {
					interp.loger.error(`Expected string as second "has" directive attribute, but got: `, key.type);
				}
				interp._stack ~= IvyData(cast(bool)(key.str in collection));
				break;
			case IvyDataType.Array:
				interp._stack ~= IvyData(collection.array.canFind(key));
				break;
			default:
				interp.loger.error(`Expected array or assoc array as first "has" directive attribute, but got: `, collection.type);
				break;
		}
	}

	private __gshared DirAttrsBlock[] _attrBlocks = [
		DirAttrsBlock(DirAttrKind.ExprAttr, [
			DirValueAttr("collection", "any"),
			DirValueAttr("key", "any")
		]),
		DirAttrsBlock(DirAttrKind.BodyAttr)
	];

	mixin BaseNativeDirInterpreterImpl!("has");
}