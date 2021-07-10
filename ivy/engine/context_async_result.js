define('ivy/engine/context_async_result', [], function() {
return FirClass(
	function ContextAsyncResult(interp, asyncResult) {
		var inst = firPODCtor(this, arguments);
		if( inst ) return inst;

		this.interp = interp;
		this.asyncResult = asyncResult;
	});
});