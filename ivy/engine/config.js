define('ivy/engine/config', [
], function() {
return FirClass(
	function IvyEngineConfig() {
		this.directiveFactory = null;
		this.clearCache = false;
		this.endpoint = null;
		this.deserializer = null;
	});
});