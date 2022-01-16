import {OpCode} from 'ivy/bytecode';
import {Location} from 'ivy/location';

export class ExecFrameInfo{
	public callableName: string;
	public location: Location;
	public instrIndex: number;
	public opcode: OpCode;

	constructor() {
		this.callableName = null;
		this.location = new Location();
		this.instrIndex = 0;
		this.opcode = OpCode.InvalidCode;
	}

	toString() {
		return "Module: " + this.location.fileName + ":" + this.instrIndex + ", callable: " + this.callableName + ", opcode: " + this.opcode;
	}
}