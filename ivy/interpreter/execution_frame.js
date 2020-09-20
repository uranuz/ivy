define('ivy/interpreter/execution_frame', [
	'ivy/errors'
], function(
	errors
) {
return FirClass(
function ExecutionFrame(callable) {
	this._callable = callable;
	if( this._callable == null ) {
		throw new errors.IvyError("Expected callable object for exec frame");
	}

	this._dataDict = {
		"_ivyMethod": this._callable.symbol.name,
		"_ivyModule": this._callable.moduleSymbol.name
	};
}, {
	hasValue: function(varName) {
		return this._dataDict.hasOwnProperty(varName);
	},

	getValue: function(varName) {
		if( !this.hasValue(varName) ) {
			throw new errors.IvyError("Cannot find variable with name: \"" + varName + "\" for symbol \"" + callable.symbol.name + "\"");
		}
		return res[varName];
	},

	setValue: function(varName, value) {
		this._dataDict[varName] = value;
	},

	callable: firProperty(function() {
		return this._callable;
	}),

	hasOwnScope: firProperty(function() {
		return !this.callable.symbol.bodyAttrs.isNoscope;
	})
});
});