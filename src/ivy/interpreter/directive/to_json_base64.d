module ivy.interpreter.directive.to_json_base64;

import ivy.interpreter.directive.utils;

class ToJSONBase64DirInterpreter: INativeDirectiveInterpreter
{
	import std.typecons: Tuple;

	override void interpret(Interpreter interp)
	{
		import std.base64: Base64;
		ubyte[] jsonStr = cast(ubyte[]) interp.getValue("value").toJSONString();
		interp._stack ~= IvyData(cast(string) Base64.encode(jsonStr));
	}

	private __gshared DirAttrsBlock[] _attrBlocks = [
		DirAttrsBlock(DirAttrKind.ExprAttr, [
			DirValueAttr("value", "any")
		]),
		DirAttrsBlock(DirAttrKind.BodyAttr)
	];

	mixin BaseNativeDirInterpreterImpl!("toJSONBase64");
}