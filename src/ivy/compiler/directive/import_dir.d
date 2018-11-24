module ivy.compiler.directive.import_dir;

import ivy.compiler.directive.utils;
import ivy.parser.node: INameExpression;

/// Compiles module into module object and saves it into dictionary
class ImportCompiler: IDirectiveCompiler
{
public:
	override void compile(IDirectiveStatement statement, ByteCodeCompiler compiler)
	{
		auto stmtRange = statement[];

		INameExpression moduleNameExpr = stmtRange.takeFrontAs!INameExpression("Expected module name for import");
		if( !stmtRange.empty )
			compiler.loger.error(`Not all attributes for directive "import" were parsed. Maybe ; is missing somewhere`);

		compiler.getOrCompileModule(moduleNameExpr.name); // Module must be compiled before we can import it

		size_t modNameConstIndex = compiler.addConst(IvyData(moduleNameExpr.name));
		compiler.addInstr(OpCode.LoadConst, modNameConstIndex); // The first is for ImportModule

		compiler.addInstr(OpCode.ImportModule);
		compiler.addInstr(OpCode.SwapTwo); // Swap module return value and imported execution frame
		//compiler.addInstr(OpCode.PopTop); // Drop return value of module importing, because it is meaningless
		compiler.addInstr(OpCode.StoreNameWithParents, modNameConstIndex);
		// OpCode.StoreName  does not put value on the stack so do it there
		//compiler.addInstr(OpCode.LoadConst, compiler.addConst( IvyData() ) );
	}
}