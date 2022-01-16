export class IvyException extends Error {
	constructor(msg: string) {
		super(msg);
		this.name = arguments.callee['name'];
		this.stack = (new Error()).stack;
	}
}