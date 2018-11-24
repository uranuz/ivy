module ivy.compiler.directive.slice;

import ivy.compiler.directive.utils;

class SliceCompiler: IDirectiveCompiler
{
	override void compile(IDirectiveStatement stmt, ByteCodeCompiler compiler)
	{
		auto stmtRange = stmt[];

		if( stmtRange.empty )
			compiler.loger.error(`Expected node as "slice"s "aggregate" argument!`);
		stmtRange.front.accept(compiler);
		stmtRange.popFront();

		if( stmtRange.empty )
			compiler.loger.error(`Expected node as "slice"s "begin" argument!`);
		stmtRange.front.accept(compiler);
		stmtRange.popFront();

		if( stmtRange.empty )
			compiler.loger.error(`Expected node as "slice"s "end" argument!`);
		stmtRange.front.accept(compiler);
		stmtRange.popFront();

		compiler.addInstr(OpCode.LoadSlice); // Add Insert instruction that works with 3 passed arguments

		if( !stmtRange.empty )
		{
			compiler.loger.write(`SliceCompiler. At end. stmtRange.front.kind: `, stmtRange.front.kind);
			compiler.loger.error(`Expected end of "slice" directive. Maybe ';' is missing`);
		}
	}
}