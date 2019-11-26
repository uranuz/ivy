module ivy.interpreter.directive.standard_factory;

import ivy.interpreter.directive.factory: InterpreterDirectiveFactory;

InterpreterDirectiveFactory makeStandardInterpreterDirFactory()
{
	import ivy.interpreter.directive;
	import ivy.interpreter.directive.factory;

	auto factory = new InterpreterDirectiveFactory;
	factory.add(new BoolCtorDirInterpreter);
	factory.add(new IntCtorDirInterpreter);
	factory.add(new FloatCtorDirInterpreter);
	factory.add(new StrCtorDirInterpreter);
	factory.add(new HasDirInterpreter);
	factory.add(new TypeStrDirInterpreter);
	factory.add(new LenDirInterpreter);
	factory.add(new EmptyDirInterpreter);
	factory.add(new ScopeDirInterpreter);
	factory.add(new DateTimeGetDirInterpreter);
	factory.add(new RangeDirInterpreter);
	return factory;
}