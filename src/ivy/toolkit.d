module ivy.toolkit;

import ivy.common;
import ivy.compiler;
import ivy.interpreter_data;
import ivy.interpreter;

alias TDataNode = DataNode!string;

// Structure for configuring Ivy
struct IvyConfig
{
	string[] importPaths; // Paths where to search for templates
	string fileExtension = `.ivy`; // Extension of files that are templates

	// Signature for loging methods, so logs can be forwarded to stdout, file or anywhere else...
	// If you wish debug output you must build with one of these -version specifiers:
	// IvyTotalDebug - maximum debug verbosity
	// IvyCompilerDebug - enable compiler debug output
	// IvyInterpreterDebug - enable interpreter debug output
	// IvyParserDebug - enable parser debug output
	// But errors and warnings will be sent to logs in any case. But you can ignore them...
	alias LogerMethod = void delegate(LogInfo);
	LogerMethod interpreterLoger;
	LogerMethod compilerLoger;
	LogerMethod parserLoger;

	IDirectiveCompiler[string] dirCompilers; // Dictionary of custom directive compilers
	INativeDirectiveInterpreter[string] dirInterpreters; // Dictionary of custom directive interpreters
	// Key difference between IDirectiveCompiler and INativeDirectiveInterpreter is that
	// compiler generates bytecode to execute some operation, etc...
	// But INativeDirectiveInterpreter runs in execution of Ivy programme and do these operation itself
	// Using compilers is preferable, but in some cases interpreters may be needed
}

// Representation of programme ready for execution
class ExecutableProgramme
{
	alias LogerMethod = void delegate(LogInfo);
private:
	ModuleObject[string] _moduleObjects;
	string _mainModuleName;
	LogerMethod _logerMethod;
	INativeDirectiveInterpreter[string] _dirInterpreters;

public:
	this(ModuleObject[string] moduleObjects, string mainModuleName, LogerMethod logerMethod = null)
	{
		_moduleObjects = moduleObjects;
		_mainModuleName = mainModuleName;
		_logerMethod = logerMethod;
	}

	/// Run programme main module with arguments passed as mainModuleScope parameter
	TDataNode run(TDataNode mainModuleScope = TDataNode())
	{
		mainModuleScope["__mentalModuleMagic_0451__"] = 451; // Just to make it a dict
		import std.range: back;

		import ivy.interpreter: Interpreter;
		Interpreter interp = new Interpreter(_moduleObjects, _mainModuleName, mainModuleScope, _logerMethod);
		interp.addDirInterpreters(_dirInterpreters);
		interp.execLoop();

		return interp._stack.back;
	}

	void logerMethod(LogerMethod method) @property {
		_logerMethod = method;
	}

	void dirInterpreters(INativeDirectiveInterpreter[string] dirInterps) @property {
		_dirInterpreters = dirInterps;
	}
}

ExecutableProgramme compileModule(string mainModuleName, IvyConfig config)
{
	import std.range: empty;
	import std.algorithm: map;
	import std.array: array;
	debug import std.stdio: writeln;

	if( config.importPaths.empty )
		compilerError(`List of compiler import paths must not be empty!`);
	
	// Creating object that manages reading source files, parse and store them as AST
	auto moduleRepo = new CompilerModuleRepository(config.importPaths, config.fileExtension, config.parserLoger);

	// Preliminary compiler phase that analyse imported modules and stores neccessary info about directives
	auto symbolsCollector = new CompilerSymbolsCollector(moduleRepo, mainModuleName, config.compilerLoger);
	symbolsCollector.run(); // Run analyse

	// Main compiler phase that generates bytecode for modules
	auto compiler = new ByteCodeCompiler(moduleRepo, symbolsCollector.getModuleSymbols(), mainModuleName, config.compilerLoger);
	compiler.addDirCompilers(config.dirCompilers);
	compiler.addGlobalSymbols( config.dirInterpreters.values.map!(it => it.compilerSymbol).array );
	compiler.run(); // Run compilation itself

	debug writeln("compileModule:\r\n", compiler.toPrettyStr());

	// Creating additional object that stores all neccessary info for simple usage
	auto prog = new ExecutableProgramme(compiler.moduleObjects, mainModuleName, config.interpreterLoger);
	prog.dirInterpreters = config.dirInterpreters;

	return prog;
}

/// Simple method that can be used to compile source file and get executable
ExecutableProgramme compileFile(string sourceFileName, IvyConfig config)
{
	import std.path: extension, stripExtension, relativePath, dirSeparator, dirName;
	import std.array: split, join, empty, front;

	//importPaths = sourceFileName.dirName() ~ importPaths; // For now let main source file path be in import paths

	// Calculating main module name
	string mainModuleName = sourceFileName.relativePath(config.importPaths.front).stripExtension().split(dirSeparator).join('.');

	return compileModule(mainModuleName, config);
}

/// Dump-simple in-memory cache for compiled programmes
class ProgrammeCache(bool useCache = true)
{
private:
	IvyConfig _config;

	static if(useCache)
	{
		ExecutableProgramme[string] _progs;

		import core.sync.mutex: Mutex;
		Mutex _mutex;
	}

public:
	this(IvyConfig config)
	{
		_config = config;
		static if(useCache)
		{
			_mutex = new Mutex();
		}
	}

	/// Generate programme object or get existing from cache (if cache enabled)
	ExecutableProgramme getByModuleName(string moduleName)
	{
		static if(useCache)
		{
			if( moduleName !in _progs )
			{
				synchronized(_mutex) {
					_progs[moduleName] = compileModule(moduleName, _config);
				}
			}
			return _progs[moduleName];
		}
		else
		{
			return compileModule(moduleName, _config);
		}
	}
}
