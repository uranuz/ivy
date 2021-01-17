define('ivy/interpreter/execution_frame', [
	'ivy/exception'
], function(
	IvyException
) {
return FirClass(
function ExecutionFrame(callable, dataDict) {
	dataDict = dataDict || {};
	this._callable = callable;
	if( this._callable == null ) {
		throw new IvyException("Expected callable object for exec frame");
	}

	this._dataDict = dataDict;
	this._dataDict["_ivyMethod"] = this._callable.symbol.name;
	this._dataDict["_ivyModule"] = this._callable.moduleSymbol.name;
}, {
	hasValue: function(varName) {
		return this._dataDict.hasOwnProperty(varName);
	},

	getValue: function(varName) {
		if( !this.hasValue(varName) ) {
			throw new IvyException("Cannot find variable with name: \"" + varName + "\" for symbol \"" + this.callable.symbol.name + "\"");
		}
		return this._dataDict[varName];
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