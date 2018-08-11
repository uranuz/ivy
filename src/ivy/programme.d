module ivy.programme;

import ivy.common;
import ivy.code_object: ModuleObject;
import ivy.compiler.compiler;
import ivy.compiler.symbol_collector;
import ivy.compiler.module_repository;
import ivy.interpreter.data_node;
import ivy.interpreter.interpreter;
import ivy.interpreter.directives;

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
	TDataNode run(TDataNode mainModuleScope = TDataNode(), TDataNode[string] extraGlobals = null)
	{
		import std.range: back;

		import ivy.interpreter.interpreter: Interpreter;
		Interpreter interp = new Interpreter(_moduleObjects, _mainModuleName, mainModuleScope, _logerMethod);
		interp.addDirInterpreters(_dirInterpreters);
		interp.addExtraGlobals(extraGlobals);
		return interp.execLoop();
	}

	void logerMethod(LogerMethod method) @property {
		_logerMethod = method;
	}

	void dirInterpreters(INativeDirectiveInterpreter[string] dirInterps) @property {
		_dirInterpreters = dirInterps;
	}

	import std.json: JSONValue;
	JSONValue toStdJSON()
	{
		JSONValue jProg = ["mainModuleName": _mainModuleName];
		JSONValue[string] moduleObjects;
		foreach( string modName, ModuleObject modObj; _moduleObjects )
		{
			JSONValue[] jConsts;
			foreach( ref TDataNode con; modObj._consts ) {
				jConsts ~= .toStdJSON(con);
			}
			moduleObjects[modName] = [
				"entryPointIndex": JSONValue(modObj._entryPointIndex),
				"consts": JSONValue(jConsts),
				"fileName": JSONValue(modObj._fileName)
			];
		}
		jProg[`moduleObjects`] = moduleObjects;
		return jProg;
	}
}

import std.json: JSONValue;
JSONValue toStdJSON(TDataNode con)
{
	final switch( con.type ) with(DataNodeType)
	{
		case Undef: return JSONValue("undef");
		case Null: return JSONValue();
		case Boolean: return JSONValue(con.boolean);
		case Integer: return JSONValue(con.integer);
		case Floating: return JSONValue(con.floating);
		case String: return JSONValue(con.str);
		case DateTime:
			return JSONValue([
				"_t": JSONValue(con.type),
				"_v": JSONValue(con.dateTime.toISOExtString())
			]);
		case Array: {
			JSONValue[] arr;
			foreach( TDataNode node; con.array ) {
				arr ~= toStdJSON(node);
			}
			return JSONValue(arr);
		}
		case AssocArray: {
			JSONValue[string] arr;
			foreach( string key, TDataNode node; con.assocArray ) {
				arr[key] ~= toStdJSON(node);
			}
			return JSONValue(arr);
		}
		case CodeObject: {
			JSONValue jCode = [
				"_t": JSONValue(con.type),
				"name": JSONValue(con.codeObject.name),
				"moduleObj": JSONValue(con.codeObject._moduleObj._name),
			];
			JSONValue[] jInstrs;
			foreach( instr; con.codeObject._instrs ) {
				jInstrs ~= JSONValue([ JSONValue(instr.opcode), JSONValue(instr.arg) ]);
			}
			jCode["instrs"] = jInstrs;
			JSONValue[] jAttrBlocks;
			import ivy.directive_stuff: DirAttrKind;
			foreach( ref attrBlock; con.codeObject._attrBlocks )
			{
				JSONValue jBlock = ["kind": attrBlock.kind];
				final switch( attrBlock.kind )
				{
					case DirAttrKind.NamedAttr:
					{
						JSONValue[string] block;
						foreach( key, va; attrBlock.namedAttrs ) {
							block[key] = _valueAttrToStdJSON(va);
						}
						jBlock["namedAttrs"] = block;
						break;
					}
					case DirAttrKind.ExprAttr:
					{
						JSONValue[] block;
						foreach( va; attrBlock.exprAttrs ) {
							block ~= _valueAttrToStdJSON(va);
						}
						jBlock["exprAttrs"] = block;
						break;
					}
					case DirAttrKind.IdentAttr:
					{
						jBlock["names"] = attrBlock.names;
						break;
					}
					case DirAttrKind.KwdAttr:
					{
						jBlock["keyword"] = attrBlock.keyword;
						break;
					}
					case DirAttrKind.BodyAttr:
					{
						jBlock["bodyAttr"] = [
							"isNoscope": attrBlock.bodyAttr.isNoscope,
							"isNoescape": attrBlock.bodyAttr.isNoescape
						];
						break;
					}
				}
				jAttrBlocks ~= jBlock;
			}
			jCode["attrBlocks"] = jAttrBlocks;
			return jCode;
		}
		case Callable, ClassNode, ExecutionFrame, DataNodeRange: {
			return JSONValue(["_t": con.type]);
		}
	}
	assert(false);
}

JSONValue _valueAttrToStdJSON(VA)(auto ref VA va) {
	return JSONValue([
		"name": va.name,
		"typeName": va.typeName
	]);
}

ExecutableProgramme compileModule(string mainModuleName, IvyConfig config)
{
	import std.range: empty;
	import std.algorithm: map;
	import std.array: array;

	assert(!config.importPaths.empty, `List of compiler import paths must not be empty!`);
	// Creating object that manages reading source files, parse and store them as AST
	auto moduleRepo = new CompilerModuleRepository(config.importPaths, config.fileExtension, config.parserLoger);

	// Preliminary compiler phase that analyse imported modules and stores neccessary info about directives
	auto symbolsCollector = new CompilerSymbolsCollector(moduleRepo, mainModuleName, config.compilerLoger);
	symbolsCollector.run(); // Run analyse

	auto dirInterps = config.dirInterpreters.dup;
	// Add native directive interpreters to global scope
	dirInterps["int"] = new IntCtorDirInterpreter();
	dirInterps["float"] = new FloatCtorDirInterpreter();
	dirInterps["str"] = new StrCtorDirInterpreter();
	dirInterps["has"] = new HasDirInterpreter();
	dirInterps["typestr"] = new TypeStrDirInterpreter();
	dirInterps["len"] = new LenDirInterpreter();
	dirInterps["empty"] = new EmptyDirInterpreter();
	dirInterps["scope"] = new ScopeDirInterpreter();
	dirInterps["toJSONBase64"] = new ToJSONBase64DirInterpreter();
	dirInterps["dtGet"] = new DateTimeGetDirInterpreter();
	dirInterps["range"] = new RangeDirInterpreter();

	// Main compiler phase that generates bytecode for modules
	auto compiler = new ByteCodeCompiler(moduleRepo, symbolsCollector.getModuleSymbols(), mainModuleName, config.compilerLoger);
	compiler.addDirCompilers(config.dirCompilers);
	compiler.addGlobalSymbols( dirInterps.values.map!(it => it.compilerSymbol).array );
	compiler.run(); // Run compilation itself

	if( config.compilerLoger ) {
		debug config.compilerLoger(LogInfo(
			"compileModule:\r\n" ~ compiler.toPrettyStr(),
			LogInfoType.info,
			__FUNCTION__, __FILE__, __LINE__
		));
	}

	// Creating additional object that stores all neccessary info for simple usage
	auto prog = new ExecutableProgramme(compiler.moduleObjects, mainModuleName, config.interpreterLoger);
	prog.dirInterpreters = dirInterps;

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
				synchronized(_mutex)
				{
					if( moduleName !in _progs ) {
						_progs[moduleName] = compileModule(moduleName, _config);
					}
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
