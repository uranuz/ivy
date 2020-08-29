module ivy.compiler.directive.break_dir;

import ivy.compiler.directive.utils;
import ivy.compiler.compiler: JumpKind;

class BreakCompiler: BaseDirectiveCompiler
{
public:
	override void compile(IDirectiveStatement stmt, ByteCodeCompiler compiler)
	{
		import std.range: empty, back;
		alias JumpTableItem = ByteCodeCompiler.JumpTableItem;

		auto stmtRange = stmt[];

		if( !stmtRange.empty ) {
			compiler.log.error(`Expected end of "return" directive. Maybe ';' is missing`);
		}

		compiler.log.internalAssert(!compiler._jumpTableStack.empty, `Jump table stack is empty!`);
		// Add instruction to jump at SOME position and put instruction index and kind in jump table
		// This SOME position will be calculated and patched when generating loop bytecode
		compiler._jumpTableStack.back ~= JumpTableItem(JumpKind.Break, compiler.addInstr(OpCode.Jump));
	}
}