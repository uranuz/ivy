'use strict';

var
	devMode = process.env.NODE_ENV !== 'production',
	path = require('path'),
	gulp = require('gulp'),
	webpack = require('webpack'),
	nodeExternals = require('webpack-node-externals'),
	gutil = require("gulp-util"),
	vfs = require('vinyl-fs'),
	glob = require('glob'),
	yargs = require('yargs'),
	argv = yargs.argv,
	config = {};

(function resolveConfig() {
	config.outSite = argv.outSite;
	if( argv.publicPath ) {
		config.publicPath = argv.publicPath;
	} else {
		config.publicPath = '/pub/';
		console.warn('--publicPath is not set, so using default value: ' + config.publicPath);
	}
	
	if( argv.outPub ) {
		config.outPub = argv.outPub
	} else if( config.outSite ) {
		config.outPub = path.resolve(
			config.outSite,
			config.publicPath.replace(/^\//, '') // Trime leading slash
		);
		console.warn('--outPub is not set, so using default value: ' + config.outPub);
	}
})();

function buildLib(config, callback) {
	var manifestsPath = path.join(config.outPub, `manifest/`);
	// run webpack
	webpack({
		context: __dirname,
		mode: (devMode? 'development': 'production'),
		entry: {
			ivy: glob.sync(path.join(__dirname, 'ivy/**/*.js'))
		},
		/*
		externals: [
			nodeExternals(),
			// /^fir\//,
			function(basePath, moduleName, callback) {
				if( /^(fir)\//.test(moduleName) ) {
					return callback(null, 'arguments[2]("./' + moduleName + '.js")');
				}
				callback();
			}
			
		],
		*/
		resolve: {
			modules: [
				__dirname
			],
			extensions: ['.js']
		},
		/*
		optimization: {
			runtimeChunk: {
				name: "manifest",
			}
		},
		*/
		devtool: 'cheap-source-map',
		output: {
			path: config.outPub,
			publicPath: config.publicPath,
			libraryTarget: 'var',
			library: '[name]_lib',
		},
		plugins: [
			new webpack.DllPlugin({
				name: '[name]_lib',
				path: path.join(manifestsPath, '[name].manifest.json')
			}),
		]
	}, function(err, stats) {
		if(err) {
			throw new gutil.PluginError("webpack", err);
		}
		gutil.log("[webpack]", stats.toString({
			// output options
		}));
		callback();
	});
}

gulp.task("ivy-webpack", function(callback) {
	if( !config.outPub ) {
		throw new Error('Need to pass "--outPub" option, containing output directory!');
	}
	buildLib(config, callback);
});


gulp.task("ivy-symlink-js", function() {
	if( !config.outPub ) {
		throw new Error('Need to pass "--outPub" option, containing output directory!');
	}
	return gulp.src(['ivy/**/*.js'], {
			base: './'
		})
		.pipe(vfs.symlink(config.outPub, {
			owerwrite: false // Don't overwrite files generated by webpack
		}));
});

// Create symlinks then overwrite matching files by webpack bundles...
gulp.task("ivy-js", gulp.series(["ivy-webpack", "ivy-symlink-js"]));

gulp.task("ivy", gulp.parallel(["ivy-js"]));


gulp.task("default", gulp.parallel(['ivy']));
