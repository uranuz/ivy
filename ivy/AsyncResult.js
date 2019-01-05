define('ivy/AsyncResult', ['ivy/Consts'], function(Consts) {
	function AsyncResult() {
		this._deferred = new $.Deferred();
	};
	return __mixinProto(AsyncResult, {
		then: function(doneFn, failFn) {
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
			this._deferred.resolve(value);
		},
		reject: function(reason) {
			this._deferred.reject(reason);
		}
	});
});