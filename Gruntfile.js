 module.exports = function (grunt) {
	'use strict';

	// Force use of Unix newlines
	grunt.util.linefeed = '\n';
	var expandTilde = require('expand-tilde');

	grunt.initConfig({
		pkg: grunt.file.readJSON('package.json'),
		deployPath: expandTilde(grunt.option('deployPath') || '~/sites/mkk'),
		symlink: {
			scripts: {
				expand: true,
				src: ['ivy/**/*.js'],
				dest: '<%= deployPath %>/pub/',
				filter: 'isFile',
				overwrite: true
			}
		},
		clean: {
			scripts: {
				options: { force: true },
				files: { src: '<%= deployPath %>/pub/ivy/**/*.js' }
			}
		}
	});

	grunt.loadNpmTasks('grunt-contrib-symlink');
	grunt.loadNpmTasks('grunt-contrib-clean');

	grunt.registerTask('cleanAll', ['clean:scripts'])
	grunt.registerTask('deploy', ['cleanAll', 'symlink:scripts']);
	grunt.registerTask('default', ['deploy']);
	grunt.registerTask('dist', ['deploy']);
}
