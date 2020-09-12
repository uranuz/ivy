define('ivy/engine_config', [
], function(EngineConfig) {
return FirClass(
	function EngineConfig() {
		this.directiveFactory = null;
		this.clearCache = false;
	});
});