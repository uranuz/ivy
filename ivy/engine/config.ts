import {InterpreterDirectiveFactory} from 'ivy/interpreter/directive/factory';

export class IvyEngineConfig {
	directiveFactory: InterpreterDirectiveFactory = null;
	clearCache: boolean = false;
	endpoint: string = null;
	deserializer: any = null;
}