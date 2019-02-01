module ivy.interpreter.async_result;

import ivy.interpreter.data_node: IvyData;

enum AsyncResultState: ubyte {
	pending, resolved, rejected
}

class AsyncResult
{
	alias CalbackMethod = void delegate(IvyData data);
	alias ErrbackMethod = void delegate(Throwable error);
	void then(CalbackMethod doneFn, ErrbackMethod failFn = null)
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
				failFn(_error);
			}
		}
	}

	void except(ErrbackMethod failFn)
	{
		if( failFn !is null )
		{
			_errbacks ~= failFn;
			if( _state == AsyncResultState.rejected ) {
				failFn(_error);
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

	void reject(Throwable error)
	{
		if( _state != AsyncResultState.pending )
			return; // Already resolved or rejected

		_state = AsyncResultState.rejected;
		_error = error;

		foreach( fn; _errbacks ) {
			fn(_error);
		}
	}

	AsyncResultState state() @property {
		return _state;
	}
private:
	CalbackMethod[] _callbacks;
	ErrbackMethod[] _errbacks;
	IvyData _value;
	Throwable _error;
	AsyncResultState _state;
}