export class LogInfo {
	public msg: string;
	public type: any;
	public sourceFuncName: string;
	public sourceFileName: string;
	public sourceLine: number;
	public processedFile: string;
	public processedLine: number;
	public processedText: string;

	constructor(
		msg: string,
		type: any,
		sourceFuncName: string,
		sourceFileName: string,
		sourceLine: number,
		processedFile: string,
		processedLine: number,
		processedText: string
	) {
		this.msg = msg;
		this.type = type;
		this.sourceFuncName = sourceFuncName;
		this.sourceFileName = sourceFileName;
		this.sourceLine = sourceLine;
		this.processedFile = processedFile;
		this.processedLine = processedLine;
		this.processedText = processedText;
	}
}
