module ivy.compiler.directive.insert;

import ivy.compiler.directive.utils;

class InsertCompiler: IDirectiveCompiler
{
	override void compile(IDirectiveStatement stmt, ByteCodeCompiler compiler)
	{
		auto stmtRange = stmt[];

		if( stmtRange.empty )
			compiler.loger.error(`Expected node as "insert"s "aggregate" argument!`);
		stmtRange.front.accept(compiler);
		stmtRange.popFront();

		if( stmtRange.empty )
			compiler.loger.error(`Expected node as "insert"s "value" argument!`);
		stmtRange.front.accept(compiler);
		stmtRange.popFront();

		if( stmtRange.empty )
			compiler.loger.error(`Expected node as "insert"s "index" argument!`);
		stmtRange.front.accept(compiler);
		stmtRange.popFront();

		compiler.addInstr(OpCode.Insert); // Add Insert instruction that works with 3 passed arguments

		if( !stmtRange.empty )
		{
			compiler.loger.write(`InsertCompiler. At end. stmtRange.front.kind: `, stmtRange.front.kind);
			compiler.loger.error(`Expected end of "insert" directive. Maybe ';' is missing`);
		}
	}
}