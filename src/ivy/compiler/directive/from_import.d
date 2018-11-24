module ivy.compiler.directive.from_import;

import ivy.compiler.directive.utils;
import ivy.parser.node: INameExpression;

/// Compiles module into module object and saves it into dictionary
class FromImportCompiler: IDirectiveCompiler
{
public:
	override void compile(IDirectiveStatement statement, ByteCodeCompiler compiler)
	{
		auto stmtRange = statement[];

		INameExpression moduleNameExpr = stmtRange.takeFrontAs!INameExpression("Expected module name for import");

		INameExpression importKwdExpr = stmtRange.takeFrontAs!INameExpression("Expected 'import' keyword, but got end of range");
		if( importKwdExpr.name != "import" )
			compiler.loger.error("Expected 'import' keyword");

		string[] varNames;
		while( !stmtRange.empty )
		{
			INameExpression varNameExpr = stmtRange.takeFrontAs!INameExpression("Expected imported variable name");
			varNames ~= varNameExpr.name;
		}

		if( !stmtRange.empty )
			compiler.loger.error(`Not all attributes for directive "from" were parsed. Maybe ; is missing somewhere`);

		compiler.getOrCompileModule(moduleNameExpr.name); // Module must be compiled before we can import it

		compiler.addInstr(OpCode.LoadConst, compiler.addConst( IvyData(moduleNameExpr.name) ));

		compiler.addInstr(OpCode.ImportModule);
		compiler.addInstr(OpCode.SwapTwo); // Swap module return value and imported execution frame
		//compiler.addInstr(OpCode.PopTop); // Drop return value of module importing, because it is meaningless
		compiler.addInstr(OpCode.LoadConst, compiler.addConst( IvyData(varNames) )); // Put list of imported names on the stack
		compiler.addInstr(OpCode.FromImport); // Store names from module exec frame into current frame
		// OpCode.FromImport  does not put value on the stack so do it there
		//compiler.addInstr(OpCode.LoadConst, compiler.addConst( IvyData() ) );
	}
}