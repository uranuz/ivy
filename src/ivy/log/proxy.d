module ivy.log.proxy;

import ivy.log.info: LogInfo;

alias LogerMethod = void delegate(ref LogInfo);

struct IvyLogProxy
{
	import ivy.log.consts: LogInfoType;

	/// This method need to be implemented to actualy send log message
	LogerMethod _logerMethod;

	this(LogerMethod logerMethod) {
		this._logerMethod = logerMethod;
	}

	void write(A...)(
		LogInfoType logInfoType,
		lazy A args,
		string file = __FILE__,
		size_t line = __LINE__,
		string func = __FUNCTION__
	) {
		import trifle.utils: aformat;

		if( this._logerMethod is null )
			return;
		LogInfo logInfo;
		logInfo.type = logInfoType;
		logInfo.msg = aformat(args);
		logInfo.sourceFileName = file;
		logInfo.sourceLine = line;
		logInfo.sourceFuncName = func;
		this._logerMethod(logInfo);
	}

	/// Writes regular log message
	void info(A...)(
		lazy A args,
		string file = __FILE__,
		size_t line = __LINE__,
		string func = __FUNCTION__
	) {
		this.write(LogInfoType.info, args, file, line, func);
	}

	/// Writes warning message
	void warn(A...)(
		lazy A args,
		string file = __FILE__,
		size_t line = __LINE__,
		string func = __FUNCTION__
	) {
		this.write(LogInfoType.warn, args, file, line, func);
	}

	/// Writes error
	void error(A...)(
		lazy A args,
		string file = __FILE__,
		size_t line = __LINE__,
		string func = __FUNCTION__
	) {
		this.write(LogInfoType.error, args, file, line, func);
	}

	/// Writes internal error
	void internalError(A...)(
		lazy A args,
		string file = __FILE__,
		size_t line = __LINE__,
		string func = __FUNCTION__
	) {
		this.write(LogInfoType.internalError, args, file, line, func);
	}
}
