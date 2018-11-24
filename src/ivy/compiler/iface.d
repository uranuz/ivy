module ivy.compiler.iface;

import ivy.parser.node: IDirectiveStatement;
import ivy.compiler.compiler: ByteCodeCompiler;

interface IDirectiveCompiler
{
	void compile(IDirectiveStatement stmt, ByteCodeCompiler compiler);
}