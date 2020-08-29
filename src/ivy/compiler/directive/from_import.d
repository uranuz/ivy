module ivy.compiler.directive.from_import;

import ivy.compiler.directive.utils;

/// Compiles module into module object and saves it into dictionary
class FromImportCompiler: IDirectiveCompiler
{
	import ivy.ast.iface:
		INameExpression,
		IAttributeRange;
	import ivy.compiler.symbol_table: SymbolTableFrame;
	import ivy.types.symbol.iface: IIvySymbol;

public:
	override void collect(IDirectiveStatement stmt, CompilerSymbolsCollector collector)
	{
		import std.range: back;

		IAttributeRange attrRange = stmt[];
		if( attrRange.empty )
			collector.log.error(`Expected module name in import statement, but got end of directive`);

		INameExpression moduleNameExpr = attrRange.takeFrontAs!INameExpression("Expected module name in import directive");
		INameExpression importKwdExpr = attrRange.takeFrontAs!INameExpression("Expected 'import' keyword!");
		if( importKwdExpr.name != "import" )
			collector.log.error("Expected 'import' keyword!");

		string[] symbolNames;
		while( !attrRange.empty )
		{
			INameExpression symbolNameExpr = attrRange.takeFrontAs!INameExpression("Expected imported symbol name");
			symbolNames ~= symbolNameExpr.name;
		}

		SymbolTableFrame moduleTable = collector.getModuleSymbols(moduleNameExpr.name);

		foreach( symbolName; symbolNames )
		{
			// As long as variables currently shall be imported in runtime only and there is no compile-time
			// symbols for it, so import symbol that currently exists
			if( IIvySymbol importedSymbol = moduleTable.localLookup(symbolName) ) {
				collector._frameStack.back.add(importedSymbol);
			}
		}
	}

	override void compile(IDirectiveStatement stmt, ByteCodeCompiler compiler)
	{
		auto stmtRange = stmt[];

		INameExpression moduleNameExpr = stmtRange.takeFrontAs!INameExpression("Expected module name for import");

		INameExpression importKwdExpr = stmtRange.takeFrontAs!INameExpression("Expected 'import' keyword, but got end of range");
		if( importKwdExpr.name != "import" )
			compiler.log.error("Expected 'import' keyword");

		string[] varNames;
		while( !stmtRange.empty )
		{
			INameExpression varNameExpr = stmtRange.takeFrontAs!INameExpression("Expected imported variable name");
			varNames ~= varNameExpr.name;
		}

		if( !stmtRange.empty )
			compiler.log.error(`Not all attributes for directive "from" were parsed. Maybe ; is missing somewhere`);

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