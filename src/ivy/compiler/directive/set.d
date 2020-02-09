module ivy.compiler.directive.set;

import ivy.compiler.directive.utils;
import ivy.ast.iface: IKeyValueAttribute;

/++
	`Set` directive is used to set values of existing variables in context.
	It is defined as list of named attributes where key is variable name
	and attr value is new value for variable in context. Example:
	{# set a: "Example" #}

	Multiple variables could be set using one `set` directive
	{# set
			a: "Example"
			b: 10
			c: { s: 10, k: "Example2" }
	#}
+/
class SetCompiler : IDirectiveCompiler
{
public:
	override void compile(IDirectiveStatement statement, ByteCodeCompiler compiler)
	{
		auto stmtRange = statement[];

		while( !stmtRange.empty )
		{
			IKeyValueAttribute kwPair = stmtRange.takeFrontAs!IKeyValueAttribute("Key-value pair expected");

			if( !kwPair.value )
				compiler.loger.error("Expected value for 'set' directive");

			kwPair.value.accept(compiler); //Evaluating expression

			compiler.addInstr(OpCode.StoreName, compiler.addConst( IvyData(kwPair.name) ));
		}

		// For now we expect that directive should return some value on the stack
		compiler.addInstr(OpCode.LoadConst, compiler.addConst( IvyData() ));

		if( !stmtRange.empty )
			compiler.loger.error("Expected end of directive after key-value pair. Maybe ';' is missing");
	}

}