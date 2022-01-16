import { ModuleObject } from "ivy/types/module_object";

export class ModuleObjectCache {
	private _moduleObjects: { [k: string]: ModuleObject } = {};

	get(moduleName: string): ModuleObject {
		return this._moduleObjects[moduleName];
	}

	add(moduleObject: ModuleObject): void {
		this._moduleObjects[moduleObject.symbol.name] = moduleObject;
	}

	clearCache() {
		for(var key of Object.keys(this._moduleObjects)) {
			delete this._moduleObjects[key];
		}
	}

	get moduleObjects(): object {
		return this._moduleObjects
	}
}