module ivy.programme;


import ivy.module_object: ModuleObject;
import ivy.compiler.compiler;
import ivy.compiler.symbol_collector;
import ivy.compiler.module_repository;
import ivy.compiler.iface: IDirectiveCompiler;
import ivy.compiler.directive.standard_factory: makeStandardDirCompilerFactory;
import ivy.interpreter.data_node;
import ivy.interpreter.interpreter;
import ivy.interpreter.directive;
import ivy.interpreter.iface: INativeDirectiveInterpreter;
import ivy.interpreter.directive.factory: InterpreterDirectiveFactory;
import ivy.interpreter.module_objects_cache: ModuleObjectsCache;
import ivy.engine: IvyEngine;
import ivy.interpreter.async_result: AsyncResult, AsyncResultState;
import ivy.loger: LogInfo;

import std.typecons: Tuple;

alias SaveStateResult = Tuple!(Interpreter, `interp`, AsyncResult, `asyncResult`);

enum IVY_TYPE_FIELD = "_t";
enum IVY_VALUE_FIELD = "_v";

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
	AsyncResult run(IvyData mainModuleScope = IvyData(), IvyData[string] extraGlobals = null) {
		return runSaveState(mainModuleScope, extraGlobals).asyncResult;
	}

	IvyData runSync(IvyData mainModuleScope = IvyData(), IvyData[string] extraGlobals = null) {
		IvyData ivyRes = runSaveStateSync(mainModuleScope, extraGlobals)._stack.back();
		if( ivyRes.type == IvyDataType.AsyncResult ) {
			ivyRes.asyncResult.then(
				(IvyData methodRes) => ivyRes = methodRes
			);
		}
		return ivyRes;
	}

	SaveStateResult runSaveState(IvyData mainModuleScope = IvyData(), IvyData[string] extraGlobals = null)
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
		return SaveStateResult(interp, interp.execLoop());
	}

	Interpreter runSaveStateSync(IvyData mainModuleScope = IvyData(), IvyData[string] extraGlobals = null)
	{
		import std.exception: enforce;
		SaveStateResult moduleExecRes = runSaveState(mainModuleScope, extraGlobals);
		enforce(
			moduleExecRes.asyncResult.state == AsyncResultState.resolved,
			`Expected module execution async result resolved state`);
		return moduleExecRes.interp;
	}

	AsyncResult runMethod(
		string methodName,
		IvyData methodParams = IvyData(),
		IvyData[string] extraGlobals = null,
		IvyData mainModuleScope = IvyData()
	) {
		AsyncResult fResult = new AsyncResult();
		SaveStateResult moduleExecRes = runSaveState(mainModuleScope, extraGlobals);
		
		moduleExecRes.asyncResult.then(
			(IvyData modRes) {
				// Module executed successfuly, then call method
				moduleExecRes.interp.runModuleDirective(methodName, methodParams).then(fResult);
			},
			&fResult.reject);
		return fResult;
	}

	IvyData runMethodSync(
		string methodName,
		IvyData methodParams = IvyData(),
		IvyData[string] extraGlobals = null,
		IvyData mainModuleScope = IvyData()
	) {
		import std.exception: enforce;
		AsyncResult asyncRes =
			runSaveStateSync(mainModuleScope, extraGlobals)
			.runModuleDirective(methodName, methodParams);
		enforce(
			asyncRes.state == AsyncResultState.resolved,
			`Expected method execution async result resolved state`);
		IvyData ivyRes;
		asyncRes.then((IvyData methodRes) => ivyRes = methodRes);
		return ivyRes;
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
				"fileName": JSONValue(modObj._fileName),
				IVY_TYPE_FIELD: JSONValue(IvyDataType.ModuleObject)
			];
		}
		jProg[`moduleObjects`] = moduleObjects;
		return jProg;
	}
}

import std.json: JSONValue;
JSONValue toStdJSON(IvyData con)
{
	final switch( con.type )
	{
		case IvyDataType.Undef: return JSONValue("undef");
		case IvyDataType.Null: return JSONValue();
		case IvyDataType.Boolean: return JSONValue(con.boolean);
		case IvyDataType.Integer: return JSONValue(con.integer);
		case IvyDataType.Floating: return JSONValue(con.floating);
		case IvyDataType.String: return JSONValue(con.str);
		case IvyDataType.DateTime:
			return JSONValue([
				IVY_TYPE_FIELD: JSONValue(con.type),
				IVY_VALUE_FIELD: JSONValue(con.dateTime.toISOExtString())
			]);
		case IvyDataType.Array: {
			JSONValue[] arr;
			foreach( IvyData node; con.array ) {
				arr ~= toStdJSON(node);
			}
			return JSONValue(arr);
		}
		case IvyDataType.AssocArray: {
			JSONValue[string] arr;
			foreach( string key, IvyData node; con.assocArray ) {
				arr[key] ~= toStdJSON(node);
			}
			return JSONValue(arr);
		}
		case IvyDataType.CodeObject: {
			JSONValue jCode = [
				IVY_TYPE_FIELD: JSONValue(con.type),
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
		case IvyDataType.Callable:
		case IvyDataType.ClassNode:
		case IvyDataType.ExecutionFrame:
		case IvyDataType.DataNodeRange:
		case IvyDataType.AsyncResult:
		case IvyDataType.ModuleObject: {
			return JSONValue([IVY_TYPE_FIELD: con.type]);
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


