define('ivy/types/callable_object', [
	'ivy/types/code_object',
	'ivy/utils',
	'ivy/exception'
], function(
	CodeObject,
	iutil,
	IvyException
) {
var assure = iutil.ensure.bind(iutil, IvyException);

var CallableObject = FirClass(
	function CallableObject(someCallable, defaultsOrContext) {
		if(someCallable instanceof CodeObject) {
			this._codeObject = someCallable;
			this._defaults = defaultsOrContext || {};
			this._context = void(0);
		} else if(someCallable instanceof CallableObject) {
			if( someCallable.isNative ) {
				this._dirInterp = someCallable.dirInterp;
			} else {
				this._codeObject = someCallable.codeObject;
			}
			this._defaults = someCallable.defaults;
			this._context = defaultsOrContext;
		} else {
			this._dirInterp = someCallable;
			this._defaults = {};
			this._context = void(0);
		}
	}, {
		isNative: firProperty(function() {
			return !!this._dirInterp;
		}),

		dirInterp: firProperty(function() {
			assure(this._dirInterp, "Callable is not a native dir interpreter");
			return this._dirInterp;
		}),

		codeObject: firProperty(function() {
			assure(this._codeObject, "Callable is not an ivy code object");
			return this._codeObject;
		}),

		symbol: firProperty(function() {
			if( this.isNative ) {
				return this._dirInterp.symbol;
			}
			return this._codeObject.symbol;
		}),

		moduleSymbol: firProperty(function() {
			if( this.isNative ) {
				return this.dirInterp.moduleSymbol;
			}
			return this.codeObject.moduleObject.symbol;
		}),

		defaults: firProperty(function() {
			return this._defaults;
		}, function(val) {
			this._defaults = val
		}),

		context: firProperty(function() {
			return this._context;
		})
	});
return CallableObject;
});