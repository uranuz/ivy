module ivy.types.data.async_result;

import ivy.types.data: IvyData;
public import ivy.types.data.consts: AsyncResultState;

class AsyncResult
{
	alias CalbackMethod = void delegate(IvyData data);
	alias ErrbackMethod = void delegate(Throwable error);

	void then(CalbackMethod doneFn, ErrbackMethod failFn = null)
	{
		if( doneFn !is null )
			this._callbacks ~= doneFn;
		if( failFn !is null )
			this._errbacks ~= failFn;

		// If already resolved or rejected then notify immediately
		if( this.isResolved )
			this._resolveImpl();
		else if( this.isRejected )
			this._rejectImpl();
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

	void resolve(IvyData value = IvyData())
	{
		if( !this.isPending )
			return; // Already resolved or rejected

		this._state = AsyncResultState.resolved;
		this._value = value;

		this._resolveImpl();
	}

	void reject(Throwable error)
	{
		if( error is null )
			return; // No error - no problemmes

		if( !this.isPending )
			return; // Already resolved or rejected

		this._state = AsyncResultState.rejected;
		this._error = error;

		this._rejectImpl();
	}

	AsyncResultState state() @property {
		return this._state;
	}

	bool isPending() @property {
		return this.state == AsyncResultState.pending;
	}

	bool isResolved() @property {
		return this.state == AsyncResultState.resolved;
	}

	bool isRejected() @property {
		return this.state == AsyncResultState.rejected;
	}

	private void _resolveImpl()
	{
		foreach( fn; this._callbacks )
			fn(this._value);

		// Remove all notified subscribers from list after notification
		this._callbacks.length = 0;
	}

	private void _rejectImpl()
	{
		foreach( fn; this._errbacks )
			fn(this._error);

		// Remove all notified subscribers from list after notification
		this._errbacks.length = 0;
	}

private:
	CalbackMethod[] _callbacks;
	ErrbackMethod[] _errbacks;
	IvyData _value;
	Throwable _error;
	AsyncResultState _state;
}