define('ivy/log/info', [], function() {
return FirClass(
	function LogInfo(
		msg,
		type,
		sourceFuncName,
		sourceFileName,
		sourceLine,
		processedFile,
		processedLine,
		processedText
	) {
		var inst = firPODCtor(this, arguments);
		if( inst ) return inst;

		this.msg = msg;
		this.type = type;
		this.sourceFuncName = sourceFuncName;
		this.sourceFileName = sourceFileName;
		this.sourceLine = sourceLine;
		this.processedFile = processedFile;
		this.processedLine = processedLine;
		this.processedText = processedText;
	});
});