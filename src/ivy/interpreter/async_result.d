module ivy.interpreter.async_result;

import ivy.interpreter.data_node: IvyData;

enum AsyncResultState: ubyte {
	pending, resolved, rejected
}

class AsyncResult
{
	alias HandlerMethod = void delegate(IvyData data);
	void then(HandlerMethod doneFn, HandlerMethod failFn = null)
	{
		if( doneFn !is null )
		{
			_callbacks ~= doneFn;
			if( _state == AsyncResultState.resolved ) {
				doneFn(_value);
			}
		}

		if( failFn !is null )
		{
			_errbacks ~= failFn;
			if( _state == AsyncResultState.rejected ) {
				failFn(_value);
			}
		}
	}

	void except(HandlerMethod failFn)
	{
		if( failFn !is null )
		{
			_errbacks ~= failFn;
			if( _state == AsyncResultState.rejected ) {
				failFn(_value);
			}
		}
	}

	void resolve(IvyData value)
	{
		if( _state != AsyncResultState.pending )
			return; // Already resolved or rejected

		_state = AsyncResultState.resolved;
		_value = value;

		foreach( fn; _callbacks ) {
			fn(_value);
		}
	}

	void reject(IvyData value)
	{
		if( _state != AsyncResultState.pending )
			return; // Already resolved or rejected

		_state = AsyncResultState.rejected;
		_value = value;

		foreach( fn; _errbacks ) {
			fn(_value);
		}
	}

	AsyncResultState state() @property {
		return _state;
	}
private:
	HandlerMethod[] _callbacks;
	HandlerMethod[] _errbacks;
	IvyData _value;
	AsyncResultState _state;
}