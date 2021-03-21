module ivy.interpreter.directive.has;

import ivy.interpreter.directive.utils;

class HasDirInterpreter: BaseDirectiveInterpreter
{
	this()
	{
		this._symbol = new DirectiveSymbol("has", [
			DirAttr("collection", IvyAttrType.Any),
			DirAttr("key", IvyAttrType.Any)
		]);
	}
	
	override void interpret(Interpreter interp)
	{
		import std.algorithm: canFind;

		IvyData collection = interp.getValue("collection");
		IvyData key = interp.getValue("key");
		switch(collection.type)
		{
			case IvyDataType.AssocArray:
				interp.assure(
					key.type == IvyDataType.String,
					"Expected string as second \"has\" directive attribute, but got: ", key.type);
				interp._stack.push(cast(bool)(key.str in collection));
				break;
			case IvyDataType.Array:
				interp._stack.push(collection.array.canFind(key));
				break;
			default:
				interp.assure(false, "Expected array or assoc array as first \"has\" directive attribute, but got: ", collection.type);
				break;
		}
	}
}