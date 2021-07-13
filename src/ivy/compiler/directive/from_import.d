module ivy.compiler.directive.from_import;

import ivy.compiler.directive.utils;

/// Compiles module into module object and saves it into dictionary
class FromImportCompiler: IDirectiveCompiler
{
	import ivy.ast.iface:
		INameExpression,
		IAttributeRange;
	import ivy.compiler.symbol_table: SymbolTableFrame, SymbolWithFrame;
	import ivy.types.symbol.iface: IIvySymbol;

	import ivy.types.module_object: ModuleObject;

public:
	override void collect(IDirectiveStatement stmt, CompilerSymbolsCollector collector)
	{
		import std.range: back;

		IAttributeRange attrRange = stmt[];
		assure(!attrRange.empty, "Expected module name in import statement, but got end of directive");

		INameExpression moduleNameExpr = attrRange.takeFrontAs!INameExpression("Expected module name in import directive");
		INameExpression importKwdExpr = attrRange.takeFrontAs!INameExpression("Expected 'import' keyword!");
		assure(importKwdExpr.name == "import", "Expected 'import' keyword!");

		string[] symbolNames;
		while( !attrRange.empty )
		{
			INameExpression symbolNameExpr = attrRange.takeFrontAs!INameExpression("Expected imported symbol name");
			symbolNames ~= symbolNameExpr.name;
		}

		SymbolWithFrame swf = collector.getModuleSymbols(moduleNameExpr.name);

		foreach( symbolName; symbolNames )
		{
			// As long as variables currently shall be imported in runtime only and there is no compile-time
			// symbols for it, so import symbol that currently exists
			IIvySymbol importedSymbol = swf.frame.localLookup(symbolName);
			assure(importedSymbol, "Symbol not found: ", symbolName);
			collector._frameStack.back.add(importedSymbol);
		}
	}

	override void compile(IDirectiveStatement stmt, ByteCodeCompiler compiler)
	{
		auto stmtRange = stmt[];

		INameExpression moduleNameExpr = stmtRange.takeFrontAs!INameExpression("Expected module name for import");

		INameExpression importKwdExpr = stmtRange.takeFrontAs!INameExpression("Expected 'import' keyword, but got end of range");
		assure(importKwdExpr.name == "import", "Expected 'import' keyword");

		string[] varNames;
		while( !stmtRange.empty )
		{
			INameExpression varNameExpr = stmtRange.takeFrontAs!INameExpression("Expected imported variable name");
			varNames ~= varNameExpr.name;
		}

		assure("Not all attributes for directive \"from\" were parsed. Maybe ';' is missing somewhere");

		// Module must be compiled before we can import it
		ModuleObject importedModuleObj = compiler.getOrCompileModule(moduleNameExpr.name);

		compiler.currentModule.addDependModule(importedModuleObj.name, importedModuleObj.fileName);

		compiler.addInstr(OpCode.LoadConst, compiler.addConst( IvyData(moduleNameExpr.name) ));
		compiler.addInstr(OpCode.ImportModule);

		compiler.addInstr(OpCode.LoadConst, compiler.addConst( IvyData(varNames) )); // Put list of imported names on the stack
		compiler.addInstr(OpCode.FromImport); // Store names from module exec frame into current frame
		// OpCode.FromImport  does not put value on the stack so do it there
		compiler.addInstr(OpCode.LoadConst, compiler.addConst( IvyData() ) );
	}
}