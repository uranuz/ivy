module ivy.compiler.directive.expr;

import ivy.compiler.directive.utils;
import ivy.ast.iface: INameExpression;

class ExprCompiler: BaseDirectiveCompiler
{
public:
	override void compile(IDirectiveStatement stmt, ByteCodeCompiler compiler)
	{
		auto stmtRange = stmt[];
		if( stmtRange.empty )
			compiler.log.error(`Expected node as "expr" argument!`);

		stmtRange.front.accept(compiler);
		stmtRange.popFront();

		if( !stmtRange.empty )
		{
			compiler.log.write("ExprCompiler. At end. stmtRange.front.kind: ", ( cast(INameExpression) stmtRange.front ).name);
			compiler.log.error(`Expected end of "expr" directive. Maybe ';' is missing`);
		}
	}
}