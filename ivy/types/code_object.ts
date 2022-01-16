import { Instruction } from "ivy/bytecode";
import { ModuleObject } from "ivy/types/module_object";
import { ICallableSymbol } from "ivy/types/symbol/iface/callable";

export class CodeObject {
	private _symbol: ICallableSymbol;
	private _moduleObject: ModuleObject;
	private _instrs: Instruction[];

	constructor(symbol: ICallableSymbol, moduleObject: ModuleObject) {
		this._symbol = symbol;
		this._moduleObject = moduleObject;
		this._instrs = [];
	}

	get symbol(): ICallableSymbol {
		return this._symbol;
	}

	get moduleObject(): ModuleObject {
		return this._moduleObject;
	}

	get instrs(): Instruction[] {
		return this._instrs;
	}

	addInstr(instr: Instruction) {
		var index = this._instrs.length;
		this._instrs.push(instr);
		return index;
	}

	get instrCount(): number {
		return this._instrs.length;
	}
}