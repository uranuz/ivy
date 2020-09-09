module ivy.compiler.iface;

import ivy.ast.iface: IDirectiveStatement;
import ivy.compiler.symbol_collector: CompilerSymbolsCollector;
import ivy.compiler.compiler: ByteCodeCompiler;

interface IDirectiveCompiler
{
	/// Preliminary phase that is used to collect info before compilation
	void collect(IDirectiveStatement stmt, CompilerSymbolsCollector collector);
	
	/// Main phase that is used to compile directive
	void compile(IDirectiveStatement stmt, ByteCodeCompiler compiler);
}

class BaseDirectiveCompiler: IDirectiveCompiler
{
public:
	override void collect(IDirectiveStatement stmt, CompilerSymbolsCollector collector) {
		foreach( childNode; stmt[] )
		{
			collector.log.write(`!!!!!Symbols collector. Analyse child of kind: `, childNode.kind, ` for IDirectiveStatement node: `, stmt.name);
			collector.log.internalAssert(childNode, `Child node is null`);
			childNode.accept(collector);
		}
	}

	override void compile(IDirectiveStatement stmt, ByteCodeCompiler compiler) {}
}