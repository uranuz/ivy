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

public IvyData _dataDict;

public:
	this(CallableObject callable)
	{
		this._callable = callable;
		enf(this._callable !is null, "Expected callable object for exec frame");

		this._dataDict = [
			"_ivyMethod": this._callable.symbol.name,
			"_ivyModule": this._callable.moduleSymbol.name
		];
	}

	bool hasValue(string varName) {
		return (varName in this._dataDict) !is null;
	}

	IvyData getValue(string varName)
	{
		IvyData* res = varName in this._dataDict;
		enf(res !is null, "Cannot find variable with name \"" ~ varName ~ "\" in exec frame for symbol \"" ~ this.callable.symbol.name ~ "\"");
		return *res;
	}

	void setValue(string varName, IvyData value) {
		this._dataDict[varName] = value;
	}

	bool hasOwnScope() @property {
		return !this._callable.symbol.bodyAttrs.isNoscope;
	}

	CallableObject callable() @property
	{
		enf(this._callable !is null, "No callable for global execution frame");
		return this._callable;
	}

	override string toString() {
		return "<Exec frame for dir object \"" ~ this.callable.symbol.name ~ "\">";
	}

}