define('ivy/types/data/async_result', [
	'ivy/types/data/consts'
], function(Consts) {
var mod = FirClass(
	function AsyncResult() {
		this._deferred = new $.Deferred();
		this._state = Consts.AsyncResultState.Init;
	}, {
		then: function(doneFn, failFn) {
			if (doneFn instanceof mod) {
				return this._thenImpl(
					doneFn.resolve.bind(doneFn),
					doneFn.reject.bind(doneFn)
				);
			}
			this._thenImpl(doneFn, failFn);
		},
		_thenImpl: function(doneFn, failFn) {
			if( (doneFn != null) && (typeof doneFn !== 'function') ) {
				throw new Error('doneFn argument expected to be function, undefined or null');
			}
			if( (failFn != null) && (typeof failFn !== 'function') ) {
				throw new Error('failFn argument expected to be function, undefined or null');
			}
			this._deferred.then(doneFn, failFn);
		},
		catch: function(failFn) {
			if( (failFn != null) && (typeof failFn !== 'function') ) {
				throw new Error('failFn argument expected to be function, undefined or null');
			}
			this._deferred.catch(failFn);
		},
		resolve: function(value) {
			this._state = Consts.AsyncResultState.Success;
			this._deferred.resolve(value);
		},
		reject: function(reason) {
			this._state = Consts.AsyncResultState.Error;
			console.warn(reason);
			this._deferred.reject(reason);
		},
		state: firProperty(function() {
			return this._state;
		})
	});
return mod;
});