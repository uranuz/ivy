module ivy.compiler.directive.factory;

import ivy.compiler.iface: IDirectiveCompiler;

class DirectiveCompilerFactory
{
public:
	this() {}

	IDirectiveCompiler get(string name) {
		return _dirCompilers.get(name, null);
	}

	void set(string name, IDirectiveCompiler dir) {
		_dirCompilers[name] = dir;
	}

private:
	// Dictionary of native compilers for directives
	IDirectiveCompiler[string] _dirCompilers;
}

auto makeStandartDirCompilerFactory()
{
	import ivy.compiler.directive;
	
	auto factory = new DirectiveCompilerFactory;
	factory.set(`at`, new AtCompiler);
	factory.set(`break`, new BreakCompiler);
	factory.set(`call`, new CallCompiler);
	factory.set(`continue`, new ContinueCompiler);
	factory.set(`def`, new DefCompiler);
	factory.set(`expr`, new ExprCompiler);
	factory.set(`for`, new ForCompiler);
	factory.set(`from`, new FromImportCompiler);
	factory.set(`if`, new IfCompiler);
	factory.set(`import`, new ImportCompiler);
	factory.set(`insert`, new InsertCompiler);
	factory.set(`pass`, new PassCompiler);
	factory.set(`repeat`, new RepeatCompiler);
	factory.set(`return`, new ReturnCompiler);
	factory.set(`setat`, new SetAtCompiler);
	factory.set(`set`, new SetCompiler);
	factory.set(`slice`, new SliceCompiler);
	factory.set(`var`, new VarCompiler);
	return factory;
}