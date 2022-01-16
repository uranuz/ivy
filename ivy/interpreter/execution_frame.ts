import {IvyException} from 'ivy/exception';
import {Location} from 'ivy/location';
import {ensure} from 'ivy/utils';
import {Instruction} from 'ivy/bytecode';
import {ExecFrameInfo} from 'ivy/interpreter/exec_frame_info';
import { CallableObject } from 'ivy/types/callable_object';
import { IvyData, IvyDataDict } from 'ivy/types/data/data';

var assure = ensure.bind(null, IvyException);

export class ExecutionFrame{
	private _callable: CallableObject;
	private _instrIndex: number;
	private _dataDict: IvyDataDict;

	constructor(callable: CallableObject, dataDict?: IvyDataDict) {
		assure(callable, "Expected callable object for exec frame");
	
		this._callable = callable;
		this._instrIndex = 0;
		this._dataDict = dataDict || {};
	
		this._dataDict["_ivyMethod"] = this._callable.symbol.name;
		this._dataDict["_ivyModule"] = this._callable.moduleSymbol.name;
	}

	hasValue(varName: string): boolean {
		return this._dataDict.hasOwnProperty(varName);
	}

	getValue(varName: string): IvyData {
		assure(
			this.hasValue(varName),
			"Cannot find variable with name \"", varName, "\" in exec frame for symbol \"", this.callable.symbol.name, "\"");
		return this._dataDict[varName];
	}

	setValue(varName: string, value: IvyData) {
		this._dataDict[varName] = value;
	}

	setJump(instrIndex: number): void {
		if( this.callable.isNative )
			return; // Cannot set jump for native directive
		assure(
			instrIndex <= this.callable.codeObject.instrs.length,
			"Cannot jump after the end of code object");
		this._instrIndex = instrIndex;
	}

	nextInstr(): void {
		++this._instrIndex;
	}

	get callable(): CallableObject {
		return this._callable;
	}

	get hasInstrs(): boolean {
		if( this.callable.isNative )
			return false; 
		return this._instrIndex < this.callable.codeObject.instrCount;
	}

	get currentInstr(): Instruction {
		if( !this.hasInstrs )
			return new Instruction(); // Cannot get instruction for native directive
		return this.callable.codeObject.instrs[this._instrIndex];
	}

	get dict(): IvyDataDict {
		return this._dataDict;
	}

	get currentInstrLine(): number {
		return 0;
	}

	get currentLocation(): Location {
		var loc = new Location();

		loc.fileName = this.callable.moduleSymbol.name;
		loc.lineIndex = this.currentInstrLine;

		return loc;
	}

	get info(): ExecFrameInfo {
		var info = new ExecFrameInfo();

		info.callableName = this.callable.symbol.name;
		info.location = this.currentLocation;
		info.instrIndex = this._instrIndex;
		info.opcode = this.currentInstr.opcode;

		return info;
	}

	toString() {
		return "<Exec frame for dir object \"" + this.callable.symbol.name + "\">";
	}
}