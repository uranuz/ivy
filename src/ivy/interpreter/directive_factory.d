module ivy.interpreter.directive_factory;

import ivy.interpreter.iface: INativeDirectiveInterpreter;
import ivy.compiler.symbol_table: Symbol;

class InterpreterDirectiveFactory
{
private:
	INativeDirectiveInterpreter[string] _dirInterps;

public:
	this() {}

	INativeDirectiveInterpreter get(string name) {
		return _dirInterps.get(name, null);
	}

	void add(INativeDirectiveInterpreter dirInterp) {
		_dirInterps[dirInterp.symbol.name] = dirInterp;
	}

	INativeDirectiveInterpreter[string] interps() @property {
		return _dirInterps;
	}

	Symbol[] symbols() @property
	{
		import std.algorithm: map;
		import std.array: array;
		return _dirInterps.values.map!(it => it.symbol).array;
	}
}

InterpreterDirectiveFactory makeStandardInterpreterDirFactory()
{
	import ivy.interpreter.directives;

	auto factory = new InterpreterDirectiveFactory;
	factory.add(new IntCtorDirInterpreter);
	factory.add(new FloatCtorDirInterpreter);
	factory.add(new StrCtorDirInterpreter);
	factory.add(new HasDirInterpreter);
	factory.add(new TypeStrDirInterpreter);
	factory.add(new LenDirInterpreter);
	factory.add(new EmptyDirInterpreter);
	factory.add(new ScopeDirInterpreter);
	factory.add(new ToJSONBase64DirInterpreter);
	factory.add(new DateTimeGetDirInterpreter);
	factory.add(new RangeDirInterpreter);
	return factory;
}
