const { Octokit } = require("@octokit/rest");

// Initialize a new octokit instance with your GitHub personal access token
const octokit = new Octokit({
  auth: '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'
});

async function copyLabels(sourceOwner, sourceRepo, targetOwner, targetRepo) {
  try {
    // Fetch all labels from the source repository
    const { data: sourceLabels } = await octokit.rest.issues.listLabelsForRepo({
      owner: sourceOwner,
      repo: sourceRepo,
    });

    // Fetch all labels from the target repository to check for duplicates
    const { data: targetLabels } = await octokit.rest.issues.listLabelsForRepo({
      owner: targetOwner,
      repo: targetRepo,
    });
    const targetLabelNames = targetLabels.map(label => label.name);

    for (const label of sourceLabels) {
      // Check if the label already exists in the target repository
      if (!targetLabelNames.includes(label.name)) {
        // Create each label in the target repository
        await octokit.rest.issues.createLabel({
          owner: targetOwner,
          repo: targetRepo,
          name: label.name,
          color: label.color,
          description: label.description,
        });
      } else {
        console.log(`Label "${label.name}" already exists in ${targetOwner}/${targetRepo}. Skipping.`);
      }
    }

    console.log(`Successfully copied labels from ${sourceOwner}/${sourceRepo} to ${targetOwner}/${targetRepo}`);
  } catch (error) {
    console.error('An error occurred:', error);
  }
}

// Replace 'sourceOwner', 'sourceRepo', 'targetOwner', and 'targetRepo' with actual values
copyLabels('FMCalisto', 'github-labels-copy', 'FMCalisto', 'redux-get-started');
