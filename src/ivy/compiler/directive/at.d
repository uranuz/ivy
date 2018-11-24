module ivy.compiler.directive.at;

import ivy.compiler.directive.utils;
import ivy.parser.node: IvyNode;

class AtCompiler : IDirectiveCompiler
{
public:
	override void compile(IDirectiveStatement statement, ByteCodeCompiler compiler)
	{
		auto stmtRange = statement[];

		IvyNode aggregate = stmtRange.takeFrontAs!IvyNode(`Expected "at" aggregate argument`);
		IvyNode indexValue = stmtRange.takeFrontAs!IvyNode(`Expected "at" index value`);

		aggregate.accept(compiler); // Evaluate aggregate
		indexValue.accept(compiler); // Evaluate index
		compiler.addInstr(OpCode.LoadSubscr);

		if( !stmtRange.empty )
			compiler.loger.error(`Expected end of "at" directive after index expression. Maybe ';' is missing. `
				~ `Info: multiple index expressions are not supported yet.`);
	}
}