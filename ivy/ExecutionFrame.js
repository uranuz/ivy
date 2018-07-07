define('ivy/ExecutionFrame', [], function() {
	function ExecutionFrame(callableObj, modFrame, dataDict, isNoscope) {
		this._callableObj = callableObj;
		this._moduleFrame = modFrame;
		this._dataDict = dataDict || {};
		this._isNoscope = isNoscope || false;
	};
	return __mixinProto(ExecutionFrame, {
		
	});
});