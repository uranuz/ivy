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
			if( _state == AsyncResultState.resolved ) {
				doneFn(_value);
			} else {
				_callbacks ~= doneFn;
			}
		}

		if( failFn !is null )
		{
			if( _state == AsyncResultState.rejected ) {
				failFn(_error);
			} else {
				_errbacks ~= failFn;
			}
		}
	}

	void then(AsyncResult other)
	{
		if (other !is null) {
			then(&other.resolve, &other.reject);
		}
	}

	void except(ErrbackMethod failFn) {
		this.then(null, failFn);
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

		_callbacks.length = 0;
	}

	void reject(Throwable error)
	{
		if( error is null )
			return; // No error - no problemmes

		if( _state != AsyncResultState.pending )
			return; // Already resolved or rejected

		_state = AsyncResultState.rejected;
		_error = error;

		foreach( fn; _errbacks ) {
			fn(_error);
		}

		_errbacks.length = 0;
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