import {ModuleSymbol} from 'ivy/types/symbol/module_';
import {GLOBAL_SYMBOL_NAME} from 'ivy/types/symbol/consts';
import {Location} from 'ivy/location';

export const globalSymbol = new ModuleSymbol(GLOBAL_SYMBOL_NAME, new Location(GLOBAL_SYMBOL_NAME));