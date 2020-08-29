module ivy.interpreter.execution_frame;

import ivy.exception: IvyException;

class IvyExecutionFrameException: IvyException
{
public:
	@nogc @safe this(string msg, string file = __FILE__, size_t line = __LINE__, Throwable next = null) pure nothrow
	{
		super(msg, file, line, next);
	}
}

class ExecutionFrame
{
	import ivy.loger: LogInfo, LogerProxyImpl, LogInfoType;
	import ivy.types.data: IvyData, IvyDataType;
	import ivy.types.callable_object: CallableObject;

	import std.exception: enforce;

	alias LogerMethod = void delegate(LogInfo);
private:
	CallableObject _callable;

	ExecutionFrame _moduleFrame;

	/*
		Type of _dataDict should be Undef or Null if directive call or something that represented
		by this ExecutionFrame haven't it's own data scope and uses parent scope for data.
		In other cases _dataDict should be of AssocArray type for storing local variables
	*/
	IvyData _dataDict;

	// Loger method for used to send error and debug messages
	LogerMethod _logerMethod;

public:
	this(
		CallableObject callable,
		ExecutionFrame modFrame,
		LogerMethod logerMethod
	) {
		this._callable = callable;
		this._moduleFrame = modFrame;

		enforce(this._callable !is null, `Expected callable object for exec frame`);
		enforce(this._moduleFrame !is null, `Expected module frame for exec frame`);

		this._dataDict = [
			"_ivyMethod": this._callable.symbol.name,
			"_ivyModule": (callable.isNative? null: this._callable.codeObject.moduleObject.symbol.name)
		];

		this._logerMethod = logerMethod;
	}

	version(IvyInterpreterDebug)
		enum isDebugMode = true;
	else
		enum isDebugMode = false;

	static struct LogerProxy {
		mixin LogerProxyImpl!(IvyExecutionFrameException, isDebugMode);
		ExecutionFrame frame;

		string sendLogInfo(LogInfoType logInfoType, string msg)
		{
			import ivy.loger: getShortFuncName;

			if( frame._logerMethod !is null ) {
				frame._logerMethod(LogInfo(msg, logInfoType, getShortFuncName(func), file, line));
			}
			return msg;
		}
	}

	LogerProxy log(string func = __FUNCTION__, string file = __FILE__, int line = __LINE__)	{
		return LogerProxy(func, file, line, this);
	}

	IvyData* findValue(string varName)
	{
		log.write(`Searching for local variable with name: `, varName);

		return varName in this._dataDict;
	}

	IvyData* findGlobalValue(string varName)
	{
		log.write(`Searching for variable with name: `, varName);

		IvyData* res = this.findValue(varName);
		if( res !is null ) {
			return res;
		}

		if( this._moduleFrame is null ) {
			return null;
		}
		log.write(`Searching for variable in module frame: `, varName);
		return _moduleFrame.findGlobalValue(varName);
	}

	IvyData getValue(string varName)
	{
		IvyData* res = this.findValue(varName);
		if( res is null ) {
			log.error("Cannot find variable with name: " ~ varName );
		}
		return *res;
	}

	void setValue(string varName, IvyData value)
	{
		IvyData* res = this.findValue(varName);
		if( res is null ) {
			log.write(`Set new variable with name: `, varName, ` with value: `, value);
			this._dataDict[varName] = value;
		} else {
			log.write(`Change existing variable with name: `, varName, ` with new value: `, value);
			(*res) = value;
		}
	}

	void setGlobalValue(string varName, IvyData value)
	{
		IvyData* res = this.findGlobalValue(varName);
		if( res is null ) {
			log.write(`Set new variable with name: `, varName, ` with value: `, value);
			this._dataDict[varName] = value;
		} else {
			log.write(`Change existing variable with name: `, varName, ` with new value: `, value);
			(*res) = value;
		}
	}

	bool hasOwnScope() @property {
		return !this._callable.symbol.bodyAttrs.isNoscope;
	}

	CallableObject callable() @property {
		return this._callable;
	}

	override string toString()
	{
		return `<Exec frame for dir object "` ~ this._callable.symbol.name ~ `">`;
	}

}