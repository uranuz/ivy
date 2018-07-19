define('ivy/ProgrammeCache', [], function() {
	function ProgrammeCache(codeLoader) {
		if( !codeLoader ) {
			throw new Error('Code loader instance needed!');
		}
		// Instance of class that is used to load compiled programme
		// For now we use loader that loads code from remote Ivy service, but it could be JS-compiler as well
		this._codeLoader = codeLoader;
		this._progs = {};
	};
	return __mixinProto(ProgrammeCache, {
		// Get Ivy programme ready for execution from cache or using loader
		getIvyModule: function(moduleName, callback) {
			if( typeof(moduleName) !== 'string' ) {
				throw new Error('Module name is required!');
			}
			if( typeof(callback) !== 'function' ) {
				throw new Error('Callback function is required!');
			}
			this._codeLoader.load(moduleName, function(moduleObjects) {
				
			});
		}
	});
});