// Nazty bad js file .. ugh


var COV_DIR = 'coverage';
var COV_DEST = 'coverage-coffee.json';

var path = require('path');
var coffeeCoverage = require('coffee-coverage');
var projectRoot = __dirname;
var coverageVar = coffeeCoverage.findIstanbulVariable();
// Only write a coverage report if we're not running inside of Istanbul.


/* jshint ignore:start */
var writeOnExit = (coverageVar == null) ? (projectRoot + '/' + COV_DIR + '/' + COV_DEST) : null;
/* jshint ignore:end */

// console.warn ("coverageVar:", coverageVar);
// console.warn ("writeOnExit:", writeOnExit);
// console.warn ("pRoot:", projectRoot);

coffeeCoverage.register({
  instrumentor: 'istanbul',
  basePath: projectRoot,
  exclude: ['test', 'node_modules', '.git', 'features', '_*' ,'coverage'],
  coverageVar: coverageVar,
  writeOnExit: writeOnExit,
  initAll: true
});
