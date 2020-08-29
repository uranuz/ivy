module ivy.compiler.directive.pass;

import ivy.compiler.directive.utils;

// Produces OpCode.Nop
class PassCompiler : BaseDirectiveCompiler
{
public:
	override void compile(IDirectiveStatement statement, ByteCodeCompiler compiler) {
		compiler.addInstr(OpCode.Nop);
	}
}