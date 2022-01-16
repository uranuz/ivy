export class Location {
	public fileName: string;
	public index: number;
	public length: number;
	public lineIndex: number = null;

	constructor(fileName?: string, index?: number, length?: number) {
		this.fileName = fileName || null;
		this.index = index || 0;
		this.length = length || 0;
		this.lineIndex = 0
	}

	toString() {
		return this.fileName + ' [' + this.index + ' .. ' + (this.index + this.length) + ']';
	}
};