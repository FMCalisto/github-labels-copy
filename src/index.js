// Define custom options
var options = {

  // Dry run is a special option that allows us to perform
  // a test run without actually copying the labels.
  dryRun: false
};

// Instantiate with custom options
var copyGitHubLabels = require('copy-github-labels')(options);

// Repository Objects
var src = {
  user: 'FMCalisto',
  repo: 'github-labels-copy'
};
var dst = {
  user: 'MIMBCD-UI',
  repo: 'clinical-annotators-filler'
};

var scp = '/';

// Define source and destination
var srcPath = src.user + scp + src.repo;
var dstPath = dst.user + scp + dst.repo;

// Optionally use credentials
copyGitHubLabels.authenticate({
  type: "oauth",
  token: 'bef99f643ad8614b2c28b0aaa2d93ea626bb61c8'
});

// Copy labels from one repository to another
// The callback is called for every label but no actual
// copy operation is performed, so the destination repository is not updated.
copyGitHubLabels.copy(srcPath, dstPath, function (err, label){

  // Log errors
  if(err){
    return console.log('Could not copy label: ' + JSON.stringify(err));
  }

  // Log copies
  console.log('Label copied successfully: ' + JSON.stringify(label))
});
