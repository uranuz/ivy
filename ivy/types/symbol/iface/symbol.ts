import { SymbolKind } from "ivy/types/symbol/consts";
import { Location } from "ivy/location";

export interface IIvySymbol {
	get name(): string;

	get location(): Location;

	get kind(): SymbolKind;
}