module ivy.compiler.directive.at;

import ivy.compiler.directive.utils;
import ivy.ast.iface: IvyNode;

class AtCompiler: BaseDirectiveCompiler
{
public:
	override void compile(IDirectiveStatement stmt, ByteCodeCompiler compiler)
	{
		auto stmtRange = stmt[];

		IvyNode aggregate = stmtRange.takeFrontAs!IvyNode("Expected \"at\" aggregate argument");
		IvyNode indexValue = stmtRange.takeFrontAs!IvyNode("Expected \"at\" index value");

		aggregate.accept(compiler); // Evaluate aggregate
		indexValue.accept(compiler); // Evaluate index
		compiler.addInstr(OpCode.LoadSubscr);

		assure(stmtRange.empty, "Expected end of \"at\" directive after index expression. Maybe ';' is missing");
	}
}