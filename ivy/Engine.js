define('ivy/Engine', [
	'ivy/RemoteModuleLoader',
	'ivy/DirectiveFactory',
	'ivy/Programme'
], function(
	RemoteModuleLoader,
	DirectiveFactory,
	ExecutableProgramme
) {
	function Engine(ivyConfig, codeLoader) {
		this._config = ivyConfig;

		// Instance of class that is used to load compiled programme
		// For now we use loader that loads code from remote Ivy service, but it could be JS-compiler as well
		this._codeLoader = codeLoader;

		if( this._codeLoader == null ) {
			throw new Error('Code loader is required!');
		}
		
		this._initObjects();
	};
	return __mixinProto(Engine, {
		_initObjects: function() {
			if( this._config.directiveFactory == null ) {
				this._config.directiveFactory = DirectiveFactory.makeStandardInterpreterDirFactory();
			}
		},

		/// Generate programme object or get existing from cache (if cache enabled)
		getByModuleName: function(moduleName, callback) {
			if( typeof(moduleName) !== 'string' ) {
				throw new Error('Module name is required!');
			}

			if( typeof(callback) !== 'function' ) {
				throw new Error('Callback function is required!')
			}

			if( this._config.clearCache ) {
				this.clearCache();
			}

			if( this._codeLoader.get(moduleName) == null ) {
				this._codeLoader.load(moduleName, function() {
					callback(this._makeProgramme(moduleName));
				}.bind(this));
			} else {
				callback(this._makeProgramme(moduleName));
			}
		},

		_makeProgramme: function(moduleName) {
			return new ExecutableProgramme(
				this._codeLoader,
				this._config.directiveFactory,
				moduleName
			);
		},

		clearCache: function() {
			this._codeLoader.clearCache();
		}
	});
});