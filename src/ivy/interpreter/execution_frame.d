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

	alias enf = enforce!IvyExecutionFrameException;

private:
	CallableObject _callable;

	ExecutionFrame _moduleFrame;

	/*
		Type of _dataDict should be Undef or Null if directive call or something that represented
		by this ExecutionFrame haven't it's own data scope and uses parent scope for data.
		In other cases _dataDict should be of AssocArray type for storing local variables
	*/
public IvyData _dataDict;

public:
	this(
		CallableObject callable,
		ExecutionFrame modFrame
	) {
		this._callable = callable;
		this._moduleFrame = modFrame;

		enf(this._callable !is null, `Expected callable object for exec frame`);

		this._dataDict = [
			"_ivyMethod": this._callable.symbol.name,
			"_ivyModule": (callable.isNative? null: this._callable.codeObject.moduleObject.symbol.name)
		];
	}

	/// Global execution frame constructor. Do not use it for any other purpose
	this(bool isGlobal)
	{
		enf(isGlobal, `Expected creation of global frame`);
		this._dataDict = [
			"_ivyMethod": "__global__"
		];
	}

	IvyData* findValue(string varName) {
		return varName in this._dataDict;
	}

	IvyData* findGlobalValue(string varName)
	{
		if( IvyData* res = this.findValue(varName) ) {
			return res;
		}

		if( this._moduleFrame is null ) {
			return null;
		}
		return this._moduleFrame.findGlobalValue(varName);
	}

	IvyData getValue(string varName)
	{
		IvyData* res = this.findValue(varName);
		enf(res !is null, "Cannot find variable with name: " ~ varName);
		return *res;
	}

	void setValue(string varName, IvyData value)
	{
		if( IvyData* res = this.findValue(varName) ) {
			(*res) = value;
		} else {
			this._dataDict[varName] = value;
		}
	}

	void setGlobalValue(string varName, IvyData value)
	{
		if( IvyData* res = this.findGlobalValue(varName) ) {
			(*res) = value;
		} else {
			this._dataDict[varName] = value;
		}
	}

	bool hasOwnScope() @property {
		return !this._callable.symbol.bodyAttrs.isNoscope;
	}

	CallableObject callable() @property
	{
		enf(this._callable !is null, `No callable for global execution frame`);
		return this._callable;
	}

	override string toString() {
		return `<Exec frame for dir object "` ~ this._callable.symbol.name ~ `">`;
	}

}