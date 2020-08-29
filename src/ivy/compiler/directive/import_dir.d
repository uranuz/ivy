module ivy.compiler.directive.import_dir;

import ivy.compiler.directive.utils;

/// Compiles module into module object and saves it into dictionary
class ImportCompiler: IDirectiveCompiler
{
	import ivy.ast.iface:
		IAttributeRange,
		INameExpression;
	import ivy.types.symbol.module_: ModuleSymbol;

public:
	override void collect(IDirectiveStatement stmt, CompilerSymbolsCollector collector)
	{
		import std.range: back;

		IAttributeRange attrRange = stmt[];
		if( attrRange.empty )
			collector.log.error(`Expected module name in import statement, but got end of directive`);

		INameExpression moduleNameExpr = attrRange.takeFrontAs!INameExpression("Expected module name in import directive");

		if( !attrRange.empty )
			collector.log.error(`Expected end of import directive, maybe ; is missing`);

		// Add imported module symbol table as local symbol
		collector._frameStack.back.add(new ModuleSymbol(moduleNameExpr.name, stmt.location.fileName));
	}

	override void compile(IDirectiveStatement stmt, ByteCodeCompiler compiler)
	{
		compiler.log.error(`"import" directive is not working yet. Use "from ... import ..." instead`);
		/*
		import std.array: split;

		auto stmtRange = statement[];

		INameExpression moduleNameExpr = stmtRange.takeFrontAs!INameExpression("Expected module name for import");
		if( !stmtRange.empty )
			compiler.log.error(`Not all attributes for directive "import" were parsed. Maybe ; is missing somewhere`);

		
		compiler.getOrCompileModule(moduleNameExpr.name); // Module must be compiled before we can import it
		string[] varPath = moduleNameExpr.name.split('.');

		size_t modNameConstIndex = compiler.addConst(IvyData(moduleNameExpr.name));
		compiler.addInstr(OpCode.LoadConst, modNameConstIndex); // The first is for ImportModule

		compiler.addInstr(OpCode.ImportModule);
		compiler.addInstr(OpCode.SwapTwo); // Swap module return value and imported execution frame
		//compiler.addInstr(OpCode.PopTop); // Drop return value of module importing, because it is meaningless
		compiler.addInstr(OpCode.StoreGlobalName, modNameConstIndex);
		*/

	
		// OpCode.StoreGlobalName does not put value on the stack so do it there
		//compiler.addInstr(OpCode.LoadConst, compiler.addConst( IvyData() ) );
	}
}