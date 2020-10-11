define('ivy/types/callable_object', [
	'ivy/types/code_object',
	'ivy/utils',
	'ivy/exception'
], function(
	CodeObject,
	iutil,
	IvyException
) {
var enforce = iutil.enforce.bind(iutil, IvyException);

return FirClass(
	function CallableObject(codeObjectOrDirInterp, defaults) {
		if( codeObjectOrDirInterp instanceof CodeObject ) {
			this._codeObject = codeObjectOrDirInterp;
			this._dirInterp = null;
		} else {
			this._codeObject = null;
			this._dirInterp = codeObjectOrDirInterp;
		}
		this._defaults = defaults || {};
	}, {
		isNative: firProperty(function() {
			return this._dirInterp != null;
		}),

		dirInterp: firProperty(function() {
			enforce(this._dirInterp != null, "Callable is not a native dir interpreter");
			return this._dirInterp;
		}),

		codeObject: firProperty(function() {
			enforce(this._codeObject != null, "Callable is not an ivy code object");
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
				return this._dirInterp.moduleSymbol;
			}
			return this.codeObject.moduleObject.symbol;
		}),

		defaults: firProperty(function() {
			return this._defaults;
		})
	});
});