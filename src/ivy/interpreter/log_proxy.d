module ivy.interpreter.log_proxy;

struct InterpreterLogProxy
{
	import ivy.interpreter.interpreter: Interpreter;
	import ivy.interpreter.exception: IvyInterpretException;
	import ivy.log: LogInfo, LogProxyImpl, LogInfoType;
	import ivy.types.module_object: ModuleObject;

	version(IvyInterpreterDebug)
		enum isDebugMode = true;
	else
		enum isDebugMode = false;

	mixin LogProxyImpl!(IvyInterpretException, isDebugMode);
	Interpreter interp;

	string sendLogInfo(LogInfoType logInfoType, string msg)
	{
		import ivy.log.utils: getShortFuncName;

		import std.algorithm: map, canFind;
		import std.array: join;
		import std.conv: text;
		import std.range: empty;

		string moduleName;
		size_t instrLine;
		if( !interp._frameStack.empty )
		{
			if( ModuleObject modObj = interp.currentModule ) {
				moduleName = modObj.symbol.name;
			}
			instrLine = interp.currentInstrLine();

			// Put name of module and line where event occured
			msg = "Ivy module: " ~ moduleName ~ ":" ~ instrLine.text ~ ", OpCode: " ~ interp.currentOpCode().text ~ " (pk: " ~ interp._pk.text ~ ")" ~  "\n" ~ msg;

			debug {
				if( [LogInfoType.error, LogInfoType.internalError].canFind(logInfoType) )
				{
					// Give additional debug data if error occured
					string dataStack = interp._stack._stack.map!(
						(it) => `<div style="padding: 8px; border-bottom: 1px solid gray;">` ~ it.toHTMLDebugString() ~ `</div>`
					).join("\n");
					string callStack = interp.callStackInfo.map!(
						(it) => `<div style="padding: 8px; border-bottom: 1px solid gray;">` ~ it ~ `</div>`
					).join("\n");
					msg ~= "\n\n<h3 style=\"color: darkgreen;\">Call stack (most recent call last):</h3>\n" ~ callStack 
						~ "\n\n<h3 style=\"color: darkgreen;\">Data stack:</h3>\n" ~ dataStack;
				}
			}
		}

		if( interp._logerMethod !is null ) {
			interp._logerMethod(LogInfo(
				msg,
				logInfoType,
				getShortFuncName(func),
				file,
				line,
				moduleName,
				instrLine
			));
		}
		return msg;
	}
}