module ivy.interpreter.directive.to_json_str;

import ivy.interpreter.data_node: IvyDataType, IvyData, NodeEscapeState;
import ivy.interpreter.iface: INativeDirectiveInterpreter;
import ivy.interpreter.interpreter: Interpreter;
import ivy.directive_stuff: DirAttrKind, DirAttrsBlock, DirValueAttr;
import ivy.interpreter.directive: BaseNativeDirInterpreterImpl;

class ToJSONStrDirInterpreter: INativeDirectiveInterpreter
{
	override void interpret(Interpreter interp)
	{
		IvyData val = IvyData(interp.getValue("value").toJSONString());
        val.escapeState = NodeEscapeState.Safe;
        interp._stack.push(val);
	}

	private __gshared DirAttrsBlock[] _attrBlocks = [
		DirAttrsBlock(DirAttrKind.ExprAttr, [
			DirValueAttr("value", "any")
		]),
		DirAttrsBlock(DirAttrKind.BodyAttr)
	];

	mixin BaseNativeDirInterpreterImpl!("to_json_str");
}