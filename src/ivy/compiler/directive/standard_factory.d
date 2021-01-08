module ivy.compiler.directive.standard_factory;

auto makeStandardDirCompilerFactory()
{
	import ivy.compiler.directive;
	import ivy.compiler.directive.factory: DirectiveCompilerFactory;
	
	auto factory = new DirectiveCompilerFactory;
	factory.set(`at`, new AtCompiler);
	factory.set(`await`, new AwaitCompiler);
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
	factory.set(`class`, new DeclClassCompiler);
	return factory;
}