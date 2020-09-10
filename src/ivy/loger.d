module ivy.loger;

enum LogInfoType
{
	info, // Regular log message for debug or smth
	warn, // Warning about strange conditions
	error, // Regular error, caused by wrong template syntax, wrong user input or smth
	internalError // Error that caused by wrong Ivy implementation or smth that should never happens
}

// Struct consolidating info for logging
struct LogInfo
{
	string msg; // Log message
	LogInfoType type; // Kind of log event
	string sourceFuncName; // D function name where log event happens
	string sourceFileName; // D source file name where log event happens
	size_t sourceLine; // D code source line where log event happens
	string processedFile; // Path or name to processed file
	size_t processedLine; // Line number of processed file where log event happens
	string processedText; // Short fragment of processed text where log event happens
}

string getShortFuncName(string func)
{
	import std.algorithm: splitter;
	import std.range: retro, take;
	import std.array: array, join;

	return func.splitter('.').retro.take(2).array.retro.join(".");
}

mixin template LogerProxyImpl(ExceptionType, bool isDebugMode = false)
{
	import std.exception: enforce;

	string func;
	string file;
	int line;

	private alias enf = enforce!ExceptionType;

	string genericWrite(T...)(LogInfoType logInfoType, lazy T data)
	{
		import std.format: formattedWrite;
		import std.array: appender;
		auto logMessage = appender!string();
		foreach(item; data) {
			formattedWrite(logMessage, "%s", item);
		}

		return this.sendLogInfo(logInfoType, logMessage.data); /// This method need to be implemented to actualy send log message
	}

	/// Writes regular log message for debug
	void write(T...)(lazy T data) {
		static if(isDebugMode) {
			genericWrite(LogInfoType.info, data);
		}
	}

	/// Writes warning message
	void warn(T...)(lazy T data) {
		genericWrite(LogInfoType.warn, data);
	}

	/// Writes regular error to log and throws ExceptionType
	void error(T...)(lazy T data) {
		this.enforce(false, data);
	}

	/// Tests assertion. If it's false then writes regular error to log and throws ExceptionType
	void enforce(C, T...)(C cond, lazy T data) {
		enf(cond, genericWrite(LogInfoType.error, data));
	}



	/// Writes internal error to log and throws ExceptionType
	void internalError(T...)(lazy T data) {
		internalAssert(false, data);
	}

	/// Tests assertion. If it's false then writes internal error to log and throws ExceptionType
	void internalAssert(C, T...)(C cond, lazy T data) {
		enf(cond, genericWrite(LogInfoType.internalError, data));
	}
}
