module ivy.programme;

import ivy.common;
import ivy.code_object: ModuleObject;
import ivy.compiler.compiler;
import ivy.compiler.symbol_collector;
import ivy.compiler.module_repository;
import ivy.compiler.iface: IDirectiveCompiler;
import ivy.compiler.directive.factory: makeStandartDirCompilerFactory;
import ivy.interpreter.data_node;
import ivy.interpreter.interpreter;
import ivy.interpreter.directives;
import ivy.interpreter.iface: INativeDirectiveInterpreter;
import ivy.interpreter.directive_factory: InterpreterDirectiveFactory;
import ivy.interpreter.module_objects_cache: ModuleObjectsCache;
import ivy.engine: IvyEngine;

// Representation of programme ready for execution
class ExecutableProgramme
{
	alias LogerMethod = void delegate(LogInfo);
private:
	ModuleObjectsCache _moduleObjCache;
	InterpreterDirectiveFactory _directiveFactory;
	string _mainModuleName;
	LogerMethod _logerMethod;

public:
	this(
		ModuleObjectsCache moduleObjCache,
		InterpreterDirectiveFactory directiveFactory,
		string mainModuleName,
		LogerMethod logerMethod = null
	) {
		assert(moduleObjCache, `Expected module objects cache`);
		assert(directiveFactory, `Expected directive factory`);
		assert(mainModuleName.length, `Expected programme main module name`);

		_moduleObjCache = moduleObjCache;
		_directiveFactory = directiveFactory;
		_mainModuleName = mainModuleName;
		_logerMethod = logerMethod;
	}

	/// Run programme main module with arguments passed as mainModuleScope parameter
	IvyData run(IvyData mainModuleScope = IvyData(), IvyData[string] extraGlobals = null) {
		return runSaveState(mainModuleScope, extraGlobals)._stack.back();
	}

	Interpreter runSaveState(IvyData mainModuleScope = IvyData(), IvyData[string] extraGlobals = null)
	{
		import ivy.interpreter.interpreter: Interpreter;
		Interpreter interp = new Interpreter(
			_moduleObjCache,
			_directiveFactory,
			_mainModuleName,
			mainModuleScope,
			_logerMethod
		);
		interp.addExtraGlobals(extraGlobals);
		interp.execLoop();
		return interp;
	}

	void logerMethod(LogerMethod method) @property {
		_logerMethod = method;
	}

	import std.json: JSONValue;
	JSONValue toStdJSON()
	{
		JSONValue jProg = ["mainModuleName": _mainModuleName];
		JSONValue[string] moduleObjects;
		foreach( string modName, ModuleObject modObj; _moduleObjCache.moduleObjects )
		{
			JSONValue[] jConsts;
			foreach( ref IvyData con; modObj._consts ) {
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
JSONValue toStdJSON(IvyData con)
{
	final switch( con.type ) with(IvyDataType)
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
			foreach( IvyData node; con.array ) {
				arr ~= toStdJSON(node);
			}
			return JSONValue(arr);
		}
		case AssocArray: {
			JSONValue[string] arr;
			foreach( string key, IvyData node; con.assocArray ) {
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

/++
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
+/

