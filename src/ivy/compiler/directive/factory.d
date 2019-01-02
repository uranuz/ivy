module ivy.compiler.directive.factory;

class DirectiveCompilerFactory
{
	import ivy.compiler.iface: IDirectiveCompiler;
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
