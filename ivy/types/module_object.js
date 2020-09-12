define('ivy/types/module_object', [], function() {
return FirClass(
	function ModuleObject(name, consts, entryPointIndex) {
		if( entryPointIndex >= consts.length ) {
			throw Error('Index of module object main code object is out of range!');
		}
		this._name = name;
		this._consts = consts;
		this._entryPointIndex = entryPointIndex;
	}, {
		mainCodeObject: function() {
			return this._consts[this._entryPointIndex];
		},
		getConst: function(index) {
			if( index >= this._consts.length ) {
				throw Error('There is no module const with specified index!');
			}
			return this._consts[index];
		}
	});
});