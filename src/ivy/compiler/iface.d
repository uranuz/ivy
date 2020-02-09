module ivy.compiler.iface;

import ivy.ast.iface: IDirectiveStatement;
import ivy.compiler.compiler: ByteCodeCompiler;

interface IDirectiveCompiler
{
	void compile(IDirectiveStatement stmt, ByteCodeCompiler compiler);
}