define('ivy/location', [], function() {
return FirClass(
	function Location(fileName, index, length) {
		var inst = firPODCtor(this, Location, arguments);
		if( inst ) return inst;

		this.fileName = fileName || null;
		this.index = index || null;
		this.length = length || null;
	}, {
		toString: function() {
			return this.fileName + ' [' + this.index + ' .. ' + (index + length) + ']';
		}
	}
);
});