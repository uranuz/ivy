module ivy.log.proxy;

mixin template LogProxyImpl(ExceptionType, bool isDebugMode = false)
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

		return this.sendLogInfo(logInfoType, logMessage[]); /// This method need to be implemented to actualy send log message
	}

	/// Writes regular log message for debug
	void write(T...)(lazy T data) {
		static if(isDebugMode) {
			this.genericWrite(LogInfoType.info, data);
		}
	}

	/// Writes warning message
	void warn(T...)(lazy T data) {
		this.genericWrite(LogInfoType.warn, data);
	}

	/// Writes regular error to log and throws ExceptionType
	void error(T...)(lazy T data) {
		this.enforce(false, data);
	}

	/// Tests assertion. If it's false then writes regular error to log and throws ExceptionType
	void enforce(C, T...)(C cond, lazy T data) {
		enf(cond, this.genericWrite(LogInfoType.error, data));
	}

	/// Writes internal error to log and throws ExceptionType
	void internalError(T...)(lazy T data) {
		this.internalAssert(false, data);
	}

	/// Tests assertion. If it's false then writes internal error to log and throws ExceptionType
	void internalAssert(C, T...)(C cond, lazy T data) {
		enf(cond, this.genericWrite(LogInfoType.internalError, data));
	}
}
