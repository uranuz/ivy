import {AsyncResult} from 'ivy/types/data/async_result';
import {ModuleObjectCache} from 'ivy/engine/module_object_cache';
import { IvyEngineConfig } from 'ivy/engine/config';

declare var jQuery: any;

export class ModuleObjectLoader {
	private _endpoint: string;
	private _cache: ModuleObjectCache;
	private _deserializer: any;

	constructor(config: IvyEngineConfig) {
		if( !config.endpoint ) {
			throw new Error('Endpoint URL required to load compiled templates!');
		}
		if( !config.deserializer ) {
			throw new Error('Required link to "fir/datctrl/ivy/Deserializer" in ivy config');
		}
		this._endpoint = config.endpoint;
		this._cache = new ModuleObjectCache();
		this._deserializer = config.deserializer;
	}

	load(moduleName: string): AsyncResult {
		var fResult = new AsyncResult();
		if (this.cache.get(moduleName)) {
			fResult.resolve(this.cache.get(moduleName));
			return fResult;
		}

		jQuery.ajax(this._endpoint + '?moduleName=' + moduleName + '&appTemplate=no', {
			success: function(json: any) {
				this._parseModules(json.result);
				fResult.resolve(this.cache.get(moduleName));
			}.bind(this),
			error: fResult.reject.bind(fResult)
		});
		return fResult;
	}

	get cache(): ModuleObjectCache {
		return this._cache;
	}

	clearCache(): void {
		this.cache.clearCache();
	}

	_parseModules(json: any): void {
		json.moduleObjects.forEach(this._parseModule.bind(this));
	}

	_parseModule(rawModule: any): void {
		var moduleName = this._deserializer.getRawModuleName(rawModule);
		if( this.cache.get(moduleName) ) {
			// Module is loaded already. No need to spend more time for deserialization
			return;
		}
		this.cache.add(this._deserializer.deserialize(rawModule));
	}
}