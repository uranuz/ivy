module ivy.compiler.directive.decl_class;

import ivy.compiler.directive.utils;

class DeclClassCompiler: IDirectiveCompiler
{
	import ivy.compiler.symbol_table: SymbolTableFrame;
	import ivy.types.symbol.directive: DirectiveSymbol;
	import ivy.types.symbol.decl_class: DeclClassSymbol;

	import ivy.ast.iface:
		IAttributeRange,
		INameExpression,
		ICodeBlockStatement;

	override void collect(IDirectiveStatement stmt, CompilerSymbolsCollector collector)
	{
		import std.range: empty, back, popBack;

		IAttributeRange classAttrsRange = stmt[];

		INameExpression classNameExpr = classAttrsRange.takeFrontAs!INameExpression("Expected directive name");
		ICodeBlockStatement classBodyStmt = classAttrsRange.takeFrontAs!ICodeBlockStatement("Expected code block as directive attributes definition");

		// Add directive definition into existing frame
		DeclClassSymbol classSymbol = new DeclClassSymbol(classNameExpr.name, classNameExpr.location);

		{
			DirectiveSymbol makeClassSymbol = new DirectiveSymbol("__make_" ~ classNameExpr.name ~ "__", stmt.location);

			// Create new frame for class body
			collector._frameStack ~= collector._frameStack.back.newChildFrame(makeClassSymbol);
			scope(exit) collector.exitScope();

			classBodyStmt.accept(collector);

			DirectiveSymbol initSymbol = cast(DirectiveSymbol) collector.symbolLookup("__init__");
			if( initSymbol is null )
				collector.log.error("Expected \"init\" symbol");

			// Add "__new__" symbol to class body scope. Copy "__init__" attrs to "__new__"
			DirectiveSymbol newClassSymbol = new DirectiveSymbol("__new__", classBodyStmt.location, initSymbol.attrs, initSymbol.bodyAttrs);
			collector._frameStack.back.newChildFrame(newClassSymbol);

			classSymbol.initSymbol = initSymbol;
		}

		collector._frameStack.back.newChildFrame(classSymbol);
	}

	override void compile(IDirectiveStatement stmt, ByteCodeCompiler compiler)
	{
		import ivy.types.call_spec: CallSpec;

		IAttributeRange classAttrsRange = stmt[];

		INameExpression classNameExpr = classAttrsRange.takeFrontAs!INameExpression("Expected directive name");
		ICodeBlockStatement classBodyStmt = classAttrsRange.takeFrontAs!ICodeBlockStatement("Expected code block as directive attributes definition");

		DirectiveSymbol makeClassSymbol = new DirectiveSymbol("__make_" ~ classNameExpr.name ~ "__", classNameExpr.location);
		if( makeClassSymbol is null )
			compiler.log.error("Expected make class symbol");

		DeclClassSymbol classSymbol = cast(DeclClassSymbol) compiler.symbolLookup(classNameExpr.name);
		if( classSymbol is null )
			compiler.log.error("Expected class symbol");

		size_t classNameConstIndex = compiler.addConst(IvyData(classNameExpr.name));

		// Creating code object for class body
		size_t classCodeObjIndex; 
		{
			// Enter symbols collector scope of class body
			compiler._symbolsCollector.enterScope(stmt.location);
			scope(exit) compiler._symbolsCollector.exitScope();

			classCodeObjIndex = compiler.enterNewCodeObject(makeClassSymbol);
			scope(exit) compiler.exitCodeObject();

			// Generating code for class body
			classBodyStmt.accept(compiler);

			DirectiveSymbol newClassSymbol = cast(DirectiveSymbol) compiler.symbolLookup("__new__");
			if( newClassSymbol is null )
				compiler.log.error("Expected new class symbol");

			size_t newClassCodeObjIndex; 
			{
				compiler._symbolsCollector.enterScope(newClassSymbol.location);
				scope(exit) compiler._symbolsCollector.exitScope();

				newClassCodeObjIndex = compiler.enterNewCodeObject(newClassSymbol);
				scope(exit) compiler.exitCodeObject();

				// Class object expected to be stored in context variable "this". Use it as argunent to "__new_alloc__"
				compiler.addInstr(OpCode.LoadName, compiler.addConst( IvyData("this") ));
				// Add instruction to load "__new_alloc__" callable from global scope
				compiler.addInstr(OpCode.LoadName, compiler.addConst( IvyData("__new_alloc__") ));
				// Call "__new_alloc__" passing 1 positional parameter, that is a class object to be allocated
				compiler.addInstr(OpCode.RunCallable, CallSpec(1, false).encode());

				// Duplicate class on the stack, because we want to return it at the end, but it will be consumed by LoadAttr
				compiler.addInstr(OpCode.DubTop);

				// Get all the variables from scope that can be used as constructor arguments in order to use later (**1)
				compiler.addInstr(OpCode.LoadName, compiler.addConst( IvyData("scope") ));
				// Run "scope" in order to get all local variables
				compiler.addInstr(OpCode.RunCallable, CallSpec().encode());

				// Swap "__init__" arguments and duplicate class
				compiler.addInstr(OpCode.SwapTwo);

				// Load name of "__init__" function
				compiler.addInstr(OpCode.LoadConst, compiler.addConst( IvyData("__init__") ));
				// No we have newly allocated class instance and name of "__init__" before it on the stack...
				// We shall get "__init__" function of class instance
				compiler.addInstr(OpCode.LoadAttr);

				// (**1) Call "__init__" and pass it's arguments by name got from "scope"
				compiler.addInstr(OpCode.RunCallable, CallSpec(0, true).encode());

				// Drop what is returned by "__init__" and leave only class on the stack
				compiler.addInstr(OpCode.PopTop);
			}

			// Drop result of execution of code in class body
			compiler.addInstr(OpCode.PopTop);

			// Add instruction to load "__new__" code object
			compiler.addInstr(OpCode.LoadConst, newClassCodeObjIndex);

			// Add instruction to create callable object for "__new__"
			compiler.addInstr(OpCode.MakeCallable, CallSpec().encode());

			// Store "__new__" callable in local scope
			compiler.addInstr(OpCode.StoreName, compiler.addConst( IvyData("__new__") ));

			// Add class name onto the stack to build class
			compiler.addInstr(OpCode.LoadConst, classNameConstIndex);

			// Add instructions to load and run "scope", which gets all locals in current scope
			compiler.addInstr(OpCode.LoadName, compiler.addConst( IvyData("scope") ));
			compiler.addInstr(OpCode.RunCallable, CallSpec().encode());

			// Build class. It will be result of code object
			compiler.addInstr(OpCode.MakeClass);
		}

		// Add instruction to load *make class* code object from module constants
		compiler.addInstr(OpCode.LoadConst, classCodeObjIndex);
		// Add instruction to create callable object to *make class*
		compiler.addInstr(OpCode.MakeCallable, CallSpec().encode());
		// Add instruction to run callable object to *make class*
		compiler.addInstr(OpCode.RunCallable, CallSpec().encode());

		// Store class in current scope by name of the class
		compiler.addInstr(OpCode.StoreName, classNameConstIndex);

		// For now we expect that directive should return some value on the stack
		compiler.addInstr(OpCode.LoadConst, compiler.addConst( IvyData() ));
	}

}