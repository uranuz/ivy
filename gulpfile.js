'use strict';

var
	path = require('path'),
	tfConfig = require('../trifle/builder/config'),
	tfBuilder = require('../trifle/builder/builder');

function makeConfig() {
	var config = tfConfig.resolveConfig();
	// Set paths to clean before run build
	config.cleanPaths = [
		path.join(config.buildPath, 'ivy/'),
		path.join(config.buildAuxPath, 'ivy/'),
		path.join(config.outPub, 'ivy/')
	];

	config.symlinkBuildPaths = [
		path.join(__dirname, 'ivy')
	];

	// Set webpack libraries we want to build
	config.webpack.entries = {
		ivy: path.join(config.buildPath, 'ivy/**/*.{ts,js}')
	};

	return config;
}

Object.assign(exports, {
	default: tfBuilder.makeTasks(makeConfig())
});