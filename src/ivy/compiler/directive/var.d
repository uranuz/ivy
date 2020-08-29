module ivy.compiler.directive.var;

import ivy.compiler.directive.utils;
import ivy.ast.iface: IKeyValueAttribute, INameExpression;

/++
	`Var` directive is defined as list of elements. Each of them could be of following forms:
	- Just name of new variable without any value or type (default value will be set, type is `any`)
		{=var a}
	- Name with initializer value (type is `any`)
		{=var a: "Example"}
	- Name with type but without any value (`as` context keyword is used to describe type)
		{=var a as str}
	- Name with initializer and type
		{=var a: "Example" as str}

	Multiple variables could be defined using one `var` directive
	{=var
		a
		b: "Example"
		c as str
		d: "Example2" as str
	}
+/
class VarCompiler: BaseDirectiveCompiler
{
public:
	override void compile(IDirectiveStatement stmt, ByteCodeCompiler compiler)
	{
		import std.range: empty, back, empty;
		import std.algorithm: canFind;

		auto stmtRange = stmt[];
		while( !stmtRange.empty )
		{
			size_t varNameConstIndex;
			if( auto kwPair = cast(IKeyValueAttribute) stmtRange.front )
			{
				if( kwPair.name.empty )
					compiler.log.error(`Variable name cannot be empty`);

				if( kwPair.name.canFind('.') )
					compiler.log.error(`Unable to set attributes with "var" directive`);
				varNameConstIndex = compiler.addConst( IvyData(kwPair.name) );

				if( !kwPair.value )
					compiler.log.error("Expected value for 'var' directive");

				kwPair.value.accept(compiler); // Compile expression for getting value
				stmtRange.popFront();
			}
			else if( auto nameExpr = cast(INameExpression) stmtRange.front )
			{
				if( nameExpr.name.empty )
					compiler.log.error(`Variable name cannot be empty`);
				if( nameExpr.name.canFind('.') )
					compiler.log.error(`Unable to set attributes with "var" directive`);
				varNameConstIndex = compiler.addConst( IvyData(nameExpr.name) );

				stmtRange.popFront();
			}
			else
			{
				compiler.log.error(`Expected named attribute or name as variable declarator!`);
			}

			if( !stmtRange.empty )
			{
				if( auto asKwdExpr = cast(INameExpression) stmtRange.front )
				{
					if( asKwdExpr.name == "as" )
					{
						// TODO: Try to find out type of variable after `as` keyword
						// Assuming that there will be no variable with name `as` in programme
						stmtRange.popFront(); // Skip `as` keyword

						if( stmtRange.empty )
							compiler.log.error(`Expected variable type declaration`);

						// For now just skip type expression
						stmtRange.popFront();
					}
				}
			}

			compiler.addInstr(OpCode.StoreName, varNameConstIndex);
		}

		// For now we expect that directive should return some value on the stack
		compiler.addInstr(OpCode.LoadConst, compiler.addConst( IvyData() ));

		if( !stmtRange.empty )
			compiler.log.error("Expected end of directive after key-value pair. Maybe ';' is missing");
	}
}