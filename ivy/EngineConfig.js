define('ivy/EngineConfig', [
], function(EngineConfig) {
return FirClass(
	function EngineConfig() {
		this.directiveFactory = null;
		this.clearCache = false;
	});
});