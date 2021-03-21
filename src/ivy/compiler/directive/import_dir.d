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
		assure(!attrRange.empty, "Expected module name in import statement, but got end of directive");

		INameExpression moduleNameExpr = attrRange.takeFrontAs!INameExpression("Expected module name in import directive");

		assure(attrRange.empty, "Expected end of \"import\" directive, maybe ; is missing");

		// Add imported module symbol table as local symbol
		collector._frameStack.back.add(collector.getModuleSymbols(moduleNameExpr.name).symbol);
	}

	override void compile(IDirectiveStatement stmt, ByteCodeCompiler compiler)
	{
		import std.array: split;

		assure(false, "'import' directive is not working yet. Use 'from ... import ...' instead");
		/*
		

		auto stmtRange = statement[];

		INameExpression moduleNameExpr = stmtRange.takeFrontAs!INameExpression("Expected module name for import");
		assure(stmtRange.empty, "Not all attributes for directive "import" were parsed. Maybe ; is missing somewhere");

		
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