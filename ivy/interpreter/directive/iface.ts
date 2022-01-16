import { Interpreter } from "ivy/interpreter/interpreter";
import { ICallableSymbol } from "ivy/types/symbol/iface/callable";

export interface IDirectiveInterpreter {
	interpret(interp: Interpreter): void;

	get symbol(): ICallableSymbol;
	get moduleSymbol(): ICallableSymbol;
}